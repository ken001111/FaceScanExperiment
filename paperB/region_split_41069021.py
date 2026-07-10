#!/usr/bin/env python
"""Split completeness by LiDAR-quality region.

lidar-good = GT points densely covered by high-confidence (conf==2) LiDAR
returns; lidar-poor = observed GT lacking that support. If the fusion
hypothesis holds, fused ~ lidar in lidar-good and fused < lidar (better)
in lidar-poor.
"""
import json, os
import numpy as np
import imageio.v2 as iio
import open3d as o3d
from scipy.spatial import cKDTree

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
WORK = os.path.expanduser("~/FaceScan/work/arkit_41069021")

t = json.load(open(f"{WORK}/transforms_train.json"))
frames = t["frames"]

def backproject(f, step=4, conf_min=None):
    d = iio.imread(os.path.join(WORK, f["depth_png"])).astype(np.float32) / 1000.0
    ok = (d > 0.05) & (d < 4.5)
    if conf_min is not None:
        c = iio.imread(os.path.join(WORK, f["confidence_png"]))
        ok &= (c >= conf_min)
    h, w = d.shape
    fx, fy, cx, cy = f["fl_x"], f["fl_y"], f["cx"], f["cy"]
    v, u = np.mgrid[0:h:step, 0:w:step]
    z, oks = d[::step, ::step], ok[::step, ::step]
    u, v, z = u[oks], v[oks], z[oks]
    Pc = np.stack([(u - cx) / fx * z, -((v - cy) / fy * z), -z], 1)
    T = np.array(f["transform_matrix"])
    return Pc @ T[:3, :3].T + T[:3, 3]

hi = np.concatenate([backproject(f, conf_min=2) for f in frames[::5]])
pc = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(hi)).voxel_down_sample(0.03)
hi_tree = cKDTree(np.asarray(pc.points))
print(f"high-conf lidar cloud: {len(pc.points)} pts")

gt = o3d.io.read_point_cloud(GT_PLY)
g_all = np.asarray(gt.points)
traj = np.array([np.array(f["transform_matrix"])[:3, 3] for f in frames])
in_range = cKDTree(traj).query(g_all, workers=-1)[0] < 3.0
d8 = hi_tree.query(g_all, k=8, workers=-1)[0][:, -1]
good = in_range & (d8 < 0.10)
poor = in_range & ~good
print(f"GT split: lidar-good {good.sum()} ({good.mean():.2f})  lidar-poor {poor.sum()} ({poor.mean():.2f})")

gt_good_mm = g_all[good] * 1000.0
gt_poor_mm = g_all[poor] * 1000.0

print(f"{'arm':10s} {'compGOOD_med':>12s} {'compPOOR_med':>12s} {'compGOOD<20mm':>13s} {'compPOOR<20mm':>13s}")
for arm in ["nodepth", "mono", "lidar", "lidarconf", "fused"]:
    mesh_path = f"{ABLATION}/{arm}/mesh/tsdf/tsdf_fusion_post.ply"
    if not os.path.isfile(mesh_path): continue
    mesh = o3d.io.read_triangle_mesh(mesh_path)
    rec_mm = np.asarray(mesh.sample_points_uniformly(1_000_000).points) * 1000.0
    tree_rec = cKDTree(rec_mm)
    dg = tree_rec.query(gt_good_mm, workers=-1)[0]
    dp = tree_rec.query(gt_poor_mm, workers=-1)[0]
    out = {"comp_good_med": float(np.median(dg)), "comp_poor_med": float(np.median(dp)),
           "comp_good_rec20": float((dg < 20).mean()), "comp_poor_rec20": float((dp < 20).mean())}
    json.dump(out, open(f"{ABLATION}/{arm}/region_split.json", "w"), indent=1)
    print(f"{arm:10s} {out['comp_good_med']:10.1f}mm {out['comp_poor_med']:10.1f}mm "
          f"{out['comp_good_rec20']:12.3f} {out['comp_poor_rec20']:12.3f}")
