# One crash-resilient GeoSVR training attempt: resumes from the latest checkpoint,
# checkpoints every 2k iters, watchdog kills a hung trainer (exit 42 = retry me).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export PYTHONUNBUFFERED=1        # keep the log live so the watchdog reads real progress
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True   # fight fragmentation OOM on 16GB
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
DR=~/FaceScan/work/face_scan
MODEL=~/FaceScan/output/geosvr_best
mkdir -p "$MODEL"
LOG="$MODEL/train_attempt.log"

# v5: NO blend_mask — the masks are circular capture ROIs, and blending forces
# the model to build black "curtains" at every view's circle boundary, which
# slice through the head volume and mush the fused geometry (v4 failure).
# Train on full images like the successful validation run; the background junk
# is removed at extraction time by the world-space head crop.
cat > ~/geosvr_head_overrides.yaml <<'YAML'
data:
  blend_mask: False
YAML

LOAD=""
if ls "$MODEL/checkpoints"/*.pt >/dev/null 2>&1; then
  LOAD="--load_iteration -1"
  echo "[chunk] resuming from latest checkpoint: $(ls -t "$MODEL/checkpoints"/*.pt | head -1)"
else
  echo "[chunk] fresh start"
fi

cd ~/geosvr
python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_head_overrides.yaml \
  --source_path "$DR" --model_path "$MODEL" \
  --n_iter 20000 --bound_mode camera_median --bound_scale 1.0 --outside_level 1 \
  --init_n_level 6 --subdivide_max_num 3000000 \
  --checkpoint_iterations 2000 4000 6000 8000 10000 12000 14000 15000 16000 17000 18000 19000 \
  $LOAD > "$LOG" 2>&1 &
PID=$!

# watchdog: no log write for 300s => hung GPU channel => kill, exit 42.
# If the WSL filesystem itself dies (date/sleep start failing), exit 43 instead
# of spinning — the outer loop restarts WSL and resumes from the checkpoint.
while kill -0 $PID 2>/dev/null; do
  sleep 30 || { echo "[chunk] fs dead (sleep failed)"; exit 43; }
  NOW=$(date +%s) || { echo "[chunk] fs dead (date failed)"; exit 43; }
  AGE=$(( NOW - $(stat -c %Y "$LOG" 2>/dev/null || echo 0) ))
  if [ "$AGE" -gt 300 ]; then
    echo "[chunk] WATCHDOG: log stale ${AGE}s -> killing trainer"
    kill -9 $PID 2>/dev/null
    exit 42
  fi
done
wait $PID; RC=$?
echo "[chunk] train exit=$RC"
tail -c 300 "$LOG" | tr '\r' '\n' | grep -v '^$' | tail -2
exit $RC
