source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
from pathlib import Path
OLD = ("    # Find the smallest radius with point density equal to pcd_density_rate of maximum\n"
       "    target_density = pcd_density_rate * density[max_idx]\n"
       "    target_idx = max_idx + np.where(density[max_idx:] < target_density)[0][0]\n")
NEW = ("    # Find the smallest radius with point density equal to pcd_density_rate of maximum.\n"
       "    # If the density never falls below the threshold (pre-cropped subject-only\n"
       "    # clouds, e.g. a LiDAR head scan), use the full cloud extent instead.\n"
       "    target_density = pcd_density_rate * density[max_idx]\n"
       "    below = np.where(density[max_idx:] < target_density)[0]\n"
       "    target_idx = max_idx + below[0] if len(below) else len(dist) - 1\n")
for repo in ("~/geosvr", "~/svraster"):
    p = Path(repo).expanduser() / "src/utils/bounding_utils.py"
    if not p.exists():
        print(f"  missing {p}"); continue
    s = p.read_text()
    if "pre-cropped subject-only" in s:
        print(f"  already patched {p}")
    elif OLD in s:
        p.write_text(s.replace(OLD, NEW)); print(f"  patched {p}")
    else:
        print(f"  PATTERN NOT FOUND in {p}")
PY
