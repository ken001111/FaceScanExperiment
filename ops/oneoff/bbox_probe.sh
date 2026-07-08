#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os, glob
def bb(p, what):
    if what == 'mesh': g = o3d.io.read_triangle_mesh(p)
    else: g = o3d.io.read_point_cloud(p)
    n = len(g.vertices) if what=='mesh' else len(g.points)
    if n == 0: print(f"{p}: EMPTY"); return
    b = g.get_axis_aligned_bounding_box()
    print(f"{os.path.basename(p)} ({what}, n={n}): ctr {np.round(np.asarray(b.get_center()),2)} ext {np.round(np.asarray(b.get_extent()),2)}")
R = os.path.expanduser("~/FaceScan/work/face_scan")
bb(f"{R}/points3D.ply", 'pcd')
bb(f"{R}/points3d.ply", 'pcd')
M = glob.glob(os.path.expanduser("~/FaceScan/output/geosvr_best/**/tsdf_fusion_post.ply"), recursive=True)
for p in M: bb(p, 'mesh')
PY
