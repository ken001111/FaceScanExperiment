RA="$HOME/FaceScan/run_all.log"; PL="$HOME/FaceScan/prep.log"; TL="$HOME/FaceScan/train.log"
n=0
while [ $n -lt 70 ]; do
  if grep -qiE 'ERROR:' "$RA" 2>/dev/null; then echo "=== PREP/RUN ERROR ==="; grep -iE 'error|traceback' "$RA" | tail -6; exit 0; fi
  if grep -qE 'OK data ready|WHITE_DIAG' "$PL" 2>/dev/null; then break; fi
  sleep 5; n=$((n+1))
done
echo "=== PREP SUMMARY (new scan) ==="
grep -E 'Loading:|HEIC support|Subsampled|Renamed|Applied|No masks|OK data ready|WHITE_DIAG' "$PL"
echo ""
echo "=== waiting for training to pass collapse zone ==="
n=0
while [ $n -lt 70 ]; do
  L=$(tr '\r' '\n' < "$TL" 2>/dev/null | grep 'Loss=' | tail -1)
  case "$L" in *"Points=0"*) echo "COLLAPSE (over-masked?)"; echo "$L"; exit 0;; esac
  it=$(echo "$L" | grep -oE '[0-9]+/10000' | head -1 | cut -d/ -f1)
  if [ -n "$it" ] && [ "$it" -ge 900 ]; then echo "HEALTHY past iter 900:"; echo "$L"; exit 0; fi
  sleep 5; n=$((n+1))
done
echo "still warming up:"; tr '\r' '\n' < "$TL" 2>/dev/null | grep 'Loss=' | tail -1
