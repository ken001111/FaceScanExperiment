#!/bin/bash
# Paper A M3: raw-LiDAR baseline meshes (Poisson on the metric seed cloud) —
# the plan's "bare-sensor floor". CPU-only.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
cd ~/pe_verify/method_comparison
mkdir -p ~/FaceScan/paperA/meshes
python make_raw_lidar_mesh.py ~/FaceScan/work/dummy_head_raw/points3d.ply \
  ~/FaceScan/paperA/meshes/raw_lidar_dummy.ply 2>&1 | tail -2 || \
python - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser("~/pe_verify/method_comparison"))
from make_raw_lidar_mesh import raw_lidar_mesh
raw_lidar_mesh(os.path.expanduser("~/FaceScan/work/dummy_head_raw/points3d.ply"),
               os.path.expanduser("~/FaceScan/paperA/meshes/raw_lidar_dummy.ply"),
               m_to_mm=100.0)   # scene units: 1 unit = 10 cm -> mm is x100
print("dummy raw-lidar mesh done")
PY
python - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser("~/pe_verify/method_comparison"))
from make_raw_lidar_mesh import raw_lidar_mesh
raw_lidar_mesh(os.path.expanduser("~/FaceScan/work/face_scan_raw/points3d.ply"),
               os.path.expanduser("~/FaceScan/paperA/meshes/raw_lidar_ken.ply"),
               m_to_mm=100.0)
print("ken raw-lidar mesh done")
PY
ls -la ~/FaceScan/paperA/meshes/
echo RAW_LIDAR_BASELINES_DONE
