#!/bin/bash
# Fetch ARKitScenes metadata, pick a small Validation scene with laser GT,
# and download its assets + laser point cloud.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
cd ~/ARKitScenes
python - <<'PY'
import pandas as pd, urllib.request, os
url = "https://docs-assets.developer.apple.com/ml-research/datasets/arkitscenes/v1/metadata.csv"
dst = os.path.expanduser("~/ARKitScenes/metadata.csv")
if not os.path.isfile(dst):
    urllib.request.urlretrieve(url, dst)
md = pd.read_csv(dst)
print("metadata columns:", list(md.columns))
splits = pd.read_csv(os.path.expanduser("~/ARKitScenes/raw/raw_train_val_splits.csv"))
val_ids = set(splits[splits["fold"] == "Validation"]["video_id"])
sel = md[md["video_id"].isin(val_ids) & (md["has_laser_scanner_point_clouds"] == True)]
print("Validation scenes with laser GT:", len(sel))
cols = [c for c in ("video_id","visit_id","number_of_frames","is_in_upsampling") if c in md.columns]
sel = sel.sort_values(cols[2] if len(cols) > 2 else "video_id")
print(sel[cols].head(6).to_string())
sel[cols].head(6).to_csv(os.path.expanduser("~/arkit_laser_val.csv"), index=False)
PY
echo PICK_DONE
