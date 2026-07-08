source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
from pathlib import Path
OLD = ("    # Load sparse point\n"
       "    if points is not None:\n"
       "        key = f\"{image_name}.{extension}\"\n"
       "        sparse_pt = points[correspondent[key]]")
NEW = ("    # Load sparse point (needs BOTH the cloud and the correspondence map;\n"
       "    # a LiDAR seed cloud without points_correspondent.json has no sparse_pt)\n"
       "    if points is not None and correspondent is not None:\n"
       "        key = f\"{image_name}.{extension}\"\n"
       "        sparse_pt = points[correspondent[key]]")
p = Path("~/geosvr").expanduser() / "src/dataloader/reader_nerf_dataset.py"
s = p.read_text()
if "needs BOTH the cloud" in s:
    print(f"  already patched {p}")
elif OLD in s:
    p.write_text(s.replace(OLD, NEW)); print(f"  patched {p}")
else:
    print(f"  PATTERN NOT FOUND in {p}")
PY
