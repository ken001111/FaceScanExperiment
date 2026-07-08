#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import glob, os
from PIL import Image
bad = []
d = os.path.expanduser("~/FaceScan/param_study/geosvr_dummy_raw/train/ours_20000_r2.0/renders")
if not os.path.isdir(d):
    cands = glob.glob(os.path.expanduser("~/FaceScan/param_study/geosvr_dummy_raw/train/ours_*/renders"))
    d = cands[0] if cands else None
print("renders dir:", d)
files = sorted(glob.glob(f"{d}/*"))
print("n files:", len(files))
for p in files:
    try:
        im = Image.open(p); im.verify()
        im = Image.open(p); im.load()
    except Exception as e:
        bad.append((os.path.basename(p), str(e)[:60]))
print("corrupt:", bad if bad else "none")
PY
