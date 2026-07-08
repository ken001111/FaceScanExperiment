echo "--- memory + swap ---"
free -h
echo "--- iter sample over 15s ---"
for i in 1 2 3; do
  tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1 | grep -oE '[0-9]+/20000' | head -1
  sleep 5
done
echo "--- gpu ---"
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader
