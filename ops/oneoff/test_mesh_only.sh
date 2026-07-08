source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
MODEL=$(ls -d ~/FaceScan/output/exp_3dgs_* | tail -1)
echo "using model: $MODEL"
cd ~/gaussian-splatting
PYTHONPATH=~/gaussian-splatting python ~/gs_external/mesh_3dgs_tsdf.py \
  -m "$MODEL" --iteration 3000 --mask_dir ~/FaceScan/work/face_scan/masks \
  --voxel 0.01 --sdf_trunc 0.04 --num_cluster 1 --out ~/3dgs_test.ply
echo "=== compare extents: 3dgs vs the 2dgs test mesh ==="
python - <<'PY'
import open3d as o3d, numpy as np, glob, os
for f in ["/home/m352395/3dgs_test.ply"] + glob.glob("/tmp/EXPDATA/kentest/methods/2dgs.ply"):
    if os.path.exists(f):
        m=o3d.io.read_triangle_mesh(f)
        bb=m.get_axis_aligned_bounding_box()
        print(os.path.basename(f), "->", len(m.vertices),"verts", "extent", np.round(np.asarray(bb.get_extent()),3))
PY
