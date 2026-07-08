source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
cd ~/2d-gaussian-splatting
DATA_ROOT="$HOME/FaceScan/work/face_scan/Scan__20260529_094706_cropped"
RUN_ID=$(date +%m%d_%H%M)
OUTPUT_PATH="$HOME/FaceScan/output/Rear_Camera_$RUN_ID"
{ echo "RUN_ID=$RUN_ID"; echo "OUTPUT_PATH=$OUTPUT_PATH"; echo "DATA_ROOT=$DATA_ROOT"; } > "$HOME/FaceScan/last_run.txt"
python train.py -s "$DATA_ROOT" \
  --iterations 20000 \
  --data_device cpu \
  --model_path "$OUTPUT_PATH" \
  --test_iterations -1 \
  --save_iterations 20000 \
  --white_background 2>&1 | tee "$HOME/FaceScan/train.log"
echo "EXIT=${PIPESTATUS[0]}" >> "$HOME/FaceScan/last_run.txt"
