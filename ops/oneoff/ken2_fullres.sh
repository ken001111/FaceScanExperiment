source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
OUTPUT_PATH="$HOME/FaceScan/output/Rear_Camera_0612_1217"   # ken2 full-res model
[ -d "$OUTPUT_PATH" ] || { echo "MODEL MISSING"; ls ~/FaceScan/output/; exit 1; }

echo "=== 1) restore ken2 source at 120 frames (safe for full-res render) ==="
rm -f ~/FaceScan/raw_data/*.zip
cp /mnt/c/Users/m352395/Downloads/Scan_ken2_*.zip ~/FaceScan/raw_data/
FRAMES=120 "$PY" ~/FaceScan/bin/prep.py 2>&1 | grep -E 'OK data ready|WHITE_DIAG'

echo "=== 2) FULL-RES re-render (watching memory) ==="
cd ~/2d-gaussian-splatting
( for i in $(seq 1 150); do echo "mem: $(free -m | awk '/Mem:/{print $3"/"$2" MB"}')  vram: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)MiB"; sleep 3; done > ~/FaceScan/mem_fullres.log ) &
SMPL=$!
"$PY" render.py -m "$OUTPUT_PATH" --skip_test \
    --depth_trunc 5.0 --sdf_trunc 0.05 --voxel_size 0.01 --num_cluster 20 \
    2>&1 | tee "$HOME/FaceScan/render_fullres.log" | grep -E 'bounding radius|num vertices|mesh saved|rror' | tail -8
RC=${PIPESTATUS[0]}
kill $SMPL 2>/dev/null
echo "render exit: $RC"
echo "peak system mem: $(awk -F'[:/ ]+' '/mem:/{print $2}' ~/FaceScan/mem_fullres.log | sort -n | tail -1) MB"

echo "=== 3) rebuild mesh ==="
export OUTPUT_PATH
export RUN_ID=0612_1217_fullres
"$PY" ~/FaceScan/bin/finish_mesh.py
cp "$HOME/FaceScan/results/Face_Mesh_MetricScale_0612_1217_fullres_nn.ply" /mnt/c/Users/m352395/Downloads/ 2>/dev/null && echo "copied to Downloads"
