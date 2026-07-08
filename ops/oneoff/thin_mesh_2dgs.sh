#!/bin/bash
# Gentle 2DGS mesh step: fuse from every 2nd training view via a thinned dataset
# root (symlinked images, halved transforms). Usage: bash thin_mesh_2dgs.sh <data_root> <model_dir> <log>
DR="$1"; MODEL="$2"; LOG="$3"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
THIN="${DR}_meshthin"
if [ ! -d "$THIN" ]; then
  mkdir -p "$THIN"
  for f in images points3D.ply points3d.ply scale_factor.txt; do
    [ -e "$DR/$f" ] && ln -s "$DR/$f" "$THIN/$f"
  done
  python - "$DR" "$THIN" <<'PY'
import json, sys, os
src, dst = sys.argv[1], sys.argv[2]
for tf in ("transforms_train.json", "transforms_test.json"):
    t = json.load(open(f"{src}/{tf}"))
    t["frames"] = t["frames"][::2] if tf.endswith("train.json") else t["frames"][:3]
    json.dump(t, open(f"{dst}/{tf}", "w"), indent=2)
    print(dst, tf, len(t["frames"]))
PY
fi
cd ~/2d-gaussian-splatting
export PYTHONPATH="$HOME/2d-gaussian-splatting"
python render.py -m "$MODEL" -s "$THIN" --quiet --skip_test --skip_train --data_device cpu \
  --voxel_size 0.01 --sdf_trunc 0.04 --depth_trunc 3.5 --num_cluster 1 > "$LOG" 2>&1
ec=$?
echo "mesh exit=$ec"
ls "$MODEL/train/ours_30000/"*.ply 2>/dev/null
