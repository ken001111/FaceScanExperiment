n=0
status="STILL_TRAINING"
while [ $n -lt 105 ]; do
  if grep -q 'Training complete' "$HOME/FaceScan/train.log" 2>/dev/null; then status="COMPLETE"; break; fi
  if ! pgrep -f 'python train.py' >/dev/null; then status="STOPPED_NO_COMPLETE"; break; fi
  sleep 5
  n=$((n+1))
done
echo "STATUS=$status"
echo "--- latest ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep -E 'Loss=|complete|Saving' | tail -3
