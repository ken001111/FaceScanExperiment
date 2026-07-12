#!/bin/bash
# Build SVRaster svraster_cuda ext in-place, copy to isolated ~/svraster_cuda_lib.
LOG="$HOME/build_svraster.log"; echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0" MAX_JOBS=6
cd ~/svraster/cuda || exit 1
rm -rf build svraster_cuda/_C*.so
python setup.py build_ext --inplace >> "$LOG" 2>&1
ec=$?; echo "build_ext exit=$ec" >> "$LOG"
if [ $ec -eq 0 ]; then
  rm -rf ~/svraster_cuda_lib; mkdir -p ~/svraster_cuda_lib
  cp -r svraster_cuda ~/svraster_cuda_lib/
  cd /tmp && PYTHONPATH=~/svraster_cuda_lib python -c "import svraster_cuda; from svraster_cuda import _C; print('svraster_cuda+_C OK', svraster_cuda.__file__)" >> "$LOG" 2>&1
  echo "smoke exit=$?" >> "$LOG"
fi
echo "ALLDONE $(date)" >> "$LOG"; grep -E "build_ext exit|smoke exit|OK|error:|Error" "$LOG" | tail -8
