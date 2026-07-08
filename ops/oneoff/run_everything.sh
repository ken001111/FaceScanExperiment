#!/bin/bash
# ENTIRE remaining full-res queue. Run inside an open WSL terminal:
#   bash /mnt/c/Users/M352395/Downloads/run_everything.sh
# Keep the window open until it prints ALL_DONE. Every step is idempotent.
set -u
echo "=== [1/4] full-res trio on dummy raw (2DGS mesh, 3DGS, SVRaster) ==="
bash ~/fg.sh ~/FaceScan/work/dummy_head_raw dummyraw

echo "=== [2/4] GeoSVR dummy raw @1.5x (resume from checkpoint) ==="
bash ~/fr.sh ~/FaceScan/work/dummy_head_raw geosvr_dummy_raw_fullres

echo "=== [3/4] full-res trio on ken raw ==="
bash ~/fg.sh ~/FaceScan/work/face_scan_raw kenraw

echo "=== [4/4] GeoSVR ken raw @1.5x ==="
bash ~/fr.sh ~/FaceScan/work/face_scan_raw geosvr_ken_raw_fullres

echo "=== previews ==="
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os, glob
P = os.path.expanduser("~/FaceScan/param_study")
OUT = "/mnt/c/Users/m352395/Downloads/fullres_previews"
os.makedirs(OUT, exist_ok=True)
ANCHOR = {
  "dummyraw": ("~/FaceScan/work/dummy_head_raw/points3d.ply", False),
  "kenraw":   ("~/FaceScan/work/face_scan_raw/points3d.ply", True),
}
MESHES = {
  "2dgs_dummyraw":  (f"{P}/2dgs_dummyraw_fullres/train/ours_30000/fuse_post.ply", "dummyraw"),
  "3dgs_dummyraw":  (f"{P}/3dgs_dummyraw_fullres/fuse_post.ply", "dummyraw"),
  "svr_dummyraw":   (f"{P}/svr_dummyraw_fullres/mesh/latest/mesh_dense.ply", "dummyraw"),
  "geosvr_dummyraw":(f"{P}/geosvr_dummy_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply", "dummyraw"),
  "2dgs_kenraw":    (f"{P}/2dgs_kenraw_fullres/train/ours_30000/fuse_post.ply", "kenraw"),
  "3dgs_kenraw":    (f"{P}/3dgs_kenraw_fullres/fuse_post.ply", "kenraw"),
  "svr_kenraw":     (f"{P}/svr_kenraw_fullres/mesh/latest/mesh_dense.ply", "kenraw"),
  "geosvr_kenraw":  (f"{P}/geosvr_ken_raw_fullres/mesh/tsdf/tsdf_fusion_post.ply", "kenraw"),
}
r = o3d.visualization.rendering.OffscreenRenderer(760, 760)
for name, (mp, tag) in MESHES.items():
    if not os.path.isfile(mp): print("MISSING", name); continue
    seed_p, flip = ANCHOR[tag]
    seed = o3d.io.read_point_cloud(os.path.expanduser(seed_p))
    ctr = np.asarray(seed.points).mean(0)
    m = o3d.io.read_triangle_mesh(mp)
    v = np.asarray(m.vertices)
    if name.startswith("3dgs") and np.abs(v).max() > 100: m.scale(0.001, center=(0,0,0)); v = np.asarray(m.vertices)
    cands = [ctr, ctr*np.array([1.0,-1.0,-1.0])]
    best = max(cands, key=lambda c: int((np.linalg.norm(v-c,axis=1) < 1.5).sum()))
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
    for i in range(4):
        a = i*np.pi/2
        dv = np.array([np.sin(a), 0.15, np.cos(a)]); dv/=np.linalg.norm(dv)
        r.setup_camera(50.0, mc, mc + dv*rad*1.4, [0,1,0])
        o3d.io.write_image(f"{OUT}/{name}_{i}.png", r.render_to_image())
    print("ok", name, len(m.vertices))
print("PREVIEWS DONE")
PY
echo ALL_DONE
