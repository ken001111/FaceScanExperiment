source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/geosvr
M=~/FaceScan/output/geosvr_500
echo "[geosvr] render training views"
python render.py "$M" --skip_test --use_jpg > "$M.render.log" 2>&1 || { echo RENDER_FAILED; tail -15 "$M.render.log"; exit 1; }
echo "[geosvr] tsdf mesh"
MARK="$M/.mesh_marker"; touch "$MARK"
python mesh_extract/tsdf_mesh.py "$M" --voxel_size 0.005 --sdf_trunc_scale 2.0 --max_depth 5.0 --num_cluster 1 \
  > "$M.mesh2.log" 2>&1 || { echo MESH_FAILED; tail -15 "$M.mesh2.log"; exit 1; }
MESH=$(find "$M" -name '*.ply' -newer "$MARK" | head -1)
echo "mesh: $MESH"
[ -n "$MESH" ] || { echo NO_MESH; exit 1; }
python - "$MESH" <<'PY'
import sys, numpy as np, open3d as o3d, os
m = o3d.io.read_triangle_mesh(sys.argv[1])
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.01*nt.max()), 200)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))    # scale_factor 10 -> mm
for a in ("vertex_colors","vertex_normals","triangle_normals"):
    setattr(m, a, o3d.utility.Vector3dVector())
o3d.io.write_triangle_mesh(os.path.expanduser("~/geosvr_test.ply"), m, write_vertex_colors=False)
e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"geosvr_test.ply: {len(m.vertices)} verts, extent(mm) {np.round(e,1)}")
PY
echo "GEO_MESH_DONE"
