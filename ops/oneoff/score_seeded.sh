#!/bin/bash
# Wait for the seeded TSDF mesh, then score all 6 arms with v6 scorer.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES=1
MESHPLY="$HOME/FaceScan/paperB/ablation_41069021/seeded/mesh/tsdf/tsdf_fusion_post.ply"
MOUT="$HOME/mesh_seeded.out"
SLOG="$HOME/FaceScan/paperB/logs/score_41069021_v6_seeded.log"
echo "WAIT START $(date)" > "$SLOG"

# wait up to ~3h for the mesh (or explicit failure)
for i in $(seq 1 2160); do
  if [ -f "$MESHPLY" ]; then break; fi
  if grep -qsE "MESH_FAILED|RENDER_FAILED|SEEDED_MESH_MISSING" "$MOUT"; then
    echo "MESH DID NOT COMPLETE — aborting score" >> "$SLOG"; tail -5 "$MOUT" >> "$SLOG"; exit 1
  fi
  sleep 5
done
[ -f "$MESHPLY" ] || { echo "TIMEOUT waiting for mesh" >> "$SLOG"; exit 1; }

echo "MESH READY $(date): $(head -c 400 "$MESHPLY" | tr -d '\0' | grep -a 'element vertex')" >> "$SLOG"
cd ~/facescan-experiments/paperB
python score_41069021_v6.py >> "$SLOG" 2>&1
echo "SCORE_EXIT=$? $(date)" >> "$SLOG"
echo "===== SCORE SUMMARY ====="
grep -aE "^\[|convention|-> using|SCORE_EXIT" "$SLOG" | tail -20
