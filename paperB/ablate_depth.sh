#!/bin/bash
# Paper B depth-source ablation on ARKitScenes 47331963 (4 arms x 20k iters).
# Idempotent: skips arms whose final checkpoint exists, resumes partial arms.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1 PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
git checkout -q lidar-fork

SRC=${ABLATE_SRC:-~/FaceScan/work/arkit_47331963}
OUTROOT=${ABLATE_OUT:-~/FaceScan/paperB/ablation}
mkdir -p "$OUTROOT" ~/FaceScan/paperB/logs

write_overrides () {  # $1=arm
  local f="$OUTROOT/$1_overrides.yaml"
  case "$1" in
    nodepth)
      cat > "$f" <<'YAML'
regularizer:
  lambda_depthanythingv2: 0.0
  lambda_normal_dmono: 0.0
  lambda_lidar_depth: 0.0
YAML
      ;;
    mono)
      cat > "$f" <<'YAML'
regularizer:
  lambda_lidar_depth: 0.0
YAML
      ;;
    lidar)
      cat > "$f" <<'YAML'
regularizer:
  lambda_depthanythingv2: 0.0
  lambda_normal_dmono: 0.0
  lambda_lidar_depth: 0.1
  lidar_depth_from: 0
  lidar_depth_end: 20000
  lidar_depth_use_conf: False
YAML
      ;;
    lidarconf)
      cat > "$f" <<'YAML'
regularizer:
  lambda_depthanythingv2: 0.0
  lambda_normal_dmono: 0.0
  lambda_lidar_depth: 0.1
  lidar_depth_from: 0
  lidar_depth_end: 20000
  lidar_depth_use_conf: True
YAML
      ;;
    fused)
      cat > "$f" <<'YAML'
regularizer:
  lambda_depthanythingv2: 0.0
  lambda_normal_dmono: 0.0
  lambda_lidar_depth: 0.1
  lidar_depth_from: 0
  lidar_depth_end: 20000
  lidar_depth_use_conf: True
YAML
      ;;
  esac
  echo "$f"
}

run_arm () {  # $1=arm
  local arm=$1 mp="$OUTROOT/$1" log=~/FaceScan/paperB/logs/ablate_$(basename $OUTROOT)_$1.log
  local src="$SRC"
  if [ "$arm" = fused ]; then
    src="${SRC}_fused"
    if [ ! -f "$src/transforms_train.json" ]; then
      echo "[fused] building fused depth (needs mono priors from mono arm)"
      python ~/facescan-experiments/paperB/fuse_depth.py "$SRC" || { echo "[fused] fuse_depth FAILED"; return 1; }
    fi
  fi
  if [ -f "$mp/checkpoints/iter020000_model.pt" ]; then
    echo "[$arm] final checkpoint exists - skip"; return 0
  fi
  local ov; ov=$(write_overrides "$arm")
  local ec=1 attempt=0
  while [ $attempt -lt 6 ]; do
    attempt=$((attempt+1))
    local resume=()
    local last
    last=$(ls "$mp"/checkpoints/iter*_model.pt 2>/dev/null | sed 's/.*iter0*\([0-9]*\)_model.pt/\1/' | sort -n | tail -1)
    if [ -n "$last" ]; then
      resume=(--load_iteration "$last")
      echo "[$arm] attempt $attempt: resuming from iter $last"
    else
      echo "[$arm] attempt $attempt: fresh start"
    fi
    python train.py --cfg_files cfg/dtu_mesh.yaml "$ov" \
      --source_path "$src" --model_path "$mp" \
      --bound_mode camera_median --bound_scale 1.0 --subdivide_max_num 2000000 \
      --n_iter 20000 --checkpoint_iterations 2500 5000 7500 10000 12500 15000 17500 \
      --test_iterations -1 "${resume[@]}" >> "$log" 2>&1
    ec=$?
    echo "[$arm] exit=$ec (attempt $attempt)"
    [ $ec -eq 0 ] && break
    sleep 10   # let the driver settle after a phantom OOM
  done
  tr '\r' '\n' < "$log" | grep -av 'it/s.$' | tail -4
  tr '\r' '\n' < "$log" | grep -a 'Training: 100' | tail -1
  return $ec
}

overall=0
for arm in nodepth lidar lidarconf mono fused; do
  run_arm "$arm" || overall=1
done
echo "ALL_DONE overall=$overall"
