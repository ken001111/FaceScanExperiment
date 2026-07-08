echo "--- train.py running? ---"
if pgrep -f train.py >/dev/null; then echo RUNNING; else echo "NOT RUNNING"; fi
echo "--- last_run ---"
cat "$HOME/FaceScan/last_run.txt" 2>/dev/null
echo "--- recent loss/points ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep -E 'Loss=|complete|Saving' | tail -4
echo "--- gpu ---"
nvidia-smi --query-gpu=utilization.gpu,power.draw,memory.used --format=csv,noheader
