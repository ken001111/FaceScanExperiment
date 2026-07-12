#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_DEVICE_ORDER=PCI_BUS_ID
echo "nvcc:      $(/usr/local/cuda-12.8/bin/nvcc --version | grep release | sed 's/^.*release //')"
python - <<'EOF'
import torch
print("torch:    ", torch.__version__, "| cuda", torch.version.cuda, "| avail", torch.cuda.is_available())
for i in range(torch.cuda.device_count()):
    print(f"  cuda:{i} = {torch.cuda.get_device_name(i)} {torch.cuda.get_device_capability(i)}")
EOF
echo "--- method module imports ---"
cd /tmp
PYTHONPATH=~/geosvr_cuda_lib  python -c "from svraster_cuda import _C; print('GeoSVR   svraster_cuda._C   OK')" 2>&1 | tail -1
PYTHONPATH=~/svraster_cuda_lib python -c "from svraster_cuda import _C; print('SVRaster svraster_cuda._C   OK')" 2>&1 | tail -1
python -c "import diff_surfel_rasterization; print('2DGS     diff_surfel_rast    OK')" 2>&1 | tail -1
python -c "import diff_gaussian_rasterization; print('3DGS     diff_gaussian_rast  OK')" 2>&1 | tail -1
python -c "import fused_ssim, simple_knn; print('         fused_ssim+simple_knn OK')" 2>&1 | tail -1
PYTHONPATH=~/sugar_dgr python -c "import diff_gaussian_rasterization as d,pytorch3d; print('SuGaR    sugar_dgr+pytorch3d',pytorch3d.__version__,'OK')" 2>&1 | tail -1
echo "--- geosvr branch ---"
git -C ~/geosvr branch --show-current
echo "--- disk ---"; df -h ~ | tail -1
