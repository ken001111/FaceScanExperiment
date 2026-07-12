# Dell 16 Premium (WSL2) setup — sm_120 / CUDA 12.8 build recipe (2026-07-11)

Run order after `wsl --install -d Ubuntu-24.04`, miniconda, and
`conda create -n facescan python=3.11` (accept conda ToS first):

1. As root (`wsl -u root`): apt install build-essential cmake ninja-build git;
   add NVIDIA CUDA repo; `apt install cuda-toolkit-12-8`.
2. `pip install torch torchvision --index-url https://download.pytorch.org/whl/cu128`
   (use `--cert /etc/ssl/certs/ca-certificates.crt` if the R2 CDN SSL-fails).
3. `pip install numpy==1.26.4` — open3d 0.18 TSDF segfaults on numpy 2.x.
4. clone_methods.sh, restore_data.sh (edit the OneDrive path).
5. build_geosvr.sh (deps + patch), rebuild_exts.sh (svraster_cuda in-place ->
   ~/geosvr_cuda_lib; fused-ssim), finalize_geosvr.sh (commit lidar-fork branch).
6. build_rest.sh (svraster/2dgs/3dgs) then fix_rasterizers.sh (adds <cstdint> for
   CUDA 12.8), build_sugar.sh (isolated 2-output rast -> ~/sugar_dgr + pytorch3d).
7. verify_all.sh — imports every stack.

GPU pin: CUDA_DEVICE_ORDER=PCI_BUS_ID; index 1 = RTX 5080 (train), 0 = 5070.
Isolated ext dirs (PYTHONPATH-selected, same pkg name svraster_cuda):
~/geosvr_cuda_lib, ~/svraster_cuda_lib; SuGaR 2-output rast in ~/sugar_dgr.
