#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
OUT = "/mnt/c/Users/m352395/Downloads/fullres_previews"
JOBS = {
  "2dgs_kenraw_fix": os.path.expanduser("~/FaceScan/param_study/2dgs_kenraw_fullres/train/ours_30000/fuse_post.ply"),
  "3dgs_kenraw_fix": os.path.expanduser("~/FaceScan/param_study/3dgs_kenraw_fullres/fuse_post.ply"),
}
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
for name, p in JOBS.items():
    if not os.path.isfile(p): print("MISSING", name); continue
    m = o3d.io.read_triangle_mesh(p)
    v = np.asarray(m.vertices)
    if np.abs(v).max() > 100: m.scale(0.001, center=(0,0,0)); v = np.asarray(m.vertices)
    # densest 30cm cell via grid histogram -> head anchor
    g = np.floor(v / 3.0).astype(np.int64)
    key = g[:,0]*73856093 ^ g[:,1]*19349663 ^ g[:,2]*83492791
    vals, counts = np.unique(key, return_counts=True)
    kbest = vals[np.argmax(counts)]
    ctr = v[key == kbest].mean(0)
    d = np.linalg.norm(v - ctr, axis=1)
    print(name, "anchor", np.round(ctr,2), "verts<1.5:", int((d<1.5).sum()), "of", len(v))
    m.remove_vertices_by_mask(~(d < 1.5))
    c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
    if len(nt):
        m.remove_triangles_by_mask(nt[tc] < max(int(0.02*nt.max()),300)); m.remove_unreferenced_vertices()
    m.compute_vertex_normals()
    bb = m.get_axis_aligned_bounding_box()
    mc, rad = np.asarray(bb.get_center()), float(np.linalg.norm(np.asarray(bb.get_extent())))
    mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
    r.scene.clear_geometry(); r.scene.add_geometry("m", m, mat)
    r.scene.set_background([1,1,1,1])
    r.scene.scene.set_sun_light([0.3,-0.4,-0.7],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
    for i in range(4):
        a = i*np.pi/2
        dv = np.array([np.sin(a), 0.15, np.cos(a)]); dv/=np.linalg.norm(dv)
        r.setup_camera(50.0, mc, mc + dv*rad*1.35, [0,1,0])
        o3d.io.write_image(f"{OUT}/{name}_{i}.png", r.render_to_image())
    print("ok", name, len(m.vertices))
print("DONE")
PY
