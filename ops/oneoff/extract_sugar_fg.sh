source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/sugar_dgr:${PYTHONPATH:-}"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/SuGaR
# drop the background shell -> foreground-only mesh (code handles empty bg)
sed -i 's/bg_bbox_factor = 4\./bg_bbox_factor = 0./' sugar_extractors/coarse_mesh.py
echo "bg factor now: $(grep -n 'bg_bbox_factor = ' sugar_extractors/coarse_mesh.py | head -1)"
rm -rf output/coarse_mesh/face_scan_fg
CKPT=$(ls output/coarse/face_scan/*/15000.pt | head -1)
python extract_mesh.py -s ~/FaceScan/work/face_scan -c output/vanilla_gs/face_scan/ -i 7000 \
  -m "$CKPT" -l 0.3 -o output/coarse_mesh/face_scan_fg --center_bbox True --eval False --gpu 0 \
  > output/extract_fg.log 2>&1
echo "extract_exit=$?"
grep -iE "Foreground points|Background points|foreground mesh only|Mesh saved" output/extract_fg.log | tail -6
ls output/coarse_mesh/face_scan_fg/
# scale fg mesh -> mm and render
python - <<'PY'
import open3d as o3d, numpy as np, glob, os
sf=float(open(os.path.expanduser("~/FaceScan/work/face_scan/scale_factor.txt")).read())
src=sorted(glob.glob(os.path.expanduser("~/SuGaR/output/coarse_mesh/face_scan_fg/sugarmesh_*decim1000000.ply")))[-1]
m=o3d.io.read_triangle_mesh(src)
c=m.cluster_connected_triangles(); tc,nt=np.asarray(c[0]),np.asarray(c[1])
m.remove_triangles_by_mask(tc!=int(np.argmax(nt))); m.remove_unreferenced_vertices()
m.scale(1000.0/sf,center=(0,0,0)); m.compute_vertex_normals()
o3d.io.write_triangle_mesh(os.path.expanduser("~/sugar_fg.ply"),m)
e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"SuGaR foreground mm: {len(m.vertices)} verts, extent {np.round(e,1)} diag {np.linalg.norm(e):.1f}")
# render front + 3/4
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT,exist_ok=True)
ctr=m.get_axis_aligned_bounding_box().get_center(); rad=np.linalg.norm(e)*0.9
r=o3d.visualization.rendering.OffscreenRenderer(900,900)
mat=o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m",m,mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
for vn,d in {"front":(0,0,1),"threequarter":(0.7,0.3,0.7),"left":(1,0,0)}.items():
    d=np.asarray(d,float); d/=np.linalg.norm(d); eye=ctr+d*rad*2.2
    r.setup_camera(50.0,ctr,eye,[0,1,0])
    o3d.io.write_image(f"{OUT}/sugar_fg_{vn}.png", r.render_to_image())
import shutil; shutil.copy(os.path.expanduser("~/sugar_fg.ply"), OUT+"/sugar_foreground_mesh.ply")
print("rendered sugar_fg views + copied ply")
PY
