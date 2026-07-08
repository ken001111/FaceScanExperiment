#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
seed = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/dummy_head_raw/points3d.ply"))
ctr = np.asarray(seed.points).mean(0)
m = o3d.io.read_triangle_mesh(os.path.expanduser(
    "~/FaceScan/param_study/geosvr_dummy_raw/mesh/tsdf/tsdf_fusion_post.ply"))
v = np.asarray(m.vertices)
d = np.linalg.norm(v - ctr, axis=1)
print("total", len(v), " within r1.5:", int((d<1.5).sum()))
m.remove_vertices_by_mask(~(d < 1.5))
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.02*nt.max()), 300)); m.remove_unreferenced_vertices()
print("after crop+cluster:", len(m.vertices))
m.compute_vertex_normals()
bb = m.get_axis_aligned_bounding_box()
mc, rad = np.asarray(bb.get_center()), float(np.linalg.norm(np.asarray(bb.get_extent())))
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.7],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
OUT = "/mnt/c/Users/m352395/Downloads/dummy_previews"
for i in range(4):
    a = i*np.pi/2
    dv = np.array([np.sin(a), 0.15, np.cos(a)]); dv/=np.linalg.norm(dv)
    r.setup_camera(50.0, mc, mc + dv*rad*1.4, [0,1,0])
    o3d.io.write_image(f"{OUT}/rawgeo_{i}.png", r.render_to_image())
o3d.io.write_triangle_mesh(os.path.expanduser("~/geosvr_dummy_raw_head.ply"), m)
print("RAW REVEAL DONE")
PY
