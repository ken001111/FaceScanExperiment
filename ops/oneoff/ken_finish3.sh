#!/bin/bash
# ken: only the post-training steps (GeoSVR render+tsdf, SVRaster mesh, previews).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
K=~/FaceScan/bench_ken

echo "########## GeoSVR ken render + tsdf ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$K/geosvr/model"
if [ ! -d "$G/train" ]; then
  python render.py "$G" --skip_test --use_jpg > "$K/geosvr/render.log" 2>&1 || { echo GEO_RENDER_FAIL; exit 42; }
fi
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$K/geosvr/mesh.log" 2>&1 || { echo GEO_MESH_FAIL; tr '\r' '\n' < "$K/geosvr/mesh.log" | grep -av 'it/s' | tail -3; }
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -2

echo "########## SVRaster ken mesh (default -> final_lv 9) ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$K/svraster/model"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1 \
    || { echo "OOM -> final_lv 9 (deviation: 16GB VRAM)"; \
         python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$K/svraster/mesh.log" 2>&1; } \
    || { echo SVR_MESH_FAIL_LV9; tr '\r' '\n' < "$K/svraster/mesh.log" | grep -av 'it/s' | tail -3; }
fi
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -2

echo "########## previews ##########"
python - <<'PY'
import numpy as np, open3d as o3d, os
K = os.path.expanduser("~/FaceScan/bench_ken")
OUT = "/mnt/c/Users/m352395/Downloads/ken_previews"
os.makedirs(OUT, exist_ok=True)
MESHES = {
  "2dgs":    f"{K}/2dgs/model/train/ours_30000/fuse_post.ply",
  "3dgs":    f"{K}/3dgs/fuse_post.ply",
  "svraster":f"{K}/svraster/model/mesh/latest/mesh_dense.ply",
  "geosvr":  f"{K}/geosvr/model/mesh/tsdf/tsdf_fusion_post.ply",
}
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
for meth, p in MESHES.items():
    if not os.path.isfile(p): print("MISSING", meth); continue
    m = o3d.io.read_triangle_mesh(p)
    if len(m.vertices) == 0: print("EMPTY", meth); continue
    m.compute_vertex_normals()
    bb = m.get_axis_aligned_bounding_box()
    ctr, rad = np.asarray(bb.get_center()), float(np.linalg.norm(np.asarray(bb.get_extent())))
    mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
    r.scene.clear_geometry(); r.scene.add_geometry("m", m, mat)
    r.scene.set_background([1,1,1,1])
    r.scene.scene.set_sun_light([0.3,-0.4,-0.7],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
    for vn, d in {"a":(0,0.2,-1),"b":(0.8,0.2,-0.5)}.items():
        d = np.asarray(d,float); d/=np.linalg.norm(d)
        r.setup_camera(50.0, ctr, ctr - d*rad*1.2, [0,1,0])
        o3d.io.write_image(f"{OUT}/ken_{meth}_{vn}.png", r.render_to_image())
    print("ok", meth, len(m.vertices))
print("KEN PREVIEWS DONE")
PY
echo KEN_FINISH3_DONE
