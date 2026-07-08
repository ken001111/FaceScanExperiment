PY="$HOME/miniconda3/envs/facescan/bin/python"
cd /mnt/c/Users/m352395/Downloads/paper_experiments
echo "=== make_raw_lidar_mesh selftest ==="
"$PY" make_raw_lidar_mesh.py --selftest 2>&1 | tail -2
echo "=== syntax ==="
bash -n run_methods.sh && echo "run_methods.sh OK"
bash -n run_init_study.sh && echo "run_init_study.sh OK"
echo "=== real fast run_methods on ken (2dgs + raw_lidar) ==="
KEN="/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped"
ITERS=4000 FRAMES=120 TRAIN_RES='-r 2' RENDER_RES='-r 2' bash run_methods.sh "$KEN" kentest /tmp/EXPDATA 2>&1 | grep -vE 'Training progress|reconstruct radiance|export images|TSDF integration' | tail -25
echo "=== verify meshes ==="
"$PY" - <<'PYEOF'
import open3d as o3d, glob
for f in sorted(glob.glob('/tmp/EXPDATA/kentest/methods/*.ply')):
    m = o3d.io.read_triangle_mesh(f)
    print(f.split('/')[-1], '->', len(m.vertices), 'verts,', len(m.triangles), 'tris')
PYEOF
