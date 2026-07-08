source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
M=$(find ~/FaceScan/output -maxdepth 1 -type d -name 'exp_3dgs_*' | tail -1)
echo "MODEL=$M"
cd ~/gaussian-splatting
PYTHONPATH=~/gaussian-splatting python ~/gs_external/mesh_3dgs_tsdf.py \
  -m "$M" --iteration 3000 --mask_dir ~/FaceScan/work/face_scan/masks \
  --voxel 0.01 --sdf_trunc 0.04 --num_cluster 1 --out ~/3dgs_test.ply
