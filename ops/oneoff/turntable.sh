#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
m = o3d.io.read_triangle_mesh(os.path.expanduser("~/v5_head.ply"))
m.compute_vertex_normals()
mc = m.get_axis_aligned_bounding_box().get_center()
rad = float(np.linalg.norm(np.asarray(m.get_axis_aligned_bounding_box().get_extent())))
r = o3d.visualization.rendering.OffscreenRenderer(640, 640)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.78,0.75,0.73,1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.5,-0.5],[1,1,1],85000); r.scene.scene.enable_sun_light(True)
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"
for i in range(8):
    a = i * np.pi/4
    d = np.array([np.sin(a), 0.15, np.cos(a)]); d /= np.linalg.norm(d)
    r.setup_camera(50.0, mc, mc + d*rad*1.6, [0,1,0])
    o3d.io.write_image(f"{OUT}/tt_{i}.png", r.render_to_image())
print("turntable done")
PY
