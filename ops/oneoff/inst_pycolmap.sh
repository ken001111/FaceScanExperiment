source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
pip install -q pycolmap 2>&1 | tail -1
python - <<'PY'
import pycolmap
print("pycolmap", pycolmap.__version__)
PY
