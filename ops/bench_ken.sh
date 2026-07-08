#!/bin/bash
# ken capture through the SAME 4-method pipeline as the DTU benchmark.
# Paper-default configs everywhere (GeoSVR: pure repo defaults incl. pcd bound —
# documents the out-of-the-box result; fixes belong to the parameter study).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DR=~/FaceScan/work/face_scan
K=~/FaceScan/bench_ken
mkdir -p "$K"/{2dgs,3dgs,svraster,geosvr}

echo "########## [1/4] 2DGS ken (repo defaults) ##########"
cd ~/2d-gaussian-splatting
export PYTHONPATH="$HOME/2d-gaussian-splatting"
if [ ! -f "$K/2dgs/model/train/ours_30000/fuse_post.ply" ]; then
  python train.py -s "$DR" -m "$K/2dgs/model" --quiet --test_iterations -1 > "$K/2dgs/train.log" 2>&1 || echo 2DGS_TRAIN_FAIL
  python render.py -m "$K/2dgs/model" -s "$DR" --quiet --skip_test --skip_train > "$K/2dgs/mesh.log" 2>&1 || echo 2DGS_MESH_FAIL
fi
ls "$K/2dgs/model/train"/ours_30000/*.ply 2>/dev/null | head -2

echo "########## [2/4] 3DGS ken (repo defaults + shared TSDF) ##########"
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
if [ ! -d "$K/3dgs/model/point_cloud/iteration_30000" ]; then
  python train.py -s "$DR" -m "$K/3dgs/model" --quiet --test_iterations -1 > "$K/3dgs/train.log" 2>&1 || echo 3DGS_TRAIN_FAIL
fi
python ~/gs_external/mesh_3dgs_tsdf.py -m "$K/3dgs/model" --iteration 30000 \
  --num_cluster 1 --scale_factor 1000 --mask_dir "$DR/masks" \
  --out "$K/3dgs/fuse_post.ply" > "$K/3dgs/mesh.log" 2>&1 || { echo 3DGS_MESH_FAIL; tail -3 "$K/3dgs/mesh.log"; }

echo "########## [3/4] SVRaster ken (paper mesh cfg) ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$K/svraster/model"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$S" > "$K/svraster/train.log" 2>&1 || echo SVR_TRAIN_FAIL
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$K/svraster/render.log" 2>&1 || echo SVR_RENDER_FAIL
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1 || echo SVR_MESH_FAIL
fi
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -2

echo "########## [4/4] GeoSVR ken (pure repo defaults) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$K/geosvr/model"
if [ ! -d "$G/checkpoints" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$G" --test_iterations 6000 15000 > "$K/geosvr/train.log" 2>&1 || echo GEO_TRAIN_FAIL
  python render.py "$G" --skip_test --use_jpg > "$K/geosvr/render.log" 2>&1 || echo GEO_RENDER_FAIL
fi
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$K/geosvr/mesh.log" 2>&1 || echo GEO_MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -2

echo "########## KEN BENCH DONE ##########"
df -h / | tail -1
echo BENCH_KEN_DONE
