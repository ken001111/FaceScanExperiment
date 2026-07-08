PY="$HOME/miniconda3/envs/facescan/bin/python"
GS="$HOME/2d-gaussian-splatting"
OUT="$HOME/FaceScan/initstudy"
DR="$HOME/FaceScan/work/face_scan/Scan_ken2_20260611_173913_cropped"
rm -f "$DR/points3d.ply"          # force random init for ken2
cd "$GS"
echo "=== training ken2 random (10k) ==="
t0=$(date +%s)
"$PY" train.py -s "$DR" --iterations 10000 --data_device cuda -r 2 \
  --model_path "$OUT/out_ken2_random" --test_iterations -1 --save_iterations 10000 \
  --white_background > "$OUT/out_ken2_random.train.log" 2>&1
t1=$(date +%s)
echo "train time: $(( (t1-t0)/60 ))m$(( (t1-t0)%60 ))s"
echo "=== ken2 results (from training logs) ==="
for init in lidar random; do
  L="$OUT/out_ken2_${init}.train.log"
  ipts=$(grep -oE 'initialisation :[[:space:]]*[0-9]+' "$L" | grep -oE '[0-9]+' | tail -1)
  line=$(tr '\r' '\n' < "$L" | grep 'Loss=' | tail -1)
  loss=$(echo "$line" | grep -oE 'Loss=[0-9.]+' | cut -d= -f2)
  fpts=$(echo "$line" | grep -oE 'Points=[0-9]+' | cut -d= -f2)
  printf 'ken2  %-7s | init_pts %-7s | final_loss %-8s | final_pts %-8s\n' "$init" "${ipts:-?}" "${loss:-?}" "${fpts:-?}"
done
