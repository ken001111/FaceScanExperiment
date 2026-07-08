#!/bin/bash
# Recovery: correct sed target (prep_dummy.py, which already points at dummy_head),
# rebuild both variants, then rebuild ken and swap it back.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
SRC='/mnt/c/Users/M352395/Downloads/Scan_depth5_20260630_200737_cropped-5995F03E-250E-433F-9EDB-80FE41645811/Scan_depth5_20260630_200737_cropped'

echo "--- variant A: raw (sed on prep_dummy.py) ---"
sed "s|work/dummy_head'|work/dummy_head_raw'|; s|masks_dir = DATA_ROOT/'masks'|masks_dir = DATA_ROOT/'masks_DISABLED'|" \
    ~/FaceScan/bin/prep_dummy.py > ~/FaceScan/bin/prep_dummy_raw.py
grep -c "dummy_head_raw" ~/FaceScan/bin/prep_dummy_raw.py
SCAN_DIR="$SRC" python ~/FaceScan/bin/prep_dummy_raw.py 2>&1 | grep -E 'DATA_ROOT|OK data'

echo "--- variant B: appmask ---"
STAGE=~/FaceScan/work/.appmask_stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$SRC/transforms.json" "$SRC/points3D.ply" "$SRC/crop.json" "$STAGE/" 2>/dev/null || true
cp -r "$SRC/photogrammetry/images_masked" "$STAGE/images"
sed "s|work/dummy_head'|work/dummy_head_appmask'|; s|masks_dir = DATA_ROOT/'masks'|masks_dir = DATA_ROOT/'masks_DISABLED'|" \
    ~/FaceScan/bin/prep_dummy.py > ~/FaceScan/bin/prep_dummy_appmask.py
SCAN_DIR="$STAGE" python ~/FaceScan/bin/prep_dummy_appmask.py 2>&1 | grep -E 'DATA_ROOT|OK data'
rm -rf "$STAGE"

echo "--- postprocess variants ---"
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

echo "--- rebuild ken (was clobbered by the bad sed) ---"
rm -rf ~/FaceScan/work/face_scan ~/FaceScan/work/face_scan_rebuild
SCAN_DIR='/mnt/c/Users/M352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped' \
  python ~/FaceScan/bin/prep_ken_rebuild.py 2>&1 | grep -E 'DATA_ROOT|OK data|LiDAR'
mv ~/FaceScan/work/face_scan_rebuild ~/FaceScan/work/face_scan
readlink -e ~/FaceScan/work/face_scan_matte/images >/dev/null && echo "ken matte symlinks OK"
ls ~/FaceScan/work/ | grep -E 'dummy|face'
echo FIX_VARIANTS_DONE
