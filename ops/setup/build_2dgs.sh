#!/bin/bash
# Build 2DGS rasterizers into facescan site-packages (unique pkg names).
LOG="$HOME/build_2dgs.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0"
cd ~/2d-gaussian-splatting || exit 1
pip install --no-build-isolation ./submodules/diff-surfel-rasterization >> "$LOG" 2>&1
echo "surfel exit=$?" >> "$LOG"
pip install --no-build-isolation ./submodules/simple-knn >> "$LOG" 2>&1
echo "simpleknn exit=$?" >> "$LOG"
python -c "import diff_surfel_rasterization, simple_knn; print('2dgs rasterizers OK')" >> "$LOG" 2>&1
echo "smoke exit=$?" >> "$LOG"; echo "ALLDONE $(date)" >> "$LOG"; tail -10 "$LOG"
