#!/usr/bin/env python
"""PROXY scoring for scene 47331963: reference = ARKit on-device 3dod mesh.

47331963 is not in the ARKitScenes upsampling split (no highres laser-rendered
depth) and direct Faro-mesh registration failed (register_v3 negative result),
so the only available reference surface is the on-device ARKit mesh. Numbers
are cross-method AGREEMENT with the ARKit reconstruction (~cm-grade), not
laser accuracy — same caveat class as ken's 2DGS-proxy scoring.

Protocol otherwise mirrors score_41069021_v6.py: convention auto-pick,
traversal-region crop (GT within 3 m of camera path), fine ICP, 100 mm
support crop, full_stats + F-scores.
"""
import json, os, sys
import numpy as np
import imageio.v2 as iio
import open3d as o3d
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import full_stats, fscore

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation")
GT_MESH = os.path.expanduser(
    "~/FaceScan/data/arkit/raw/Validation/47331963/47331963_3dod_mesh.ply")
WORK = os.path.expanduser("~/FaceScan/work/arkit_47331963")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)
STRIDE = 5
SANITY_MM = 200.0   # abort if even the best convention lands this far off

t = json.load(open(f"{WORK}/transforms_train.json"))
frames = t["frames"]

def backproject(f, conv, step=4):
    d = iio.imread(os.path.join(WORK, f["depth_png"])).astype(np.float32) / 1000.0
    h, w = d.shape
    fx, fy, cx, cy = f["fl_x"], f["fl_y"], f["cx"], f["cy"]
    v, u = np.mgrid[0:h:step, 0:w:step]
    z = d[::step, ::step]
    ok = (z > 0.05) & (z < 4.5)
    u, v, z = u[ok], v[ok], z[ok]
    x = (u - cx) / fx * z
    y = (v - cy) / fy * z
    if conv == "opengl":          # +X right, +Y up, -Z forward
        Pc = np.stack([x, -y, -z], 1)
    else:                          # opencv: +X right, +Y down, +Z forward
        Pc = np.stack([x, y, z], 1)
    T = np.array(f["transform_matrix"])
    return Pc @ T[:3, :3].T + T[:3, 3]

gt_mesh = o3d.io.read_triangle_mesh(GT_MESH)
gt = gt_mesh.sample_points_uniformly(3_000_000)
g_all = np.asarray(gt.points)
gt_tree_full = cKDTree(g_all)
print(f"ARKit mesh: {len(gt_mesh.vertices)} verts -> {len(g_all)} sampled pts")

# auto-pick convention on ~10 spread frames
best = None
for conv in ["opengl", "opencv"]:
    idx = range(0, len(frames), max(1, len(frames) // 10))
    pts = np.concatenate([backproject(frames[i], conv) for i in idx])
    med = np.median(gt_tree_full.query(pts[::10], workers=-1)[0])
    print(f"convention {conv}: median dist to ARKit mesh = {med*1000:.1f}mm")
    if best is None or med < best[1]:
        best = (conv, med)
conv, med = best
if med * 1000 > SANITY_MM:
    sys.exit(f"FRAME MISMATCH: best convention ({conv}) still {med*1000:.0f}mm "
             f"from ARKit mesh — workdir and 3dod mesh do not share a world "
             f"frame; do NOT score against it.")
print(f"-> using {conv} (sanity {med*1000:.1f}mm)")

traj = np.array([np.array(f['transform_matrix'])[:3, 3] for f in frames])
vis = cKDTree(traj).query(g_all, workers=-1)[0] < 3.0   # traversal-region crop
gt_v = gt.select_by_index(np.where(vis)[0])
gt_mm = np.asarray(gt_v.points) * 1000.0
tree_gt = cKDTree(gt_mm)
print(f"GT {len(g_all)} -> {len(gt_mm)} traversal-region ({vis.mean():.2f})")

for arm in ["nodepth", "mono", "lidar", "lidarconf", "fused"]:
    mesh_path = f"{ABLATION}/{arm}/mesh/tsdf/tsdf_fusion_post.ply"
    if not os.path.isfile(mesh_path):
        print(f"[{arm}] NO MESH - skip"); continue
    mesh = o3d.io.read_triangle_mesh(mesh_path)
    rec = mesh.sample_points_uniformly(1_000_000)
    icp = o3d.pipelines.registration.registration_icp(
        rec, gt_v, 0.02, np.eye(4),
        o3d.pipelines.registration.TransformationEstimationPointToPoint())
    rec.transform(icp.transformation)
    rec_mm = np.asarray(rec.points) * 1000.0
    d_acc_all = tree_gt.query(rec_mm, workers=-1)[0]
    keep = d_acc_all < 100.0            # support crop (fog robustness)
    d_acc = d_acc_all[keep]
    d_comp = cKDTree(rec_mm).query(gt_mm, workers=-1)[0]
    r = {("acc_" + k): v for k, v in full_stats(d_acc).items()}
    r.update({("comp_" + k): v for k, v in full_stats(d_comp).items()})
    r["chamfer"] = 0.5 * (r["acc_mean"] + r["comp_mean"])
    r.update(fscore(d_acc, d_comp, TAUS_MM))
    r["icp_fitness"] = float(icp.fitness)
    r["support_frac"] = float(keep.mean())
    r["mesh"] = mesh_path
    r["reference"] = "arkit_3dod_mesh (PROXY, not laser)"
    json.dump(r, open(f"{ABLATION}/{arm}/eval_vs_arkitmesh.json", "w"),
              indent=1, default=float)
    print(f"[{arm}] acc={r['acc_mean']:.2f} comp={r['comp_mean']:.2f} "
          f"chamfer={r['chamfer']:.2f} F@10={r['fscore@10.0']:.3f} "
          f"F@20={r['fscore@20.0']:.3f} icp_fit={icp.fitness:.3f} "
          f"support={keep.mean():.2f}")
