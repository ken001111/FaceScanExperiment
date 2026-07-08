#!/bin/bash
# Full inventory of produced artifacts (WSL side).
echo "=== RESULT MESHES (WSL) ==="
for f in \
  ~/FaceScan/bench/2dgs/scan*/train/ours_30000/fuse_post.ply \
  ~/FaceScan/bench/3dgs/scan*/fuse_post.ply \
  ~/FaceScan/bench/svraster/scan*/mesh/latest/mesh_dense_cleaned_for_eval.ply \
  ~/FaceScan/bench/geosvr/scan*/mesh/tsdf/tsdf_fusion_post.ply \
  ~/FaceScan/bench_ken/2dgs/model/train/ours_30000/fuse_post.ply \
  ~/FaceScan/bench_ken/3dgs/fuse_post.ply \
  ~/FaceScan/bench_ken/svraster/model/mesh/latest/mesh_dense.ply \
  ~/FaceScan/bench_ken/geosvr/model/mesh/tsdf/tsdf_fusion_post.ply \
  ~/FaceScan/bench_dummy/2dgs/model/train/ours_30000/fuse_post.ply \
  ~/FaceScan/bench_dummy/3dgs/fuse_post.ply \
  ~/FaceScan/bench_dummy/svraster/model/mesh/latest/mesh_dense.ply \
  ~/FaceScan/bench_dummy/geosvr/model/mesh/tsdf/tsdf_fusion_post.ply \
  ~/FaceScan/param_study/geosvr_*/mesh/tsdf/tsdf_fusion_post.ply \
  ~/FaceScan/param_study/geosvr_ken_raw_fullres/mesh/tsdf/tsdf_fusion.ply \
  ~/FaceScan/param_study/svr_*/mesh/latest/mesh_dense.ply \
  ~/FaceScan/param_study/2dgs_*/train/ours_30000/fuse_post.ply \
  ~/FaceScan/param_study/3dgs_*/fuse_post.ply \
  ~/FaceScan/param_study/*_meshonly/*.ply \
  ~/FaceScan/paperA/meshes/*.ply \
  ~/FaceScan/results/Face_Mesh_MetricScale_ken_*_nn.ply \
  ~/geosvr_dummy_raw_head.ply ~/geosvr_ken_raw_head.ply ~/v5_head.ply ~/dummy_2dgs_head.ply ~/dummy_3dgs_head.ply ~/dummy_svraster_head.ply ~/dummy_geosvr_head.ply; do
  [ -f "$f" ] && du -h "$f" | sed 's|/home/m352395/|~|'
done
echo ""
echo "=== OFFICIAL EVAL RESULTS ==="
for f in ~/FaceScan/bench/geosvr/scan*/mesh/tsdf/results.json ~/FaceScan/bench/2dgs/eval_scan*/results.json ~/FaceScan/bench/3dgs/eval_scan*/results.json ~/FaceScan/bench/svraster/scan*/mesh/latest/evaluation/*.json; do
  [ -f "$f" ] && echo "$(echo $f | sed 's|/home/m352395/|~|'): $(head -c 160 $f)"
done
echo ""
echo "=== TABLES ==="
cat ~/FaceScan/paperA/table3_dev.json 2>/dev/null
cat ~/FaceScan/initstudy/summary.txt 2>/dev/null | tail -6
echo ""
echo "=== DATASETS PREPARED ==="
du -sh ~/FaceScan/work/* ~/FaceScan/data/* 2>/dev/null | sed 's|/home/m352395/|~|'
echo INVENTORY_DONE
