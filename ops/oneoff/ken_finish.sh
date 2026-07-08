#!/bin/bash
# Finish ken baseline: SVRaster mesh retry, GeoSVR full retrain (defaults), previews.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DR=~/FaceScan/work/face_scan
K=~/FaceScan/bench_ken

echo "########## SVRaster ken mesh retry ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$K/svraster/model"
python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1 \
  || { echo retry_no_save_gpu; python extract_mesh.py "$S/" --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1; } \
  || { echo SVR_MESH_FAIL_AGAIN; tr '\r' '\n' < "$K/svraster/mesh.log" | grep -av 'it/s' | tail -3; }
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -2

echo "########## GeoSVR ken retrain (pure defaults) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$K/geosvr/model"
rm -rf "$G"
python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$G" --test_iterations 6000 15000 \
  --checkpoint_iterations 5000 10000 15000 > "$K/geosvr/train.log" 2>&1 || { echo GEO_TRAIN_FAIL; tr '\r' '\n' < "$K/geosvr/train.log" | grep -av 'it/s' | tail -3; }
python render.py "$G" --skip_test --use_jpg > "$K/geosvr/render.log" 2>&1 || echo GEO_RENDER_FAIL
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$K/geosvr/mesh.log" 2>&1 || echo GEO_MESH_FAIL
ls "$G/mesh/tsdf/"*.ply 2>/dev/null | head -2

echo "########## previews (4 ken meshes) ##########"
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
echo KEN_FINISH_DONE
