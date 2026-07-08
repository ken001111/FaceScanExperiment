#!/bin/bash
# scan65 retries after subdivision OOM on 16GB.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench

echo "########## SVRaster scan65 mesh retry (fresh GPU) ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$B/svraster/scan65"
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan65_mesh.log" 2>&1 \
  || { echo "retry without --save_gpu"; python extract_mesh.py "$S/" --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan65_mesh.log" 2>&1; } \
  || { echo SVR_MESH_FAIL_AGAIN; tr '\r' '\n' < "$B/svraster/scan65_mesh.log" | grep -av 'it/s' | tail -3; }
if [ -f "$S/mesh/latest/mesh_dense.ply" ]; then
  mkdir -p "$S/mesh/latest/evaluation"
  python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan65/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan65_clean.log" 2>&1
  python scripts/dtu_eval/eval.py --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
    --scan 65 --dataset_dir "$OFFICIAL" --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan65_eval.log" 2>&1
  echo "SVRaster scan65 chamfer: $(tr '\r' '\n' < "$B/svraster/scan65_eval.log" | grep -avE 'it/s|%|^\s*$' | tail -1)"
fi

echo "########## GeoSVR scan65 train retry ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$B/geosvr/scan65"
rm -rf "$G"
python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DATA/scan65/" --model_path "$G" --test_iterations 6000 15000 > "$B/geosvr/scan65_train.log" 2>&1 \
  || { echo "OOM again -> retry with subdivide_max_num 3M (16GB constraint, footnote)"; rm -rf "$G"; \
       python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DATA/scan65/" --model_path "$G" --test_iterations 6000 15000 --subdivide_max_num 3000000 > "$B/geosvr/scan65_train.log" 2>&1; } \
  || { echo GEO_TRAIN_FAIL_AGAIN; tr '\r' '\n' < "$B/geosvr/scan65_train.log" | grep -av 'it/s' | tail -3; exit 1; }
python render.py "$G" --skip_test --use_jpg > "$B/geosvr/scan65_render.log" 2>&1
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$B/geosvr/scan65_mesh.log" 2>&1
python scripts/eval_dtu_vanilla/evaluate_single_scene.py --input_mesh "$G/mesh/tsdf/tsdf_fusion_post.ply" \
  --scan_id 65 --output_dir "$G/mesh/tsdf/" --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/geosvr/scan65_eval.log" 2>&1
echo "GeoSVR scan65 chamfer: $(grep -aE '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/geosvr/scan65_eval.log" | tail -1)"
echo SCAN65_RETRY_DONE
