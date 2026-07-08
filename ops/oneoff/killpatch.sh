echo "--- killing hung train.py ---"
PIDS=$(pgrep -f train.py)
if [ -n "$PIDS" ]; then kill $PIDS 2>/dev/null; sleep 2; kill -9 $PIDS 2>/dev/null; echo "killed: $PIDS"; else echo "none running"; fi
echo "--- applying densify patch ---"
~/miniconda3/envs/facescan/bin/python /mnt/c/Users/m352395/Downloads/patch_densify.py
echo "--- verify ---"
sed -n '405,412p' "$HOME/2d-gaussian-splatting/scene/gaussian_model.py"
