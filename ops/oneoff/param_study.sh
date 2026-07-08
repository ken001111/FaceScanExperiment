#!/bin/bash
# Parameter study, arm 1 (the decisive one): REAL head mattes.
# GeoSVR: v5 recipe (camera_median bound + 3M cap) + blend_mask on matte roots.
# SVRaster: its own DTU protocol config on matte roots (its DTU cfg handles masks).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
P=~/FaceScan/param_study
mkdir -p "$P"

cat > ~/geosvr_matte_overrides.yaml <<'YAML'
data:
  blend_mask: True
YAML

run_geosvr() {  # $1 = data root, $2 = out name
  cd ~/geosvr
  export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
  G="$P/$2"
  LOAD=""
  if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then LOAD="--load_iteration -1"; fi
  python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_matte_overrides.yaml \
    --source_path "$1" --model_path "$G" \
    --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 3000000 \
    --test_iterations 6000 15000 \
    --checkpoint_iterations 4000 8000 12000 16000 \
    $LOAD > "$P/$2.train.log" 2>&1 || { echo "GEO $2 TRAIN_FAIL"; return 1; }
  python render.py "$G" --skip_test --use_jpg > "$P/$2.render.log" 2>&1 || echo "GEO $2 RENDER_FAIL"
  python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$P/$2.mesh.log" 2>&1 || echo "GEO $2 MESH_FAIL"
  ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -1
}

run_svraster() {  # $1 = data root, $2 = out name
  cd ~/svraster
  export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
  S="$P/$2"
  if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
    python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$1" --model_path "$S" > "$P/$2.train.log" 2>&1 || { echo "SVR $2 TRAIN_FAIL"; return 1; }
    python render.py "$S" --skip_test --rgb_only --use_jpg > "$P/$2.render.log" 2>&1 || echo "SVR $2 RENDER_FAIL"
    python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$P/$2.mesh.log" 2>&1 \
      || { echo "lv9 fallback"; python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$P/$2.mesh.log" 2>&1; } \
      || echo "SVR $2 MESH_FAIL"
  fi
  ls "$S/mesh/latest/"*.ply 2>/dev/null | head -1
}

echo "########## [1/4] GeoSVR dummy+matte ##########"
run_geosvr ~/FaceScan/work/dummy_head_matte geosvr_dummy_matte
echo "########## [2/4] GeoSVR ken+matte ##########"
run_geosvr ~/FaceScan/work/face_scan_matte geosvr_ken_matte
echo "########## [3/4] SVRaster dummy+matte ##########"
run_svraster ~/FaceScan/work/dummy_head_matte svr_dummy_matte
echo "########## [4/4] SVRaster ken+matte ##########"
run_svraster ~/FaceScan/work/face_scan_matte svr_ken_matte
echo PARAM_STUDY_ARM1_DONE

