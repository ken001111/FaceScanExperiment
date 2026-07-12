#!/bin/bash
# Render + TSDF band mesh for the seeded arm, identical recipe to the other 5 arms
# (geo_best_mesh.sh core: render --skip_test --use_jpg; tsdf_mesh_band voxel 0.005
#  min_depth 1.0 max_depth 4.0 num_cluster 1). Produces mesh/tsdf/tsdf_fusion_post.ply.
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=1     # RTX 5080
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export PYTHONUNBUFFERED=1
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/geosvr || exit 1
git checkout -q lidar-fork
M="$HOME/FaceScan/paperB/ablation_41069021/seeded"
RLOG="$HOME/FaceScan/paperB/logs/render_seeded.log"
MLOG="$HOME/FaceScan/paperB/logs/mesh_ablation_41069021_seeded.log"

echo "[mesh] render training views $(date)"
if [ ! -d "$M/train/ours_20000_r2.0/renders" ]; then
  python render.py "$M" --skip_test --use_jpg > "$RLOG" 2>&1 || { echo RENDER_FAILED; tail -15 "$RLOG"; exit 1; }
else
  echo "[mesh] renders exist, skipping"
fi
echo "[mesh] band TSDF fusion (voxel 0.005, band [1.0,4.0], num_cluster 1) $(date)"
python mesh_extract/tsdf_mesh_band.py "$M" --voxel_size 0.005 --sdf_trunc_scale 2.0 \
  --min_depth 1.0 --max_depth 4.0 --num_cluster 1 > "$MLOG" 2>&1 || { echo MESH_FAILED; tail -15 "$MLOG"; exit 1; }

echo "=== result ==="
ls -la "$M/mesh/tsdf/" 2>&1
[ -f "$M/mesh/tsdf/tsdf_fusion_post.ply" ] && echo "SEEDED_MESH_OK" || echo "SEEDED_MESH_MISSING"
