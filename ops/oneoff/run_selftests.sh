PY="$HOME/miniconda3/envs/facescan/bin/python"
# scipy is optional (stats has a numpy fallback) but install for the real Wilcoxon
"$PY" -c "import scipy" 2>/dev/null || "$PY" -m pip install -q scipy
cd /mnt/c/Users/m352395/Downloads/paper_experiments
for s in table1_tier0_frame_vs_cad table2_tier1_surface figure2_method_heatmaps table3_init_study figure3_init_comparison; do
  echo "================= $s --selftest ================="
  "$PY" "$s.py" --selftest 2>&1 | tail -12
  echo "exit: ${PIPESTATUS[0]}"
done
