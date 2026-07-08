source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
cd /mnt/c/Users/m352395/Downloads/facescan_work
export PYTHONPATH="$(pwd)/src:$PYTHONPATH"
echo "=== python + deps ==="
python -c "import numpy,yaml,open3d,matplotlib; print('deps ok')" || { echo DEPS_MISSING; }
echo "=== list models ==="
python scripts/run_experiment.py --list-models
echo "=== dummy experiment end-to-end ==="
python scripts/run_experiment.py --config configs/example_dummy.yaml
echo "=== pytest (if available) ==="
python -m pytest -q 2>&1 | tail -25 || echo "pytest not available or failed"
echo "=== aggregate ==="
python scripts/aggregate_results.py --results_dir outputs/ --out results/ --group_by model 2>&1 | tail -15
echo "TEST_FRAMEWORK_DONE"
