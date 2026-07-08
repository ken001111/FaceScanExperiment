source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
cd ~/2d-gaussian-splatting
. "$HOME/FaceScan/last_run.txt"
echo "Rendering OUTPUT_PATH=$OUTPUT_PATH"
python render.py -m "$OUTPUT_PATH" \
    --skip_test \
    -r 2 \
    --depth_trunc 5.0 \
    --sdf_trunc 0.05 \
    --voxel_size 0.01 \
    --num_cluster 20 2>&1 | tee "$HOME/FaceScan/render.log" | tail -45
echo "=== render exit: ${PIPESTATUS[0]} ==="
ls -la "$OUTPUT_PATH/train/ours_20000/" 2>/dev/null
