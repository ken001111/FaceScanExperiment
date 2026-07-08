#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
B = os.path.expanduser("~/FaceScan/bench")
OUT = "/mnt/c/Users/m352395/Downloads/dtu_previews"
os.makedirs(OUT, exist_ok=True)
MESHES = {
  "2dgs":    lambda s: f"{B}/2dgs/scan{s}/train/ours_30000/fuse_post.ply",
  "3dgs":    lambda s: (f"{B}/3dgs/scan{s}/fuse_post_crop.ply" if s==24 else f"{B}/3dgs/scan{s}/fuse_post.ply"),
  "svraster":lambda s: f"{B}/svraster/scan{s}/mesh/latest/mesh_dense_cleaned_for_eval.ply",
  "geosvr":  lambda s: f"{B}/geosvr/scan{s}/mesh/tsdf/tsdf_fusion_post.ply",
}
r = o3d.visualization.rendering.OffscreenRenderer(760, 570)
for s in (24, 37, 65):
    for meth, pf in MESHES.items():
        p = pf(s)
        if not os.path.isfile(p):
            print("MISSING", meth, s, p); continue
        m = o3d.io.read_triangle_mesh(p)
        if len(m.vertices) == 0: print("EMPTY", meth, s); continue
        m.compute_vertex_normals()
        bb = m.get_axis_aligned_bounding_box()
        ctr, ext = np.asarray(bb.get_center()), np.asarray(bb.get_extent())
        rad = float(np.linalg.norm(ext))
        mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
        r.scene.clear_geometry()
        r.scene.add_geometry("m", m, mat)
        r.scene.set_background([1,1,1,1])
        r.scene.scene.set_sun_light([0.4,-0.4,-0.8],[1,1,1],90000)
        r.scene.scene.enable_sun_light(True)
        # DTU scenes: object sits below the camera ring; a high three-quarter view works
        d = np.array([0.25, -0.9, -0.65]); d /= np.linalg.norm(d)
        r.setup_camera(45.0, ctr, ctr - d*rad*1.15, [0,0,-1])
        o3d.io.write_image(f"{OUT}/scan{s}_{meth}.png", r.render_to_image())
        print("ok", s, meth, len(m.vertices))
print("PREVIEWS DONE")
PY
