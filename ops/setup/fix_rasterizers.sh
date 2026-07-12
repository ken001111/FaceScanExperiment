#!/bin/bash
# CUDA 12.8 nvcc is strict about implicit headers: rasterizer_impl.h needs <cstdint>.
# Patch (idempotent) and rebuild the 2DGS + 3DGS rasterizers. Pin to 5070.
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=0
LOG="$HOME/fix_rasterizers.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0" MAX_JOBS=6

patch_hdr () {  # add '#include <cstdint>' after '#pragma once' if missing
  local h="$1"
  [ -f "$h" ] || { echo "  MISSING $h" >> "$LOG"; return 0; }
  if grep -q "include <cstdint>" "$h"; then
    echo "  already patched: $h" >> "$LOG"
  else
    sed -i 's/#pragma once/#pragma once\n#include <cstdint>/' "$h"
    echo "  patched: $h" >> "$LOG"
  fi
}

patch_hdr ~/2d-gaussian-splatting/submodules/diff-surfel-rasterization/cuda_rasterizer/rasterizer_impl.h
patch_hdr ~/gaussian-splatting/submodules/diff-gaussian-rasterization/cuda_rasterizer/rasterizer_impl.h
patch_hdr ~/SuGaR/gaussian_splatting/submodules/diff-gaussian-rasterization/cuda_rasterizer/rasterizer_impl.h

echo "== rebuild 2DGS diff-surfel-rasterization ==" >> "$LOG"
pip install --no-build-isolation --force-reinstall --no-deps ~/2d-gaussian-splatting/submodules/diff-surfel-rasterization >> "$LOG" 2>&1
echo "  surfel exit=$?" >> "$LOG"

echo "== rebuild 3DGS diff-gaussian-rasterization ==" >> "$LOG"
pip install --no-build-isolation --force-reinstall --no-deps ~/gaussian-splatting/submodules/diff-gaussian-rasterization >> "$LOG" 2>&1
echo "  diffgauss exit=$?" >> "$LOG"

cd /tmp
python -c "import diff_surfel_rasterization; print('diff_surfel_rasterization OK')" >> "$LOG" 2>&1; echo "  surfel smoke=$?" >> "$LOG"
python -c "import diff_gaussian_rasterization; print('diff_gaussian_rasterization OK')" >> "$LOG" 2>&1; echo "  diffgauss smoke=$?" >> "$LOG"
python -c "import simple_knn; print('simple_knn OK')" >> "$LOG" 2>&1; echo "  simpleknn smoke=$?" >> "$LOG"
echo "ALLDONE $(date)" >> "$LOG"
grep -E "patched|already|surfel exit|diffgauss exit|OK|smoke=" "$LOG" | tail -20
