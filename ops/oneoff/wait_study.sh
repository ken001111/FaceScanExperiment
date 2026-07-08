n=0
while [ $n -lt 95 ]; do
  if grep -q 'DONE_INIT_STUDY' "$HOME/FaceScan/initstudy_run.log" 2>/dev/null; then echo "=== STUDY COMPLETE ==="; break; fi
  sleep 6; n=$((n+1))
done
echo "--- results so far (one line per completed run) ---"
grep -E '\| init_pts|########|LiDAR seed|Init:|Sharpness' "$HOME/FaceScan/initstudy/summary.txt" 2>/dev/null
echo "--- current activity ---"
ls "$HOME/FaceScan/initstudy/"/out_*.train.log 2>/dev/null | sed 's#.*/##'
for L in "$HOME/FaceScan/initstudy"/out_*.train.log; do
  [ -f "$L" ] || continue
  echo "$(basename "$L"): $(tr '\r' '\n' < "$L" | grep 'Loss=' | tail -1 | grep -oE '[0-9]+/[0-9]+ ' | head -1)"
done
