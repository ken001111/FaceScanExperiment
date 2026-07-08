#!/bin/bash
# FaceScan end-to-end: prep -> train -> render -> mesh -> report (+GPU log)
# Usage:  run_all.sh [optional_scan.zip]
#   RENDER_RES='' run_all.sh   # full-res render (default is half-res '-r 2')
set -uo pipefail
source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
BIN="$HOME/FaceScan/bin"
PY="$HOME/miniconda3/envs/facescan/bin/python"
# --- speed knobs (defaults = MAX SPEED ~8-10 min). Override per run, e.g.:
#   ITERS=20000 FRAMES=0 TRAIN_RES='' RENDER_RES='' bash run_all.sh ...   # full quality
ITERS="${ITERS:-10000}"            # training iterations (was 20000)
FRAMES="${FRAMES:-120}"            # subsample to N frames (0 = keep all)
TRAIN_RES="${TRAIN_RES--r 2}"      # train at half resolution
RENDER_RES="${RENDER_RES--r 2}"
DATA_DEVICE="${DATA_DEVICE:-cuda}" # cuda = images in VRAM -> high GPU use + faster.
                                   # Use cpu ONLY for full-res + all-frames (could exceed 16GB VRAM).
export FRAMES

echo "================ FaceScan run_all ================"
date
echo "config: ITERS=$ITERS FRAMES=$FRAMES TRAIN_RES='$TRAIN_RES' RENDER_RES='$RENDER_RES' DATA_DEVICE=$DATA_DEVICE"

# [0] optional scan zip -> raw_data (newest auto-selected by prep)
if [ "${1:-}" != "" ]; then
  echo "[0] copying scan: $1"
  cp "$1" "$HOME/FaceScan/raw_data/" || { echo "ERROR: copy failed"; exit 1; }
fi

# GPU sampler in background: timestamp, util%, VRAM MiB, power W  every 2s
GPULOG="$HOME/FaceScan/gpu.log"; : > "$GPULOG"
( while true; do nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used,power.draw \
    --format=csv,noheader,nounits >> "$GPULOG" 2>/dev/null; sleep 2; done ) &
SAMPLER=$!
cleanup(){ kill "$SAMPLER" 2>/dev/null; }
trap cleanup EXIT

# [1] PREP
echo "[1/5] prep ..."
$PY "$BIN/prep.py" 2>&1 | tee "$HOME/FaceScan/prep.log"
[ "${PIPESTATUS[0]}" = "0" ] || { echo "ERROR: prep failed"; exit 1; }
DATA_ROOT=$(grep '^DATA_ROOT=' "$HOME/FaceScan/prep.log" | tail -1 | cut -d= -f2- || true)
[ -n "$DATA_ROOT" ] || { echo "ERROR: no DATA_ROOT from prep"; exit 1; }

# [2] TRAIN
RUN_ID=$(date +%m%d_%H%M)
OUTPUT_PATH="$HOME/FaceScan/output/Rear_Camera_$RUN_ID"
{ echo "RUN_ID=$RUN_ID"; echo "OUTPUT_PATH=$OUTPUT_PATH"; echo "DATA_ROOT=$DATA_ROOT"; } > "$HOME/FaceScan/last_run.txt"
echo "[2/5] train 20k iters -> $OUTPUT_PATH"
cd "$HOME/2d-gaussian-splatting"
$PY train.py -s "$DATA_ROOT" --iterations "$ITERS" --data_device "$DATA_DEVICE" $TRAIN_RES \
    --model_path "$OUTPUT_PATH" --test_iterations -1 --save_iterations "$ITERS" \
    --white_background 2>&1 | tee "$HOME/FaceScan/train.log"
[ "${PIPESTATUS[0]}" = "0" ] || { echo "ERROR: train failed"; exit 1; }

# [3] RENDER + TSDF MESH
echo "[3/5] render $RENDER_RES + TSDF mesh ..."
$PY render.py -m "$OUTPUT_PATH" --skip_test $RENDER_RES \
    --depth_trunc 5.0 --sdf_trunc 0.05 --voxel_size 0.01 --num_cluster 20 \
    2>&1 | tee "$HOME/FaceScan/render.log"
[ "${PIPESTATUS[0]}" = "0" ] || { echo "ERROR: render failed"; exit 1; }

# [4] MESH CONVERT (largest component + mm + xyz nn.ply)
echo "[4/5] mesh convert ..."
export OUTPUT_PATH RUN_ID DATA_ROOT
$PY "$BIN/finish_mesh.py" || { echo "ERROR: mesh convert failed"; exit 1; }

# [5] REPORT (stop sampler first so gpu.log is complete)
cleanup; trap - EXIT
echo "[5/5] report ..."
bash "$BIN/make_report.sh"

echo "================ DONE: run $RUN_ID ================"
date
