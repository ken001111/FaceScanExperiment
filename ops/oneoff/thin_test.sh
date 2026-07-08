#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import json, os
for root in ("~/FaceScan/work/dummy_head", "~/FaceScan/work/dummy_head_matte"):
    p = os.path.expanduser(f"{root}/transforms_test.json")
    t = json.load(open(p))
    n = len(t["frames"])
    t["frames"] = t["frames"][::8]
    json.dump(t, open(p, "w"), indent=2)
    print(root, f"test split: {n} -> {len(t['frames'])}")
PY
