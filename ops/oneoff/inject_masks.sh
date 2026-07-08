source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import json, os
from pathlib import Path
DR = Path(os.path.expanduser("~/FaceScan/work/face_scan"))
n_ok = n_missing = 0
for tj in ("transforms_train.json", "transforms_test.json"):
    p = DR / tj
    if not p.exists():
        continue
    meta = json.loads(p.read_text())
    for fr in meta.get("frames", []):
        stem = Path(fr["file_path"]).name          # e.g. frame_00000
        mp = f"masks/{stem}.heic.png"              # prep's mask naming
        if (DR / mp).exists():
            fr["mask_path"] = mp; n_ok += 1
        else:
            n_missing += 1
    p.write_text(json.dumps(meta, indent=1))
    print(f"updated {tj}")
print(f"mask_path set for {n_ok} frames ({n_missing} missing)")
PY
# refresh wrapper copies from the repo (render step + PYTHONPATH fix)
EXT=/mnt/c/Users/m352395/Downloads/facescan_work/paper_experiments/method_comparison/external
tr -d '\r' < "$EXT/run_geosvr.sh"   > ~/svr_wrap/run_geosvr.sh
tr -d '\r' < "$EXT/run_svraster.sh" > ~/svr_wrap/run_svraster.sh
chmod +x ~/svr_wrap/*.sh
echo "wrappers refreshed"
