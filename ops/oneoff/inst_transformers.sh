source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
pip install -q "transformers==4.49.0" 2>&1 | tail -2
python - <<'PY'
import transformers
print("transformers", transformers.__version__)
PY
