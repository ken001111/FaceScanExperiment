#!/bin/bash
# Pilot part 3: finish all remaining scan24 pieces.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench

echo "########## [1/3] GeoSVR scan24 mesh + eval (official cmds, module path fixed) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
python mesh_extract/tsdf_mesh.py "$B/geosvr/scan24/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 \
  > "$B/geosvr/scan24_mesh.log" 2>&1 || { echo GEO_MESH_FAIL; tail -5 "$B/geosvr/scan24_mesh.log"; }
python scripts/eval_dtu_vanilla/evaluate_single_scene.py \
  --input_mesh "$B/geosvr/scan24/mesh/tsdf/tsdf_fusion_post.ply" \
  --scan_id 24 --output_dir "$B/geosvr/scan24/mesh/tsdf/" \
  --mask_dir "$DATA" --DTU "$OFFICIAL" \
  > "$B/geosvr/scan24_eval.log" 2>&1 || { echo GEO_EVAL_FAIL; tail -5 "$B/geosvr/scan24_eval.log"; }
echo "GeoSVR chamfer:"; tail -2 "$B/geosvr/scan24_eval.log"

echo "########## [2/3] SVRaster scan24 (official cmds, module path fixed) ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$B/svraster/scan24"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$NEUS/dtu_scan24/" --model_path "$S" > "$B/svraster/scan24_train.log" 2>&1 || { echo SVR_TRAIN_FAIL; grep -aE 'Error' "$B/svraster/scan24_train.log" | head -3; }
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$B/svraster/scan24_render.log" 2>&1 || echo SVR_RENDER_FAIL
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan24_mesh.log" 2>&1 || { echo SVR_MESH_FAIL; tail -4 "$B/svraster/scan24_mesh.log"; }
fi
mkdir -p "$S/mesh/latest/evaluation"
python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan24/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan24_clean.log" 2>&1 || echo SVR_CLEAN_FAIL
python scripts/dtu_eval/eval.py \
  --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
  --scan 24 --dataset_dir "$OFFICIAL" \
  --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan24_eval.log" 2>&1 || echo SVR_EVAL_FAIL
echo "SVRaster chamfer:"; tail -3 "$B/svraster/scan24_eval.log"

echo "########## [3/3] 3DGS scan24 mesh + eval (2DGS TSDF params) ##########"
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
python ~/gs_external/mesh_3dgs_tsdf.py -m "$B/3dgs/scan24" --iteration 30000 \
  --voxel 0.004 --sdf_trunc 0.016 --depth_trunc 3.0 --num_cluster 1 \
  --out "$B/3dgs/scan24/fuse_post.ply" > "$B/3dgs/scan24_mesh.log" 2>&1 || { echo 3DGS_MESH_FAIL; tail -5 "$B/3dgs/scan24_mesh.log"; }
cd ~/2d-gaussian-splatting
python scripts/eval_dtu/evaluate_single_scene.py \
  --input_mesh "$B/3dgs/scan24/fuse_post.ply" \
  --scan_id 24 --output_dir "$B/3dgs/eval_scan24" \
  --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/3dgs/scan24_eval.log" 2>&1 || { echo 3DGS_EVAL_FAIL; tail -5 "$B/3dgs/scan24_eval.log"; }
echo "3DGS chamfer:"; tail -2 "$B/3dgs/scan24_eval.log"

echo "########## ALL SCAN24 DONE ##########"
echo BENCH_SCAN24C_DONE
