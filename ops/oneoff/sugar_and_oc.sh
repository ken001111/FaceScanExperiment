source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, numpy as np, copy, os, glob
# 1) scale SuGaR coarse mesh -> mm (largest comp, xyz-only), like finish_mesh
sf=float(open(os.path.expanduser("~/FaceScan/work/face_scan/scale_factor.txt")).read())
src=sorted(glob.glob(os.path.expanduser("~/SuGaR/output/coarse_mesh/face_scan/sugarmesh_*decim1000000.ply")))[-1]
m=o3d.io.read_triangle_mesh(src)
c=m.cluster_connected_triangles(); tc,nt=np.asarray(c[0]),np.asarray(c[1])
m.remove_triangles_by_mask(tc!=int(np.argmax(nt))); m.remove_unreferenced_vertices()
m.scale(1000.0/sf, center=(0,0,0))
m.vertex_colors=o3d.utility.Vector3dVector(); m.vertex_normals=o3d.utility.Vector3dVector(); m.triangle_normals=o3d.utility.Vector3dVector()
o3d.io.write_triangle_mesh(os.path.expanduser("~/sugar_test.ply"),m,write_vertex_colors=False,write_vertex_normals=False)
e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"SuGaR mm: {len(m.vertices)} verts, extent {np.round(e,1)} diag {np.linalg.norm(e):.1f}, centroid {np.round(np.asarray(m.vertices).mean(0),1)}")

# 2) where are our reconstructions centered? (compare frames)
twodgs=o3d.io.read_triangle_mesh(os.path.expanduser("~/FaceScan/results/Face_Mesh_MetricScale_exp_kentest_2dgs_nn.ply"))
print(f"2dgs centroid {np.round(np.asarray(twodgs.vertices).mean(0),1)} extent {np.round(np.asarray(twodgs.get_axis_aligned_bounding_box().get_extent()),1)}")

# 3) OC: largest comp + centroid (foreign frame?)
oc=o3d.io.read_triangle_mesh("/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped/photogrammetry/face_nn.ply")
v=np.asarray(oc.vertices)
print(f"OC full: {len(v)} verts, centroid {np.round(v.mean(0),1)}, extent {np.round(np.asarray(oc.get_axis_aligned_bounding_box().get_extent()),1)}")
oc2=copy.deepcopy(oc); c=oc2.cluster_connected_triangles(); tc,nt=np.asarray(c[0]),np.asarray(c[1])
oc2.remove_triangles_by_mask(tc!=int(np.argmax(nt))); oc2.remove_unreferenced_vertices()
print(f"OC largest comp: {len(oc2.vertices)} verts, extent {np.round(np.asarray(oc2.get_axis_aligned_bounding_box().get_extent()),1)}")
PY
