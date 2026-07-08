#!/bin/bash
# Crop the archived validation-run mesh (no blend_mask, 5k iters) at the head
# center to test whether the face is clean there.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
m = o3d.io.read_triangle_mesh(os.path.expanduser(
    "~/FaceScan/output/_archive_meshes/geosvr_500/geosvr_500/mesh/tsdf/tsdf_fusion_post.ply"))
ctr = np.array([0.032, 0.335, 1.577])
v = np.asarray(m.vertices)
d = np.linalg.norm(v - ctr, axis=1)
print("verts within r=1.5:", (d<1.5).sum(), "of", len(v))
m.remove_vertices_by_mask(~(d < 1.5))
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.01*nt.max()),200)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))
print("cropped:", len(m.vertices), "verts, extent(mm)",
      np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1))
m.compute_vertex_normals()
mc = m.get_axis_aligned_bounding_box().get_center()
rad = float(np.linalg.norm(np.asarray(m.get_axis_aligned_bounding_box().get_extent())))
r = o3d.visualization.rendering.OffscreenRenderer(800, 800)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"
for vn, dv in {"posx":(1,0,0),"negx":(-1,0,0),"posy":(0,1,0),"negy":(0,-1,0),"posz":(0,0,1),"negz":(0,0,-1)}.items():
    dv = np.asarray(dv,float); up = [0,1,0] if abs(dv[1])<0.9 else [0,0,1]
    r.setup_camera(50.0, mc, mc+dv*rad*1.7, up)
    o3d.io.write_image(f"{OUT}/val_{vn}.png", r.render_to_image())
print("val previews done")
PY
