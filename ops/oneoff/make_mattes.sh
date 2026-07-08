#!/bin/bash
# Generate true head mattes for the ken frames with rembg (human segmentation),
# then build a parallel dataset root face_scan_matte with mask_path -> mattes.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
pip install -q "rembg[cpu]" 2>&1 | tail -1 || true
DR=~/FaceScan/work/face_scan
MT=~/FaceScan/work/face_scan_matte
python - <<'PY'
import os, glob, json, shutil
import numpy as np
from PIL import Image
from rembg import remove, new_session
DR = os.path.expanduser("~/FaceScan/work/face_scan")
MT = os.path.expanduser("~/FaceScan/work/face_scan_matte")
os.makedirs(f"{MT}/masks_matte", exist_ok=True)
sess = new_session("u2net_human_seg")
imgs = sorted(glob.glob(f"{DR}/images/*.png")) + sorted(glob.glob(f"{DR}/images/*.jpg"))
print("frames:", len(imgs))
for i, p in enumerate(imgs):
    name = os.path.splitext(os.path.basename(p))[0]
    out = f"{MT}/masks_matte/{name}.png"
    if os.path.exists(out): continue
    try:
        im = Image.open(p).convert("RGB")
    except Exception as e:
        print("skip unreadable:", os.path.basename(p), e); continue
    m = remove(im, session=sess, only_mask=True)
    # binarize + AND with the capture circle so stray background people/objects outside the ROI can't leak in
    m = np.array(m)
    circ_p = f"{DR}/masks/{name}.heic.png"
    if not os.path.exists(circ_p): circ_p = f"{DR}/masks/{name}.png"
    if os.path.exists(circ_p):
        circ = np.array(Image.open(circ_p).convert("L").resize(m.shape[::-1] if m.ndim==2 else (m.shape[1], m.shape[0])))
        m = np.where(circ > 127, m, 0)
    Image.fromarray((m > 127).astype(np.uint8) * 255).save(out)
    if i % 20 == 0: print(f"{i}/{len(imgs)}")
# dataset root: symlink images + seed clouds, rewrite transforms to point at mattes
for f in ("images", "points3D.ply", "points3d.ply", "scale_factor.txt"):
    src, dst = f"{DR}/{f}", f"{MT}/{f}"
    if os.path.exists(src) and not os.path.exists(dst):
        os.symlink(src, dst)
for tf in ("transforms_train.json", "transforms_test.json"):
    t = json.load(open(f"{DR}/{tf}"))
    for fr in t.get("frames", []):
        stem = os.path.splitext(os.path.basename(fr["file_path"]))[0]
        fr["mask_path"] = f"masks_matte/{stem}.png"
    json.dump(t, open(f"{MT}/{tf}", "w"), indent=2)
print("matte dataset root ready:", MT)
PY
# preview grid source: copy 3 mattes to Windows
mkdir -p /mnt/c/Users/m352395/Downloads/matte_previews
cp "$MT"/masks_matte/frame_00000.png "$MT"/masks_matte/frame_00040.png "$MT"/masks_matte/frame_00080.png /mnt/c/Users/m352395/Downloads/matte_previews/ 2>/dev/null || true
echo MATTES_DONE
