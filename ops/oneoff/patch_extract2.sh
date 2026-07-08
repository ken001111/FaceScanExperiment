source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/svraster_cuda_lib"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
python - <<'PY'
from pathlib import Path
OLD = ("    # Formula of voxel size: scene_extent * pow(2, -L)\n"
       "    return torch.ldexp(scene_extent, -octlevel)")
NEW = ("    # Formula of voxel size: scene_extent * pow(2, -L)\n"
       "    if torch.is_tensor(octlevel) and torch.is_tensor(scene_extent) and octlevel.device != scene_extent.device:\n"
       "        octlevel = octlevel.to(scene_extent.device)   # torch>=2 same-device requirement\n"
       "    return torch.ldexp(scene_extent, -octlevel)")
for repo in ("~/svraster", "~/geosvr"):
    p = Path(repo).expanduser() / "src/utils/octree_utils.py"
    if not p.exists():
        print(f"missing {p}"); continue
    s = p.read_text()
    if "same-device requirement" in s:
        print(f"already patched {p}")
    elif OLD in s:
        p.write_text(s.replace(OLD, NEW)); print(f"patched {p}")
    else:
        print(f"PATTERN NOT FOUND in {p}")
PY
echo "=== extraction on the trained model ==="
cd ~/svraster
M=~/FaceScan/output/svraster_457
python extract_mesh.py "$M" --final_lv 10 --bbox_scale 1.0 > "$M.mesh2.log" 2>&1 \
  || { echo EXTRACT_FAILED; tail -15 "$M.mesh2.log"; exit 1; }
MESH=$(find "$M/mesh" -name '*.ply' 2>/dev/null | head -1)
echo "mesh: $MESH"
[ -n "$MESH" ] || { echo NO_MESH; ls -R "$M/mesh" 2>/dev/null; exit 1; }
python - "$MESH" <<'PY'
import sys, numpy as np, open3d as o3d, os
m = o3d.io.read_triangle_mesh(sys.argv[1])
c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
if len(nt):
    m.remove_triangles_by_mask(nt[tc] < max(int(0.01*nt.max()), 200)); m.remove_unreferenced_vertices()
m.scale(100.0, center=(0,0,0))    # scale_factor 10 -> mm
for a in ("vertex_colors","vertex_normals","triangle_normals"):
    setattr(m, a, o3d.utility.Vector3dVector())
o3d.io.write_triangle_mesh(os.path.expanduser("~/svraster_test.ply"), m, write_vertex_colors=False)
e = np.asarray(m.get_axis_aligned_bounding_box().get_extent())
print(f"svraster_test.ply: {len(m.vertices)} verts, extent(mm) {np.round(e,1)}")
PY
echo "PATCH_EXTRACT_DONE"
