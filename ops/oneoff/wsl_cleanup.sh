#!/bin/bash
# Archive final meshes + configs from old runs, then delete the bulky run dirs.
# Keeps: geosvr_best (active run), work/ (training data), logs (tiny).
A=~/FaceScan/output/_archive_meshes
mkdir -p "$A"
cd ~/FaceScan/output || exit 1
for d in Rear_Camera_* exp_kentest_2dgs exp_3dgs_424 exp_3dgs_494 \
         geosvr_458 geosvr_459 geosvr_461 geosvr_463 geosvr_465 geosvr_467 \
         geosvr_471 geosvr_500 svraster_457 svraster_571; do
  [ -d "$d" ] || continue
  mkdir -p "$A/$d"
  find "$d" \( -name 'fuse_post.ply' -o -name 'fuse.ply' -o -name 'cameras.json' \
    -o -name 'cfg_args' -o -name '*.yaml' -o -name 'metrics*.json' \
    -o -name 'tsdf_fusion_post.ply' \) -size -300M -exec cp --parents {} "$A/$d/" \;
  rm -rf "$d" && echo "archived+removed $d"
done
echo "--- archive size:"; du -sh "$A"
echo "--- remaining output:"; du -sh ~/FaceScan/output
fstrim -v / 2>/dev/null || sudo fstrim -v / 2>/dev/null || echo "fstrim skipped"
df -h / | tail -1
