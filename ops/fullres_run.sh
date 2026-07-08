#!/bin/bash
# Quality arm: GeoSVR at FULL capture resolution (1920x1440) + auto-exposure.
# Usage: bash fullres_run.sh <data_root> <run_name>
DR="$1"; NAME="$2"
[ -n "$NAME" ] || { echo "usage: $0 <data_root> <run_name>"; exit 1; }
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
P=~/FaceScan/param_study

cat > ~/geosvr_fullres_overrides.yaml <<'YAML'
data:
  res_downscale: 1.5
auto_exposure:
  enable: True
YAML

G="$P/$NAME"
LOAD=""
if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then LOAD="--load_iteration -1"; fi
python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_fullres_overrides.yaml \
  --source_path "$DR" --model_path "$G" \
  --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 2000000 \
  --test_iterations 6000 15000 --checkpoint_iterations 4000 8000 12000 16000 \
  $LOAD > "$P/$NAME.train.log" 2>&1 \
  || { echo "full-res OOM? retry res_downscale 1.5"; \
       sed -i 's/res_downscale: 0/res_downscale: 1.5/' ~/geosvr_fullres_overrides.yaml; \
       rm -rf "$G"; \
       python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_fullres_overrides.yaml \
         --source_path "$DR" --model_path "$G" \
         --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 2000000 \
         --test_iterations 6000 15000 --checkpoint_iterations 4000 8000 12000 16000 \
         > "$P/$NAME.train.log" 2>&1; } \
  || { echo TRAIN_FAIL; exit 1; }
python render.py "$G" --skip_test --use_jpg > "$P/$NAME.render.log" 2>&1 || echo RENDER_FAIL
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.005 --max_depth 4.0 > "$P/$NAME.mesh.log" 2>&1 || echo MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -1
grep -aoE 'psnr=[0-9.]+' "$P/$NAME.train.log" | tail -1
echo FULLRES_${NAME}_DONE

