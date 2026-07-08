#!/bin/bash
# Second hard prune: regenerables + superseded intermediates.
df -h / | tail -1
# renders are regenerable; mono_priors regenerate on demand
find ~/FaceScan/param_study -type d \( -name renders -o -name gt -o -name pg_view -o -name test_view \) -exec rm -rf {} + 2>/dev/null
rm -rf ~/FaceScan/work/*/mono_priors
# superseded models: matte arms are out of scope (keep their meshes only)
for d in ~/FaceScan/param_study/geosvr_ken_matte ~/FaceScan/param_study/geosvr_dummy_matte; do
  [ -d "$d" ] || continue
  mkdir -p "${d}_meshonly"
  cp "$d/mesh/tsdf/"*.ply "${d}_meshonly/" 2>/dev/null
  rm -rf "$d"
done
# keep only newest checkpoint everywhere under param_study + bench dirs
for d in ~/FaceScan/param_study/*/checkpoints ~/FaceScan/bench_ken/*/model/checkpoints ~/FaceScan/bench_dummy/*/model/checkpoints; do
  [ -d "$d" ] || continue
  keep=$(ls -t "$d"/*.pt 2>/dev/null | head -1)
  for f in "$d"/*.pt; do [ "$f" != "$keep" ] && rm -f "$f"; done
done
# svraster training dumps
find ~/FaceScan/param_study -maxdepth 2 -type d -name train -exec rm -rf {} + 2>/dev/null
du -sh ~/FaceScan/param_study ~/FaceScan/work 2>/dev/null
df -h / | tail -1
echo SLIM2_DONE
