tr -d '\r' < /mnt/c/Users/m352395/Downloads/run_all.sh > ~/FaceScan/bin/run_all.sh
chmod +x ~/FaceScan/bin/run_all.sh
bash -n ~/FaceScan/bin/run_all.sh && echo "run_all.sh syntax OK"
# remove the batch experiment
rm -f ~/2d-gaussian-splatting/train_batch.py
rm -f /mnt/c/Users/m352395/Downloads/train_orig.py /mnt/c/Users/m352395/Downloads/train_batch.py
echo "--- BATCH/train_batch refs left in run_all.sh (want 0) ---"
grep -c 'BATCH\|train_batch' ~/FaceScan/bin/run_all.sh || echo "0 (clean)"
echo "--- train_batch.py removed? ---"
ls ~/2d-gaussian-splatting/train_batch.py 2>/dev/null && echo "STILL THERE" || echo "removed"
echo "--- stock train.py intact ---"
ls -la ~/2d-gaussian-splatting/train.py
