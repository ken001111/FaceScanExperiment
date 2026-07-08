source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
DR=~/FaceScan/work/face_scan
echo "=== contents ==="; ls "$DR"
echo "=== images (first 3 real) ==="; ls "$DR/images" | grep -ivE 'thumbs.db' | head -3
echo "=== masks present? ==="; ls "$DR/masks" 2>/dev/null | grep -ivE 'thumbs.db' | head -3 || echo "NO masks dir"
python - <<PY
import json, glob, os
from PIL import Image
imgs=[f for f in sorted(glob.glob("$DR/images/*")) if not f.lower().endswith('thumbs.db')]
print("n images:", len(imgs))
im=Image.open(imgs[0]); print("img0:", os.path.basename(imgs[0]), im.mode, im.size)
tj="$DR/transforms_train.json"
if os.path.exists(tj):
    d=json.load(open(tj)); print("frame0 file_path:", d['frames'][0].get('file_path'), "| n frames:", len(d['frames']))
PY
