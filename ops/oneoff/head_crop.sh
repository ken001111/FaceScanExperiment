#!/bin/bash
# Find the head as the least-squares intersection of all camera optical axes,
# crop the fused mesh to a sphere around it, keep the largest cluster, scale to mm.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
python - <<'PY'
import numpy as np, open3d as o3d, os, shutil
# Cameras in the MODEL's world frame (the loader may renormalize), so the
# convergence point lands in the same coordinates as the TSDF mesh.
from src.config import cfg, update_config
update_config(['cfg/dtu_mesh.yaml', os.path.expanduser('~/geosvr_head_overrides.yaml')],
              ['--source_path', os.path.expanduser('~/FaceScan/work/face_scan'),
               '--model_path',  os.path.expanduser('~/FaceScan/output/geosvr_best')])
from src.dataloader.data_pack import DataPack
dp = DataPack(cfg.data, cfg.model.white_background)
cams = dp.get_train_cameras()
A = np.zeros((3,3)); b = np.zeros(3)
pos = []
for cam in cams:
    w2c = cam.w2c.cpu().numpy() if hasattr(cam, 'w2c') else np.asarray(cam.world_view_transform.cpu()).T
    c2w = np.linalg.inv(w2c)
    o, d = c2w[:3,3], c2w[:3,2]
    d = d/np.linalg.norm(d)
    P = np.eye(3) - np.outer(d,d)
    A += P; b += P @ o
    pos.append(o)
pos = np.array(pos)
ctr = np.linalg.solve(A, b)
ctr = np.array([ctr[0], -ctr[1], -ctr[2]])   # loader world is y/z-flipped vs transforms (OpenGL->OpenCV)
print("head center (flipped convergence):", np.round(ctr,3))
print("cam dist to ctr: median %.2f" % np.median(np.linalg.norm(pos-ctr,axis=1)))
# RAW fusion output — the repo post-processing keeps only the largest cluster,
# which is the sky dome; the face lives in the clusters it drops.
mesh_path = os.path.expanduser("~/FaceScan/output/geosvr_best/mesh/tsdf/tsdf_fusion.ply")
m = o3d.io.read_triangle_mesh(mesh_path)
v = np.asarray(m.vertices)
d = np.linalg.norm(v - ctr, axis=1)
print("mesh verts within r of ctr:  r=1.0: %d  r=1.5: %d  r=2.0: %d  total %d"
      % ((d<1.0).sum(), (d<1.5).sum(), (d<2.0).sum(), len(v)))
keep = d < 1.5   # 15 cm around head center
m.remove_vertices_by_mask(~keep)
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.01*nt.max()),200)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))
for a in ("vertex_colors","vertex_normals","triangle_normals"):
    setattr(m, a, o3d.utility.Vector3dVector())
out = os.path.expanduser("~/geosvr_best.ply")
o3d.io.write_triangle_mesh(out, m, write_vertex_colors=False)
e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"cropped mesh: {len(m.vertices)} verts, extent(mm) {np.round(e,1)}")
# previews
m.compute_vertex_normals()
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT, exist_ok=True)
mc = m.get_axis_aligned_bounding_box().get_center(); rad = float(np.linalg.norm(e))
r = o3d.visualization.rendering.OffscreenRenderer(800, 800)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
views = {"posx":(1,0,0),"negx":(-1,0,0),"posy":(0,1,0),"negy":(0,-1,0),"posz":(0,0,1),"negz":(0,0,-1)}
for vn, dv in views.items():
    dv = np.asarray(dv,float); up = [0,1,0] if abs(dv[1])<0.9 else [0,0,1]
    r.setup_camera(50.0, mc, mc+dv*rad*1.7, up)
    o3d.io.write_image(f"{OUT}/head_{vn}.png", r.render_to_image())
shutil.copy(out, "/mnt/c/Users/m352395/Downloads/mesh_compare/geosvr_best_mesh.ply")
print("previews done")
PY
