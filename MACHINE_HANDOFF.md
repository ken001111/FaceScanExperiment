# Machine handoff — moving RTX 5080 eGPU to new Dell laptop (2026-07-10)

State snapshot at the moment the old box (32 GB corporate laptop, WSL2) was
retired from GPU duty. Written for the first Claude Code session on the new
machine; also serves as the restore checklist.

## Campaign state (2026-07-10)

- **Paper B ablations**: scene 41069021 (laser GT) 5-arm table COMPLETE
  (RESULTS_41069021.md); scene 47331963 5-arm PROXY table COMPLETE
  (RESULTS_47331963.md, ARKit-mesh reference). Findings replicate across
  scenes: metric anchoring works, mono-alone harmful, fused~lidar in rooms.
- **Seeded-init arm (full method, 6th row)**: code DONE + validated
  (GeoSVR lidar-fork: cfg.init.init_mode=seeded, seed_path, seed_dilate;
  constructor octlayout_inside_seeded via xyz_2_octpath Morton encoding;
  paperB/make_seeds.py generates the seed cloud from fused depth).
  Training on 41069021 INTERRUPTED at iter 7500/20000 for the machine move —
  checkpoints in ~/FaceScan/paperB/ablation_41069021/seeded/checkpoints/.
  Resume = rerun the queue (idempotent):
  `ABLATE_SRC=$HOME/FaceScan/work/arkit_41069021 \
   ABLATE_OUT=$HOME/FaceScan/paperB/ablation_41069021 ABLATE_ARMS=seeded \
   bash paperB/ablate_depth.sh`
  Then: render + tsdf mesh (same recipe as other arms), score with
  paperB/score_41069021_v6.py (add seeded to its arm list), add row to
  RESULTS_41069021.md.
- **Paper A**: M1 (metric library, DTU-validated) + M2 (export audit) done;
  M3 raw-LiDAR baseline, M4 init-study arms, M5 tables remain.
- Living inventory artifact must be updated after new results
  (inventory/build_report.py -> redeploy same artifact path).

## What moves to the new machine

From WSL (tar these from ~; ~28 GB total):
- ~/FaceScan/work        (6.9G — prepped workdirs incl. arkit_41069021[_fused],
                          arkit_47331963[_fused], face_scan*, dummy_head*)
- ~/FaceScan/paperB      (11G — ablation arms, gt_cache, logs, seeded ckpts)
- ~/FaceScan/bench       (4.7G — DTU + ken + dummy 4-method results)
- ~/FaceScan/data        (3.9G — arkit raw/upsampling subset; DTU re-downloadable)
- ~/FaceScan/output/_archive_meshes (2.0G — final meshes of old runs)
- ~/pe_verify            (tiny — eval_common metric library used by scorers)

From Windows Downloads (capture ORIGINALS — prep.py rebuilds workdirs
deterministically from these):
- "Scan_Ken _20260611_163306_cropped-299678C5-…" (note space after Scan_Ken)
- "Scan_depth5_20260630_200737_cropped-5995F03E-…"
- Documents/Claude project docs (Experiment_Plans_PaperA_and_PaperB.docx etc.)

NOT moved: conda envs, built CUDA extensions, repo clones — all rebuilt from
this repo's setup scripts (they encode every sm_120/Blackwell fix).

## New-machine setup order (Windows Dell laptop + WSL2 assumed)

0. DUAL-GPU NOTE: the Dell has an internal RTX 5070 Laptop (8 GB) alongside the
   5080 eGPU. Both appear in WSL as cuda:0/cuda:1 under the one GeForce driver;
   select per-job with CUDA_VISIBLE_DEVICES. Plan: 5080 = heavy training,
   5070 = DAV2 priors / rendering / mesh extraction / face-scale arms + display.
   Methods are single-GPU - parallelism = two independent jobs, RAM permitting.
0. Dell prep: run Dell Command Update (BIOS + Thunderbolt firmware), confirm
   the USB-C port is TB4/USB4 (lightning-bolt icon / spec sheet). Plain
   USB-C 3.x will NOT run an eGPU.
1. NVIDIA GeForce driver (Windows side; includes WSL CUDA passthrough).
   Connect Sonnet enclosure, approve the Thunderbolt device, power-cycle the
   enclosure once with cable attached. Device Manager must show RTX 5080 OK.
2. `wsl --install -d Ubuntu-24.04` (or 22.04 to match old box), then inside:
   miniconda -> `conda create -n facescan python=3.11`.
3. Clone this repo; run ops/setup scripts in order:
   setup_svraster.sh, setup_sugar.sh/setup_3dgs.sh as needed; GeoSVR:
   clone + `git checkout lidar-fork` — the fork patches (MetricLidarDepthLoss,
   camera attach, seeded init) live in the geosvr fork dir / patch flow under
   paperB/geosvr_fork. Build CUDA extensions into isolated dirs
   (~/svraster_cuda_lib, ~/geosvr_cuda_lib) exactly as the scripts do.
4. Restore the data tars into ~. Re-link face_scan_matte symlinks if used.
5. ~/.wslconfig on the Dell: size memory= to (RAM - 10GB for Windows), modest
   swap (4-8GB). The old box's crash physics: Windows commit exhaustion kills
   the WSL VM during training data load — symptoms are VM death at
   "Read dataset in NeRF format", journal 'uncleanly shut down' on reboot.
   Check `Get-PSDrive C` (disk) and commit charge FIRST when WSL gets flaky.
6. Smoke: `nvidia-smi` in WSL -> CUDA matmul -> resume the seeded arm (above).

## Old-box gotchas that may not apply on the new machine (verify before
assuming): diskpart-compact blocked by corporate policy; no admin; 16 GB VRAM
ceiling (same GPU — still applies); eGPU bus recovery = power-cycle enclosure
(still applies); one-workload-at-a-time RAM discipline (relax per new RAM).
