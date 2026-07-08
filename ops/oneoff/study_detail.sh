echo "=== train.py / render.py running? ==="
pgrep -af 'train.py|render.py' | sed 's/^[0-9]* //' | head -3
echo "=== ken2 logs ==="
for L in "$HOME/FaceScan/initstudy"/out_ken2_*; do
  echo "--- $(basename "$L") ---"
  tr '\r' '\n' < "$L" 2>/dev/null | grep -E 'initialisation|Loss=|reconstruct radiance|TSDF integration|mesh saved|num vertices post|Error|Traceback' | tail -2
done
echo "=== summary lines so far ==="
grep -cE '\| init_pts' "$HOME/FaceScan/initstudy/summary.txt" 2>/dev/null
