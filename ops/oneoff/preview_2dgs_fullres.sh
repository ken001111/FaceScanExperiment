#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
seed = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/dummy_head_raw/points3d.ply"))
ctr0 = np.asarray(seed.points).mean(0)
OUT = "/mnt/c/Users/m352395/Downloads/fullres_previews"
os.makedirs(OUT, exist_ok=True)
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
JOBS = {
  "2dgs_fullres1600": os.path.expanduser("~/FaceScan/param_study/2dgs_dummyraw_fullres/train/ours_30000/fuse_post.ply"),
  "2dgs_baseline960": os.path.expanduser("~/FaceScan/bench_dummy/2dgs/model/train/ours_30000/fuse_post.ply"),
}
for name, p in JOBS.items():
    if not os.path.isfile(p): print("MISSING", name); continue
    m = o3d.io.read_triangle_mesh(p)
    v = np.asarray(m.vertices)
    best = max([ctr0, ctr0*np.array([1.0,-1.0,-1.0])],
               key=lambda c: int((np.linalg.norm(v-c,axis=1) < 1.5).sum()))
    m.remove_vertices_by_mask(~(np.linalg.norm(v-best,axis=1) < 1.5))
    if len(m.vertices) == 0: print("EMPTY", name); continue
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
    for i in (0, 1):
        a = i*np.pi/2
        dv = np.array([np.sin(a), 0.15, np.cos(a)]); dv/=np.linalg.norm(dv)
        r.setup_camera(50.0, mc, mc + dv*rad*1.35, [0,1,0])
        o3d.io.write_image(f"{OUT}/{name}_{i}.png", r.render_to_image())
    print("ok", name, len(m.vertices))
print("DONE")
PY
