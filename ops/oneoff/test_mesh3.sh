source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
tr -d '\r' < /mnt/c/Users/m352395/Downloads/paper_experiments/external/mesh_3dgs_tsdf.py > ~/gs_external/mesh_3dgs_tsdf.py
M=$(find ~/FaceScan/output -maxdepth 1 -type d -name 'exp_3dgs_*' | tail -1)
SF=$(cat ~/FaceScan/work/face_scan/scale_factor.txt)
echo "MODEL=$M  scale_factor=$SF"
cd ~/gaussian-splatting
PYTHONPATH=~/gaussian-splatting python ~/gs_external/mesh_3dgs_tsdf.py \
  -m "$M" --iteration 3000 --mask_dir ~/FaceScan/work/face_scan/masks \
  --voxel 0.01 --sdf_trunc 0.04 --num_cluster 1 --scale_factor "$SF" --out ~/3dgs_test.ply
echo "=== compare to any existing 2dgs metric mesh ==="
python - <<'PY'
import open3d as o3d, numpy as np, glob, os
fl=["/home/m352395/3dgs_test.ply"]+glob.glob("/home/m352395/FaceScan/results/*_nn.ply")
for f in fl[:6]:
    if os.path.exists(f):
        m=o3d.io.read_triangle_mesh(f); e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
        print(os.path.basename(f),"->",len(m.vertices),"verts, extent(mm)",np.round(e,1),"diag",round(float(np.linalg.norm(e)),1))
PY
