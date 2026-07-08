#!/bin/bash
# Crop all 4 dummy meshes to the head (LiDAR seed centroid, r=1.5 units = 15cm),
# keep largest cluster, render comparable previews.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os
K = os.path.expanduser("~/FaceScan/bench_dummy")
OUT = "/mnt/c/Users/m352395/Downloads/dummy_previews"
seed = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/dummy_head/points3d.ply"))
ctr = np.asarray(seed.points).mean(0)
print("head center (seed centroid):", np.round(ctr, 2))
MESHES = {
  "2dgs":    f"{K}/2dgs/model/train/ours_30000/fuse_post.ply",
  "3dgs":    f"{K}/3dgs/fuse_post.ply",
  "svraster":f"{K}/svraster/model/mesh/latest/mesh_dense.ply",
  "geosvr":  f"{K}/geosvr/model/mesh/tsdf/tsdf_fusion_post.ply",
}
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
for meth, p in MESHES.items():
    if not os.path.isfile(p): print("MISSING", meth); continue
    m = o3d.io.read_triangle_mesh(p)
    v = np.asarray(m.vertices)
    if meth == "3dgs":  # ken-era script leaves 3DGS mesh in mm (x1000)
        if np.linalg.norm(v.mean(0) - ctr) > 100: m.scale(0.001, center=(0,0,0)); v = np.asarray(m.vertices)
    d = np.linalg.norm(v - ctr, axis=1)
    print(meth, "verts<1.5:", int((d<1.5).sum()), "of", len(v))
    m.remove_vertices_by_mask(~(d < 1.5))
    if len(m.vertices) == 0: print("EMPTY after crop", meth); continue
    c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
    if len(nt):
        m.remove_triangles_by_mask(nt[tc] < max(int(0.02*nt.max()), 300)); m.remove_unreferenced_vertices()
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
        r.setup_camera(50.0, mc, mc + dv*rad*1.4, [0,1,0])
        o3d.io.write_image(f"{OUT}/head_{meth}_{i}.png", r.render_to_image())
    o3d.io.write_triangle_mesh(os.path.expanduser(f"~/dummy_{meth}_head.ply"), m)
    print("ok", meth, len(m.vertices))
print("HEADCROP DONE")
PY
