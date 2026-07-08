#!/bin/bash
# Unproject rendered depth of two views into world points; find the head empirically.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/geosvr
python - <<'PY'
import torch, numpy as np, os
from src.config import cfg, update_config
MP = os.path.expanduser('~/FaceScan/output/geosvr_best')
update_config(os.path.join(MP, 'config.yaml'))
from src.dataloader.data_pack import DataPack
from src.sparse_voxel_model import SparseVoxelModel
dp = DataPack(cfg.data, cfg.model.white_background)
cfg.model.model_path = MP
vm = SparseVoxelModel(cfg.model)
vm.load_iteration(-1)
views = dp.get_train_cameras()
pts_all = []
for idx in (50, 5, 30, 70):
    view = views[idx]
    with torch.no_grad():
        pkg = vm.render(view, output_depth=True)
    depth = pkg['depth'][0].squeeze().cpu().numpy()
    H, W = depth.shape
    print(f"view {idx} ({view.image_name}): depth min {depth.min():.2f} med {np.median(depth[depth>0]):.2f} max {depth.max():.2f}")
    # face pixel: center of image
    ys, xs = np.mgrid[0:H:40, 0:W:40]
    zs = depth[ys, xs]
    ok = (zs > 0.1) & (zs < 20)
    x, y, z = xs[ok], ys[ok], zs[ok]
    xc = (x - view.Cx) / view.Fx * z
    yc = (y - view.Cy) / view.Fy * z
    campts = np.stack([xc, yc, z, np.ones_like(z)], axis=0)
    pose = np.identity(4)   # same as tsdf_mesh: extrinsic world->cam
    pose[:3,:3] = view.R.transpose(-1,-2) if isinstance(view.R, np.ndarray) else view.R.cpu().numpy().T
    T = view.T if isinstance(view.T, np.ndarray) else view.T.cpu().numpy()
    pose[:3,3] = T
    w = np.linalg.inv(pose) @ campts
    pts_all.append(w[:3].T)
    cz = depth[H//2, W//2]
    if cz > 0:
        xc = (W/2 - view.Cx)/view.Fx*cz; yc = (H/2 - view.Cy)/view.Fy*cz
        wc = np.linalg.inv(pose) @ np.array([xc, yc, cz, 1.0])
        print(f"   center pixel depth {cz:.2f} -> world {np.round(wc[:3],2)}")
pts = np.concatenate(pts_all)
print("all-depth world cloud: ctr", np.round(pts.mean(0),2), "min", np.round(pts.min(0),2), "max", np.round(pts.max(0),2))
PY
