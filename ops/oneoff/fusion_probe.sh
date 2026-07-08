#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
cd ~/geosvr
python mesh_extract/tsdf_mesh.py ~/FaceScan/param_study/geosvr_dummy_raw/ \
  --num_cluster 1 --voxel_size 0.005 --max_depth 4.0 > /tmp/fusion_probe.log 2>&1
ec=$?
echo "EXIT_CODE=$ec"
tr '\r' '\n' < /tmp/fusion_probe.log | grep -av '^\s*$' | tail -6
dmesg 2>/dev/null | tail -3
free -g | sed -n 2p
