RA="$HOME/FaceScan/run_all.log"
TL="$HOME/FaceScan/train.log"
n=0
while [ $n -lt 70 ]; do
  if grep -qiE 'ERROR:|out of memory|CUDA error' "$RA" 2>/dev/null; then
    echo "=== ERROR/OOM DETECTED ==="; grep -iE 'error|out of memory|traceback' "$RA" | tail -6; exit 0
  fi
  if grep -q '\[2/5\]' "$RA" 2>/dev/null && tr '\r' '\n' < "$TL" 2>/dev/null | grep -q 'Loss='; then break; fi
  sleep 5
  n=$((n+1))
done
echo "=== training active (data_device=cuda) — sampling GPU 8x over ~24s ==="
echo "util%, VRAM MiB, power W"
for i in 1 2 3 4 5 6 7 8; do
  nvidia-smi --query-gpu=utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits
  sleep 3
done
echo "--- current iter/loss/speed ---"
tr '\r' '\n' < "$TL" | grep 'Loss=' | tail -1
