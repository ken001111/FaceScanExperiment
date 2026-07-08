#!/bin/bash
# GeoSVR ken + TRUE mattes (blend_mask) — resume from 10k. Own session.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
P=~/FaceScan/param_study
G="$P/geosvr_ken_matte"
DR=~/FaceScan/work/face_scan_matte
LOAD=""
if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then LOAD="--load_iteration -1"; fi
python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_matte_overrides.yaml \
  --source_path "$DR" --model_path "$G" \
  --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 3000000 \
  --test_iterations 6000 15000 --checkpoint_iterations 4000 8000 12000 16000 \
  $LOAD > "$P/geosvr_ken_matte.train.log" 2>&1 || { echo TRAIN_FAIL; exit 1; }
python render.py "$G" --skip_test --use_jpg > "$P/geosvr_ken_matte.render.log" 2>&1 || echo RENDER_FAIL
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.005 --max_depth 4.0 > "$P/geosvr_ken_matte.mesh.log" 2>&1 || echo MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -1
echo KEN_MATTE_DONE
