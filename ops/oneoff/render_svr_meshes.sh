source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os, shutil
OUT = "/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT, exist_ok=True)
CMP = "/mnt/c/Users/m352395/Downloads/mesh_compare"; os.makedirs(CMP, exist_ok=True)
for name in ("svraster_test", "geosvr_test"):
    f = os.path.expanduser(f"~/{name}.ply")
    if not os.path.exists(f):
        print("missing", f); continue
    m = o3d.io.read_triangle_mesh(f); m.compute_vertex_normals()
    e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
    print(f"{name}: {len(m.vertices)} verts, extent(mm) {np.round(e,1)}")
    ctr = m.get_axis_aligned_bounding_box().get_center(); rad = float(np.linalg.norm(e)) * 0.9
    r = o3d.visualization.rendering.OffscreenRenderer(900, 900)
    mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
    mat.base_color = [0.75, 0.75, 0.78, 1.0]
    r.scene.add_geometry("m", m, mat); r.scene.set_background([1, 1, 1, 1])
    r.scene.scene.set_sun_light([0.3, -0.4, -0.6], [1, 1, 1], 90000)
    r.scene.scene.enable_sun_light(True)
    for vn, d in {"front": (0, 0, 1), "threequarter": (0.7, 0.3, 0.7)}.items():
        d = np.asarray(d, float); d /= np.linalg.norm(d)
        r.setup_camera(50.0, ctr, ctr + d * rad * 2.2, [0, 1, 0])
        o3d.io.write_image(f"{OUT}/{name}_{vn}.png", r.render_to_image())
    del r
    shutil.copy(f, f"{CMP}/{name.replace('_test','')}_mesh.ply")
print("previews + copies done")
PY
