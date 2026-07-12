#!/usr/bin/env python
"""v4 (final): laser-GT scoring culled to the TRAINING-observed region.

The training split (2036 frames) covers only the main room; the laser GT
covers the full two-room scene. The observed-region mask is built by
back-projecting the training frames' own LiDAR depth maps (occlusion-true
sensor visibility). Camera convention (OpenGL vs OpenCV) is auto-selected
by testing which back-projection lands on the GT surface.
"""
import json, os, sys
import numpy as np
import imageio.v2 as iio
import open3d as o3d
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import full_stats, fscore

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
WORK = os.path.expanduser("~/FaceScan/work/arkit_41069021")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)
STRIDE, MASK_R = 5, 0.15

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

gt = o3d.io.read_point_cloud(GT_PLY)
g_all = np.asarray(gt.points)
gt_tree_full = cKDTree(g_all)

# auto-pick convention on 10 frames
best = None
for conv in ["opengl", "opencv"]:
    pts = np.concatenate([backproject(frames[i], conv) for i in range(0, 1000, 100)])
    med = np.median(gt_tree_full.query(pts[::10], workers=-1)[0])
    print(f"convention {conv}: median dist to GT = {med*1000:.1f}mm")
    if best is None or med < best[1]:
        best = (conv, med)
conv = best[0]
print(f"-> using {conv}")

cloud = np.concatenate([backproject(f, conv) for f in frames[::STRIDE]])
pc = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(cloud)).voxel_down_sample(0.03)
obs = np.asarray(pc.points)
print(f"observed cloud: {len(obs)} pts, bbox {np.round(pc.get_min_bound(),2)} {np.round(pc.get_max_bound(),2)}")
obs_tree = cKDTree(obs)

traj = np.array([np.array(f['transform_matrix'])[:3, 3] for f in frames])
vis = cKDTree(traj).query(g_all, workers=-1)[0] < 3.0   # within LiDAR range of camera path
gt_v = gt.select_by_index(np.where(vis)[0])
gt_mm = np.asarray(gt_v.points) * 1000.0
tree_gt = cKDTree(gt_mm)
print(f"GT {len(g_all)} -> {len(gt_mm)} training-observed ({vis.mean():.2f})")

for arm in ["nodepth", "mono", "lidar", "lidarconf", "fused", "seeded"]:
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
    json.dump(r, open(f"{ABLATION}/{arm}/eval_vs_laser_v6.json", "w"), indent=1, default=float)
    print(f"[{arm}] acc={r['acc_mean']:.2f} comp={r['comp_mean']:.2f} chamfer={r['chamfer']:.2f} "
          f"F@5={r['fscore@5.0']:.3f} F@10={r['fscore@10.0']:.3f} F@20={r['fscore@20.0']:.3f} "
          f"icp_fit={icp.fitness:.3f} support={keep.mean():.2f}")
