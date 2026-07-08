set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export CC=/usr/bin/gcc-13 CXX=/usr/bin/g++-13
export TORCH_CUDA_ARCH_LIST="12.0"
export NVCC_PREPEND_FLAGS="-allow-unsupported-compiler"
cd ~/gaussian-splatting
echo "=== nvcc / gcc in use ==="; nvcc --version | tail -1; $CC --version | head -1
for m in diff-gaussian-rasterization simple-knn fused-ssim; do
  echo "############ building $m ############"
  pip install --no-build-isolation ./submodules/$m 2>&1 | tail -4
done
echo "=== import check ==="
python - <<'PY'
import torch
import diff_gaussian_rasterization as d; print("diff_gaussian_rasterization OK")
import simple_knn._C; print("simple_knn OK")
try:
    import fused_ssim; print("fused_ssim OK")
except Exception as e:
    print("fused_ssim FAIL:", e)
PY
echo "BUILD_3DGS_DONE"
