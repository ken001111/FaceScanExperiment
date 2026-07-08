#!/bin/bash
# Ablation arm A: dummy head, RAW images (full background, no masks anywhere).
# GeoSVR: camera_median + 3M cap recipe. SVRaster: DTU cfg.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DR=~/FaceScan/work/dummy_head_raw
P=~/FaceScan/param_study
mkdir -p "$P"

echo "########## GeoSVR dummy RAW ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$P/geosvr_dummy_raw"
LOAD=""
if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then LOAD="--load_iteration -1"; fi
python train.py --cfg_files cfg/dtu_mesh.yaml \
  --source_path "$DR" --model_path "$G" \
  --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 3000000 \
  --test_iterations 6000 15000 \
  --checkpoint_iterations 4000 8000 12000 16000 \
  $LOAD > "$P/geosvr_dummy_raw.train.log" 2>&1 || { echo GEO_RAW_TRAIN_FAIL; exit 42; }
python render.py "$G" --skip_test --use_jpg > "$P/geosvr_dummy_raw.render.log" 2>&1 || echo GEO_RAW_RENDER_FAIL
# raw scene includes desk/floor: 0.002 units (=0.2mm) voxels over room surfaces OOMs
# the 14GB VM ~40 views in. 0.005 (=0.5mm) matches the head-scale wrapper default.
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.005 --max_depth 4.0 > "$P/geosvr_dummy_raw.mesh.log" 2>&1 || echo GEO_RAW_MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -1

echo "########## SVRaster dummy RAW ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$P/svr_dummy_raw"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$S" > "$P/svr_dummy_raw.train.log" 2>&1 || { echo SVR_RAW_TRAIN_FAIL; exit 43; }
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$P/svr_dummy_raw.render.log" 2>&1 || echo SVR_RAW_RENDER_FAIL
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$P/svr_dummy_raw.mesh.log" 2>&1 \
    || { echo lv9; python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$P/svr_dummy_raw.mesh.log" 2>&1; } \
    || echo SVR_RAW_MESH_FAIL
fi
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -1
echo RAW_ARM_DONE

