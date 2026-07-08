#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import os, glob, shutil
from PIL import Image
import numpy as np
DR = os.path.expanduser("~/FaceScan/work/dummy_head")
MT = os.path.expanduser("~/FaceScan/work/dummy_head_matte/masks_matte")
missing = 0
for p in sorted(glob.glob(f"{DR}/images/*.png")):
    stem = os.path.splitext(os.path.basename(p))[0]
    if os.path.exists(f"{MT}/{stem}.png"): continue
    cands = [f"{DR}/masks/{stem}.png"] + sorted(glob.glob(f"{DR}/masks/{stem}.*png"))
    src = next((c for c in cands if os.path.exists(c)), None)
    if src:
        m = np.array(Image.open(src).convert("L"))
        Image.fromarray((m > 127).astype(np.uint8)*255).save(f"{MT}/{stem}.png")
        missing += 1
print("filled", missing, "gaps with circle masks; total mattes:", len(glob.glob(f"{MT}/*.png")))
PY
