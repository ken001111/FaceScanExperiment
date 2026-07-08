echo "=== processes ==="
ps -o pid,etime,%cpu,rss,cmd --sort=-%cpu | grep -E 'train.py|render.py|finish_mesh|init_study' | grep -v grep | head
echo "=== system mem ==="
free -h | head -2
echo "=== ken2_lidar render.log tail (CR->LF) ==="
tr '\r' '\n' < "$HOME/FaceScan/initstudy/out_ken2_lidar.render.log" 2>/dev/null | grep -vE '^$' | tail -6
echo "=== ken2_lidar mesh.log ==="
cat "$HOME/FaceScan/initstudy/out_ken2_lidar.mesh.log" 2>/dev/null | tail -6
echo "=== ken2_random train.log tail ==="
tr '\r' '\n' < "$HOME/FaceScan/initstudy/out_ken2_random.train.log" 2>/dev/null | grep -E 'initialisation|Loss=' | tail -2
echo "=== run log tail ==="
tail -4 "$HOME/FaceScan/initstudy_run.log"
