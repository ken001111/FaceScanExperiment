#!/bin/bash
# Pilot part 2: GeoSVR (with PYTHONPATH fix) then SVRaster, both scan24,
# both via their official dtu_run.sh procedures.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench
mkdir -p "$B/svraster"

echo "########## GeoSVR scan24 (official dtu_run.sh, PYTHONPATH fixed) ##########"
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
rm -rf "$B/geosvr/scan24"
bash scripts/dtu_run.sh "$B/geosvr" 15 1 > "$B/geosvr/scan24_run.log" 2>&1 || { echo GEOSVR_FAIL; grep -aE 'Error|Traceback' "$B/geosvr/scan24_run.log" | head -3; }
grep -aiE "mean_d2s|mean_s2d|overall" "$B/geosvr/scan24_run.log" | tail -4

echo "########## SVRaster scan24 (official dtu_run.sh commands) ##########"
export PYTHONPATH="$HOME/svraster"
cd ~/svraster
S="$B/svraster/scan24"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$NEUS/dtu_scan24/" --model_path "$S" > "$B/svraster/scan24_train.log" 2>&1 || { echo SVR_TRAIN_FAIL; grep -aE 'Error|Traceback' -A2 "$B/svraster/scan24_train.log" | head -6; }
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$B/svraster/scan24_render.log" 2>&1 || echo SVR_RENDER_FAIL
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan24_mesh.log" 2>&1 || { echo SVR_MESH_FAIL; tail -4 "$B/svraster/scan24_mesh.log"; }
fi
mkdir -p "$S/mesh/latest/evaluation"
python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan24/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan24_clean.log" 2>&1 || { echo SVR_CLEAN_FAIL; tail -4 "$B/svraster/scan24_clean.log"; }
python scripts/dtu_eval/eval.py \
  --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
  --scan 24 --dataset_dir "$OFFICIAL" \
  --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan24_eval.log" 2>&1 || { echo SVR_EVAL_FAIL; tail -4 "$B/svraster/scan24_eval.log"; }
tail -3 "$B/svraster/scan24_eval.log"

echo "########## DONE ##########"
echo BENCH_SCAN24B_DONE
