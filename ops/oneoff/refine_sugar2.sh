source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/sugar_dgr:${PYTHONPATH:-}"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/SuGaR
COARSE=$(ls output/coarse_mesh/face_scan/sugarmesh_*decim200000.ply | head -1)   # 200k mesh -> ~5x less VRAM
echo "[refine] coarse mesh: $COARSE"
rm -rf output/refined/face_scan output/refined_mesh/face_scan
echo "[refine] train_refined (7000 iters, fg cap 200k)..."
python train_refined.py -s ~/FaceScan/work/face_scan -c output/vanilla_gs/face_scan/ \
  -m "$COARSE" -o output/refined/face_scan -i 7000 -f 7000 -v 200000 \
  --eval False --white_background True --gpu 0 > output/refine.log 2>&1
echo "[refine] train_refined exit=$?"; tail -3 output/refine.log
REFINED=$(ls -t output/refined/face_scan/*/*.pt 2>/dev/null | head -1)
echo "[refine] refined checkpoint: $REFINED"
[ -n "$REFINED" ] || { echo "REFINE FAILED"; tail -25 output/refine.log; exit 1; }
echo "[refine] extracting refined mesh..."
python extract_refined_mesh_with_texture.py -s ~/FaceScan/work/face_scan -i 7000 \
  -c output/vanilla_gs/face_scan/ -m "$REFINED" -o output/refined_mesh/face_scan \
  --eval False -g 0 > output/extract_refined.log 2>&1
echo "[refine] extract exit=$?"; tail -4 output/extract_refined.log
ls -la output/refined_mesh/face_scan/
python - <<'PY'
import open3d as o3d, numpy as np, glob, os
sf=float(open(os.path.expanduser("~/FaceScan/work/face_scan/scale_factor.txt")).read())
objs=glob.glob(os.path.expanduser("~/SuGaR/output/refined_mesh/face_scan/*.obj"))
if not objs:
    print("no refined .obj produced"); raise SystemExit
CMP="/mnt/c/Users/m352395/Downloads/mesh_compare"; OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"
def save_xyz(mm,p):
    mm.vertex_colors=o3d.utility.Vector3dVector(); mm.triangle_normals=o3d.utility.Vector3dVector()
    o3d.io.write_triangle_mesh(p,mm,write_vertex_colors=False)
m=o3d.io.read_triangle_mesh(sorted(objs)[-1]); m.scale(1000.0/sf,center=(0,0,0)); m.compute_vertex_normals()
e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"SuGaR refined (full) mm: {len(m.vertices)} verts, extent {np.round(e,1)} diag {np.linalg.norm(e):.1f}")
save_xyz(o3d.io.read_triangle_mesh(sorted(objs)[-1]).scale(1000.0/sf,center=(0,0,0)), f"{CMP}/sugar_refined_full.ply")
ref=o3d.io.read_triangle_mesh(f"{CMP}/2dgs_ours.ply"); bb=ref.get_axis_aligned_bounding_box()
box=o3d.geometry.AxisAlignedBoundingBox(bb.min_bound-15, bb.max_bound+15)
mc=m.crop(box); save_xyz(mc, f"{CMP}/sugar_refined_cropped.ply")
print(f"refined cropped: {len(mc.vertices)} verts, extent {np.round(np.asarray(mc.get_axis_aligned_bounding_box().get_extent()),1)}")
mesh=m; ctr=mesh.get_axis_aligned_bounding_box().get_center(); rad=np.linalg.norm(mesh.get_axis_aligned_bounding_box().get_extent())*0.9
r=o3d.visualization.rendering.OffscreenRenderer(900,900)
mat=o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m",mesh,mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
for vn,d in {"front":(0,0,1),"threequarter":(0.7,0.3,0.7)}.items():
    d=np.asarray(d,float); d/=np.linalg.norm(d); eye=ctr+d*rad*2.2
    r.setup_camera(50.0,ctr,eye,[0,1,0]); o3d.io.write_image(f"{OUT}/sugar_refined_{vn}.png", r.render_to_image())
print("rendered sugar_refined views + added to mesh_compare")
PY
echo "DONE_REFINE_SUGAR2"
