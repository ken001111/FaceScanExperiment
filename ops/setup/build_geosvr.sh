#!/bin/bash
# Build GeoSVR (lidar-fork) + CUDA ext into isolated dir, install python deps.
set -o pipefail
LOG="$HOME/build_geosvr.log"
echo "START $(date)" > "$LOG"
source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan

export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/targets/x86_64-linux/lib:$LD_LIBRARY_PATH
export TORCH_CUDA_ARCH_LIST="12.0"

echo "== nvcc ==" >> "$LOG"; nvcc --version >> "$LOG" 2>&1

# 1. Apply lidar-fork patch (idempotent: skip if marker file present)
cd ~/geosvr || exit 1
git config --global --add safe.directory ~/geosvr 2>/dev/null
if [ ! -f .lidar_fork_applied ]; then
  echo "== applying lidar-fork.patch ==" >> "$LOG"
  git checkout -- . 2>/dev/null
  if git apply --check ~/facescan-experiments/paperB/geosvr_fork/lidar-fork.patch 2>>"$LOG"; then
    git apply ~/facescan-experiments/paperB/geosvr_fork/lidar-fork.patch >>"$LOG" 2>&1 && touch .lidar_fork_applied && echo "  patch applied OK" >> "$LOG"
  else
    echo "  PATCH CHECK FAILED (see log)" >> "$LOG"
  fi
else
  echo "== patch already applied ==" >> "$LOG"
fi

# 2. Python deps (GeoSVR environment.yml pip section, minus pinned torch)
echo "== pip deps $(date) ==" >> "$LOG"
pip install --cert /etc/ssl/certs/ca-certificates.crt \
  einops opencv-python yacs tqdm natsort pillow imageio imageio-ffmpeg \
  scikit-image plyfile shapely "trimesh==4.0.4" "open3d==0.18.0" gpytoolbox \
  "transformers==4.49.0" lpips pytorch-msssim pycolmap >>"$LOG" 2>&1
echo "  deps exit=$?" >> "$LOG"
pip install --cert /etc/ssl/certs/ca-certificates.crt \
  "git+https://github.com/rahul-goel/fused-ssim.git@3006269823fc28110ba44686a172cbd59ec01bc3" >>"$LOG" 2>&1
echo "  fused-ssim exit=$?" >> "$LOG"

# 3. Build CUDA ext into isolated dir ~/geosvr_cuda_lib
echo "== build svraster_cuda -> ~/geosvr_cuda_lib $(date) ==" >> "$LOG"
mkdir -p ~/geosvr_cuda_lib
cd ~/geosvr/cuda || exit 1
pip install --no-build-isolation --target ~/geosvr_cuda_lib . >>"$LOG" 2>&1
echo "  build exit=$?" >> "$LOG"

# 4. Smoke import
echo "== import smoke ==" >> "$LOG"
PYTHONPATH=~/geosvr_cuda_lib:~/geosvr python -c "import torch, svraster_cuda; print('svraster_cuda OK', svraster_cuda.__file__)" >>"$LOG" 2>&1
echo "  smoke exit=$?" >> "$LOG"
echo "ALLDONE $(date)" >> "$LOG"
tail -20 "$LOG"
