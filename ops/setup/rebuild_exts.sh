#!/bin/bash
# Reliable CUDA-ext build: compile in-place with the env's torch, copy to isolated dir.
LOG="$HOME/rebuild_exts.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0"
export MAX_JOBS=8

build_svraster_cuda () {  # $1 = repo cuda dir, $2 = isolated target dir
  local cudir="$1" tgt="$2"
  echo "== build_ext in $cudir -> $tgt $(date) ==" >> "$LOG"
  cd "$cudir" || return 1
  rm -rf build svraster_cuda/_C*.so
  python setup.py build_ext --inplace >> "$LOG" 2>&1
  local ec=$?
  echo "  build_ext exit=$ec" >> "$LOG"
  [ $ec -ne 0 ] && return $ec
  rm -rf "$tgt"; mkdir -p "$tgt"
  cp -r svraster_cuda "$tgt/"
  PYTHONPATH="$tgt" python -c "import torch, svraster_cuda; from svraster_cuda import _C; print('svraster_cuda+_C OK ->', svraster_cuda.__file__)" >> "$LOG" 2>&1
  echo "  smoke exit=$?" >> "$LOG"
}

# GeoSVR
build_svraster_cuda "$HOME/geosvr/cuda"  "$HOME/geosvr_cuda_lib"

# fused-ssim (needed by GeoSVR train.py) -- install into site-packages, no isolation
echo "== fused-ssim (no-build-isolation) $(date) ==" >> "$LOG"
pip install --no-build-isolation "git+https://github.com/rahul-goel/fused-ssim.git@3006269823fc28110ba44686a172cbd59ec01bc3" >> "$LOG" 2>&1
echo "  fused-ssim exit=$?" >> "$LOG"
python -c "import fused_ssim; print('fused_ssim OK')" >> "$LOG" 2>&1
echo "  fused-ssim smoke exit=$?" >> "$LOG"

echo "ALLDONE $(date)" >> "$LOG"
grep -E "build_ext exit|smoke exit|OK ->|fused_ssim OK|Error|error:" "$LOG" | tail -20
