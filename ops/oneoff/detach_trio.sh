#!/bin/bash
# Launch the full-res trio fully detached from the calling session.
MARK=~/FaceScan/param_study/.trio_running
if [ -f "$MARK" ] && kill -0 "$(cat "$MARK")" 2>/dev/null; then
  echo "already running pid $(cat "$MARK")"
  exit 0
fi
setsid nohup bash -c '
  echo $$ > ~/FaceScan/param_study/.trio_running
  bash ~/fg.sh ~/FaceScan/work/dummy_head_raw dummyraw > ~/FaceScan/param_study/trio.out 2>&1
  echo done > ~/FaceScan/param_study/.trio_done
  rm -f ~/FaceScan/param_study/.trio_running
' > /dev/null 2>&1 &
disown
echo "detached launcher started"
