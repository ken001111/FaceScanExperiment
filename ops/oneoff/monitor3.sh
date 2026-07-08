n=0
status="TIMEOUT"
while [ $n -lt 85 ]; do
  if ! pgrep -f 'python train.py' >/dev/null; then status="DIED"; break; fi
  L=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep 'Loss=' | tail -1)
  case "$L" in *"Points=0"*) status="COLLAPSE"; break;; esac
  it=$(echo "$L" | grep -oE '[0-9]+/20000' | head -1 | cut -d/ -f1)
  if [ -n "$it" ] && [ "$it" -ge 1200 ]; then status="HEALTHY_1200"; break; fi
  sleep 4
  n=$((n+1))
done
echo "STATUS=$status"
echo "--- mem ---"
free -h | head -2
echo "--- recent log ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep -E 'Loss=|Loading|Reading|Number of points|complete' | tail -6 || true
