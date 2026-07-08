source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, numpy as np, glob, os
sf=float(open(os.path.expanduser("~/FaceScan/work/face_scan/scale_factor.txt")).read())
f=sorted(glob.glob(os.path.expanduser("~/SuGaR/output/coarse_mesh/face_scan_fg/sugarmesh_*decim1000000.ply")))[-1]
m=o3d.io.read_triangle_mesh(f); m.scale(1000.0/sf,center=(0,0,0)); m.compute_vertex_normals()
e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"FULL foreground (all comps) mm: {len(m.vertices)} verts, extent {np.round(e,1)} diag {np.linalg.norm(e):.1f}")
c=m.cluster_connected_triangles(); nt=np.asarray(c[1])
print("num components:",len(nt)," top sizes:",np.sort(nt)[::-1][:8])
o3d.io.write_triangle_mesh(os.path.expanduser("~/sugar_fg_full.ply"),m)
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"
ctr=m.get_axis_aligned_bounding_box().get_center(); rad=np.linalg.norm(e)*0.9
r=o3d.visualization.rendering.OffscreenRenderer(900,900)
mat=o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m",m,mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
for vn,d in {"front":(0,0,1),"threequarter":(0.7,0.3,0.7)}.items():
    d=np.asarray(d,float); d/=np.linalg.norm(d); eye=ctr+d*rad*2.2
    r.setup_camera(50.0,ctr,eye,[0,1,0]); o3d.io.write_image(f"{OUT}/sugar_fgfull_{vn}.png", r.render_to_image())
print("rendered sugar_fgfull views")
PY
