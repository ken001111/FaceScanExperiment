source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
PE=/mnt/c/Users/m352395/Downloads/paper_experiments
W=~/paper_experiments        # clean (CRLF-stripped) working copy
mkdir -p "$W"
for f in eval_common.py stats_util.py report_util.py assemble_ken.py table_method_surface.py \
         figure2_method_heatmaps.py figure3_init_comparison.py table3_init_study.py; do
  tr -d '\r' < "$PE/$f" > "$W/$f"
done
cd "$W"
EXP=~/FaceScan/EXPDATA; RES="$EXP/results"; mkdir -p "$RES"
echo "########## 1) assemble EXPDATA/ken ##########"
python assemble_ken.py || { echo ASSEMBLE_FAILED; exit 1; }
echo "########## 2) method surface table ##########"
python table_method_surface.py --data "$EXP" --specimen ken --out "$RES"
echo "########## 3) Figure 2 (method heatmaps) ##########"
python figure2_method_heatmaps.py --data "$EXP" --specimen ken --out "$RES" --vmax 5 2>&1 | tail -3
echo "########## 4) Table 3 (init study) ##########"
python table3_init_study.py --data "$EXP" --out "$RES" 2>&1 | tail -20
echo "########## 5) Figure 3 (init comparison) ##########"
python figure3_init_comparison.py --data "$EXP" --specimen ken --out "$RES" --vmax 5 2>&1 | tail -3
echo "########## 6) copy artifacts to Downloads ##########"
mkdir -p /mnt/c/Users/m352395/Downloads/ken_experiment_results
cp "$RES"/*.md "$RES"/*.csv "$RES"/*.png /mnt/c/Users/m352395/Downloads/ken_experiment_results/ 2>/dev/null
echo "DONE_ANALYSIS"; ls -la "$RES"
