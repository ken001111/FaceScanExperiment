#!/bin/bash
# Diagnostic: dump (a) the composited gt the trainer sees, (b) the model's render
# from the latest surviving checkpoint, for the same training view.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/geosvr
python - <<'PY'
import torch, numpy as np, os
from PIL import Image
from src.config import cfg, update_config
update_config(['cfg/dtu_mesh.yaml', os.path.expanduser('~/geosvr_head_overrides.yaml')],
              ['--source_path', os.path.expanduser('~/FaceScan/work/face_scan'),
               '--model_path',  os.path.expanduser('~/FaceScan/output/geosvr_best')])
from src.dataloader.data_pack import DataPack
dp = DataPack(cfg.data, cfg.model.white_background)
cams = dp.get_train_cameras()
print("n_train:", len(cams), "has_mask:", dp.has_mask)
OUT = '/mnt/c/Users/m352395/Downloads/mesh_previews'
cam = cams[0]
gt = (cam.image.cpu().numpy().transpose(1,2,0)*255).astype(np.uint8)
Image.fromarray(gt).save(f'{OUT}/diag_gt0.png')
print("gt saved", gt.shape, "gt mean:", gt.mean()/255)

import src.sparse_voxel_gears as svg
from src.sparse_voxel_model import SparseVoxelModel
model = SparseVoxelModel(cfg.model)
loaded = model.load_iteration(cfg.model.model_path, -1)
print("loaded iter:", loaded)
model.freeze_vox_geo()
with torch.no_grad():
    ret = model.render(cam, ss=1.0, output_depth=True)
im = ret['color'].clamp(0,1).cpu().numpy().transpose(1,2,0)
Image.fromarray((im*255).astype(np.uint8)).save(f'{OUT}/diag_render0.png')
print("render saved; render mean:", im.mean())
print("scene_center:", model.scene_center.tolist(), "scene_extent:", float(model.scene_extent))
print("inside_extent:", float(model.inside_extent) if hasattr(model,'inside_extent') else '?')
print("cam0 pos:", cam.position.tolist() if hasattr(cam,'position') else cam.camera_center.tolist())
PY
