#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
p = os.path.expanduser("~/FaceScan/param_study/geosvr_ken_raw/mesh/tsdf/tsdf_fusion.ply")
m = o3d.io.read_triangle_mesh(p)
v = np.asarray(m.vertices)
seed = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/face_scan_raw/points3d.ply"))
sc = np.asarray(seed.points)
print("seed centroid:", np.round(sc.mean(0),2), "seed bbox:", np.round(sc.min(0),1), np.round(sc.max(0),1))
print("mesh bbox:", np.round(v.min(0),1), np.round(v.max(0),1))
ctr = sc.mean(0)
for r in (1.5, 3, 5, 8):
    print(f"verts within {r}:", int((np.linalg.norm(v-ctr,axis=1)<r).sum()))
# also check density around the camera ring center
import json
t = json.load(open(os.path.expanduser("~/FaceScan/work/face_scan_raw/transforms_train.json")))
pos = np.array([np.array(f["transform_matrix"])[:3,3] for f in t["frames"]])
print("cam centroid:", np.round(pos.mean(0),2))
PY
