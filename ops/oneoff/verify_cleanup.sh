source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
PE=/mnt/c/Users/m352395/Downloads/paper_experiments
echo "=== bash -n syntax check (all .sh) ==="
for f in $(find "$PE" -name '*.sh'); do
  tr -d '\r' < "$f" > /tmp/chk.sh && bash -n /tmp/chk.sh && echo "  OK  ${f#$PE/}" || echo "  FAIL ${f#$PE/}"
done
echo
echo "=== analysis selftests (synthetic data) ==="
W=~/paper_experiments_verify; rm -rf "$W"; mkdir -p "$W"
for f in eval_common.py stats_util.py report_util.py table1_tier0_frame_vs_cad.py table2_tier1_surface.py \
         figure2_method_heatmaps.py table3_init_study.py figure3_init_comparison.py; do
  tr -d '\r' < "$PE/$f" > "$W/$f"
done
cd "$W"
for s in table1_tier0_frame_vs_cad table2_tier1_surface figure2_method_heatmaps table3_init_study figure3_init_comparison; do
  python $s.py --selftest >/dev/null 2>&1 && echo "  OK  $s" || echo "  FAIL $s"
done
echo
echo "=== preliminary/table_method_surface.py imports from repo root? ==="
cd "$PE" && python -c "import sys,os; sys.argv=['x']; exec(open('preliminary/table_method_surface.py').read().split('if __name__')[0]); print('  import OK')" 2>&1 | tail -1
echo "VERIFY_DONE"
