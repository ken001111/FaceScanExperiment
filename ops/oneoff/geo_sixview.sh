#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
m = o3d.io.read_triangle_mesh(os.path.expanduser("~/geosvr_best.ply"))
m.compute_vertex_normals()
e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
ctr = m.get_axis_aligned_bounding_box().get_center()
rad = float(np.linalg.norm(e))
OUT = "/mnt/c/Users/m352395/Downloads/mesh_previews"
r = o3d.visualization.rendering.OffscreenRenderer(700, 700)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
mat.base_color = [0.75, 0.75, 0.78, 1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1, 1, 1, 1])
r.scene.scene.set_sun_light([0.3, -0.4, -0.6], [1, 1, 1], 90000)
r.scene.scene.enable_sun_light(True)
views = {"posx": (1,0,0), "negx": (-1,0,0), "posy": (0,1,0),
         "negy": (0,-1,0), "posz": (0,0,1), "negz": (0,0,-1)}
for vn, d in views.items():
    d = np.asarray(d, float)
    up = [0,1,0] if abs(d[1]) < 0.9 else [0,0,1]
    r.setup_camera(50.0, ctr, ctr + d*rad*1.6, up)
    o3d.io.write_image(f"{OUT}/six_{vn}.png", r.render_to_image())
print("six views done")
PY
