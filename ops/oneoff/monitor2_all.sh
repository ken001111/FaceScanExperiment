RA="$HOME/FaceScan/run_all.log"
LR="$HOME/FaceScan/last_run.txt"
TL="$HOME/FaceScan/train.log"
n=0
status="RUNNING"
while [ $n -lt 85 ]; do
  if grep -qE 'ERROR:' "$RA" 2>/dev/null; then status="FAILURE"; break; fi
  if grep -q 'DONE: run' "$RA" 2>/dev/null; then status="COMPLETE"; break; fi
  RID=$(grep '^RUN_ID=' "$LR" 2>/dev/null | cut -d= -f2)
  if [ -n "$RID" ] && [ "$RID" != "0609_1650" ]; then
    L=$(tr '\r' '\n' < "$TL" 2>/dev/null | grep 'Loss=' | tail -1)
    case "$L" in *"Points=0"*) status="COLLAPSE"; break;; esac
    it=$(echo "$L" | grep -oE '[0-9]+/20000' | head -1 | cut -d/ -f1)
    if [ -n "$it" ] && [ "$it" -ge 1500 ]; then status="TRAIN_HEALTHY(new run $RID)"; break; fi
  fi
  sleep 6
  n=$((n+1))
done
echo "STATUS=$status"
echo "RUN_ID now : $(grep '^RUN_ID=' "$LR" 2>/dev/null | cut -d= -f2)  (prev was 0609_1650)"
echo "stage      : $(grep -E '\[[0-9]/5\]' "$RA" | tail -1)"
echo "train      : $(tr '\r' '\n' < "$TL" 2>/dev/null | grep 'Loss=' | tail -1)"
echo "gpu samples: $(wc -l < "$HOME/FaceScan/gpu.log" 2>/dev/null)"
