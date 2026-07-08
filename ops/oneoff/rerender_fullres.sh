source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
OUTPUT_PATH="$HOME/FaceScan/output/Rear_Camera_0611_1712"
[ -d "$OUTPUT_PATH" ] || { echo "MODEL MISSING: $OUTPUT_PATH"; ls ~/FaceScan/output/; exit 1; }

echo "=== 1) restore ken source images (re-prep, same 86 frames) ==="
rm -f ~/FaceScan/raw_data/*.zip
cp /mnt/c/Users/m352395/Downloads/Scan_Ken*cropped*.zip ~/FaceScan/raw_data/
FRAMES=200 "$PY" ~/FaceScan/bin/prep.py 2>&1 | grep -E 'OK data ready|WHITE_DIAG'

echo "=== 2) FULL-RES re-render of the trained ken model (no -r flag) ==="
cd ~/2d-gaussian-splatting
"$PY" render.py -m "$OUTPUT_PATH" --skip_test \
    --depth_trunc 5.0 --sdf_trunc 0.05 --voxel_size 0.01 --num_cluster 20 \
    2>&1 | tee "$HOME/FaceScan/render_fullres.log" | grep -E 'bounding radius|num vertices|mesh saved|rror' | tail -8
echo "render exit: ${PIPESTATUS[0]}"

echo "=== 3) rebuild mesh ==="
export OUTPUT_PATH
export RUN_ID=0611_1712_fullres
"$PY" ~/FaceScan/bin/finish_mesh.py
cp "$HOME/FaceScan/results/Face_Mesh_MetricScale_0611_1712_fullres_nn.ply" /mnt/c/Users/m352395/Downloads/ 2>/dev/null && echo "copied to Downloads"
ls -la /mnt/c/Users/m352395/Downloads/Face_Mesh_MetricScale_0611_1712_fullres_nn.ply 2>/dev/null
