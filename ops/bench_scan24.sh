#!/bin/bash
# DTU scan24 pilot: 2DGS -> 3DGS -> GeoSVR (SVRaster runs separately once NeuS
# preproc lands). Commands are verbatim from each repo's official DTU scripts.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench
mkdir -p "$B"/{2dgs,3dgs,geosvr}

echo "########## [1/3] 2DGS scan24 (official dtu_eval.py commands) ##########"
cd ~/2d-gaussian-splatting
if [ ! -f "$B/2dgs/scan24/train/ours_30000/fuse_post.ply" ]; then
  python train.py -s "$DATA/scan24" -m "$B/2dgs/scan24" --quiet --test_iterations -1 --depth_ratio 1.0 -r 2 --lambda_dist 1000 \
    > "$B/2dgs/scan24_train.log" 2>&1 || { echo 2DGS_TRAIN_FAIL; tail -5 "$B/2dgs/scan24_train.log"; }
  python render.py --iteration 30000 -s "$DATA/scan24" -m "$B/2dgs/scan24" --quiet --skip_train --depth_ratio 1.0 --num_cluster 1 --voxel_size 0.004 --sdf_trunc 0.016 --depth_trunc 3.0 \
    > "$B/2dgs/scan24_mesh.log" 2>&1 || { echo 2DGS_MESH_FAIL; tail -5 "$B/2dgs/scan24_mesh.log"; }
fi
python scripts/eval_dtu/evaluate_single_scene.py \
  --input_mesh "$B/2dgs/scan24/train/ours_30000/fuse_post.ply" \
  --scan_id 24 --output_dir "$B/2dgs/eval_scan24" \
  --mask_dir "$DATA" --DTU "$OFFICIAL" \
  > "$B/2dgs/scan24_eval.log" 2>&1 || { echo 2DGS_EVAL_FAIL; tail -8 "$B/2dgs/scan24_eval.log"; }
tail -3 "$B/2dgs/scan24_eval.log"

echo "########## [2/3] 3DGS scan24 (repo-default train; TSDF mesh note applies) ##########"
cd ~/gaussian-splatting
if [ ! -d "$B/3dgs/scan24/point_cloud/iteration_30000" ]; then
  python train.py -s "$DATA/scan24" -m "$B/3dgs/scan24" -r 2 --quiet --test_iterations -1 \
    > "$B/3dgs/scan24_train.log" 2>&1 || { echo 3DGS_TRAIN_FAIL; tail -5 "$B/3dgs/scan24_train.log"; }
fi
echo "3DGS training done (mesh extraction handled in eval step)"

echo "########## [3/3] GeoSVR scan24 (official dtu_run.sh, subset 1/15) ##########"
cd ~/geosvr
mkdir -p data
ln -sfn "$DATA" data/DTU_2dgs
ln -sfn "$OFFICIAL" data/DTU
bash scripts/dtu_run.sh "$B/geosvr" 15 1 > "$B/geosvr/scan24_run.log" 2>&1 || { echo GEOSVR_FAIL; tail -8 "$B/geosvr/scan24_run.log"; }
grep -iE "mean|overall|chamfer|d2s|s2d" "$B/geosvr/scan24_run.log" | tail -5

echo "########## PILOT CHAIN DONE ##########"
df -h / | tail -1
echo BENCH_SCAN24_DONE
