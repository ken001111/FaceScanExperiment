n=0
while [ $n -lt 110 ]; do
  L=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" 2>/dev/null | grep 'Loss=' | tail -1)
  case "$L" in
    *"Points=0"*) echo "COLLAPSE DETECTED"; break;;
  esac
  it=$(echo "$L" | grep -oE '[0-9]+/20000' | head -1 | cut -d/ -f1)
  if [ -n "$it" ] && [ "$it" -ge 2000 ]; then echo "HEALTHY past iter 2000"; break; fi
  if grep -q 'Training complete' "$HOME/FaceScan/train.log" 2>/dev/null; then echo "DONE"; break; fi
  sleep 4
  n=$((n+1))
done
echo "--- recent loss/points ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -4
