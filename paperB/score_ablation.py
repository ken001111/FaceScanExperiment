#!/usr/bin/env python
"""Score Paper B depth-source ablation arms vs ARKitScenes Faro laser GT.

Stages (each cached by artifact guard):
  1. Build GT cloud: laser scans + site-frame poses -> downsampled crop cache.
  2. Register ARKit world -> laser site frame once, using the 3dod mesh
     (FPFH RANSAC global init + point-to-plane ICP refine).
  3. Per arm: transform recon mesh into GT frame, evaluate_full in mm with
     room-scale taus (5/10/20/50 mm), write JSON next to the mesh.

All geometry is metric metres on disk; evaluation converts to mm.
"""
import argparse, json, os, sys
import numpy as np
import open3d as o3d

sys.path.insert(0, os.path.expanduser("~/pe_verify/common"))
from eval_common import evaluate_full

LASER_DIR = os.path.expanduser("~/FaceScan/data/arkit/laser_scanner_point_clouds/470831")
SCENE_DIR = os.path.expanduser("~/FaceScan/data/arkit/raw/Validation/47331963")
ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation")
CACHE = os.path.expanduser("~/FaceScan/paperB/gt_cache")
TAUS_MM = (5.0, 10.0, 20.0, 50.0)


def load_laser_site_frame(scan_id):
    """Laser ply + its 4x4 pose (row-vector convention: p' = p @ M)."""
    pc = o3d.io.read_point_cloud(f"{LASER_DIR}/{scan_id}.ply")
    M = np.loadtxt(f"{LASER_DIR}/{scan_id}_pose.txt", delimiter=",")
    pc.transform(M.T)          # row-vector matrix -> standard column transform
    return pc


def build_gt():
    os.makedirs(CACHE, exist_ok=True)
    gt_path = f"{CACHE}/gt_470831_5mm.ply"
    if os.path.isfile(gt_path):
        return o3d.io.read_point_cloud(gt_path)
    scans = [s.replace("_pose.txt", "") for s in os.listdir(LASER_DIR) if s.endswith("_pose.txt")]
    merged = o3d.geometry.PointCloud()
    for s in sorted(scans):
        if not os.path.isfile(f"{LASER_DIR}/{s}.ply"):
            continue
        pc = load_laser_site_frame(s).voxel_down_sample(0.005)
        merged += pc
        print(f"  laser {s}: {len(pc.points)} pts (5mm)")
    merged = merged.voxel_down_sample(0.005)
    o3d.io.write_point_cloud(gt_path, merged)
    return merged


def register_arkit_to_site(gt):
    """One transform for the whole scene, from the ARKit 3dod mesh."""
    t_path = f"{CACHE}/T_arkit_to_site.txt"
    if os.path.isfile(t_path):
        return np.loadtxt(t_path)
    mesh = o3d.io.read_triangle_mesh(f"{SCENE_DIR}/47331963_3dod_mesh.ply")
    src = mesh.sample_points_uniformly(400_000)

    def prep(pc, vox):
        p = pc.voxel_down_sample(vox)
        p.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(vox * 2.5, 30))
        f = o3d.pipelines.registration.compute_fpfh_feature(
            p, o3d.geometry.KDTreeSearchParamHybrid(vox * 5, 100))
        return p, f

    vox = 0.05
    s, sf = prep(src, vox)
    g, gf = prep(gt, vox)
    res = o3d.pipelines.registration.registration_ransac_based_on_feature_matching(
        s, g, sf, gf, mutual_filter=True, max_correspondence_distance=vox * 1.5,
        estimation_method=o3d.pipelines.registration.TransformationEstimationPointToPoint(False),
        ransac_n=3,
        checkers=[o3d.pipelines.registration.CorrespondenceCheckerBasedOnEdgeLength(0.9),
                  o3d.pipelines.registration.CorrespondenceCheckerBasedOnDistance(vox * 1.5)],
        criteria=o3d.pipelines.registration.RANSACConvergenceCriteria(400_000, 0.9999))
    print(f"  RANSAC fitness={res.fitness:.3f} rmse={res.inlier_rmse*1000:.1f}mm")
    T = res.transformation
    for dist in (0.05, 0.02, 0.008):
        g.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(dist * 3, 30))
        icp = o3d.pipelines.registration.registration_icp(
            s, g, dist, T,
            o3d.pipelines.registration.TransformationEstimationPointToPlane())
        T = icp.transformation
        print(f"  ICP@{dist*1000:.0f}mm fitness={icp.fitness:.3f} rmse={icp.inlier_rmse*1000:.1f}mm")
    np.savetxt(t_path, T)
    return T


def crop_gt_to_scene(gt, T):
    """Room-only GT: 3dod mesh bbox (in site frame) + margin."""
    mesh = o3d.io.read_triangle_mesh(f"{SCENE_DIR}/47331963_3dod_mesh.ply")
    mesh.transform(T)
    bb = mesh.get_axis_aligned_bounding_box()
    bb = o3d.geometry.AxisAlignedBoundingBox(bb.min_bound - 0.10, bb.max_bound + 0.10)
    return gt.crop(bb)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--arms", nargs="+",
                    default=["nodepth", "mono", "lidar", "lidarconf"])
    ap.add_argument("--mesh_name", default="tsdf_fusion.ply")
    args = ap.parse_args()

    print("[1/3] GT cloud")
    gt = build_gt()
    print(f"  gt: {len(gt.points)} pts")
    print("[2/3] ARKit->site registration")
    T = register_arkit_to_site(gt)
    gt_room = crop_gt_to_scene(gt, T)
    print(f"  gt cropped to room: {len(gt_room.points)} pts")
    gt_mm = np.asarray(gt_room.points) * 1000.0

    print("[3/3] arms")
    for arm in args.arms:
        mdir = f"{ABLATION}/{arm}"
        out_json = f"{mdir}/eval_vs_faro.json"
        if os.path.isfile(out_json):
            print(f"  [{arm}] cached"); continue
        # find the extracted mesh (tsdf_mesh.py writes under mesh/)
        cands = []
        for root, _, files in os.walk(mdir):
            cands += [os.path.join(root, f) for f in files if f.endswith(".ply")]
        if not cands:
            print(f"  [{arm}] NO MESH - skip"); continue
        mesh_path = max(cands, key=os.path.getmtime)
        mesh = o3d.io.read_triangle_mesh(mesh_path)
        mesh.transform(T)
        pts_mm = np.asarray(mesh.sample_points_uniformly(1_000_000).points) * 1000.0
        r = evaluate_full(pts_mm, gt_mm, align=True, icp_threshold_mm=20.0,
                          taus=TAUS_MM)
        r["mesh"] = mesh_path
        r.pop("T", None)
        json.dump(r, open(out_json, "w"), indent=1, default=float)
        print(f"  [{arm}] acc_mean={r['acc_mean']:.2f}mm comp_mean={r['comp_mean']:.2f}mm "
              f"chamfer={r['chamfer']:.2f}mm F@20mm={r['fscore@20.0']:.3f}")


if __name__ == "__main__":
    main()
