#!/bin/bash
# Surgical tick: only the 3 missing artifacts, in value order. Reentrant.
LOCK=~/FaceScan/param_study/.tick_lock
DONE_MARK=~/FaceScan/param_study/.queue_complete
[ -f "$DONE_MARK" ] && { echo COMPLETE; exit 0; }
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then echo BUSY; exit 0; fi
echo $$ > "$LOCK"
P=~/FaceScan/param_study
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"

# [2+3] SVRaster extractions (fresh-GPU attempts, deep fallbacks)
cd ~/svraster; export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
for TAG in dummyraw kenraw; do
  S="$P/svr_${TAG}_fullres"
  [ -f "$S/mesh/latest/mesh_dense.ply" ] && continue
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$P/svr_${TAG}_fullres.mesh.log" 2>&1 \
    || python extract_mesh.py "$S/" --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$P/svr_${TAG}_fullres.mesh.log" 2>&1 \
    || python extract_mesh.py "$S/" --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 8 > "$P/svr_${TAG}_fullres.mesh.log" 2>&1 \
    || { rm -f "$LOCK"; exit 45; }
done

# [1] GeoSVR dummy @1.5x — resume training / render / mesh
if [ ! -f "$P/geosvr_dummy_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply" ]; then
  cd ~/geosvr; export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
  G="$P/geosvr_dummy_raw_fullres"
  if [ ! -f "$G/checkpoints/iter020000_model.pt" ]; then
    LOAD=""; ls "$G/checkpoints"/*.pt >/dev/null 2>&1 && LOAD="--load_iteration -1"
    python train.py --cfg_files cfg/dtu_mesh.yaml ~/geosvr_fullres_overrides.yaml \
      --source_path ~/FaceScan/work/dummy_head_raw --model_path "$G" \
      --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 2000000 \
      --test_iterations 6000 15000 --checkpoint_iterations 6000 8000 10000 12000 14000 16000 18000 \
      $LOAD >> "$P/geosvr_dummy_raw_fullres.train.log" 2>&1 || { rm -f "$LOCK"; exit 42; }
  fi
  python render.py "$G" --skip_test --use_jpg > "$P/geosvr_dummy_raw_fullres.render.log" 2>&1 || { rm -f "$LOCK"; exit 43; }
  python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.005 --max_depth 4.0 > "$P/geosvr_dummy_raw_fullres.mesh.log" 2>&1 || { rm -f "$LOCK"; exit 44; }
fi

# all present?
if [ -f "$P/geosvr_dummy_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply" ] && \
   [ -f "$P/svr_dummyraw_fullres/mesh/latest/mesh_dense.ply" ] && \
   [ -f "$P/svr_kenraw_fullres/mesh/latest/mesh_dense.ply" ]; then
  touch "$DONE_MARK"; echo ALL_THREE_DONE
fi
rm -f "$LOCK"


