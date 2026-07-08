#!/bin/bash
# One tick of the remaining queue: resume whatever is unfinished, exit when all done.
# Safe to invoke repeatedly; a lockfile prevents overlap.
LOCK=~/FaceScan/param_study/.tick_lock
DONE_MARK=~/FaceScan/param_study/.queue_complete
[ -f "$DONE_MARK" ] && exit 0
if [ -f "$LOCK" ]; then
  pid=$(cat "$LOCK")
  kill -0 "$pid" 2>/dev/null && exit 0   # previous tick still alive
fi
echo $$ > "$LOCK"
P=~/FaceScan/param_study
need=0
[ -f "$P/geosvr_dummy_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply" ] || need=1
[ -f "$P/svr_dummyraw_fullres/mesh/latest/mesh_dense.ply" ] || need=1
[ -f "$P/svr_kenraw_fullres/mesh/latest/mesh_dense.ply" ] || need=1
if [ "$need" = "0" ]; then
  touch "$DONE_MARK"
  rm -f "$LOCK"
  exit 0
fi
bash ~/run_everything.sh >> ~/FaceScan/param_study/queue_tick.out 2>&1
rm -f "$LOCK"
