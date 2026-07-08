#!/bin/bash
# dummy head through the same 4-method baseline (all ken-run fixes baked in).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONUNBUFFERED=1
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
DR=~/FaceScan/work/dummy_head
K=~/FaceScan/bench_dummy
mkdir -p "$K"/{2dgs,3dgs,svraster,geosvr}

echo "########## [0] SVRaster ken preview (catch-up) ##########"
python - <<'PY'
import numpy as np, open3d as o3d, os
p = os.path.expanduser("~/FaceScan/bench_ken/svraster/model/mesh/latest/mesh_dense.ply")
if os.path.isfile(p):
    m = o3d.io.read_triangle_mesh(p); m.compute_vertex_normals()
    bb = m.get_axis_aligned_bounding_box()
    ctr, rad = np.asarray(bb.get_center()), float(np.linalg.norm(np.asarray(bb.get_extent())))
    r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
    mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
    r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
    r.scene.scene.set_sun_light([0.3,-0.4,-0.7],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
    for vn, d in {"a":(0,0.2,-1),"b":(0.8,0.2,-0.5)}.items():
        d = np.asarray(d,float); d/=np.linalg.norm(d)
        r.setup_camera(50.0, ctr, ctr - d*rad*1.2, [0,1,0])
        o3d.io.write_image(f"/mnt/c/Users/m352395/Downloads/ken_previews/ken_svraster_{vn}.png", r.render_to_image())
    print("svraster ken preview ok", len(m.vertices))
PY

echo "########## [1/4] 2DGS dummy ##########"
cd ~/2d-gaussian-splatting
export PYTHONPATH="$HOME/2d-gaussian-splatting"
if [ ! -f "$K/2dgs/model/train/ours_30000/fuse_post.ply" ]; then
  if [ ! -d "$K/2dgs/model/point_cloud/iteration_30000" ]; then
    python train.py -s "$DR" -m "$K/2dgs/model" --quiet --test_iterations -1 --data_device cpu -r 2 > "$K/2dgs/train.log" 2>&1 || echo 2DGS_TRAIN_FAIL
  fi
  python render.py -m "$K/2dgs/model" -s "$DR" --quiet --skip_test --skip_train -r 2 --data_device cpu > "$K/2dgs/mesh.log" 2>&1 || echo 2DGS_MESH_FAIL
fi
ls "$K/2dgs/model/train"/ours_30000/fuse_post.ply 2>/dev/null

echo "########## [2/4] 3DGS dummy ##########"
cd ~/gaussian-splatting
export PYTHONPATH="$HOME/gaussian-splatting"
if [ ! -d "$K/3dgs/model/point_cloud/iteration_30000" ]; then
  python train.py -s "$DR" -m "$K/3dgs/model" --quiet --test_iterations -1 --data_device cpu -r 2 > "$K/3dgs/train.log" 2>&1 || echo 3DGS_TRAIN_FAIL
fi
python ~/gs_external/mesh_3dgs_tsdf.py -m "$K/3dgs/model" --iteration 30000 \
  --num_cluster 1 --scale_factor 1000 --mask_dir "$DR/masks" \
  --out "$K/3dgs/fuse_post.ply" > "$K/3dgs/mesh.log" 2>&1 || echo 3DGS_MESH_FAIL

echo "########## [3/4] SVRaster dummy ##########"
cd ~/svraster
export PYTHONPATH="$HOME/svraster_cuda_lib:$HOME/svraster"
S="$K/svraster/model"
if [ ! -f "$S/mesh/latest/mesh_dense.ply" ]; then
  python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$S" > "$K/svraster/train.log" 2>&1 || echo SVR_TRAIN_FAIL
  python render.py "$S" --skip_test --rgb_only --use_jpg > "$K/svraster/render.log" 2>&1 || echo SVR_RENDER_FAIL
  python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive > "$K/svraster/mesh.log" 2>&1 \
    || { echo "fallback lv9"; python extract_mesh.py "$S/" --save_gpu --use_vert_color --mesh_fname mesh_dense --progressive --final_lv 9 > "$K/svraster/mesh.log" 2>&1; } \
    || echo SVR_MESH_FAIL
fi
ls "$S/mesh/latest/"*.ply 2>/dev/null | head -1

echo "########## [4/4] GeoSVR dummy (3M cap, checkpointed) ##########"
cd ~/geosvr
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
G="$K/geosvr/model"
LOAD=""
if ls "$G/checkpoints"/*.pt >/dev/null 2>&1; then LOAD="--load_iteration -1"; fi
python train.py --cfg_files cfg/dtu_mesh.yaml --source_path "$DR" --model_path "$G" \
  --test_iterations 6000 15000 --subdivide_max_num 3000000 \
  --checkpoint_iterations 2000 4000 6000 8000 10000 12000 14000 16000 18000 \
  $LOAD > "$K/geosvr/train.log" 2>&1 || { echo GEO_TRAIN_FAIL; exit 42; }
python render.py "$G" --skip_test --use_jpg > "$K/geosvr/render.log" 2>&1 || echo GEO_RENDER_FAIL
python mesh_extract/tsdf_mesh.py "$G/" --num_cluster 1 --voxel_size 0.002 --max_depth 5.0 > "$K/geosvr/mesh.log" 2>&1 || echo GEO_MESH_FAIL

echo "########## previews ##########"
python - <<'PY'
import numpy as np, open3d as o3d, os
K = os.path.expanduser("~/FaceScan/bench_dummy")
OUT = "/mnt/c/Users/m352395/Downloads/dummy_previews"
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
        o3d.io.write_image(f"{OUT}/dummy_{meth}_{vn}.png", r.render_to_image())
    print("ok", meth, len(m.vertices))
print("DUMMY PREVIEWS DONE")
PY
echo BENCH_DUMMY_DONE

