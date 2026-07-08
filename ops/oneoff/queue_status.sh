#!/bin/bash
echo "--- uptime: $(uptime -p)"
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader 2>/dev/null
for f in ~/FaceScan/param_study/*fullres*.train.log; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .train.log)
  p=$(tr '\r' '\n' < "$f" 2>/dev/null | grep -aE 'Training' | tail -1 | grep -aoE '[0-9]+/[0-9]+' | head -1)
  echo "$n: ${p:-loading}"
done
echo "--- meshes so far:"
ls ~/FaceScan/param_study/2dgs_dummyraw_fullres/train/ours_30000/fuse_post.ply 2>/dev/null
ls ~/FaceScan/param_study/3dgs_dummyraw_fullres/fuse_post.ply 2>/dev/null
ls ~/FaceScan/param_study/svr_dummyraw_fullres/mesh/latest/mesh_dense.ply 2>/dev/null
ls ~/FaceScan/param_study/geosvr_dummy_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply 2>/dev/null
ls ~/FaceScan/param_study/*kenraw*/**/*.ply 2>/dev/null | head -3
grep -c ALL_DONE ~/FaceScan/param_study/../run_everything.done 2>/dev/null || true
