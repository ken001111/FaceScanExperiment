cd /mnt/c/Users/m352395/Downloads/paper_experiments
rm -rf __pycache__ */__pycache__
SHIM='import os, sys\nsys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))'
for f in method_comparison/table1_tier0_frame_vs_cad.py method_comparison/table2_tier1_surface.py \
         method_comparison/figure2_method_heatmaps.py initialization_study/table3_init_study.py \
         initialization_study/figure3_init_comparison.py initialization_study/eval_convergence.py; do
  if grep -q '"\.\.", "common"' "$f"; then echo "skip $f"; continue; fi
  sed -i "0,/^import eval_common/s//${SHIM}\nimport eval_common/" "$f"
  echo "patched $f"
done
# preliminary/: point its existing shim at ../common
sed -i 's#sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # repo root#sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "common"))#' preliminary/table_method_surface.py
echo "=== verify shim present ==="
grep -l '"\.\.", "common"' method_comparison/*.py initialization_study/*.py
grep -n 'common' preliminary/table_method_surface.py | head -1
