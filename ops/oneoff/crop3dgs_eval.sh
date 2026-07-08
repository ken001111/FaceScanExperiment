#!/bin/bash
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
B=~/FaceScan/bench
python - <<'PY'
import numpy as np, open3d as o3d, os
import json
p = os.path.expanduser("~/FaceScan/bench/3dgs/scan24/fuse_post.ply")
m = o3d.io.read_triangle_mesh(p)
v = np.asarray(m.vertices)
print("before:", len(v), "extent", np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1))
m.scale(0.001, center=(0,0,0))   # undo the script's ken-era x1000 mm conversion
v = np.asarray(m.vertices)
cams = json.load(open(os.path.expanduser("~/FaceScan/bench/3dgs/scan24/cameras.json")))
pos = np.array([c["position"] for c in cams])
ctr = pos.mean(0)
spread = float(np.linalg.norm(pos - ctr, axis=1).max())
print("cam centroid", np.round(ctr,2), "spread", round(spread,2))
# keep everything within 2x the camera spread of the rig centroid; beyond is junk
keep = np.linalg.norm(v - ctr, axis=1) < 2.0 * spread
m.remove_vertices_by_mask(~keep)
print("after:", len(m.vertices), "extent", np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1))
o3d.io.write_triangle_mesh(os.path.expanduser("~/FaceScan/bench/3dgs/scan24/fuse_post_crop.ply"), m)
PY
cd ~/2d-gaussian-splatting
python scripts/eval_dtu/evaluate_single_scene.py \
  --input_mesh "$B/3dgs/scan24/fuse_post_crop.ply" \
  --scan_id 24 --output_dir "$B/3dgs/eval_scan24" \
  --mask_dir ~/FaceScan/data/DTU_2dgs --DTU ~/FaceScan/data/DTU \
  > "$B/3dgs/scan24_eval.log" 2>&1
echo "3DGS chamfer:"
grep -E '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/3dgs/scan24_eval.log" | tail -1
echo CROP3DGS_EVAL_DONE
