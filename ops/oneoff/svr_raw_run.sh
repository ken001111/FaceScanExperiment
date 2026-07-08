#!/bin/bash
# SVRaster on raw dummy — single-run session (chains are fragile).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
cd ~/svraster
P=~/FaceScan/param_study
S="$P/svr_dummy_raw"
DR=~/FaceScan/work/dummy_head_raw
if [ ! -f "$S/checkpoints/iter020000_model.pt" ] 2>/dev/null && [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$S" > "$P/svr_dummy_raw.train.log" 2>&1 || { echo SVR_RAW_TRAIN_FAIL; exit 1; }
fi
python render.py "$S" --skip_test --rgb_only --use_jpg > "$P/svr_dummy_raw.render.log" 2>&1 || echo RENDER_FAIL
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$P/svr_dummy_raw.mesh.log" 2>&1 \
  || { echo lv9; python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$P/svr_dummy_raw.mesh.log" 2>&1; } \
  || echo MESH_FAIL
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -1
echo SVR_RAW_DONE
