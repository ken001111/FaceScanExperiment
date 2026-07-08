#!/bin/bash
# 3DGS scan24 mesh: fuse rendered depths with the SAME TSDF params as the 2DGS
# DTU protocol (voxel 0.004, sdf_trunc 0.016, depth_trunc 3.0), then run the
# same official 2DGS DTU chamfer eval on the result.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
python ~/gs_external/mesh_3dgs_tsdf.py -m "$B/3dgs/scan24" --iteration 30000 \
  --voxel 0.004 --sdf_trunc 0.016 --depth_trunc 3.0 --num_cluster 1 \
  --out "$B/3dgs/scan24/fuse_post.ply" > "$B/3dgs/scan24_mesh.log" 2>&1 || { echo MESH_FAIL; tail -6 "$B/3dgs/scan24_mesh.log"; exit 1; }
tail -2 "$B/3dgs/scan24_mesh.log"
cd ~/2d-gaussian-splatting
python scripts/eval_dtu/evaluate_single_scene.py \
  --input_mesh "$B/3dgs/scan24/fuse_post.ply" \
  --scan_id 24 --output_dir "$B/3dgs/eval_scan24" \
  --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/3dgs/scan24_eval.log" 2>&1 || { echo EVAL_FAIL; tail -6 "$B/3dgs/scan24_eval.log"; exit 1; }
tail -2 "$B/3dgs/scan24_eval.log"
echo BENCH_3DGS_MESH_DONE
