#!/bin/bash
# Gather all campaign code into one organized git repo: ~/facescan-experiments
set -e
R=~/facescan-experiments
mkdir -p "$R"/{paperA/{metrics,method_comparison,initialization_study},paperB,pipeline,benchmarks/dtu,ops,inventory,results}

# Paper A — shared metric library + table harnesses
cp -r ~/pe_verify/common/*.py            "$R/paperA/metrics/"
cp -r ~/pe_verify/method_comparison/*.py "$R/paperA/method_comparison/" 2>/dev/null || true
cp -r ~/pe_verify/method_comparison/external "$R/paperA/method_comparison/" 2>/dev/null || true
cp -r ~/pe_verify/initialization_study/*.py "$R/paperA/initialization_study/"
cp /mnt/c/Users/M352395/Downloads/table3_dev.sh "$R/paperA/initialization_study/"
cp /mnt/c/Users/M352395/Downloads/sfm_arm.sh    "$R/paperA/initialization_study/"
cp /mnt/c/Users/M352395/Downloads/raw_lidar_baselines.sh "$R/paperA/method_comparison/"
cp ~/FaceScan/paperA/table3_dev.json "$R/results/" 2>/dev/null || true

# Paper B — ARKitScenes adapter (+ fork notes placeholder)
cp /mnt/c/Users/M352395/Downloads/arkit_adapter.py "$R/paperB/"
cp /mnt/c/Users/M352395/Downloads/arkit_pick2.sh   "$R/paperB/"

# Capture pipeline (app-export -> training data)
cp ~/FaceScan/bin/prep.py ~/FaceScan/bin/finish_mesh.py ~/FaceScan/bin/make_report.py "$R/pipeline/" 2>/dev/null || true
cp ~/FaceScan/init_study.sh "$R/paperA/initialization_study/init_study_driver.sh" 2>/dev/null || true

# DTU benchmark drivers + validation
for f in bench_scan_all.sh validate_dtu.sh validate_dtu2.sh dtu_download.sh neus_download.sh dtu_previews.sh; do
  cp "/mnt/c/Users/M352395/Downloads/$f" "$R/benchmarks/dtu/" 2>/dev/null || true
done

# Ops: run drivers that encode the hard-won pitfalls (kept minimal)
for f in fullres_gs.sh fullres_run.sh raw_arm.sh queue_tick2.sh geo_chunked.sh bench_ken.sh bench_dummy.sh; do
  cp "/mnt/c/Users/M352395/Downloads/$f" "$R/ops/" 2>/dev/null || true
done

# Inventory builder
cp /mnt/c/Users/M352395/Downloads/build_report.py "$R/inventory/"

# DTU eval results
mkdir -p "$R/results/dtu"
for m in 2dgs 3dgs svraster geosvr; do
  for s in 24 37 65; do
    for src in ~/FaceScan/bench/$m/scan$s/mesh/tsdf/results.json \
               ~/FaceScan/bench/$m/eval_scan$s/results.json \
               ~/FaceScan/bench/$m/scan$s/mesh/latest/evaluation/results.json; do
      [ -f "$src" ] && cp "$src" "$R/results/dtu/${m}_scan${s}.json" && break
    done
  done
done

cat > "$R/README.md" <<'MD'
# facescan-experiments

Research code for the LiDAR-guided facial-surface reconstruction papers.

- `paperA/` — clinical paper (MICCAI): shared surface-metric library
  (`metrics/eval_common.py`, validated against the official DTU evaluator),
  method-comparison and initialization-study harnesses.
- `paperB/` — methods paper: ARKitScenes adapter for LiDAR-anchored
  sparse-voxel experiments (GeoSVR fork with measured-depth supervision).
- `pipeline/` — app-export -> training-data preparation (prep.py; NOTE: runs
  at import, output dir hardcoded — invoke via SCAN_DIR env with a sed'd copy).
- `benchmarks/dtu/` — 4-method DTU drivers (paper-default configs) and the
  metric-library validation scripts. Known pitfalls are encoded in comments.
- `ops/` — crash-resilient run drivers for the 16 GB eGPU/WSL box
  (checkpoint-resume, VRAM caps, session-kill workarounds).
- `results/` — DTU per-scan official eval JSONs + dev-data tables.
- `inventory/` — the living data-inventory report builder.

Decisions of record: comparisons use RAW capture frames (masking/matte arms
deprecated — cross-method comparability); DTU protocol = each paper's own
config + official evaluator.
MD

cd "$R"
git init -q 2>/dev/null || true
git add -A
git commit -q -m "Organize campaign code: metric library, DTU benchmark, paper A/B harnesses, ops drivers" || echo "(nothing to commit)"
git log --oneline | head -3
echo REPO_ORGANIZED
