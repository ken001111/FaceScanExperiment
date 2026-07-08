source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
echo "=== nvcc locations ==="
ls /usr/local/ | grep -i cuda
find / -name nvcc -type f 2>/dev/null | head
echo "=== conda cuda/gcc pkgs ==="
conda list 2>/dev/null | grep -iE 'cuda|nvcc|gxx|^gcc|pytorch3d|nvdiffrast|simple-knn|rasteriz'
echo "=== system gcc/g++ ==="
gcc --version 2>/dev/null | head -1; g++ --version 2>/dev/null | head -1
echo "=== 2dgs repo submodules ==="
ls ~/2d-gaussian-splatting/submodules 2>/dev/null
echo "=== how surfel rasterizer was installed ==="
pip show diff-surfel-rasterization 2>/dev/null | grep -E 'Name|Version|Location'
pip show simple-knn 2>/dev/null | grep -E 'Name|Version'
echo "=== env vars that helped build (CUDA_HOME/TORCH_CUDA_ARCH_LIST) ==="
echo "CUDA_HOME=$CUDA_HOME  TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
echo "=== torch cpp extension cuda home ==="
python - <<'PY'
from torch.utils.cpp_extension import CUDA_HOME
import torch.utils.cpp_extension as e
print("CUDA_HOME(torch)=", CUDA_HOME)
PY
