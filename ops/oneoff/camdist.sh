#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import json, numpy as np
t = json.load(open('/home/m352395/FaceScan/work/face_scan/transforms_train.json'))
pos = np.array([np.array(f['transform_matrix'])[:3,3] for f in t['frames']])
d = np.linalg.norm(pos, axis=1)
print('cam dist to origin: median %.2f  min %.2f  max %.2f' % (np.median(d), d.min(), d.max()))
c = pos.mean(0)
d2 = np.linalg.norm(pos - c, axis=1)
print('cam dist to cam-centroid: median %.2f' % np.median(d2))
PY
