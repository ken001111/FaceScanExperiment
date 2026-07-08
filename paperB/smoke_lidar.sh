#!/bin/bash
# 500-iter smoke test of MetricLidarDepthLoss plumbing on ARKitScenes scene.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
git checkout -q lidar-fork
cat > ~/lidar_smoke_overrides.yaml <<'YAML'
regularizer:
  lambda_depthanythingv2: 0.0
  lambda_lidar_depth: 0.1
  lidar_depth_from: 0
  lidar_depth_end: 20000
  lidar_depth_use_conf: True
YAML
rm -rf ~/FaceScan/param_study/lidar_smoke
python train.py --cfg_files cfg/dtu_mesh.yaml ~/lidar_smoke_overrides.yaml \
  --source_path ~/FaceScan/work/arkit_47331963 --model_path ~/FaceScan/param_study/lidar_smoke \
  --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 1000000 \
  --n_iter 500 --test_iterations -1 > ~/lidar_smoke.log 2>&1
ec=$?
echo "exit=$ec"
tr '\r' '\n' < ~/lidar_smoke.log | grep -av 'it/s' | tail -5
tr '\r' '\n' < ~/lidar_smoke.log | grep -aE 'Training' | tail -2
