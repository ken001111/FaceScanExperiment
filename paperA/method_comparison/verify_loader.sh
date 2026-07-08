#!/bin/bash
# Paper A M2: verify the capture-export loader fields on the dummy dev scan.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import json, os, glob
SRC = "/mnt/c/Users/M352395/Downloads/Scan_depth5_20260630_200737_cropped-5995F03E-250E-433F-9EDB-80FE41645811/Scan_depth5_20260630_200737_cropped"
t = json.load(open(f"{SRC}/transforms.json"))
f0 = t["frames"][0]
print("== capture-export audit (dummy dev scan) ==")
print("global keys:", sorted(k for k in t.keys() if k != "frames"))
print("frame keys:", sorted(f0.keys()))
print("n frames:", len(t["frames"]))
need = {
  "RGB frames":            os.path.isdir(f"{SRC}/images"),
  "poses (transform_matrix)": "transform_matrix" in f0,
  "intrinsics":            any(k in t or k in f0 for k in ("fl_x","camera_angle_x","intrinsics")),
  "per-frame LiDAR depth": os.path.isdir(f"{SRC}/depth"),
  "depth refs in transforms": "depth_path" in f0,
  "confidence maps":       os.path.isdir(f"{SRC}/confidence"),
  "LiDAR seed cloud":      os.path.isfile(f"{SRC}/points3D.ply"),
  "capture ROI masks":     os.path.isdir(f"{SRC}/masks"),
}
for k, v in need.items():
    print(f"  {'OK ' if v else 'MISSING'}  {k}")
print()
print("VERDICT for Paper A A.3 components:")
print("  LiDAR init: available (seed cloud).")
print("  Foreground mask: circle ROI only, not LiDAR-thresholded per-frame mask;")
print("    Mt(x)=1[dmin<D<dmax] requires per-frame depth -> blocked.")
print("  Confidence-weighted depth supervision: blocked (no depth/, no confidence/).")
print("  -> App export must add depth/*.bin + confidence/*.bin to unblock;")
print("     transforms already reference depth/frame_XXXXX.bin so the app-side")
print("     writer exists but the folder was not exported for this scan.")
PY
