#!/bin/bash
# Matte generation v2 — from ORIGINAL scan images (not white-composited prep
# output), with per-frame sanity checks and model fallback.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
python - <<'PY'
import os, glob
import numpy as np
from PIL import Image
from pillow_heif import register_heif_opener
register_heif_opener()
from rembg import remove, new_session

JOBS = [
    # (original scan images dir, work dir, matte root)
    ("/mnt/c/Users/M352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped",
     os.path.expanduser("~/FaceScan/work/face_scan"),
     os.path.expanduser("~/FaceScan/work/face_scan_matte")),
    ("/mnt/c/Users/M352395/Downloads/Scan_depth5_20260630_200737_cropped-5995F03E-250E-433F-9EDB-80FE41645811/Scan_depth5_20260630_200737_cropped",
     os.path.expanduser("~/FaceScan/work/dummy_head"),
     os.path.expanduser("~/FaceScan/work/dummy_head_matte")),
]
s_human = new_session("u2net_human_seg")
s_gen = new_session("isnet-general-use")

def matte(im, circ):
    area = (circ > 127).mean()
    for name, sess in (("human", s_human), ("general", s_gen)):
        m = np.array(remove(im, session=sess, only_mask=True))
        if m.shape != circ.shape:
            m = np.array(Image.fromarray(m).resize((circ.shape[1], circ.shape[0])))
        m = np.where(circ > 127, m, 0)
        frac = (m > 127).mean() / max(area, 1e-6)
        if 0.05 <= frac <= 0.85:
            return (m > 127).astype(np.uint8)*255, name, frac
    return None, "fail", frac

for SRC, DR, MT in JOBS:
    out_dir = f"{MT}/masks_matte"
    os.makedirs(out_dir, exist_ok=True)
    for f in glob.glob(f"{out_dir}/*.png"): os.remove(f)   # nuke misaligned v1
    # work-dir frames define the naming; find source image by stem
    frames = sorted(glob.glob(f"{DR}/images/*.png"))
    print(os.path.basename(DR), "frames:", len(frames))
    stats = {"human":0, "general":0, "fail":0}
    for i, p in enumerate(frames):
        stem = os.path.splitext(os.path.basename(p))[0]
        src = None
        for ext in (".heic", ".HEIC", ".png", ".jpg"):
            c = f"{SRC}/images/{stem}{ext}"
            if os.path.exists(c): src = c; break
        if src is None:
            print("no source for", stem); stats["fail"] += 1; continue
        im = Image.open(src).convert("RGB")
        cp = None
        for c in (f"{DR}/masks/{stem}.png",) + tuple(sorted(glob.glob(f"{DR}/masks/{stem}.*png"))):
            if os.path.exists(c): cp = c; break
        circ = np.array(Image.open(cp).convert("L").resize(im.size)) if cp else np.full(im.size[::-1], 255, np.uint8)
        m, model, frac = matte(im, circ)
        if m is None:
            print(f"FAIL {stem} frac={frac:.2f}"); stats["fail"] += 1; continue
        Image.fromarray(m).save(f"{out_dir}/{stem}.png")
        stats[model] += 1
        if i % 40 == 0: print(f"  {i}: model={model} frac={frac:.2f}")
    print(os.path.basename(DR), "done:", stats)
print("MATTES_V2_DONE")
PY
mkdir -p /mnt/c/Users/m352395/Downloads/matte_previews
cp ~/FaceScan/work/face_scan_matte/masks_matte/frame_00040.png /mnt/c/Users/m352395/Downloads/matte_previews/ken_v2_frame_00040.png 2>/dev/null || true
cp ~/FaceScan/work/dummy_head_matte/masks_matte/frame_00040.png /mnt/c/Users/m352395/Downloads/matte_previews/dummy_v2_frame_00040.png 2>/dev/null || true
echo COPY_DONE
