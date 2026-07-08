#!/bin/bash
# Sweep ALL remaining campaign code into the repo, push, then clean local scatter.
set -e
R=~/facescan-experiments
mkdir -p "$R"/{ops/oneoff,paperA/initialization_study,pipeline}

# 1) everything from pe_verify not yet captured
cp -rn ~/pe_verify/initialization_study/. "$R/paperA/initialization_study/" 2>/dev/null || true
cp -rn ~/pe_verify/preliminary "$R/paperA/" 2>/dev/null || true
find "$R" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true

# 2) all campaign helper scripts from Downloads (one-offs go to ops/oneoff for the record)
DL=/mnt/c/Users/M352395/Downloads
for f in "$DL"/*.sh "$DL"/*.py; do
  b=$(basename "$f")
  case "$b" in
    bench_scan_all.sh|validate_dtu*.sh|dtu_download.sh|neus_download.sh|dtu_previews.sh) d="benchmarks/dtu";;
    table3_dev.sh|sfm_arm.sh|fig3_previews.sh) d="paperA/initialization_study";;
    raw_lidar_baselines.sh|verify_loader.sh) d="paperA/method_comparison";;
    arkit_*.py|arkit_*.sh) d="paperB";;
    build_report.py|inventory.sh) d="inventory";;
    fullres_*.sh|raw_arm.sh|queue_tick*.sh|geo_chunked.sh|bench_ken.sh|bench_dummy.sh|bench_scan24*.sh) d="ops";;
    *) d="ops/oneoff";;
  esac
  mkdir -p "$R/$d"
  cp -n "$f" "$R/$d/" 2>/dev/null || true
done

# 3) pipeline extras
cp -n ~/FaceScan/bin/*.py ~/FaceScan/bin/*.sh "$R/pipeline/" 2>/dev/null || true

cd "$R"
git add -A
git commit -q -m "Sweep all campaign scripts (one-offs under ops/oneoff); repo is now canonical" || echo nothing-to-commit
git push -q && echo PUSHED

# 4) clean local scatter: staged one-off scripts in ~ and Downloads campaign scripts
rm -f ~/[a-z][a-z0-9].sh ~/[a-z][a-z0-9][a-z0-9].sh ~/queue_tick.sh ~/run_everything.sh ~/sfm.sh ~/gc.sh 2>/dev/null
cd "$DL"
# delete only files that verifiably exist in the repo now
del=0
for f in "$DL"/*.sh "$DL"/*.py; do
  b=$(basename "$f")
  if find "$R" -name "$b" | grep -q .; then rm -f "$f"; del=$((del+1)); fi
done
echo "downloads scripts removed: $del"

# 5) deprecated matte data (user decision) — datasets are tiny (symlinked), outputs bigger
rm -rf ~/FaceScan/work/dummy_head_matte ~/FaceScan/work/face_scan_matte \
       ~/FaceScan/param_study/geosvr_ken_matte_meshonly ~/FaceScan/param_study/geosvr_dummy_matte_meshonly \
       ~/FaceScan/param_study/svr_dummy_matte ~/FaceScan/param_study/svr_ken_matte 2>/dev/null
echo "matte artifacts removed"
df -h / | tail -1
git log --oneline | head -2
echo SWEEP_DONE
