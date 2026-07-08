#!/bin/bash
# §0 validation: reproduce DTU scan24 numbers with the shared library and
# compare against the official evaluator's results (GeoSVR 0.321, 2DGS 0.504).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser("~/pe_verify"))
from common.eval_common import evaluate_full, load_mesh
import open3d as o3d, numpy as np

GT = os.path.expanduser("~/FaceScan/data/DTU/Points/stl/stl024_total.ply")
gt_pcd = o3d.io.read_point_cloud(GT)
print("GT points:", len(gt_pcd.points))
# The stl GT is a point cloud; build a reference mesh via Poisson for point-to-surface,
# or evaluate point-to-point. For validation we mirror the official direction logic
# with point-to-point NN distances against the dense GT cloud (2.4M pts).
from common.eval_common import as_points, rigid_align, apply_T

def nn_dist(a, b_kd, b_pts):
    d = []
    for q in a:
        _, idx, d2 = b_kd.search_knn_vector_3d(q, 1)
        d.append(np.sqrt(d2[0]))
    return np.asarray(d)

CASES = {
  "geosvr_scan24 (official 0.321)": "~/FaceScan/bench/geosvr/scan24/mesh/tsdf/tsdf_fusion_post.ply",
  "2dgs_scan24 (official 0.504)":  "~/FaceScan/bench/2dgs/scan24/train/ours_30000/fuse_post.ply",
}
gt_pts = np.asarray(gt_pcd.points)
gt_kd = o3d.geometry.KDTreeFlann(gt_pcd)
rng = np.random.default_rng(0)
gt_sub = gt_pts[rng.choice(len(gt_pts), 100_000, replace=False)]

for name, path in CASES.items():
    p = os.path.expanduser(path)
    if not os.path.isfile(p): print("MISSING", name); continue
    mesh = load_mesh(p)
    # official eval maps the normalized-world mesh into GT coords via scale_mat
    cam = np.load(os.path.expanduser("~/FaceScan/data/DTU_2dgs/scan24/cameras.npz"))
    S = cam["scale_mat_0"]
    v = np.asarray(mesh.vertices)
    mesh.vertices = o3d.utility.Vector3dVector(v * S[0, 0] + S[:3, 3][None])
    pts = np.asarray(mesh.sample_points_uniformly(100_000).points)
    # now in DTU GT coords (mm); NO ICP (official eval doesn't align)
    pcd_m = o3d.geometry.PointCloud(); pcd_m.points = o3d.utility.Vector3dVector(pts)
    kd_m = o3d.geometry.KDTreeFlann(pcd_m)
    d_acc = nn_dist(pts, gt_kd, gt_pts)          # recon -> GT
    d_comp = nn_dist(gt_sub, kd_m, pts)          # GT -> recon
    # official caps distances at 20 to reduce unmasked-region effect
    d_acc_c = np.minimum(d_acc, 20.0); d_comp_c = np.minimum(d_comp, 20.0)
    print(f"{name}: acc={d_acc_c.mean():.3f} comp={d_comp_c.mean():.3f} "
          f"chamfer={(0.5*(d_acc_c.mean()+d_comp_c.mean())):.3f}")
print("NOTE: official eval uses ObsMask culling; our library omits it, so values sit")
print("slightly above official. Validation passes if ordering + magnitude match.")
PY
