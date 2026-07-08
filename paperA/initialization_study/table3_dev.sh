#!/bin/bash
# Table 3 (dev-data edition): init study scored against the raw-LiDAR sensor
# mesh as proxy reference (Artec Leo replaces it later; documented).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import sys, os, re, glob, json
sys.path.insert(0, os.path.expanduser("~/pe_verify"))
from common.eval_common import evaluate_full
REF = os.path.expanduser("~/FaceScan/paperA/meshes/raw_lidar_ken.ply")
RESULTS = os.path.expanduser("~/FaceScan/results")
LOGS = os.path.expanduser("~/FaceScan/initstudy")
rows = []
for init in ("sfm", "random", "lidar"):
    cands = sorted(glob.glob(f"{RESULTS}/Face_Mesh_MetricScale_ken_{init}_nn.ply"))
    if not cands:
        cands = sorted(glob.glob(f"{LOGS}/out_ken_{init}/train/ours_*/fuse_post.ply"))
    if not cands:
        print(f"{init}: NO MESH"); continue
    mesh = cands[0]
    # paper-style alignment: centroid shift, then ICP with decaying threshold,
    # then crop recon to the face-reference region before scoring
    import numpy as np, open3d as o3d
    from common.eval_common import load_mesh, as_points, apply_T, point_to_mesh_mm, rigid_align
    rm = load_mesh(mesh); ref = load_mesh(REF)
    pts = as_points(rm, 200_000)
    ref_pts = as_points(ref, 200_000)
    pts = pts + (ref_pts.mean(0) - pts.mean(0))[None]          # centroid init
    for thr in (20.0, 10.0, 5.0, 2.0):                          # decaying ICP
        T = rigid_align(pts, ref_pts, threshold_mm=thr)
        pts = apply_T(pts, T)
    d0 = point_to_mesh_mm(pts, ref)
    keep = d0 < 15.0                                            # face-region crop
    pts = pts[keep]
    for thr in (5.0, 2.0):                                      # refine on face only
        T = rigid_align(pts, ref_pts, threshold_mm=thr)
        pts = apply_T(pts, T)
    d_acc = point_to_mesh_mm(pts, ref)
    from common.eval_common import full_stats, fscore
    # completeness: reference -> cropped recon points
    pcd_r = o3d.geometry.PointCloud(); pcd_r.points = o3d.utility.Vector3dVector(pts)
    kd = o3d.geometry.KDTreeFlann(pcd_r)
    d_comp = np.array([np.sqrt(kd.search_knn_vector_3d(q,1)[2][0]) for q in ref_pts[::4]])
    m = {("acc_"+k): v for k, v in full_stats(d_acc).items()}
    m["chamfer"] = 0.5*(d_acc.mean()+d_comp.mean())
    m.update(fscore(d_acc, d_comp))
    # run stats from train log
    log = f"{LOGS}/out_ken_{init}.train.log"
    txt = open(log, errors="ignore").read().replace("\r", "\n") if os.path.isfile(log) else ""
    ipts = re.findall(r"initialisation :\s*([0-9]+)", txt)
    fpts = re.findall(r"Points=([0-9]+)", txt)
    rows.append(dict(init=init, mesh=os.path.basename(mesh),
                     init_pts=ipts[-1] if ipts else "?",
                     final_pts=fpts[-1] if fpts else "?",
                     rms=round(m["acc_rms"], 3), chamfer=round(m["chamfer"], 3),
                     f1mm=round(m["fscore@1.0"], 3),
                     pct1mm=round(m["acc_pct_under_1mm"], 1)))
print()
print("Table 3 (dev proxy: vs raw-LiDAR sensor mesh, mm)")
print(f"{'init':8} {'init_pts':>9} {'final_pts':>10} {'RMS':>7} {'chamfer':>8} {'F@1mm':>6} {'%<1mm':>6}")
for r in rows:
    print(f"{r['init']:8} {r['init_pts']:>9} {r['final_pts']:>10} {r['rms']:>7} {r['chamfer']:>8} {r['f1mm']:>6} {r['pct1mm']:>6}")
out = os.path.expanduser("~/FaceScan/paperA/table3_dev.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(rows, open(out, "w"), indent=2)
print("saved:", out)
PY
