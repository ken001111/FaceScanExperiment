#!/bin/bash
# Slim WSL internal usage: keep final checkpoints + meshes, drop renders/dups.
df -h / | tail -1
# redundant dataset variants + regenerable staging
rm -rf ~/FaceScan/work/dummy_head_appmask ~/FaceScan/work/ken2_staging
# training-view render dumps (regenerable with render.py)
rm -rf ~/FaceScan/bench_ken/geosvr/model/train ~/FaceScan/bench_ken/geosvr/model/pg_view ~/FaceScan/bench_ken/geosvr/model/test_view
rm -rf ~/FaceScan/bench_dummy/geosvr/model/train ~/FaceScan/bench_dummy/geosvr/model/pg_view ~/FaceScan/bench_dummy/geosvr/model/test_view
rm -rf ~/FaceScan/bench_ken/2dgs/model/train/ours_30000/renders ~/FaceScan/bench_ken/2dgs/model/train/ours_30000/gt
rm -rf ~/FaceScan/bench_dummy/2dgs/model/train/ours_30000/renders ~/FaceScan/bench_dummy/2dgs/model/train/ours_30000/gt
rm -rf ~/FaceScan/bench_ken/svraster/model/train ~/FaceScan/bench_dummy/svraster/model/train
# old checkpoints: keep only the newest per model dir
for d in ~/FaceScan/bench_ken/geosvr/model ~/FaceScan/bench_dummy/geosvr/model \
         ~/FaceScan/param_study/geosvr_dummy_matte ~/FaceScan/param_study/geosvr_ken_matte \
         ~/FaceScan/param_study/geosvr_dummy_raw; do
  [ -d "$d/checkpoints" ] || continue
  keep=$(ls -t "$d/checkpoints"/*.pt 2>/dev/null | head -1)
  for f in "$d/checkpoints"/*.pt; do [ "$f" != "$keep" ] && rm -f "$f"; done
  echo "$d -> kept $(basename ${keep:-none})"
done
# geosvr validation-era archives already compact; old fly-through videos
find ~/FaceScan/bench_ken ~/FaceScan/bench_dummy -name '*.mp4' -delete 2>/dev/null
du -sh ~/FaceScan/work ~/FaceScan/bench_ken ~/FaceScan/bench_dummy ~/FaceScan/param_study ~/FaceScan/data 2>/dev/null
df -h / | tail -1
echo SLIM_DONE
