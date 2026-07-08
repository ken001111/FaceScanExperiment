source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
from pathlib import Path
OLD = ("    positions = np.vstack([vertices['x'], vertices['y'], vertices['z']]).T\n"
       "    colors = np.vstack([vertices['red'], vertices['green'], vertices['blue']]).T / 255.0\n"
       "    normals = np.vstack([vertices['nx'], vertices['ny'], vertices['nz']]).T\n"
       "    return positions, colors, normals")
NEW = ("    positions = np.vstack([vertices['x'], vertices['y'], vertices['z']]).T\n"
       "    names = vertices.data.dtype.names\n"
       "    if 'red' in names:\n"
       "        colors = np.vstack([vertices['red'], vertices['green'], vertices['blue']]).T / 255.0\n"
       "    else:\n"
       "        colors = np.full_like(positions, 0.5)   # tolerate color-less seed clouds\n"
       "    if 'nx' in names:\n"
       "        normals = np.vstack([vertices['nx'], vertices['ny'], vertices['nz']]).T\n"
       "    else:\n"
       "        normals = np.zeros_like(positions)      # tolerate normal-less seed clouds (LiDAR)\n"
       "    return positions, colors, normals")
for repo in ("~/geosvr", "~/svraster"):
    p = Path(repo).expanduser() / "src/dataloader/colmap_loader.py"
    if not p.exists():
        print(f"  (no colmap_loader in {repo})"); continue
    s = p.read_text()
    if "tolerate normal-less seed clouds" in s:
        print(f"  already patched {p}")
    elif OLD in s:
        p.write_text(s.replace(OLD, NEW)); print(f"  patched {p}")
    else:
        print(f"  PATTERN NOT FOUND in {p}")
PY
