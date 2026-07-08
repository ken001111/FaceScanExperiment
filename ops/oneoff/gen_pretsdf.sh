source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
M=$(find ~/FaceScan/output -maxdepth 3 -type d -name 'iteration_30000' -path '*exp_3dgs_*' 2>/dev/null | head -1)
echo "30k model iteration dir: $M"
[ -n "$M" ] || { echo "no 30k 3DGS model found"; exit 1; }
PLY="$M/point_cloud.ply"
python - "$PLY" <<'PY'
import sys, os, numpy as np, open3d as o3d
src = sys.argv[1]
sf = 10.0  # ken scale_factor
# read gaussian centres
pc = o3d.io.read_point_cloud(src)
xyz = np.asarray(pc.points)
if len(xyz) == 0:
    from plyfile import PlyData
    v = PlyData.read(src)['vertex']
    xyz = np.stack([v['x'], v['y'], v['z']], 1)
xyz = xyz * (1000.0 / sf)                      # training units -> mm (same frame as the mesh)
pc = o3d.geometry.PointCloud(); pc.points = o3d.utility.Vector3dVector(xyz)
CMP = "/mnt/c/Users/m352395/Downloads/mesh_compare"
o3d.io.write_point_cloud(CMP + "/3dgs_pretsdf_points.ply", pc)
e = np.asarray(pc.get_axis_aligned_bounding_box().get_extent())
print(f"PRE-TSDF (Gaussian cloud): {len(xyz)} points, extent(mm) {np.round(e,1)}")
# render front + 3/4 as a point cloud
OUT = "/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT, exist_ok=True)
ctr = pc.get_axis_aligned_bounding_box().get_center(); rad = np.linalg.norm(e) * 0.9
r = o3d.visualization.rendering.OffscreenRenderer(900, 900)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultUnlit"; mat.point_size = 2.0
mat.base_color = [0.15, 0.15, 0.18, 1.0]
r.scene.add_geometry("p", pc, mat); r.scene.set_background([1, 1, 1, 1])
for vn, d in {"front": (0, 0, 1), "threequarter": (0.7, 0.3, 0.7)}.items():
    d = np.asarray(d, float); d /= np.linalg.norm(d); eye = ctr + d * rad * 2.2
    r.setup_camera(50.0, ctr, eye, [0, 1, 0])
    o3d.io.write_image(f"{OUT}/3dgs_pretsdf_{vn}.png", r.render_to_image())
# report the AFTER mesh for comparison
am = "/home/m352395/3dgs_30k.ply"
if os.path.exists(am):
    m = o3d.io.read_triangle_mesh(am); em = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
    print(f"AFTER-TSDF (mesh): {len(m.vertices)} verts, extent(mm) {np.round(em,1)}")
print("wrote mesh_compare/3dgs_pretsdf_points.ply + previews")
PY
