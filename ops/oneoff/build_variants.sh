#!/bin/bash
# Build two dummy-head dataset variants:
#  A) dummy_head_raw      — original images, NO masking anywhere (mask_path stripped)
#  B) dummy_head_appmask  — the app's own photogrammetry/images_masked as training images
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
SRC='/mnt/c/Users/M352395/Downloads/Scan_depth5_20260630_200737_cropped-5995F03E-250E-433F-9EDB-80FE41645811/Scan_depth5_20260630_200737_cropped'

echo "--- inspect one app-masked frame:"
python - <<PY
from PIL import Image
from pillow_heif import register_heif_opener
register_heif_opener()
import numpy as np
im = Image.open("$SRC/photogrammetry/images_masked/frame_00040.heic")
print("mode:", im.mode, "size:", im.size)
a = np.array(im)
print("shape:", a.shape)
if a.shape[-1] == 4:
    print("alpha: min", a[...,3].min(), "max", a[...,3].max(), "fg frac", (a[...,3]>127).mean().round(3))
else:
    corners = np.concatenate([a[:40,:40].reshape(-1,a.shape[-1]), a[-40:,-40:].reshape(-1,a.shape[-1])])
    print("corner mean color:", corners.mean(0).round(1))
im.convert("RGB").resize((760,570)).save("/mnt/c/Users/m352395/Downloads/matte_previews/appmask_40.png")
PY

echo "--- variant A: raw ---"
sed "s|work/dummy_head'|work/dummy_head_raw'|; s|masks_dir = DATA_ROOT/'masks'|masks_dir = DATA_ROOT/'masks_DISABLED'|" \
    ~/FaceScan/bin/prep.py > ~/FaceScan/bin/prep_dummy_raw.py
grep -n "dummy_head_raw\|masks_DISABLED" ~/FaceScan/bin/prep_dummy_raw.py | head -2
SCAN_DIR="$SRC" python ~/FaceScan/bin/prep_dummy_raw.py 2>&1 | tail -4

echo "--- variant B: appmask ---"
STAGE=~/FaceScan/work/.appmask_stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$SRC/transforms.json" "$SRC/points3D.ply" "$SRC/crop.json" "$STAGE/" 2>/dev/null || true
cp -r "$SRC/photogrammetry/images_masked" "$STAGE/images"
sed "s|work/dummy_head'|work/dummy_head_appmask'|; s|masks_dir = DATA_ROOT/'masks'|masks_dir = DATA_ROOT/'masks_DISABLED'|" \
    ~/FaceScan/bin/prep.py > ~/FaceScan/bin/prep_dummy_appmask.py
SCAN_DIR="$STAGE" python ~/FaceScan/bin/prep_dummy_appmask.py 2>&1 | tail -4
rm -rf "$STAGE"

echo "--- postprocess both: strip depth_path + mask_path, thin test split ---"
python - <<'PY'
import json, os
for root in ("~/FaceScan/work/dummy_head_raw", "~/FaceScan/work/dummy_head_appmask"):
    for tf in ("transforms_train.json", "transforms_test.json"):
        p = os.path.expanduser(f"{root}/{tf}")
        t = json.load(open(p))
        for fr in t.get("frames", []):
            fr.pop("depth_path", None); fr.pop("mask_path", None)
        if tf.endswith("test.json"):
            t["frames"] = t["frames"][::8]
        json.dump(t, open(p, "w"), indent=2)
        print(p, len(t["frames"]))
PY
ls ~/FaceScan/work/ | grep dummy
df -h / | tail -1
echo VARIANTS_DONE
