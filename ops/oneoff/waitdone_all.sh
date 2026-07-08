RA="$HOME/FaceScan/run_all.log"
TL="$HOME/FaceScan/train.log"
n=0
status="RUNNING"
while [ $n -lt 95 ]; do
  if grep -qE 'ERROR:' "$RA" 2>/dev/null; then status="FAILURE"; break; fi
  if grep -q 'DONE: run' "$RA" 2>/dev/null; then status="COMPLETE"; break; fi
  sleep 6
  n=$((n+1))
done
echo "STATUS=$status"
echo "stage : $(grep -E '\[[0-9]/5\]|DONE|ERROR' "$RA" | tail -1)"
echo "train : $(tr '\r' '\n' < "$TL" 2>/dev/null | grep -E 'Loss=|complete' | tail -1)"
echo "render: $(tr '\r' '\n' < "$HOME/FaceScan/render.log" 2>/dev/null | grep -E 'mesh saved|num vertices post' | tail -1)"
