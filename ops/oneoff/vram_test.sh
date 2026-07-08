. ~/FaceScan/last_run.txt
cd ~/2d-gaussian-splatting
PY="$HOME/miniconda3/envs/facescan/bin/python"
echo "Comparing BATCH=1 vs BATCH=8 (full-res, cuda, 80 iters each)"
for B in 1 8; do
  rm -f /tmp/vram_$B.log
  ( for i in $(seq 1 90); do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits; sleep 1; done > /tmp/vram_$B.log ) &
  SMPL=$!
  BATCH=$B "$PY" train_batch.py -s "$DATA_ROOT" --iterations 80 --data_device cuda \
    --model_path /tmp/bt_$B --test_iterations -1 --save_iterations 999999 --white_background \
    > /tmp/tr_$B.log 2>&1
  kill $SMPL 2>/dev/null
  PEAK=$(sort -n /tmp/vram_$B.log | tail -1)
  SPD=$(tr '\r' '\n' < /tmp/tr_$B.log | grep -oE '[0-9.]+it/s' | tail -1)
  echo "BATCH=$B -> peak VRAM ${PEAK} MiB, speed ${SPD} ($((B)) renders/step)"
  rm -rf /tmp/bt_$B
done
