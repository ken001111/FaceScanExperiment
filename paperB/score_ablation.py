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
from eval_common import full_stats, fscore

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


def _floor_z(z, res=0.02):
    """Dominant low height = floor (histogram peak in the bottom 30%)."""
    lo, hi = np.percentile(z, [0.5, 99.5])
    edges = np.arange(lo, lo + (hi - lo) * 0.3 + res, res)
    h, e = np.histogram(z, bins=edges)
    return float(e[np.argmax(h)])


def _occupancy(xy, res=0.05, bbox=None):
    if bbox is None:
        bbox = (xy.min(0) - 0.5, xy.max(0) + 0.5)
    ij = np.floor((xy - bbox[0]) / res).astype(int)
    shape = np.floor((bbox[1] - bbox[0]) / res).astype(int) + 1
    ok = (ij >= 0).all(1) & (ij < shape).all(1)
    m = np.zeros(shape, np.float32)
    m[ij[ok, 0], ij[ok, 1]] = 1.0
    return m, bbox


def register_arkit_to_site(gt):
    """Gravity-aware 4DOF registration: ARKit(y-up) -> Faro site frame (z-up).

    Floor-height match fixes tz; exhaustive yaw x FFT cross-correlation of
    wall-band occupancy maps fixes (yaw, tx, ty); point-to-plane ICP refines.
    Deterministic - no RANSAC.
    """
    from scipy.signal import fftconvolve
    t_path = f"{CACHE}/T_arkit_to_site.txt"
    if os.path.isfile(t_path):
        return np.loadtxt(t_path)
    mesh = o3d.io.read_triangle_mesh(f"{SCENE_DIR}/47331963_3dod_mesh.ply")
    src_pc = mesh.sample_points_uniformly(400_000)
    P = np.asarray(src_pc.points)
    R_up = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)  # y-up -> z-up
    P = P @ R_up.T
    G = np.asarray(gt.voxel_down_sample(0.05).points)

    fz_src, fz_gt = _floor_z(P[:, 2]), _floor_z(G[:, 2])
    dz = fz_gt - fz_src
    P[:, 2] += dz
    band = lambda Q, fz: Q[(Q[:, 2] > fz + 0.3) & (Q[:, 2] < fz + 2.2)]
    Pb, Gb = band(P, fz_gt), band(G, fz_gt)
    res = 0.05
    gt_map, gt_bbox = _occupancy(Gb[:, :2], res)

    best = (-1.0, 0.0, 0, 0)   # score, yaw, di, dj
    ctr = Pb[:, :2].mean(0)
    for yaw_deg in range(0, 360, 2):
        a = np.radians(yaw_deg)
        R2 = np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
        xy = (Pb[:, :2] - ctr) @ R2.T
        src_map, _ = _occupancy(xy, res, (xy.min(0) - 0.25, xy.max(0) + 0.25))
        corr = fftconvolve(gt_map, src_map[::-1, ::-1], mode="full")
        k = np.unravel_index(np.argmax(corr), corr.shape)
        off = np.array(k) - (np.array(src_map.shape) - 1)
        if corr[k] > best[0]:
            best = (float(corr[k]), a, off[0], off[1])
    score, a, di, dj = best
    R2 = np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
    # src cell (0,0) after rotation maps to gt cell (di,dj)
    xy0 = ((Pb[:, :2] - ctr) @ R2.T).min(0) - 0.25
    t2 = gt_bbox[0] + np.array([di, dj]) * res - xy0
    print(f"  yaw-search: yaw={np.degrees(a):.0f}deg score={score:.0f}")

    T = np.eye(4)
    T[:2, :2] = R2
    T[:3, 3] = [*(t2 - R2 @ ctr), dz]
    T = T @ np.block([[R_up, np.zeros((3, 1))], [np.zeros((1, 3)), 1]])

    src_chk = o3d.geometry.PointCloud(src_pc)
    for dist in (0.10, 0.03, 0.012):
        icp = o3d.pipelines.registration.registration_icp(
            src_chk, gt, dist, T,
            o3d.pipelines.registration.TransformationEstimationPointToPoint())
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
    mesh_3dod = o3d.io.read_triangle_mesh(f"{SCENE_DIR}/47331963_3dod_mesh.ply")
    src_check = mesh_3dod.sample_points_uniformly(100_000)
    src_check.transform(T)
    for d in (0.05, 0.02):
        ev = o3d.pipelines.registration.evaluate_registration(src_check, gt, d)
        print(f"  registration check @{d*1000:.0f}mm: fitness={ev.fitness:.3f} rmse={ev.inlier_rmse*1000:.1f}mm")
    gt_room = crop_gt_to_scene(gt, T)
    print(f"  gt cropped to room: {len(gt_room.points)} pts")
    gt_mm = np.asarray(gt_room.points) * 1000.0

    print("[3/3] arms")
    for arm in args.arms:
        mdir = f"{ABLATION}/{arm}"
        out_json = f"{mdir}/eval_vs_faro.json"
        if os.path.isfile(out_json):
            print(f"  [{arm}] cached"); continue
        # cluster-filtered TSDF mesh written by mesh_extract/tsdf_mesh.py
        mesh_path = f"{mdir}/mesh/tsdf/tsdf_fusion_post.ply"
        if not os.path.isfile(mesh_path):
            print(f"  [{arm}] NO MESH - skip"); continue
        mesh = o3d.io.read_triangle_mesh(mesh_path)
        mesh.transform(T)
        rec = mesh.sample_points_uniformly(1_000_000)
        # per-arm rigid refine onto the laser GT (20mm), then point-to-point NN
        icp = o3d.pipelines.registration.registration_icp(
            rec, gt_room, 0.02, np.eye(4),
            o3d.pipelines.registration.TransformationEstimationPointToPoint())
        rec.transform(icp.transformation)
        rec_mm = np.asarray(rec.points) * 1000.0
        from scipy.spatial import cKDTree
        d_acc = cKDTree(gt_mm).query(rec_mm, workers=-1)[0]     # recon -> GT
        d_comp = cKDTree(rec_mm).query(gt_mm, workers=-1)[0]    # GT -> recon
        r = {("acc_" + k): v for k, v in full_stats(d_acc).items()}
        r.update({("comp_" + k): v for k, v in full_stats(d_comp).items()})
        r["chamfer"] = 0.5 * (r["acc_mean"] + r["comp_mean"])
        r.update(fscore(d_acc, d_comp, TAUS_MM))
        r["icp_fitness"] = float(icp.fitness)
        r["mesh"] = mesh_path
        json.dump(r, open(out_json, "w"), indent=1, default=float)
        print(f"  [{arm}] acc_mean={r['acc_mean']:.2f}mm comp_mean={r['comp_mean']:.2f}mm "
              f"chamfer={r['chamfer']:.2f}mm F@20mm={r['fscore@20.0']:.3f} icp_fit={icp.fitness:.3f}")


if __name__ == "__main__":
    main()
