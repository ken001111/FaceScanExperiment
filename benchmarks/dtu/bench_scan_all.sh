#!/bin/bash
# DTU benchmark for one scan across all 4 methods, paper-default configs.
# Usage: bash bench_scan_all.sh <scan_id>    e.g. 37
# All pitfalls pre-fixed: PYTHONPATH per repo, trimesh numpy2 patch (done),
# 3DGS --scale_factor 1000 (defeats the ken-era mm conversion).
SCAN="$1"
[ -n "$SCAN" ] || { echo "usage: $0 <scan_id>"; exit 1; }
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench
mkdir -p "$B"/{2dgs,3dgs,svraster,geosvr}

echo "########## [1/4] 2DGS scan$SCAN ##########"
cd ~/2d-gaussian-splatting
export PYTHONPATH="$HOME/2d-gaussian-splatting"
if [ ! -f "$B/2dgs/scan$SCAN/train/ours_30000/fuse_post.ply" ]; then
  python train.py -s "$DATA/scan$SCAN" -m "$B/2dgs/scan$SCAN" --quiet --test_iterations -1 --depth_ratio 1.0 -r 2 --lambda_dist 1000 > "$B/2dgs/scan${SCAN}_train.log" 2>&1
  python render.py --iteration 30000 -s "$DATA/scan$SCAN" -m "$B/2dgs/scan$SCAN" --quiet --skip_train --depth_ratio 1.0 --num_cluster 1 --voxel_size 0.004 --sdf_trunc 0.016 --depth_trunc 3.0 > "$B/2dgs/scan${SCAN}_mesh.log" 2>&1
fi
python scripts/eval_dtu/evaluate_single_scene.py --input_mesh "$B/2dgs/scan$SCAN/train/ours_30000/fuse_post.ply" \
  --scan_id "$SCAN" --output_dir "$B/2dgs/eval_scan$SCAN" --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/2dgs/scan${SCAN}_eval.log" 2>&1
echo "2DGS scan$SCAN chamfer: $(grep -aE '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/2dgs/scan${SCAN}_eval.log" | tail -1)"

echo "########## [2/4] 3DGS scan$SCAN ##########"
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
if [ ! -d "$B/3dgs/scan$SCAN/point_cloud/iteration_30000" ]; then
  python train.py -s "$DATA/scan$SCAN" -m "$B/3dgs/scan$SCAN" -r 2 --quiet --test_iterations -1 > "$B/3dgs/scan${SCAN}_train.log" 2>&1
fi
python ~/gs_external/mesh_3dgs_tsdf.py -m "$B/3dgs/scan$SCAN" --iteration 30000 \
  --voxel 0.004 --sdf_trunc 0.016 --depth_trunc 3.0 --num_cluster 1 --scale_factor 1000 \
  --out "$B/3dgs/scan$SCAN/fuse_post.ply" > "$B/3dgs/scan${SCAN}_mesh.log" 2>&1
cd ~/2d-gaussian-splatting
python scripts/eval_dtu/evaluate_single_scene.py --input_mesh "$B/3dgs/scan$SCAN/fuse_post.ply" \
  --scan_id "$SCAN" --output_dir "$B/3dgs/eval_scan$SCAN" --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/3dgs/scan${SCAN}_eval.log" 2>&1
echo "3DGS scan$SCAN chamfer: $(grep -aE '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/3dgs/scan${SCAN}_eval.log" | tail -1)"

echo "########## [3/4] SVRaster scan$SCAN ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$B/svraster/scan$SCAN"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$NEUS/dtu_scan$SCAN/" --model_path "$S" > "$B/svraster/scan${SCAN}_train.log" 2>&1
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$B/svraster/scan${SCAN}_render.log" 2>&1
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan${SCAN}_mesh.log" 2>&1
fi
mkdir -p "$S/mesh/latest/evaluation"
python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan$SCAN/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan${SCAN}_clean.log" 2>&1
python scripts/dtu_eval/eval.py --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
  --scan "$SCAN" --dataset_dir "$OFFICIAL" --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan${SCAN}_eval.log" 2>&1
echo "SVRaster scan$SCAN chamfer: $(tr '\r' '\n' < "$B/svraster/scan${SCAN}_eval.log" | grep -avE 'it/s|%|^\s*$' | tail -1)"

echo "########## [4/4] GeoSVR scan$SCAN (official cmds inline; PYTHONPATH-safe) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$B/geosvr/scan$SCAN"
if [ ! -d "$G/checkpoints" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DATA/scan$SCAN/" --model_path "$G" --test_iterations 6000 15000 > "$B/geosvr/scan${SCAN}_train.log" 2>&1
  python render.py "$G" --skip_test --use_jpg > "$B/geosvr/scan${SCAN}_render.log" 2>&1
fi
if [ "$SCAN" == "110" ]; then
  python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 --sdf_trunc_scale 1.5 > "$B/geosvr/scan${SCAN}_mesh.log" 2>&1
else
  python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$B/geosvr/scan${SCAN}_mesh.log" 2>&1
fi
python scripts/eval_dtu_vanilla/evaluate_single_scene.py --input_mesh "$G/mesh/tsdf/tsdf_fusion_post.ply" \
  --scan_id "$SCAN" --output_dir "$G/mesh/tsdf/" --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/geosvr/scan${SCAN}_eval.log" 2>&1
echo "GeoSVR scan$SCAN chamfer: $(grep -aE '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/geosvr/scan${SCAN}_eval.log" | tail -1)"

echo "########## scan$SCAN ALL DONE ##########"
