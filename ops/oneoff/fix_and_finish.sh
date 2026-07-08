#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DATA=~/FaceScan/data/DTU_2dgs
NEUS=~/FaceScan/data/DTU_neus
OFFICIAL=~/FaceScan/data/DTU
B=~/FaceScan/bench

echo "--- patch trimesh numpy2 ptp ---"
python - <<'PY'
import re, pathlib
p = pathlib.Path("~/miniconda3/envs/facescan/lib/python3.11/site-packages/trimesh/util.py").expanduser()
s = p.read_text()
old = "return float((a - b).ptp()) < atol"
new = "return float(__import__('numpy').ptp(a - b)) < atol"
if old in s:
    p.write_text(s.replace(old, new)); print("patched")
else:
    print("already patched or line moved:", new in s)
PY

echo "--- 3DGS eval status ---"
if ! grep -qE '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/3dgs/scan24_eval.log" 2>/dev/null; then
  cd ~/2d-gaussian-splatting
  python scripts/eval_dtu/evaluate_single_scene.py \
    --input_mesh "$B/3dgs/scan24/fuse_post.ply" \
    --scan_id 24 --output_dir "$B/3dgs/eval_scan24" \
    --mask_dir "$DATA" --DTU "$OFFICIAL" > "$B/3dgs/scan24_eval.log" 2>&1 || { echo 3DGS_EVAL_FAIL; tail -4 "$B/3dgs/scan24_eval.log"; }
fi
echo "3DGS chamfer:"; grep -E '^[0-9.]+ [0-9.]+ [0-9.]+$' "$B/3dgs/scan24_eval.log" | tail -1

echo "--- SVRaster mesh -> clean -> eval ---"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$B/svraster/scan24"
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$B/svraster/scan24_mesh.log" 2>&1 || { echo SVR_MESH_FAIL; tail -4 "$B/svraster/scan24_mesh.log"; }
mkdir -p "$S/mesh/latest/evaluation"
python scripts/dtu_clean_for_eval.py "$NEUS/dtu_scan24/" "$S/mesh/latest/mesh_dense.ply" > "$B/svraster/scan24_clean.log" 2>&1 || { echo SVR_CLEAN_FAIL; tail -4 "$B/svraster/scan24_clean.log"; }
python scripts/dtu_eval/eval.py \
  --data "$S/mesh/latest/mesh_dense_cleaned_for_eval.ply" \
  --scan 24 --dataset_dir "$OFFICIAL" \
  --vis_out_dir "$S/mesh/latest/evaluation" > "$B/svraster/scan24_eval.log" 2>&1 || { echo SVR_EVAL_FAIL; tail -4 "$B/svraster/scan24_eval.log"; }
echo "SVRaster chamfer:"; tail -3 "$B/svraster/scan24_eval.log"
echo FIX_AND_FINISH_DONE
