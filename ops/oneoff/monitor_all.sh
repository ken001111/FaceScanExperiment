n=0
status="RUNNING"
while [ $n -lt 100 ]; do
  if grep -qE 'ERROR:' "$HOME/FaceScan/run_all.log" 2>/dev/null; then status="FAILURE"; break; fi
  if grep -q 'DONE: run' "$HOME/FaceScan/run_all.log" 2>/dev/null; then status="COMPLETE"; break; fi
  L=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep 'Loss=' | tail -1)
  case "$L" in *"Points=0"*) status="COLLAPSE"; break;; esac
  it=$(echo "$L" | grep -oE '[0-9]+/20000' | head -1 | cut -d/ -f1)
  if [ -n "$it" ] && [ "$it" -ge 1500 ]; then status="TRAIN_HEALTHY_1500"; break; fi
  sleep 6
  n=$((n+1))
done
echo "STATUS=$status"
echo "--- run_all stage ---"; grep -E '\[[0-9]/5\]|ERROR' "$HOME/FaceScan/run_all.log" | tail -2
echo "--- train ---"; tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep 'Loss=' | tail -1
echo "--- gpu samples ---"; wc -l < "$HOME/FaceScan/gpu.log" 2>/dev/null
