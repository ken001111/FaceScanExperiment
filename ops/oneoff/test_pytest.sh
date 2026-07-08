source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
cd /mnt/c/Users/m352395/Downloads/facescan_work
pip install -q pytest 2>&1 | tail -1
echo "=== list-models ==="
python scripts/run_experiment.py --list-models
echo "=== pytest ==="
python -m pytest -q 2>&1 | tail -30
echo "PYTEST_DONE"
