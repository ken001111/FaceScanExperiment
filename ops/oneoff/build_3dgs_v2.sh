source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
# Use conda's gcc-13 + sysroot-2.17 (glibc 2.17) to dodge system glibc 2.43 noexcept clash
CONDA_GXX=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-g++ | head -1)
CONDA_GCC=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-gcc | head -1)
export CC="$CONDA_GCC" CXX="$CONDA_GXX"
export TORCH_CUDA_ARCH_LIST="12.0"
export NVCC_PREPEND_FLAGS="-ccbin $CONDA_GXX -allow-unsupported-compiler"
echo "CC=$CC"; echo "CXX=$CXX"
cd ~/gaussian-splatting
echo "=== simple_knn already built? ==="
python -c "import simple_knn._C; print('simple_knn OK (prebuilt)')" || pip install --no-build-isolation ./submodules/simple-knn 2>&1 | tail -3
for m in diff-gaussian-rasterization fused-ssim; do
  echo "############ building $m ############"
  pip install --no-build-isolation ./submodules/$m > ~/build_$m.log 2>&1 && echo "  $m: wheel built" || { echo "  $m FAILED — errors:"; grep -iE 'error:|fatal' ~/build_$m.log | tail -8; }
done
echo "=== final import check ==="
python - <<'PY'
import diff_gaussian_rasterization; print("diff_gaussian_rasterization OK")
import simple_knn._C; print("simple_knn OK")
try:
    import fused_ssim; print("fused_ssim OK")
except Exception as e:
    print("fused_ssim:", e)
PY
echo "BUILD_3DGS_V2_DONE"
