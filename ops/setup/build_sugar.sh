#!/bin/bash
# SuGaR stack: isolated 2-output diff_gaussian_rasterization -> ~/sugar_dgr,
# simple-knn (shared, already present), pytorch3d from source. Pinned to 5070.
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=0
LOG="$HOME/build_sugar.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0" MAX_JOBS=6

# 1. SuGaR's 2-output rasterizer -> isolated ~/sugar_dgr
echo "== sugar diff_gaussian_rasterization (2-output) -> ~/sugar_dgr ==" >> "$LOG"
cd ~/SuGaR/gaussian_splatting/submodules/diff-gaussian-rasterization || exit 1
rm -rf build diff_gaussian_rasterization/_C*.so
python setup.py build_ext --inplace >> "$LOG" 2>&1
ec=$?; echo "  build_ext exit=$ec" >> "$LOG"
if [ $ec -eq 0 ]; then
  rm -rf ~/sugar_dgr; mkdir -p ~/sugar_dgr
  cp -r diff_gaussian_rasterization ~/sugar_dgr/
  cd /tmp && PYTHONPATH=~/sugar_dgr python -c "import diff_gaussian_rasterization as d; from diff_gaussian_rasterization import _C; print('sugar_dgr OK', d.__file__)" >> "$LOG" 2>&1
  echo "  sugar_dgr smoke exit=$?" >> "$LOG"
fi

# 2. pytorch3d from source (riskiest: torch 2.11 / CUDA 12.8 / sm_120)
echo "== pytorch3d from source $(date) ==" >> "$LOG"
pip install --no-build-isolation "git+https://github.com/facebookresearch/pytorch3d.git@stable" >> "$LOG" 2>&1
echo "  pytorch3d exit=$?" >> "$LOG"
python -c "import pytorch3d; print('pytorch3d', pytorch3d.__version__)" >> "$LOG" 2>&1
echo "  pytorch3d smoke exit=$?" >> "$LOG"

echo "ALLDONE $(date)" >> "$LOG"
grep -E "build_ext exit|sugar_dgr|pytorch3d exit|pytorch3d smoke|OK|Error|error:" "$LOG" | tail -20
