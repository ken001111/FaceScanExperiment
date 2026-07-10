#!/usr/bin/env python
"""v2: laser-GT scoring with camera-frustum visibility culling (ScanNet-style).

Fixes v1 artifacts: (a) GT covers a second, never-visited room -> cull GT to
points seen by >=1 camera; (b) laser GT lacks the ceiling -> keep v1's
100mm-support crop on accuracy; (c) cull recon samples by the same frustums
so out-of-view fog wings don't dominate accuracy.
"""
import json, os, sys
import numpy as np
import torch
import open3d as o3d
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import full_stats, fscore

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
TRANSFORMS = os.path.expanduser("~/FaceScan/work/arkit_41069021/transforms_train.json")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)
CAM_STRIDE, NEAR, FAR = 10, 0.05, 4.5
dev = "cuda" if torch.cuda.is_available() else "cpu"

t = json.load(open(TRANSFORMS))
frames = t["frames"][::CAM_STRIDE]
w2c, tanx, tany = [], [], []
for f in frames:
    T = np.array(f["transform_matrix"], dtype=np.float64)
    w2c.append(np.linalg.inv(T))
    tanx.append(np.tan(f["camera_angle_x"] / 2))
    tany.append(np.tan(f["camera_angle_y"] / 2))
w2c = torch.tensor(np.stack(w2c), dtype=torch.float32, device=dev)          # [C,4,4]
tanx = torch.tensor(tanx, dtype=torch.float32, device=dev)[None]           # [1,C]
tany = torch.tensor(tany, dtype=torch.float32, device=dev)[None]
print(f"{len(frames)} cameras for visibility culling")

def visible(pts_np, chunk=200_000):
    keep = np.zeros(len(pts_np), dtype=bool)
    R = w2c[:, :3, :3]; tr = w2c[:, :3, 3]                                  # [C,3,3],[C,3]
    for i in range(0, len(pts_np), chunk):
        P = torch.tensor(pts_np[i:i+chunk], dtype=torch.float32, device=dev)  # [N,3]
        Pc = torch.einsum("cij,nj->nci", R, P) + tr[None]                   # [N,C,3]
        zf = -Pc[..., 2]                                                    # forward depth (OpenGL/ARKit: -Z fwd)
        inb = (zf > NEAR) & (zf < FAR) \
            & (Pc[..., 0].abs() / zf.clamp(min=1e-6) < tanx) \
            & (Pc[..., 1].abs() / zf.clamp(min=1e-6) < tany)
        keep[i:i+chunk] = inb.any(1).cpu().numpy()
    return keep

gt = o3d.io.read_point_cloud(GT_PLY)
g_all = np.asarray(gt.points)
vis_gt = visible(g_all)
gt_v = gt.select_by_index(np.where(vis_gt)[0])
gt_mm = np.asarray(gt_v.points) * 1000.0
tree_gt = cKDTree(gt_mm)
print(f"GT {len(g_all)} pts -> {len(gt_mm)} visible ({vis_gt.mean():.2f})")

for arm in ["nodepth", "mono", "lidar", "lidarconf", "fused"]:
    mesh_path = f"{ABLATION}/{arm}/mesh/tsdf/tsdf_fusion_post.ply"
    if not os.path.isfile(mesh_path):
        print(f"[{arm}] NO MESH - skip"); continue
    mesh = o3d.io.read_triangle_mesh(mesh_path)
    rec = mesh.sample_points_uniformly(1_000_000)
    r_all = np.asarray(rec.points)
    rec = rec.select_by_index(np.where(visible(r_all))[0])
    icp = o3d.pipelines.registration.registration_icp(
        rec, gt_v, 0.02, np.eye(4),
        o3d.pipelines.registration.TransformationEstimationPointToPoint())
    rec.transform(icp.transformation)
    rec_mm = np.asarray(rec.points) * 1000.0
    d_acc_all = tree_gt.query(rec_mm, workers=-1)[0]
    keep = d_acc_all < 100.0            # laser-support crop (GT lacks ceiling)
    d_acc = d_acc_all[keep]
    d_comp = cKDTree(rec_mm).query(gt_mm, workers=-1)[0]
    r = {("acc_" + k): v for k, v in full_stats(d_acc).items()}
    r.update({("comp_" + k): v for k, v in full_stats(d_comp).items()})
    r["chamfer"] = 0.5 * (r["acc_mean"] + r["comp_mean"])
    r.update(fscore(d_acc, d_comp, TAUS_MM))
    r["icp_fitness"] = float(icp.fitness)
    r["support_frac"] = float(keep.mean())
    r["mesh"] = mesh_path
    json.dump(r, open(f"{ABLATION}/{arm}/eval_vs_laser_v2.json", "w"), indent=1, default=float)
    print(f"[{arm}] acc={r['acc_mean']:.2f} comp={r['comp_mean']:.2f} chamfer={r['chamfer']:.2f} "
          f"F@10={r['fscore@10.0']:.3f} F@20={r['fscore@20.0']:.3f} "
          f"icp_fit={icp.fitness:.3f} support={keep.mean():.2f}")
