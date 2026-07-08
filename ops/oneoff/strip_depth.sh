#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import json, os
for root in ("~/FaceScan/work/dummy_head", "~/FaceScan/work/dummy_head_matte"):
    for tf in ("transforms_train.json", "transforms_test.json"):
        p = os.path.expanduser(f"{root}/{tf}")
        t = json.load(open(p))
        n = 0
        for fr in t.get("frames", []):
            if "depth_path" in fr:
                del fr["depth_path"]; n += 1
        json.dump(t, open(p, "w"), indent=2)
        print(p, "stripped", n)
PY
