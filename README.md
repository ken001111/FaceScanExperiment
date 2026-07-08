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
