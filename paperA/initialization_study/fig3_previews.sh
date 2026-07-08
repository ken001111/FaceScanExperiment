#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os, glob
OUT = "/mnt/c/Users/m352395/Downloads/fig3_previews"
os.makedirs(OUT, exist_ok=True)
RESULTS = os.path.expanduser("~/FaceScan/results")
ref = o3d.io.read_point_cloud(os.path.expanduser("~/FaceScan/work/ken_initstudy/points3d.ply"))
r = o3d.visualization.rendering.OffscreenRenderer(700, 700)
for init in ("sfm", "random", "lidar"):
    cands = glob.glob(f"{RESULTS}/Face_Mesh_MetricScale_ken_{init}_nn.ply")
    if not cands: print("missing", init); continue
    m = o3d.io.read_triangle_mesh(cands[0])
    v = np.asarray(m.vertices)
    # crop to head: densest 30cm cell
    g = np.floor(v / 30.0).astype(np.int64)
    key = g[:,0]*73856093 ^ g[:,1]*19349663 ^ g[:,2]*83492791
    vals, counts = np.unique(key, return_counts=True)
    ctr = v[key == vals[np.argmax(counts)]].mean(0)
    m.remove_vertices_by_mask(~(np.linalg.norm(v-ctr,axis=1) < 150.0))
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
        o3d.io.write_image(f"{OUT}/init_{init}_{i}.png", r.render_to_image())
    print("ok", init, len(m.vertices))
print("FIG3 PREVIEWS DONE")
PY
