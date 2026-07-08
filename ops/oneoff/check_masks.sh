#!/bin/bash
echo "--- mask refs in dataloader:"
grep -rn "mask" ~/geosvr/src/dataloader/*.py | grep -iv "blend_mask\|composite" | head -12
echo "--- transforms frame keys:"
python3 - <<'PY'
import json
t = json.load(open('/home/m352395/FaceScan/work/face_scan/transforms_train.json'))
f = t['frames'][0]
print(sorted(f.keys()))
print("n_frames:", len(t['frames']))
PY
echo "--- mask files on disk:"
ls ~/FaceScan/work/face_scan/ | head
find ~/FaceScan/work/face_scan -maxdepth 2 -iname "*mask*" | head -4
