n=0
while [ $n -lt 95 ]; do
  if grep -q DONE_INIT_STUDY "$HOME/FaceScan/initstudy_run.log" 2>/dev/null; then break; fi
  sleep 6; n=$((n+1))
done
if grep -q DONE_INIT_STUDY "$HOME/FaceScan/initstudy_run.log" 2>/dev/null; then echo "=== STUDY COMPLETE ==="; else echo "=== still running ==="; fi
echo ""
grep -E '\| init_pts' "$HOME/FaceScan/initstudy/summary.txt" 2>/dev/null
echo ""
echo "--- meshes copied to Downloads ---"
ls -la /mnt/c/Users/m352395/Downloads/Face_Mesh_MetricScale_ken*_nn.ply 2>/dev/null | sed 's#.*/##'
