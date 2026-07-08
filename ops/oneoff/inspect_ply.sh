echo "=== fetchPly / storePly (dataset_readers.py 107-135) ==="
sed -n '107,135p' ~/2d-gaussian-splatting/scene/dataset_readers.py
echo ""
echo "=== scan LiDAR cloud (points3D.ply) header ==="
"$HOME/miniconda3/envs/facescan/bin/python" - <<'PYEOF'
from plyfile import PlyData
import glob
fs = sorted(glob.glob('/home/m352395/FaceScan/work/face_scan/*/points3D.ply'))
f = fs[0]
p = PlyData.read(f)
v = p['vertex']
print('file:', f)
print('count:', v.count)
print('props:', [x.name for x in v.properties])
import numpy as np
xyz = np.c_[v['x'], v['y'], v['z']]
print('xyz min:', xyz.min(0).round(3), 'max:', xyz.max(0).round(3))
PYEOF
