set -e
SRC=/mnt/c/Users/m352395/Downloads
PY="$HOME/miniconda3/envs/facescan/bin/python"
tr -d '\r' < "$SRC/train_orig.py" > ~/2d-gaussian-splatting/train_batch.py
"$PY" -m py_compile ~/2d-gaussian-splatting/train_batch.py && echo "train_batch.py compiles OK"
tr -d '\r' < "$SRC/run_all.sh" > ~/FaceScan/bin/run_all.sh
chmod +x ~/FaceScan/bin/run_all.sh
bash -n ~/FaceScan/bin/run_all.sh && echo "run_all.sh OK"
. ~/FaceScan/last_run.txt
echo "=== sanity: BATCH=4, 200 iters, -r 2, cuda on $DATA_ROOT ==="
cd ~/2d-gaussian-splatting
( for i in $(seq 1 12); do nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader,nounits; sleep 2; done > ~/FaceScan/batch_sanity.log ) &
BATCH=4 "$PY" train_batch.py -s "$DATA_ROOT" --iterations 200 --data_device cuda -r 2 \
  --model_path /tmp/batchtest --test_iterations -1 --save_iterations 999999 --white_background \
  2>&1 | tr '\r' '\n' | grep -E 'Loss=|Traceback|Error|no kernel|Number of points' | tail -8
wait
echo "=== VRAM(MiB), util(%) during BATCH=4 run ==="
cat ~/FaceScan/batch_sanity.log
rm -rf /tmp/batchtest
