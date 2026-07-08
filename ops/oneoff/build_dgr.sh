source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
CONDA_GXX=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-g++ | head -1)
CONDA_GCC=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-gcc | head -1)
export CC="$CONDA_GCC" CXX="$CONDA_GXX"
export TORCH_CUDA_ARCH_LIST="12.0"
# force-include <cstdint> so uint32_t/uint64_t resolve under gcc-13/cuda-12.8
export CXXFLAGS="-include cstdint"
export NVCC_PREPEND_FLAGS="-ccbin $CONDA_GXX -allow-unsupported-compiler -include cstdint"
cd ~/gaussian-splatting
echo "############ building diff-gaussian-rasterization (with cstdint) ############"
pip install --no-build-isolation ./submodules/diff-gaussian-rasterization > ~/build_dgr.log 2>&1 \
  && echo "  wheel built" \
  || { echo "  FAILED:"; grep -iE 'error:|fatal' ~/build_dgr.log | tail -12; }
echo "=== import check (torch first) ==="
python - <<'PY'
import torch
import diff_gaussian_rasterization; print("diff_gaussian_rasterization OK")
import simple_knn._C; print("simple_knn OK")
import fused_ssim; print("fused_ssim OK")
print("ALL 3DGS DEPS OK")
PY
echo "BUILD_DGR_DONE"
