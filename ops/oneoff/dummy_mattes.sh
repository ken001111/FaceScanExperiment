#!/bin/bash
# Mattes for the dummy head (CPU): rembg human-seg, circle-clipped, ANDed like ken.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import os, glob
import numpy as np
from PIL import Image
from rembg import remove, new_session
DR = os.path.expanduser("~/FaceScan/work/dummy_head")
MT = os.path.expanduser("~/FaceScan/work/dummy_head_matte")
os.makedirs(f"{MT}/masks_matte", exist_ok=True)
sess = new_session("u2net_human_seg")
imgs = sorted(glob.glob(f"{DR}/images/*.png"))
print("frames:", len(imgs))
for i, p in enumerate(imgs):
    name = os.path.splitext(os.path.basename(p))[0]
    out = f"{MT}/masks_matte/{name}.png"
    if os.path.exists(out): continue
    try:
        im = Image.open(p).convert("RGB")
    except Exception as e:
        print("skip:", name, e); continue
    m = np.array(remove(im, session=sess, only_mask=True))
    circ_p = f"{DR}/masks/{name}.png"
    if not os.path.exists(circ_p):
        c = sorted(glob.glob(f"{DR}/masks/{name}.*png"))
        circ_p = c[0] if c else None
    if circ_p:
        circ = np.array(Image.open(circ_p).convert("L").resize((m.shape[1], m.shape[0])))
        m = np.where(circ > 127, m, 0)
    Image.fromarray((m > 127).astype(np.uint8)*255).save(out)
    if i % 40 == 0: print(f"{i}/{len(imgs)}")
import json
for f in ("images","points3D.ply","points3d.ply","scale_factor.txt"):
    s, d = f"{DR}/{f}", f"{MT}/{f}"
    if os.path.exists(s) and not os.path.exists(d): os.symlink(s, d)
for tf in ("transforms_train.json","transforms_test.json"):
    t = json.load(open(f"{DR}/{tf}"))
    for fr in t.get("frames", []):
        stem = os.path.splitext(os.path.basename(fr["file_path"]))[0]
        fr["mask_path"] = f"masks_matte/{stem}.png"
    json.dump(t, open(f"{MT}/{tf}", "w"), indent=2)
print("dummy matte root ready")
PY
mkdir -p /mnt/c/Users/m352395/Downloads/matte_previews
cp ~/FaceScan/work/dummy_head_matte/masks_matte/frame_00000.png /mnt/c/Users/m352395/Downloads/matte_previews/dummy_frame_00000.png 2>/dev/null || true
echo DUMMY_MATTES_DONE
