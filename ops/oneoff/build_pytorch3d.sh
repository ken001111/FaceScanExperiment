source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
CGXX=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-g++ | head -1)
CGCC=$(ls $CONDA_PREFIX/bin/*-conda-linux-gnu-gcc | head -1)
export CC="$CGCC" CXX="$CGXX"
export TORCH_CUDA_ARCH_LIST="12.0" FORCE_CUDA=1
export CXXFLAGS="-include cstdint"
export NVCC_PREPEND_FLAGS="-ccbin $CGXX -allow-unsupported-compiler -include cstdint"
LOG=~/pytorch3d_build.log
echo "[deps] fvcore iopath" | tee "$LOG"
pip install fvcore iopath >> "$LOG" 2>&1
echo "[build] pytorch3d from source (stable)" | tee -a "$LOG"
date +%s | tee -a "$LOG"
pip install --no-build-isolation "git+https://github.com/facebookresearch/pytorch3d.git@stable" >> "$LOG" 2>&1
echo "pip_exit=$?" | tee -a "$LOG"
date +%s | tee -a "$LOG"
python -c "import torch, pytorch3d; print('pytorch3d', pytorch3d.__version__, 'OK')" 2>&1 | tee -a "$LOG"
echo "PYTORCH3D_BUILD_DONE" | tee -a "$LOG"
