source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
PE=/mnt/c/Users/m352395/Downloads/paper_experiments
EXP="$HOME/FaceScan/EXPDATA"; SPEC=ken
KEN="/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped"
OC="$KEN/photogrammetry/face_nn.ply"
rm -rf "$EXP/$SPEC"
export ITERS=10000 FRAMES=120 TRAIN_RES='-r 2' RENDER_RES='-r 2'

echo "############ 1) run_methods (2dgs + raw_lidar + object_capture) ############"
OBJCAP_PLY="$OC" bash "$PE/run_methods.sh" "$KEN" "$SPEC" "$EXP"

echo "############ 2) run_init_study (lidar + random) ############"
bash "$PE/run_init_study.sh" "$KEN" "$SPEC" "$EXP"

echo "############ 3) stand-in reference (Object Capture; NO ground-truth CAD/SL for ken) ############"
mkdir -p "$EXP/$SPEC/reference"
cp "$OC" "$EXP/$SPEC/reference/cad_frame.ply"
cp "$OC" "$EXP/$SPEC/reference/structured_light.ply"

echo "############ 4) analysis (tables + figures) ############"
cd "$PE"
RES="$EXP/results"; mkdir -p "$RES"
"$PY" table1_tier0_frame_vs_cad.py --data "$EXP" --out "$RES" 2>&1 | tail -10
"$PY" table2_tier1_surface.py      --data "$EXP" --out "$RES" 2>&1 | tail -8
"$PY" table3_init_study.py         --data "$EXP" --out "$RES" 2>&1 | tail -8
"$PY" figure2_method_heatmaps.py   --data "$EXP" --specimen "$SPEC" --out "$RES" 2>&1 | tail -2
"$PY" figure3_init_comparison.py   --data "$EXP" --specimen "$SPEC" --out "$RES" 2>&1 | tail -2

echo "############ 5) copy artifacts to Downloads ############"
mkdir -p /mnt/c/Users/m352395/Downloads/ken_experiment_results
cp "$RES"/*.md "$RES"/*.csv "$RES"/*.png /mnt/c/Users/m352395/Downloads/ken_experiment_results/ 2>/dev/null
echo "DONE_KEN_EXPERIMENTS"
ls "$RES"
