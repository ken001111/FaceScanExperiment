#!/bin/bash
# Library validation round 2: score the officially-CULLED meshes with our
# library (+ObsMask observability filter) and compare to official results.json.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import os, json
import numpy as np, open3d as o3d
from scipy.io import loadmat

CASES = {
  "geosvr": ("~/FaceScan/bench/geosvr/scan24/mesh/tsdf/culled_mesh.ply",
             "~/FaceScan/bench/geosvr/scan24/mesh/tsdf/results.json"),
  "2dgs":   ("~/FaceScan/bench/2dgs/eval_scan24/culled_mesh.ply",
             "~/FaceScan/bench/2dgs/eval_scan24/results.json"),
}
GT = os.path.expanduser("~/FaceScan/data/DTU/Points/stl/stl024_total.ply")
OBS = os.path.expanduser("~/FaceScan/data/DTU/ObsMask/ObsMask24_10.mat")
gt = o3d.io.read_point_cloud(GT)
gt_pts = np.asarray(gt.points)
obs = loadmat(OBS)
mask, BB, res = obs["ObsMask"], obs["BB"], float(np.asarray(obs["Res"]).squeeze())
print("ObsMask:", mask.shape, "BB:", BB, "Res:", res)

def in_obs(pts):
    idx = np.floor((pts - BB[0:1]) / res).astype(int)
    ok = np.all((idx >= 0) & (idx < np.array(mask.shape)[None]), axis=1)
    good = np.zeros(len(pts), bool)
    good[ok] = mask[idx[ok,0], idx[ok,1], idx[ok,2]] > 0
    return good

rng = np.random.default_rng(0)
gt_kd = o3d.geometry.KDTreeFlann(gt)

for name, (mp, rj) in CASES.items():
    mesh = o3d.io.read_triangle_mesh(os.path.expanduser(mp))
    official = json.load(open(os.path.expanduser(rj)))
    pts = np.asarray(mesh.sample_points_uniformly(150_000).points)
    keep = in_obs(pts)
    pts = pts[keep]
    d_acc = np.array([np.sqrt(gt_kd.search_knn_vector_3d(q,1)[2][0]) for q in pts])
    d_acc = np.minimum(d_acc, 20.0)
    # completeness: GT -> culled mesh (GT already restricted to plane/obs by protocol)
    plane = loadmat(os.path.expanduser("~/FaceScan/data/DTU/ObsMask/Plane24.mat"))["P"]
    gt_sub = gt_pts[rng.choice(len(gt_pts), 200_000, replace=False)]
    hom = np.c_[gt_sub, np.ones(len(gt_sub))]
    above = (hom @ plane.reshape(4)) > 0
    gt_sub = gt_sub[above & in_obs(gt_sub)]
    print(f"  GT kept after plane+obs: {len(gt_sub)}")
    pm = o3d.geometry.PointCloud(); pm.points = o3d.utility.Vector3dVector(np.asarray(mesh.sample_points_uniformly(1_000_000).points))
    km = o3d.geometry.KDTreeFlann(pm)
    d_comp = np.array([np.sqrt(km.search_knn_vector_3d(q,1)[2][0]) for q in gt_sub])
    d_comp = np.minimum(d_comp, 20.0)
    ours = 0.5*(d_acc.mean()+d_comp.mean())
    print(f"{name}: ours acc={d_acc.mean():.3f} comp={d_comp.mean():.3f} chamfer={ours:.3f} | official={official}")
PY


