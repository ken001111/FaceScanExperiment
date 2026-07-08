source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export PYTHONUNBUFFERED=1
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/geosvr
M=~/FaceScan/output/geosvr_best
echo "[mesh] render training views"
if [ ! -d "$M/train/ours_20000_r2.0/renders" ]; then
  python render.py "$M" --skip_test --use_jpg > "$M/render.log" 2>&1 || { echo RENDER_FAILED; tail -12 "$M/render.log"; exit 1; }
else
  echo "[mesh] renders exist, skipping"
fi
echo "[mesh] masked TSDF fusion (voxel 0.005 = 0.5mm)"
MARK="$M/.mesh_marker"; touch "$MARK"
# Depth band [1.0, 4.0]: cameras are ~2.3 units from the head center (r~1.2), so
# real head surface is 1.0-3.6 from any camera. Semi-transparent floaters near the
# lens (depth 0.1-1.0) drag expected-depth toward the camera and must be zeroed.
python mesh_extract/tsdf_mesh_band.py "$M" --voxel_size 0.005 --sdf_trunc_scale 2.0 --min_depth 1.0 --max_depth 4.0 --num_cluster 1 \
  > "$M/mesh.log" 2>&1 || { echo MESH_FAILED; tail -12 "$M/mesh.log"; exit 1; }
MESH=$(find "$M" -name '*.ply' -newer "$MARK" | head -1)
echo "mesh: $MESH"
[ -n "$MESH" ] || { echo NO_MESH; exit 1; }
python - "$MESH" <<'PY'
import sys, numpy as np, open3d as o3d, os, shutil
m = o3d.io.read_triangle_mesh(sys.argv[1])
# World-space crop: the head is at the seed-pcd location (origin); the sky shell
# GeoSVR hallucinates sits out near the camera orbit (r~3.6). Depth cutoffs can't
# separate them (interleaved camera distances), a world box can.
pcd = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/face_scan/points3D.ply"))
bb = pcd.get_axis_aligned_bounding_box()
c0, half = np.asarray(bb.get_center()), np.asarray(bb.get_extent())/2
half = np.maximum(half*1.6, 0.6)   # inflate: LiDAR patch is frontal-only; give the skull room
crop = o3d.geometry.AxisAlignedBoundingBox(c0-half, c0+half)
m = m.crop(crop)
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.01*nt.max()), 200)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))    # scale_factor 10 -> mm
for a in ("vertex_colors","vertex_normals","triangle_normals"):
    setattr(m, a, o3d.utility.Vector3dVector())
out = os.path.expanduser("~/geosvr_best.ply")
o3d.io.write_triangle_mesh(out, m, write_vertex_colors=False)
e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"geosvr_best.ply: {len(m.vertices)} verts, extent(mm) {np.round(e,1)}")
# render previews + copy to Windows
m.compute_vertex_normals()
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT, exist_ok=True)
CMP="/mnt/c/Users/m352395/Downloads/mesh_compare"; os.makedirs(CMP, exist_ok=True)
ctr = m.get_axis_aligned_bounding_box().get_center(); rad = float(np.linalg.norm(e))*0.9
r = o3d.visualization.rendering.OffscreenRenderer(900, 900)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
for vn, d in {"front":(0,0,1),"threequarter":(0.7,0.3,0.7),"left":(1,0,0)}.items():
    d = np.asarray(d,float); d/=np.linalg.norm(d)
    r.setup_camera(50.0, ctr, ctr+d*rad*2.2, [0,1,0])
    o3d.io.write_image(f"{OUT}/geosvr_best_{vn}.png", r.render_to_image())
shutil.copy(out, f"{CMP}/geosvr_best_mesh.ply")
print("previews + copy done")
PY
echo "GEO_BEST_MESH_DONE"
