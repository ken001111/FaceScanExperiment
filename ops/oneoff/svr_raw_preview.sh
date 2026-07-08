#!/bin/bash
# Head-crop preview of SVRaster dummy-raw mesh (frame-flip aware).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
seed = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/dummy_head_raw/points3d.ply"))
raw_ctr = np.asarray(seed.points).mean(0)
m = o3d.io.read_triangle_mesh(os.path.expanduser(
    "~/FaceScan/param_study/svr_dummy_raw/mesh/latest/mesh_dense.ply"))
v = np.asarray(m.vertices)
best, best_n = None, -1
for name, c in (("plain", raw_ctr), ("flipped", raw_ctr*np.array([1.0,-1.0,-1.0]))):
    n = int((np.linalg.norm(v-c,axis=1) < 1.5).sum())
    print(name, c.round(2), "->", n, "verts")
    if n > best_n: best, best_n = c, n
m.remove_vertices_by_mask(~(np.linalg.norm(v-best,axis=1) < 1.5))
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.02*nt.max()),300)); m.remove_unreferenced_vertices()
print("cropped:", len(m.vertices))
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
    o3d.io.write_image(f"{OUT}/svrraw_{i}.png", r.render_to_image())
print("SVR RAW PREVIEW DONE")
PY
