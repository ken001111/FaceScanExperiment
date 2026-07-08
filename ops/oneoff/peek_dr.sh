source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
DR=~/FaceScan/work/face_scan
echo "DR=$DR"
echo "=== contents ==="; ls "$DR"
echo "=== images ==="; ls "$DR/images" | head -3
echo "=== masks ==="; ls "$DR/masks" 2>/dev/null | head -3
python - <<PY
import json, glob
from PIL import Image
imgs=sorted(glob.glob("$DR/images/*"))
print("n images:", len(imgs))
if imgs:
    im=Image.open(imgs[0]); print("img0:", imgs[0].split('/')[-1], im.mode, im.size)
tj="$DR/transforms_train.json"
import os
if os.path.exists(tj):
    d=json.load(open(tj)); print("frame0 file_path:", d['frames'][0].get('file_path'))
    print("n frames:", len(d['frames']))
PY
