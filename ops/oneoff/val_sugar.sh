EXT=/mnt/c/Users/m352395/Downloads/paper_experiments/method_comparison/external
mkdir -p ~/st
tr -d '\r' < "$EXT/run_sugar.sh" > ~/st/run_sugar.sh
tr -d '\r' < "$EXT/sugar_coarse.py" > ~/st/sugar_coarse.py
chmod +x ~/st/run_sugar.sh
echo "=== validating fixed run_sugar.sh (dn_consistency) on ken ==="
bash ~/st/run_sugar.sh ~/FaceScan/work/face_scan ~/sugar_coarse_test.ply
echo "=== verify mesh ==="
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, numpy as np, os
f=os.path.expanduser("~/sugar_coarse_test.ply")
if os.path.exists(f):
    m=o3d.io.read_triangle_mesh(f); e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
    print("RESULT:", len(m.vertices),"verts, extent(mm)",np.round(e,1))
else:
    print("RESULT: NO MESH")
PY
echo "VAL_SUGAR_DONE"
