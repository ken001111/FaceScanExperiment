source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
BIN="$HOME/FaceScan/bin"
GS="$HOME/2d-gaussian-splatting"
OUT="$HOME/FaceScan/initstudy"
rm -rf "$OUT"; mkdir -p "$OUT"
SUM="$OUT/summary.txt"
: > "$SUM"
ITERS=10000
TR="-r 2"; RR="-r 2"

KEN="/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped"
KEN2="/mnt/c/Users/m352395/Downloads/Scan_ken2_20260611_173913_cropped-E657D0B3-7317-4077-B715-F79FFB641FA6/Scan_ken2_20260611_173913_cropped"

train_eval () {
  local name="$1" init="$2" dr="$3"
  local o="$OUT/out_${name}_${init}"
  rm -rf "$o"
  cd "$GS"
  local t0=$(date +%s)
  "$PY" train.py -s "$dr" --iterations $ITERS --data_device cuda $TR \
    --model_path "$o" --test_iterations -1 --save_iterations $ITERS --white_background \
    > "$o.train.log" 2>&1
  local t1=$(date +%s)
  "$PY" render.py -m "$o" --skip_test $RR --depth_trunc 5.0 --sdf_trunc 0.05 \
    --voxel_size 0.01 --num_cluster 20 > "$o.render.log" 2>&1
  export OUTPUT_PATH="$o" RUN_ID="${name}_${init}" DATA_ROOT="$dr"
  "$PY" "$BIN/finish_mesh.py" > "$o.mesh.log" 2>&1
  local ipts=$(grep -oE 'initialisation :\s*[0-9]+' "$o.train.log" | grep -oE '[0-9]+' | tail -1)
  local lline=$(tr '\r' '\n' < "$o.train.log" | grep 'Loss=' | tail -1)
  local loss=$(echo "$lline" | grep -oE 'Loss=[0-9.]+' | cut -d= -f2)
  local fpts=$(echo "$lline" | grep -oE 'Points=[0-9]+' | cut -d= -f2)
  local verts=$(grep 'largest piece' "$o.mesh.log" | grep -oE '[0-9]+ verts' | grep -oE '[0-9]+' | head -1)
  local diag=$(grep -oE 'diagonal: *[0-9.]+' "$o.mesh.log" | grep -oE '[0-9.]+' | tail -1)
  printf '%-5s %-7s | init_pts %-7s | final_loss %-8s final_pts %-8s | mesh_verts %-9s diag_mm %-8s | %dm%02ds\n' \
    "$name" "$init" "${ipts:-?}" "${loss:-?}" "${fpts:-?}" "${verts:-?}" "${diag:-?}" "$(( (t1-t0)/60 ))" "$(( (t1-t0)%60 ))" | tee -a "$SUM"
  cp "$HOME/FaceScan/results/Face_Mesh_MetricScale_${name}_${init}_nn.ply" /mnt/c/Users/m352395/Downloads/ 2>/dev/null
}

for pair in "ken|$KEN" "ken2|$KEN2"; do
  name="${pair%%|*}"; dir="${pair#*|}"
  echo "######## $name : prep (LiDAR) ########" | tee -a "$SUM"
  SCAN_DIR="$dir" FRAMES=120 LIDAR_INIT=1 "$PY" "$BIN/prep.py" > "$OUT/prep_$name.log" 2>&1
  dr=$(grep '^DATA_ROOT=' "$OUT/prep_$name.log" | tail -1 | cut -d= -f2-)
  grep -E 'Subsampled|Sharpness|Applied|LiDAR seed|Init:|OK data ready' "$OUT/prep_$name.log" | tee -a "$SUM"
  train_eval "$name" "lidar" "$dr"
  rm -f "$dr/points3d.ply"          # force random seed
  train_eval "$name" "random" "$dr"
done
echo "" | tee -a "$SUM"
echo "==================== INIT STUDY SUMMARY ====================" | tee -a "$SUM"
grep -E '\| init_pts' "$SUM"
echo "DONE_INIT_STUDY"
