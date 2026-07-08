import open3d as o3d, numpy as np, os, sys

OUT = "/mnt/c/Users/m352395/Downloads/mesh_previews"
os.makedirs(OUT, exist_ok=True)
MESHES = {
    "3dgs_tsdf": os.path.expanduser("~/3dgs_test.ply"),
    "sugar":     os.path.expanduser("~/sugar_test.ply"),
}

def shaded_views(name, path):
    m = o3d.io.read_triangle_mesh(path)
    m.compute_vertex_normals()
    c = m.get_axis_aligned_bounding_box().get_center()
    rad = np.linalg.norm(m.get_axis_aligned_bounding_box().get_extent()) * 0.9
    views = {  # eye offset dir (unit) -> view name
        "front": (0, 0, 1), "back": (0, 0, -1),
        "left": (1, 0, 0), "right": (-1, 0, 0),
        "threequarter": (0.7, 0.3, 0.7),
    }
    try:
        r = o3d.visualization.rendering.OffscreenRenderer(900, 900)
        mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
        mat.base_color = [0.75, 0.75, 0.78, 1.0]
        r.scene.add_geometry("m", m, mat)
        r.scene.set_background([1, 1, 1, 1])
        r.scene.scene.set_sun_light([0.3, -0.4, -0.6], [1, 1, 1], 90000)
        r.scene.scene.enable_sun_light(True)
        for vn, d in views.items():
            d = np.asarray(d, float); d /= np.linalg.norm(d)
            eye = c + d * rad * 2.2
            r.setup_camera(50.0, c, eye, [0, 1, 0])
            o3d.io.write_image(f"{OUT}/{name}_{vn}.png", r.render_to_image())
        print(f"{name}: rendered {len(views)} shaded views (Open3D offscreen)")
        return True
    except Exception as e:
        print(f"{name}: offscreen render FAILED ({e}); falling back to matplotlib")
        return mpl_fallback(name, m, c, views)

def mpl_fallback(name, m, c, views):
    import matplotlib; matplotlib.use("Agg"); import matplotlib.pyplot as plt
    v = np.asarray(m.vertices); n = np.asarray(m.vertex_normals)
    light = np.array([0.3, -0.4, -0.6]); light /= np.linalg.norm(light)
    shade = np.clip(n @ (-light), 0.1, 1.0)
    axes = {"front": (0, 1, 2), "left": (2, 1, 0), "threequarter": (0, 1, 2)}
    fig, axs = plt.subplots(1, len(axes), figsize=(4*len(axes), 4))
    for ax, (vn, (ax0, ax1, _)) in zip(axs, axes.items()):
        order = np.argsort(v[:, 2] if vn != "left" else v[:, 0])
        ax.scatter(v[order, ax0], v[order, ax1], c=shade[order], cmap="gray", s=0.5, vmin=0, vmax=1, linewidths=0)
        ax.set_aspect("equal"); ax.axis("off"); ax.set_title(f"{name} {vn}"); ax.invert_yaxis()
    fig.savefig(f"{OUT}/{name}_views.png", dpi=140, bbox_inches="tight"); plt.close(fig)
    print(f"{name}: wrote matplotlib fallback preview")
    return False

for name, path in MESHES.items():
    m = o3d.io.read_triangle_mesh(path)
    print(f"\n{name}: {len(m.vertices)} verts, {len(m.triangles)} tris, extent "
          f"{np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1)}")
    shaded_views(name, path)

# copy the ply files for opening in a 3D viewer
import shutil
for name, path in MESHES.items():
    shutil.copy(path, f"/mnt/c/Users/m352395/Downloads/mesh_previews/{name}_mesh.ply")
print("\ncopied .ply files to Downloads/mesh_previews/")
