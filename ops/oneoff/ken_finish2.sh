#!/bin/bash
# ken baseline, attempt 3: GeoSVR retrain (2k checkpoints, resumable) then
# SVRaster mesh (default; final_lv 9 fallback on OOM, logged as deviation).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DR=~/FaceScan/work/face_scan
K=~/FaceScan/bench_ken

echo "########## GeoSVR ken retrain (defaults, resumable) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$K/geosvr/model"
LOAD=""
if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then
  LOAD="--load_iteration -1"
  echo "resuming from $(ls -t "$G/checkpoints"/*.pt | head -1)"
else
  rm -rf "$G"
fi
# --subdivide_max_num 3000000: documented deviation — paper-default budget OOMs
# on 16GB for this unbounded scene (GeoSVR paper used larger GPUs).
python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$G" \
  --test_iterations 6000 15000 --subdivide_max_num 3000000 \
  --checkpoint_iterations 2000 4000 6000 8000 10000 12000 14000 16000 18000 \
  $LOAD > "$K/geosvr/train.log" 2>&1 || { echo GEO_TRAIN_FAIL; tr '\r' '\n' < "$K/geosvr/train.log" | grep -av 'it/s' | tail -3; exit 42; }
python render.py "$G" --skip_test --use_jpg > "$K/geosvr/render.log" 2>&1 || echo GEO_RENDER_FAIL
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$K/geosvr/mesh.log" 2>&1 || echo GEO_MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -2

echo "########## SVRaster ken mesh (default -> final_lv 9 fallback) ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$K/svraster/model"
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1 \
  || { echo "OOM -> final_lv 9 (deviation: 16GB VRAM)"; \
       python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$K/svraster/mesh.log" 2>&1; } \
  || { echo SVR_MESH_FAIL_LV9; tr '\r' '\n' < "$K/svraster/mesh.log" | grep -av 'it/s' | tail -3; }
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -2
echo KEN_FINISH2_DONE
