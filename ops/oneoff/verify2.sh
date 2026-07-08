source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
PE=/mnt/c/Users/m352395/Downloads/paper_experiments
echo "=== bash -n (all .sh) ==="
for f in $(find "$PE" -name '*.sh'); do
  tr -d '\r' < "$f" > /tmp/c.sh && bash -n /tmp/c.sh && echo "  OK  ${f#$PE/}" || echo "  FAIL ${f#$PE/}"
done
echo "=== build CRLF-stripped working copy + run selftests from study dirs ==="
W=~/pe_verify; rm -rf "$W"; mkdir -p "$W"
cd "$PE"
for f in $(find . -name '*.py'); do mkdir -p "$W/$(dirname "$f")"; tr -d '\r' < "$f" > "$W/$f"; done
cd "$W"
for s in method_comparison/table1_tier0_frame_vs_cad method_comparison/table2_tier1_surface \
         method_comparison/figure2_method_heatmaps initialization_study/table3_init_study \
         initialization_study/figure3_init_comparison; do
  python "$s.py" --selftest >/dev/null 2>&1 && echo "  OK  $s" || { echo "  FAIL $s"; python "$s.py" --selftest 2>&1 | tail -4; }
done
echo "VERIFY2_DONE"
