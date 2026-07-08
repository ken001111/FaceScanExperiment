source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
echo "=== import checks (GPU) ==="
PYTHONPATH=~/svraster_cuda_lib python -c "import torch, svraster_cuda; torch.zeros(1,device='cuda'); print('  SVRaster svraster_cuda OK')" || exit 1
PYTHONPATH=~/geosvr_cuda_lib  python -c "import torch, svraster_cuda; torch.zeros(1,device='cuda'); print('  GeoSVR   svraster_cuda OK')" || exit 1
echo "=== ken data root ==="
ls ~/FaceScan/work/face_scan/transforms_train.json >/dev/null 2>&1 && echo "  prepped ken present" || { echo "  ken data root MISSING"; exit 1; }
echo "=== SVRaster short run on ken (5000 iters) ==="
EXT=/mnt/c/Users/m352395/Downloads/facescan_work/paper_experiments/method_comparison/external
mkdir -p ~/svr_wrap
tr -d '\r' < "$EXT/run_svraster.sh" > ~/svr_wrap/run_svraster.sh
tr -d '\r' < "$EXT/run_geosvr.sh"  > ~/svr_wrap/run_geosvr.sh
chmod +x ~/svr_wrap/*.sh
SVR_ITERS=5000 bash ~/svr_wrap/run_svraster.sh ~/FaceScan/work/face_scan ~/svraster_test.ply
echo "VAL_SVRASTER_DONE"
