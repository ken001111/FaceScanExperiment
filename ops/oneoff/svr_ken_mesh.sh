#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
cd ~/svraster
S=~/FaceScan/bench_ken/svraster/model
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > ~/FaceScan/bench_ken/svraster/mesh.log 2>&1 \
  || { echo "fallback final_lv 9"; python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > ~/FaceScan/bench_ken/svraster/mesh.log 2>&1; } \
  || { echo SVR_MESH_FAIL; tr '\r' '\n' < ~/FaceScan/bench_ken/svraster/mesh.log | grep -av 'it/s' | tail -4; exit 1; }
ls "$S/mesh/latest/"*.ply
echo SVR_KEN_MESH_DONE
