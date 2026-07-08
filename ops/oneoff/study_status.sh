#!/bin/bash
for f in ~/FaceScan/param_study/*.train.log; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .train.log)
  p=$(tr '\r' '\n' < "$f" | grep -aE 'Training' | tail -1 | grep -oE '[0-9]+/20000|[0-9]+it' | head -1)
  echo "$n: ${p:-starting}"
done
find ~/FaceScan/param_study -name '*.ply' 2>/dev/null | head -6
nvidia-smi --query-gpu=memory.used,utilization.gpu --format=csv,noheader 2>/dev/null
