#!/bin/bash
# Commit the applied lidar-fork patch onto a 'lidar-fork' branch so
# ablate_depth.sh's `git checkout -q lidar-fork` works.
LOG="$HOME/finalize_geosvr.log"; echo "START $(date)" > "$LOG"
cd ~/geosvr || exit 1
git config user.email >/dev/null 2>&1 || git config user.email "kenlee@dell.local"
git config user.name  >/dev/null 2>&1 || git config user.name  "kenlee"
if git rev-parse --verify lidar-fork >/dev/null 2>&1; then
  echo "lidar-fork branch already exists" >> "$LOG"
  git checkout lidar-fork >> "$LOG" 2>&1
else
  git checkout -b lidar-fork >> "$LOG" 2>&1
  git add -A >> "$LOG" 2>&1
  git commit -m "lidar-fork: MetricLidarDepthLoss + LiDAR-seeded voxel init" >> "$LOG" 2>&1
fi
echo "=== branches ===" >> "$LOG"; git branch >> "$LOG" 2>&1
echo "=== HEAD ===" >> "$LOG"; git log --oneline -1 >> "$LOG" 2>&1
echo "ALLDONE $(date)" >> "$LOG"
cat "$LOG"
