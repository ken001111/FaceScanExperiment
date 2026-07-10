#!/usr/bin/env python
"""Score scene-41069021 ablation arms vs highres laser GT (same world frame).

GT = back-projected highres_depth (Faro mesh) built by gt_from_highres.py.
No global registration needed; per-arm 20mm ICP absorbs residual drift.
Metrics restricted to the laser-observed region: accuracy uses recon points
within 10cm of GT support (crop to GT bbox + margin), completeness is GT->recon.
"""
import json, os, sys
import numpy as np
import open3d as o3d
from scipy.spatial import cKDTree

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import full_stats, fscore

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)

gt = o3d.io.read_point_cloud(GT_PLY)
gt_bb = gt.get_axis_aligned_bounding_box()
gt_bb = o3d.geometry.AxisAlignedBoundingBox(gt_bb.min_bound - 0.10, gt_bb.max_bound + 0.10)
gt_mm = np.asarray(gt.points) * 1000.0
tree_gt = cKDTree(gt_mm)
print(f"GT {len(gt_mm)} pts")

for arm in ["nodepth", "mono", "lidar", "lidarconf", "fused"]:
    out_json = f"{ABLATION}/{arm}/eval_vs_laser.json"
    mesh_path = f"{ABLATION}/{arm}/mesh/tsdf/tsdf_fusion_post.ply"
    if os.path.isfile(out_json):
        print(f"[{arm}] cached"); continue
    if not os.path.isfile(mesh_path):
        print(f"[{arm}] NO MESH - skip"); continue
    mesh = o3d.io.read_triangle_mesh(mesh_path)
    rec = mesh.sample_points_uniformly(1_000_000).crop(gt_bb)
    icp = o3d.pipelines.registration.registration_icp(
        rec, gt, 0.02, np.eye(4),
        o3d.pipelines.registration.TransformationEstimationPointToPoint())
    rec.transform(icp.transformation)
    rec_mm = np.asarray(rec.points) * 1000.0
    d_acc_all = tree_gt.query(rec_mm, workers=-1)[0]
    keep = d_acc_all < 100.0      # laser-observed region only (10cm support)
    d_acc = d_acc_all[keep]
    d_comp = cKDTree(rec_mm).query(gt_mm, workers=-1)[0]
    r = {("acc_" + k): v for k, v in full_stats(d_acc).items()}
    r.update({("comp_" + k): v for k, v in full_stats(d_comp).items()})
    r["chamfer"] = 0.5 * (r["acc_mean"] + r["comp_mean"])
    r.update(fscore(d_acc, d_comp, TAUS_MM))
    r["icp_fitness"] = float(icp.fitness)
    r["support_frac"] = float(keep.mean())
    r["mesh"] = mesh_path
    json.dump(r, open(out_json, "w"), indent=1, default=float)
    print(f"[{arm}] acc={r['acc_mean']:.2f} comp={r['comp_mean']:.2f} chamfer={r['chamfer']:.2f} "
          f"F@10={r['fscore@10.0']:.3f} F@20={r['fscore@20.0']:.3f} "
          f"icp_fit={icp.fitness:.3f} support={keep.mean():.2f}")
