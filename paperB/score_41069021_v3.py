#!/usr/bin/env python
"""v3: laser-GT scoring culled to the sensor-observed region.

GT is culled to points within 15cm of the back-projected LiDAR cloud
(points3d.ply, built from the same poses as training) — this encodes true
visibility including occlusion (the never-visited second room drops out;
the through-doorway strip the LiDAR did see stays in). Accuracy keeps the
100mm laser-support crop (GT lacks the ceiling); support_frac reports the
kept fraction (lower = more fog/out-of-region geometry).
"""
import json, os, sys
import numpy as np
import open3d as o3d
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import full_stats, fscore

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
LIDAR_PLY = os.path.expanduser("~/FaceScan/work/arkit_41069021/points3d.ply")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)

lid = o3d.io.read_point_cloud(LIDAR_PLY)
lid_tree = cKDTree(np.asarray(lid.points))
gt = o3d.io.read_point_cloud(GT_PLY)
g_all = np.asarray(gt.points)
vis = lid_tree.query(g_all, workers=-1)[0] < 0.15
gt_v = gt.select_by_index(np.where(vis)[0])
gt_mm = np.asarray(gt_v.points) * 1000.0
tree_gt = cKDTree(gt_mm)
print(f"GT {len(g_all)} -> {len(gt_mm)} sensor-observed ({vis.mean():.2f})")

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
    json.dump(r, open(f"{ABLATION}/{arm}/eval_vs_laser_v3.json", "w"), indent=1, default=float)
    print(f"[{arm}] acc={r['acc_mean']:.2f} comp={r['comp_mean']:.2f} chamfer={r['chamfer']:.2f} "
          f"F@5={r['fscore@5.0']:.3f} F@10={r['fscore@10.0']:.3f} F@20={r['fscore@20.0']:.3f} "
          f"icp_fit={icp.fitness:.3f} support={keep.mean():.2f}")
