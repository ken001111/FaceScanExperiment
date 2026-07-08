source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
from pathlib import Path
OLD = ("    else:\n"
       "        pil_image = cam_info.image\n"
       "        mask = cam_info.mask\n")
NEW = ("    else:\n"
       "        pil_image = cam_info.image\n"
       "        mask = None   # provided mask handled by the dedicated block below\n")
p = Path("~/geosvr").expanduser() / "src/dataloader/data_pack.py"
s = p.read_text()
if "dedicated block below" in s:
    print(f"  already patched {p}")
elif OLD in s:
    p.write_text(s.replace(OLD, NEW, 1)); print(f"  patched {p}")
else:
    print(f"  PATTERN NOT FOUND in {p}")
PY
