#!/bin/bash
# (1) dummy raw-LiDAR Poisson mesh; (2) head-bbox files for SVRaster extraction;
# (3) bbox-restricted SVR extractions; (4) grind tail (GeoSVR).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
P=~/FaceScan/param_study

python - <<'PY'
import sys, os
import numpy as np, open3d as o3d
sys.path.insert(0, os.path.expanduser("~/pe_verify/method_comparison"))
from make_raw_lidar_mesh import raw_lidar_mesh
out = os.path.expanduser("~/FaceScan/paperA/meshes/raw_lidar_dummy.ply")
if not os.path.isfile(out):
    raw_lidar_mesh(os.path.expanduser("~/FaceScan/work/dummy_head_raw/points3d.ply"), out, m_to_mm=100.0)
    print("dummy raw-lidar mesh done")
# head bboxes for SVRaster extraction (seed-cloud bbox, +-flip candidates, inflated)
for tag, seed in (("dummyraw", "~/FaceScan/work/dummy_head_raw/points3d.ply"),
                  ("kenraw",   "~/FaceScan/work/face_scan_raw/points3d.ply")):
    pts = np.asarray(o3d.io.read_point_cloud(os.path.expanduser(seed)).points)
    ctrs = [pts.mean(0), pts.mean(0)*np.array([1.,-1.,-1.])]
    los, his = [], []
    for c in ctrs:
        los.append(c - 2.0); his.append(c + 2.0)
    lo = np.min(los, axis=0); hi = np.max(his, axis=0)   # union covers both frames
    bbox = np.array([lo, hi])
    np.savetxt(os.path.expanduser(f"~/svr_bbox_{tag}.txt"), bbox)
    print(tag, "bbox:", bbox.round(1).tolist())
PY

cd ~/svraster; export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
for TAG in dummyraw kenraw; do
  S="$P/svr_${TAG}_fullres"
  [ -f "$S/mesh/latest/mesh_dense.ply" ] && continue
  python extract_mesh.py "$S/" --use_vert_color --mesh_fname mesh_dense --progressive \
    --bbox_path ~/svr_bbox_${TAG}.txt > "$P/svr_${TAG}_fullres.mesh.log" 2>&1 \
    || { echo "SVR $TAG bbox extraction failed"; tr '\r' '\n' < "$P/svr_${TAG}_fullres.mesh.log" | grep -av 'it/s' | tail -2; continue; }
  echo "SVR $TAG mesh OK"
done
ls "$P"/svr_*_fullres/mesh/latest/*.ply 2>/dev/null
bash ~/queue_tick.sh
