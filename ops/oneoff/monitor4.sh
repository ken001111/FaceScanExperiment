n=0
status="TIMEOUT"
while [ $n -lt 95 ]; do
  if ! pgrep -f 'python train.py' >/dev/null; then status="DIED"; break; fi
  L=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep 'Loss=' | tail -1)
  case "$L" in *"Points=0"*) status="COLLAPSE"; break;; esac
  it=$(echo "$L" | grep -oE '[0-9]+/20000' | head -1 | cut -d/ -f1)
  if [ -n "$it" ] && [ "$it" -ge 2800 ]; then status="PAST_HANG_ZONE_2800"; break; fi
  if grep -q 'Training complete' "$HOME/FaceScan/train.log" 2>/dev/null; then status="DONE"; break; fi
  sleep 5
  n=$((n+1))
done
echo "STATUS=$status"
echo "--- recent ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep -E 'Loss=|Loading|Number of points|complete' | tail -4 || true
