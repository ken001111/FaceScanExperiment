source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
EXT=/mnt/c/Users/m352395/Downloads/paper_experiments/external
mkdir -p ~/gs_external
tr -d '\r' < "$EXT/run_3dgs_tsdf.sh" > ~/gs_external/run_3dgs_tsdf.sh
tr -d '\r' < "$EXT/mesh_3dgs_tsdf.py" > ~/gs_external/mesh_3dgs_tsdf.py
chmod +x ~/gs_external/run_3dgs_tsdf.sh
echo "=== 3DGS+TSDF full 30k iters (-r 2) on ken ==="
GS3D_ITERS=30000 GS3D_TRAIN_RES='-r 2' bash ~/gs_external/run_3dgs_tsdf.sh ~/FaceScan/work/face_scan ~/3dgs_30k.ply
echo "=== render shaded views ==="
python - <<'PY'
import open3d as o3d, numpy as np, os, shutil
m=o3d.io.read_triangle_mesh(os.path.expanduser("~/3dgs_30k.ply")); m.compute_vertex_normals()
e=np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"3dgs_30k: {len(m.vertices)} verts, extent {np.round(e,1)} diag {np.linalg.norm(e):.1f}")
OUT="/mnt/c/Users/m352395/Downloads/mesh_previews"; os.makedirs(OUT,exist_ok=True)
ctr=m.get_axis_aligned_bounding_box().get_center(); rad=np.linalg.norm(e)*0.9
r=o3d.visualization.rendering.OffscreenRenderer(900,900)
mat=o3d.visualization.rendering.MaterialRecord(); mat.shader="defaultLit"; mat.base_color=[0.75,0.75,0.78,1.0]
r.scene.add_geometry("m",m,mat); r.scene.set_background([1,1,1,1])
r.scene.scene.set_sun_light([0.3,-0.4,-0.6],[1,1,1],90000); r.scene.scene.enable_sun_light(True)
for vn,d in {"front":(0,0,1),"threequarter":(0.7,0.3,0.7),"left":(1,0,0)}.items():
    d=np.asarray(d,float); d/=np.linalg.norm(d); eye=ctr+d*rad*2.2
    r.setup_camera(50.0,ctr,eye,[0,1,0]); o3d.io.write_image(f"{OUT}/3dgs_30k_{vn}.png", r.render_to_image())
shutil.copy(os.path.expanduser("~/3dgs_30k.ply"), OUT+"/3dgs_tsdf_30k_mesh.ply")
print("rendered 3dgs_30k views + copied ply")
PY
echo "DONE_3DGS_30K"
