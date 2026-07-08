#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench
S="$B/svraster/scan24"
cd ~/svraster
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan24_mesh.log" 2>&1 || { echo SVR_MESH_FAIL; tr '\r' '\n' < "$B/svraster/scan24_mesh.log" | grep -av 'it/s' | tail -5; exit 1; }
mkdir -p "$S/mesh/latest/evaluation"
python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan24/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan24_clean.log" 2>&1 || { echo SVR_CLEAN_FAIL; tail -4 "$B/svraster/scan24_clean.log"; exit 1; }
python scripts/dtu_eval/eval.py \
  --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
  --scan 24 --dataset_dir "$OFFICIAL" \
  --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan24_eval.log" 2>&1 || { echo SVR_EVAL_FAIL; tail -4 "$B/svraster/scan24_eval.log"; exit 1; }
echo "SVRaster chamfer:"
tr '\r' '\n' < "$B/svraster/scan24_eval.log" | grep -av 'it/s\|%' | tail -3
echo SVR_FINISH_DONE
