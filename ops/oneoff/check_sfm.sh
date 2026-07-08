#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, os
p = os.path.expanduser("~/FaceScan/work/ken_initstudy/points3d_sfm.ply")
if os.path.isfile(p):
    print("sfm seed pts:", len(o3d.io.read_point_cloud(p).points))
else:
    print("NO SFM SEED")
PY
ls ~/FaceScan/initstudy/out_ken_sfm/point_cloud/ 2>/dev/null
tr '\r' '\n' < ~/FaceScan/initstudy/out_ken_sfm.train.log 2>/dev/null | grep -aE 'initialisation|Points=' | tail -2
grep -aE 'triangulated points' ~/colmap_ken/*.log 2>/dev/null
