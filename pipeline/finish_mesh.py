import os, shutil, glob
import numpy as np
import open3d as o3d
from pathlib import Path

OUTPUT_PATH = os.environ['OUTPUT_PATH']
RUN_ID = os.environ['RUN_ID']
scale = 10.0
to_mm = 1000.0 / scale   # training-space (metres*10) -> millimetres

# --- cell 5: copy metric-scale mesh to results (find whatever iteration was saved) ---
_cands = sorted(glob.glob(str(Path(OUTPUT_PATH) / 'train' / 'ours_*' / 'fuse_post.ply')))
mesh_src = Path(_cands[-1]) if _cands else Path(OUTPUT_PATH) / 'train' / 'ours_20000' / 'fuse_post.ply'
if not mesh_src.exists():
    raise FileNotFoundError(f'No mesh at {mesh_src}')
results_dir = Path(os.path.expanduser('~/FaceScan/results'))
results_dir.mkdir(parents=True, exist_ok=True)
final = results_dir / f'Face_Mesh_MetricScale_{RUN_ID}.ply'
shutil.copy(mesh_src, final)
print('Saved metric mesh :', final)

# --- cell 6: largest component + rescale to mm + xyz-only PLY ---
dst = final.with_name(final.stem + '_nn.ply')
mesh = o3d.io.read_triangle_mesh(str(final))
print('loaded            :', len(mesh.vertices), 'verts,', len(mesh.triangles), 'tris')
c = mesh.cluster_connected_triangles()
mesh.remove_triangles_by_mask(np.asarray(c[0]) != np.argmax(c[1]))
mesh.remove_unreferenced_vertices()
print('largest piece     :', len(mesh.vertices), 'verts,', len(mesh.triangles), 'tris')
mesh.scale(to_mm, center=(0, 0, 0))
mesh.vertex_colors    = o3d.utility.Vector3dVector()
mesh.vertex_normals   = o3d.utility.Vector3dVector()
mesh.triangle_normals = o3d.utility.Vector3dVector()
o3d.io.write_triangle_mesh(str(dst), mesh, write_vertex_colors=False,
                           write_vertex_normals=False, write_ascii=False)
ext = mesh.get_axis_aligned_bounding_box().get_extent()
diag = float(np.linalg.norm(ext))
print('output extent (mm):', np.round(ext, 1), ' diagonal:', round(diag, 1))
print('scale sanity      :', 'OK head-sized' if 80 < diag < 1000 else 'CHECK')
print('saved NN mesh     :', dst)
