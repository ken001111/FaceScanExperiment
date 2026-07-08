#!/bin/bash
# Full-resolution raw-arm runs for 2DGS, 3DGS, SVRaster on one dataset.
# Usage: bash fullres_gs.sh <data_root> <tag>   e.g. ~/FaceScan/work/dummy_head_raw dummyraw
DR="$1"; TAG="$2"
[ -n "$TAG" ] || { echo "usage: $0 <data_root> <tag>"; exit 1; }
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
P=~/FaceScan/param_study

echo "########## 2DGS $TAG full-res ##########"
cd ~/2d-gaussian-splatting
export PYTHONPATH="$HOME/2d-gaussian-splatting"
O="$P/2dgs_${TAG}_fullres"
if [ ! -f "$O/train/ours_30000/fuse_post.ply" ]; then
  if [ ! -d "$O/point_cloud/iteration_30000" ]; then
    python train.py -s "$DR" -m "$O" --quiet --test_iterations -1 --data_device cpu > "$P/2dgs_${TAG}_fullres.train.log" 2>&1 || echo 2DGS_TRAIN_FAIL
  fi
  # gentle mesh step: thinned views + bounded fusion (full-view burst kept dying)
  bash ~/tm.sh "$DR" "$O" "$P/2dgs_${TAG}_fullres.mesh.log" || echo 2DGS_MESH_FAIL
fi
ls "$O/train/ours_30000/fuse_post.ply" 2>/dev/null

echo "########## 3DGS $TAG full-res ##########"
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
O="$P/3dgs_${TAG}_fullres"
if [ ! -d "$O/point_cloud/iteration_30000" ]; then
  python train.py -s "$DR" -m "$O" --quiet --test_iterations -1 --data_device cpu > "$P/3dgs_${TAG}_fullres.train.log" 2>&1 || echo 3DGS_TRAIN_FAIL
fi
python ~/gs_external/mesh_3dgs_tsdf.py -m "$O" --iteration 30000 \
  --num_cluster 1 --scale_factor 1000 --voxel 0.01 --depth_trunc 3.5 \
  --out "$O/fuse_post.ply" > "$P/3dgs_${TAG}_fullres.mesh.log" 2>&1 || echo 3DGS_MESH_FAIL
ls "$O/fuse_post.ply" 2>/dev/null

echo "########## SVRaster $TAG full-res ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
cat > ~/svraster_fullres_overrides.yaml <<'YAML'
data:
  res_downscale: 1.5
YAML
O="$P/svr_${TAG}_fullres"
if [ ! -f "$O/mesh/latest/mesh_dense.ply" ]; then
  if [ ! -f "$O/checkpoints/iter020000_model.pt" ]; then
    python train.py --cfg_files cfg/dtu_mesh.yaml ~/svraster_fullres_overrides.yaml --source_path "$DR" --model_path "$O" > "$P/svr_${TAG}_fullres.train.log" 2>&1 || echo SVR_TRAIN_FAIL
  fi
  python render.py "$O" --skip_test --rgb_only --use_jpg > "$P/svr_${TAG}_fullres.render.log" 2>&1 || echo SVR_RENDER_FAIL
  python extract_mesh.py "$O/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$P/svr_${TAG}_fullres.mesh.log" 2>&1 \
    || { echo lv9; python extract_mesh.py "$O/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$P/svr_${TAG}_fullres.mesh.log" 2>&1; } \
    || { echo lv8; python extract_mesh.py "$O/" --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 8 > "$P/svr_${TAG}_fullres.mesh.log" 2>&1; } \
    || echo SVR_MESH_FAIL
fi
ls "$O/mesh/latest/mesh_dense.ply" 2>/dev/null
echo FULLRES_GS_${TAG}_DONE

