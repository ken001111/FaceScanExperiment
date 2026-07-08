PY="$HOME/miniconda3/envs/facescan/bin/python"
tr -d '\r' < /mnt/c/Users/m352395/Downloads/prep.py > ~/FaceScan/bin/prep.py
"$PY" -m py_compile ~/FaceScan/bin/prep.py && echo "prep.py compiles OK" || exit 1
echo "--- scan in raw_data ---"
ls ~/FaceScan/raw_data/*.zip
echo "--- run prep (FRAMES=120) ---"
FRAMES=120 "$PY" ~/FaceScan/bin/prep.py 2>&1 | tee /tmp/prep.log | grep -E 'Loading:|Subsampled|Sharpness|Applied|LiDAR seed|No points3D|OK data ready'
DATA_ROOT=$(grep '^DATA_ROOT=' /tmp/prep.log | tail -1 | cut -d= -f2-)
echo "--- short train: which init source? ---"
cd ~/2d-gaussian-splatting
"$PY" train.py -s "$DATA_ROOT" --iterations 30 --data_device cuda -r 2 \
  --model_path /tmp/seedtest --test_iterations -1 --save_iterations 999999 --white_background \
  2>&1 | tr '\r' '\n' | grep -E 'random point cloud|Number of points at init' | head
rm -rf /tmp/seedtest
echo "--- ply files in data root ---"
ls -la "$DATA_ROOT"/points3d.ply "$DATA_ROOT"/points3D.ply 2>/dev/null
