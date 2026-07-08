#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, os, glob
from PIL import Image
D = os.path.expanduser("~/FaceScan/output/geosvr_best/train/ours_20000_r2.0")
print("dirs:", sorted(os.listdir(D)))
cands = glob.glob(f"{D}/**/frame_00050*", recursive=True)
for c in sorted(cands): print(" ", c.replace(D,''))
# find a depth artifact
dep = [c for c in cands if 'depth' in c.lower() or c.endswith('.npy') or c.endswith('.npz')]
if dep:
    p = dep[0]
    d = np.load(p) if p.endswith(('.npy','.npz')) else np.array(Image.open(p)).astype(np.float32)
    if hasattr(d,'files'): d = d[d.files[0]]
    d = np.squeeze(d)
    print("depth", p.replace(D,''), d.shape, "min %.3f max %.3f" % (d.min(), d.max()))
    vals = d[d>0]
    qs = np.percentile(vals, [5,25,50,75,95])
    print("depth percentiles(>0):", np.round(qs,2))
    dn = (d - d.min())/(d.max()-d.min()+1e-9)
    Image.fromarray((dn*255).astype(np.uint8)).save('/mnt/c/Users/m352395/Downloads/mesh_previews/depth50.png')
    print("saved depth50.png")
else:
    print("NO depth artifact found for frame 50")
PY
