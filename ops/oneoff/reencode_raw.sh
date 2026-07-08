#!/bin/bash
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import glob, os
from PIL import Image
from pillow_heif import register_heif_opener
register_heif_opener()
SRC = "/mnt/c/Users/M352395/Downloads/Scan_depth5_20260630_200737_cropped-5995F03E-250E-433F-9EDB-80FE41645811/Scan_depth5_20260630_200737_cropped/images"
files = sorted(glob.glob(os.path.expanduser("~/FaceScan/work/dummy_head_raw/images/*.png")))
fixed = healed = 0
for p in files:
    ok = False
    try:
        with open(p, "rb") as f:
            magic = f.read(8)
        if magic == b"\x89PNG\r\n\x1a\n":
            Image.open(p).verify()   # truncated PNGs fail here
            ok = True
    except Exception:
        ok = False
    if ok: continue
    stem = os.path.splitext(os.path.basename(p))[0]
    try:
        im = Image.open(p).convert("RGB")       # heic bytes under .png name
        fixed += 1
    except Exception:
        im = Image.open(f"{SRC}/{stem}.heic").convert("RGB")   # corrupt -> re-pull source
        healed += 1
    im.save(p, format="PNG")
print(f"re-encoded {fixed}, healed-from-source {healed}, total {len(files)}")
PY
echo REENCODE_DONE
