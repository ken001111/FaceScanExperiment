#!/bin/bash
# Build face_scan_raw (original ken frames, no masking) and start GeoSVR on it.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
SRC='/mnt/c/Users/M352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped'
sed "s|work/face_scan'|work/face_scan_raw'|; s|masks_dir = DATA_ROOT/'masks'|masks_dir = DATA_ROOT/'masks_DISABLED'|" \
    ~/FaceScan/bin/prep.py > ~/FaceScan/bin/prep_ken_raw.py
grep -c "face_scan_raw" ~/FaceScan/bin/prep_ken_raw.py
SCAN_DIR="$SRC" python ~/FaceScan/bin/prep_ken_raw.py 2>&1 | grep -E 'DATA_ROOT|OK data'
python - <<'PY'
import json, os, glob
from PIL import Image
from pillow_heif import register_heif_opener
register_heif_opener()
DR = os.path.expanduser("~/FaceScan/work/face_scan_raw")
# re-encode heic-bytes-as-png (masking disabled -> prep didn't re-save)
SRC = "/mnt/c/Users/M352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped/images"
fixed = 0
for p in sorted(glob.glob(f"{DR}/images/*.png")):
    try:
        with open(p, "rb") as f: magic = f.read(8)
        if magic == b"\x89PNG\r\n\x1a\n":
            Image.open(p).verify(); continue
    except Exception:
        pass
    stem = os.path.splitext(os.path.basename(p))[0]
    try:
        im = Image.open(p).convert("RGB")
    except Exception:
        im = Image.open(f"{SRC}/{stem}.heic").convert("RGB")
    im.save(p, format="PNG"); fixed += 1
print("re-encoded", fixed)
for tf in ("transforms_train.json", "transforms_test.json"):
    p = f"{DR}/{tf}"
    t = json.load(open(p))
    for fr in t.get("frames", []):
        fr.pop("depth_path", None); fr.pop("mask_path", None)
    if tf.endswith("test.json"):
        t["frames"] = t["frames"][::8]
    json.dump(t, open(p, "w"), indent=2)
    print(p, len(t["frames"]))
PY
echo KEN_RAW_BUILD_DONE
