#!/bin/bash
# Build 3DGS rasterizer (3-output graphdeco) + fused-ssim into facescan site-packages.
LOG="$HOME/build_3dgs.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0"
cd ~/gaussian-splatting || exit 1
pip install --no-build-isolation ./submodules/diff-gaussian-rasterization >> "$LOG" 2>&1
echo "diffgauss exit=$?" >> "$LOG"
pip install --no-build-isolation ./submodules/simple-knn >> "$LOG" 2>&1
echo "simpleknn exit=$?" >> "$LOG"
pip install --no-build-isolation ./submodules/fused-ssim >> "$LOG" 2>&1
echo "fusedssim exit=$?" >> "$LOG"
python -c "import diff_gaussian_rasterization, simple_knn; print('3dgs rasterizer OK')" >> "$LOG" 2>&1
echo "smoke exit=$?" >> "$LOG"; echo "ALLDONE $(date)" >> "$LOG"; tail -12 "$LOG"
