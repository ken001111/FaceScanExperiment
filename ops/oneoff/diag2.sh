echo "=== python / study processes alive? ==="
pgrep -af python | head -5
echo "--- init_study.sh alive? ---"
pgrep -af init_study | head -2 || echo "init_study NOT running"
echo "=== GPU ==="
nvidia-smi --query-gpu=utilization.gpu,memory.used,power.draw --format=csv,noheader
echo "=== mem ==="
free -m | head -2
echo "=== initstudy file sizes / mtimes ==="
ls -la --time-style=+%H:%M:%S "$HOME/FaceScan/initstudy"/out_ken2_lidar.* 2>/dev/null
echo "=== ken2_lidar render.log byte size ==="
wc -c "$HOME/FaceScan/initstudy/out_ken2_lidar.render.log" 2>/dev/null
echo "=== last 30 lines of run log (plain) ==="
tail -c 2000 "$HOME/FaceScan/initstudy_run.log" | tr '\r' '\n' | tail -8
