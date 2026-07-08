#!/bin/bash
# Paper A M4: the missing SfM (COLMAP) arm of the init study.
# Mirrors init_study.sh exactly (10k iters, -r 2, white bg, finish_mesh.py),
# differing only in the seed: COLMAP known-pose triangulated points.
set -u
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
PY="$HOME/miniconda3/envs/facescan/bin/python"
OUT=~/FaceScan/initstudy
KEN='/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped'

# --- stage 1 (CPU): prep dedicated root + COLMAP triangulation ---
DR=~/FaceScan/work/ken_initstudy
if [ ! -f "$DR/transforms_train.json" ]; then
  sed "s|work/face_scan'|work/ken_initstudy'|" ~/FaceScan/bin/prep.py > ~/FaceScan/bin/prep_ken_initstudy.py
  SCAN_DIR="$KEN" FRAMES=120 LIDAR_INIT=1 "$PY" ~/FaceScan/bin/prep_ken_initstudy.py 2>&1 | tail -3
fi
if [ ! -f "$DR/points3d_sfm.ply" ]; then
  pip install -q pycolmap 2>&1 | tail -1 || true
  "$PY" - <<'PYEOF'
import os, json, shutil
import numpy as np
import pycolmap
DR = os.path.expanduser("~/FaceScan/work/ken_initstudy")
work = os.path.expanduser("~/colmap_ken"); os.makedirs(work, exist_ok=True)
db = f"{work}/db.db"
if not os.path.isfile(db):
    ro = pycolmap.ImageReaderOptions(); ro.camera_model = "PINHOLE"
    pycolmap.extract_features(db, f"{DR}/images",
        camera_mode=pycolmap.CameraMode.SINGLE, reader_options=ro)
    pycolmap.match_exhaustive(db)
    print("features+matches done")
# reference reconstruction with FIXED ARKit poses, written as COLMAP TEXT model
# (version-independent; avoids pycolmap's read-only Image attributes)
t = json.load(open(f"{DR}/transforms_train.json"))
W, H = t.get("w", 1920), t.get("h", 1440)
fx, fy = t["fl_x"], t["fl_y"]
import sqlite3
con = sqlite3.connect(db)
name2id = {n: i for i, n in con.execute("SELECT image_id, name FROM images").fetchall()}
con.close()
from scipy.spatial.transform import Rotation as Rot
flip = np.diag([1.0, -1.0, -1.0, 1.0])
ref_dir = f"{work}/ref"; os.makedirs(ref_dir, exist_ok=True)
with open(f"{ref_dir}/cameras.txt", "w") as f:
    f.write(f"1 PINHOLE {int(W)} {int(H)} {fx} {fy} {W/2} {H/2}\n")
open(f"{ref_dir}/points3D.txt", "w").close()
n_add = 0
with open(f"{ref_dir}/images.txt", "w") as f:
    for fr in t["frames"]:
        stem = os.path.basename(fr["file_path"])
        fname = stem if stem.endswith(".png") else stem + ".png"
        if fname not in name2id:
            fname = os.path.splitext(fname)[0] + ".png"
            if fname not in name2id: continue
        c2w = np.array(fr["transform_matrix"], float) @ flip
        w2c = np.linalg.inv(c2w)
        q = Rot.from_matrix(w2c[:3, :3]).as_quat()   # x y z w
        tx, ty, tz = w2c[:3, 3]
        f.write(f"{name2id[fname]} {q[3]} {q[0]} {q[1]} {q[2]} {tx} {ty} {tz} 1 {fname}\n\n")
        n_add += 1
print("reference images:", n_add)
ref = pycolmap.Reconstruction(ref_dir)
out_dir = f"{work}/triangulated"; os.makedirs(out_dir, exist_ok=True)
rec = pycolmap.triangulate_points(ref, db, f"{DR}/images", out_dir)
print("triangulated points:", rec.num_points3D())
pts = np.array([p.xyz for p in rec.points3D.values()])
cols = np.array([p.color for p in rec.points3D.values()]) / 255.0
import open3d as o3d
pc = o3d.geometry.PointCloud()
pc.points = o3d.utility.Vector3dVector(pts)
pc.colors = o3d.utility.Vector3dVector(cols)
o3d.io.write_point_cloud(f"{DR}/points3d_sfm.ply", pc)
print("SfM seed saved:", len(pts), "points")
PYEOF
fi

# --- stage 2 (GPU): 2DGS with the SfM seed, exact init-study settings ---
O="$OUT/out_ken_sfm"
if [ ! -f "$DR/points3d_sfm.ply" ]; then echo "NO SFM SEED - aborting stage 2"; exit 44; fi
if [ ! -d "$O/point_cloud/iteration_10000" ]; then
  cp -f "$DR/points3d_sfm.ply" "$DR/points3d.ply"
  cd ~/2d-gaussian-splatting
  "$PY" train.py -s "$DR" --iterations 10000 --data_device cuda -r 2 \
    --model_path "$O" --test_iterations -1 --save_iterations 10000 --white_background \
    > "$O.train.log" 2>&1 || { echo SFM_TRAIN_FAIL; exit 42; }
fi
cd ~/2d-gaussian-splatting
"$PY" render.py -m "$O" --skip_test -r 2 --depth_trunc 5.0 --sdf_trunc 0.05 \
  --voxel_size 0.01 --num_cluster 20 > "$O.render.log" 2>&1 || { echo SFM_RENDER_FAIL; exit 43; }
export OUTPUT_PATH="$O" RUN_ID="ken_sfm" DATA_ROOT="$DR"
"$PY" ~/FaceScan/bin/finish_mesh.py > "$O.mesh.log" 2>&1 || echo SFM_MESH_FAIL
grep 'largest piece' "$O.mesh.log" | head -1
echo SFM_ARM_DONE



