source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
echo "=== SuGaR status ==="
ls ~/SuGaR/output/coarse_mesh/face_scan/ 2>/dev/null && echo "COARSE_MESH_DONE" || echo "no coarse mesh yet"
grep -iE "Iteration: 1[45][0-9]{3}|sugarmesh|Mesh saved|Extract|Computing|marching|density|Traceback|Error" ~/SuGaR/output/sugar_rerun.log 2>/dev/null | tail -6
echo
echo "=== OC mesh connected-component analysis (to plan crop) ==="
python - <<'PY'
import open3d as o3d, numpy as np
f="/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped/photogrammetry/face_nn.ply"
m=o3d.io.read_triangle_mesh(f)
print("full:", len(m.vertices), "verts, extent", np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()),1))
import copy
m2=copy.deepcopy(m)
lab,cnt,_=m2.cluster_connected_triangles()
lab=np.asarray(lab); cnt=np.asarray(cnt)
print("num components:", len(cnt), " top sizes:", np.sort(cnt)[::-1][:5])
# keep largest
big=int(np.argmax(cnt))
m2.remove_triangles_by_mask(lab!=big); m2.remove_unreferenced_vertices()
v=np.asarray(m2.vertices)
print("largest comp:", len(v), "verts, extent", np.round(np.asarray(m2.get_axis_aligned_bounding_box().get_extent()),1))
print("centroid", np.round(v.mean(0),1), " median", np.round(np.median(v,0),1))
PY
