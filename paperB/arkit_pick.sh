#!/bin/bash
# Pick 2 Validation scenes WITH laser GT and start downloading scene 1.
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import pandas as pd
df = pd.read_csv("/home/m352395/ARKitScenes/raw/raw_train_val_splits.csv")
print("columns:", list(df.columns))
val = df[(df["fold"] == "Validation") & (df.get("has_laser_scanner_point_clouds", False) == True)]
print("validation scenes with laser GT:", len(val))
print(val.head(5).to_string())
val.head(5).to_csv("/home/m352395/arkit_laser_val.csv", index=False)
PY
