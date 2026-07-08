#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
p = os.path.expanduser("~/FaceScan/work/ken_initstudy/points3d_sfm.ply")
pc = o3d.io.read_point_cloud(p)
pc.normals = o3d.utility.Vector3dVector(np.zeros((len(pc.points), 3)))
o3d.io.write_point_cloud(p, pc)
print("normals added:", len(pc.points), "points")
PY
bash ~/sfm.sh
