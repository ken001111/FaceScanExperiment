# Claude Code context — facescan-experiments

Campaign context for any machine. Deep state: MACHINE_HANDOFF.md (restore +
current experiment state), RESULTS_*.md under paperB/, README.md (layout).

## What this project is

LiDAR-guided metric facial-surface reconstruction from an iPhone app capture,
for markerless face→CT/MR registration (offline DBS/FUS planning). User:
Jongseo (Mayo Clinic), neurosurgery research; expert, prefers decisive
autonomous execution with checkpointed, resumable runs.

## Method ("Metric GeoSVR", 3 components)

1. Pre-training depth fusion: per-frame DAv2→LiDAR fit in DISPARITY space
   (confidence-weighted, robust) → dense metric D_fused (paperB/fuse_depth.py).
2. Metric confidence-weighted Huber depth loss vs D_fused (geosvr lidar-fork,
   MetricLidarDepthLoss; raw-LiDAR row kept as ablation).
3. LiDAR-seeded voxel init: D_fused → world points (paperB/make_seeds.py) →
   Morton codes → allocate octree only there (fork cfg.init.init_mode=seeded).
Ablation ladder: nodepth / mono / lidar / lidarconf / fused / fused+seeded.

## Paper roadmap

(1) LiDAR-guided metric 2DGS for stereotactic neurosurgery → MICCAI 2027;
(2) patient-dataset extension → MedIA (IRB-gated);
(3) LiDAR-supervised metric GeoSVR for surface registration → vision journal.
Pipeline naming: P1 = 2DGS on RTX 5080 PC, P2 = 2DGS on device, P3 = device
photogrammetry.

## Standing decisions (user-confirmed)

- All cross-method comparisons use RAW capture frames. Masking/matte arms are
  DEPRECATED (white-circle compositing poisons multi-view consistency — the
  single biggest failure cause we found; app should export raw + person mattes).
- This GitHub repo is the CANONICAL code home. Run/edit here, commit+push
  every session's scripts (one-offs under ops/oneoff/).
- Living inventory artifact must be refreshed when new data/results land
  (inventory/build_report.py → redeploy to the SAME artifact URL).
- 2DGS remains the geometry pipeline for LIVING subjects (motion-robust);
  GeoSVR/SVRaster viable for rigid subjects with raw/matte data.

## Key experiment facts (validated)

- DTU 3-scan (24/37/65) mean chamfer: GeoSVR 0.426 < SVRaster 0.725 ≈ 2DGS
  0.727 < 3DGS+TSDF 2.586 — every method reproduces its paper. DTU-vs-ken
  ranking INVERSION (GeoSVR best on DTU, billboard on ken) is the key figure.
- Dummy-head control: rigid mannequin + raw frames → clean GeoSVR head;
  living subject (ken) raw → sky-shell geometry; ken matte → shells gone,
  face still rough → residual failure = SUBJECT MOTION, not background.
- ARKitScenes ablations (2 scenes): metric anchoring ~halves completeness
  error; mono-alone is WORSE than no depth (scale drift); fused ≈ raw lidar
  in rooms (LiDAR-optimal regime — fused>lidar must be shown on faces).
- ARKitScenes eval traps: highres_depth GT coverage ≡ frame coverage
  (observation-culling is circular — use traversal-distance crop);
  transforms are OpenGL convention (auto-test back-projection).

## Machine notes (2026-07 move)

RTX 5080 (16 GB) in Sonnet TB enclosure, moving to Dell 16 Premium (32 GB,
TB4) with internal RTX 5070 Laptop (8 GB). Policy: ONE training at a time
(5080) + light 5070 sidecar (DAV2 priors/render/small arms) via
CUDA_VISIBLE_DEVICES; .wslconfig start memory=20GB swap=8GB. When WSL gets
flaky: check disk free and Windows COMMIT charge FIRST (VM hard-kills at
"Read dataset in NeRF format" = commit exhaustion; empty git objects after a
kill = run git fsck). prep.py executes at import and rmtree's its output —
never invoke bare. Long runs: background sessions + checkpoint-resume
(ablate_depth.sh pattern).
