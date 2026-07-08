#!/bin/bash
# Head crop + sky-color removal on a colored TSDF mesh.
# Usage: bash skin_crop.sh <mesh.ply> <out_prefix>
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
MESH="${1:-$HOME/FaceScan/output/_archive_meshes/geosvr_500/geosvr_500/mesh/tsdf/tsdf_fusion_post.ply}"
PFX="${2:-val2}"
python - "$MESH" "$PFX" <<'PY'
import sys, numpy as np, open3d as o3d, os
mesh_path, pfx = sys.argv[1], sys.argv[2]
m = o3d.io.read_triangle_mesh(mesh_path)
ctr = np.array([0.032, 0.335, 1.577])
v = np.asarray(m.vertices)
m.remove_vertices_by_mask(~(np.linalg.norm(v-ctr,axis=1) < 1.5))
col = np.asarray(m.vertex_colors)
r_, g_, b_ = col[:,0], col[:,1], col[:,2]
sky = (b_ > r_ + 0.06) & (b_ > 0.25)              # blue-dominant
bright = col.min(axis=1) > 0.72                    # white-ish clouds/roof
m.remove_vertices_by_mask(sky | bright)
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.02*nt.max()),500)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))
print("after sky removal:", len(m.vertices), "verts, extent(mm)",
      np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1))
out = os.path.expanduser(f"~/{pfx}_head.ply")
o3d.io.write_triangle_mesh(out, m)
m.compute_vertex_normals()
mc = m.get_axis_aligned_bounding_box().get_center()
rad = float(np.linalg.norm(np.asarray(m.get_axis_aligned_bounding_box().get_extent())))
r = o3d.visualization.rendering.OffscreenRenderer(800, 800)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"
for vn, dv in {"posx":(1,0,0),"negx":(-1,0,0),"posy":(0,1,0),"negy":(0,-1,0),"posz":(0,0,1),"negz":(0,0,-1)}.items():
    dv = np.asarray(dv,float); up = [0,1,0] if abs(dv[1])<0.9 else [0,0,1]
    r.setup_camera(50.0, mc, mc+dv*rad*1.7, up)
    o3d.io.write_image(f"{OUT}/{pfx}_{vn}.png", r.render_to_image())
print(pfx, "previews done ->", out)
PY
