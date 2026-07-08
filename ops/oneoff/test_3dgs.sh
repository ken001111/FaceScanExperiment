set -e
EXT=/mnt/c/Users/m352395/Downloads/paper_experiments/external
mkdir -p ~/gs_external
tr -d '\r' < "$EXT/run_3dgs_tsdf.sh" > ~/gs_external/run_3dgs_tsdf.sh
tr -d '\r' < "$EXT/mesh_3dgs_tsdf.py" > ~/gs_external/mesh_3dgs_tsdf.py
chmod +x ~/gs_external/run_3dgs_tsdf.sh
echo "=== quick validation: 3DGS+TSDF on ken (3000 iters, -r 2) ==="
GS3D_ITERS=3000 GS3D_TRAIN_RES='-r 2' bash ~/gs_external/run_3dgs_tsdf.sh ~/FaceScan/work/face_scan ~/3dgs_test.ply
echo "=== verify mesh ==="
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, numpy as np
m=o3d.io.read_triangle_mesh("/home/m352395/3dgs_test.ply")
print("3dgs_test.ply ->", len(m.vertices), "verts,", len(m.triangles), "tris")
# compare extent to the 2dgs mesh if present
import os
PY
echo "TEST_3DGS_DONE"
