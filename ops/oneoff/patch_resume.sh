#!/bin/bash
set -e
python3 - <<'PY'
import glob, os
hits = []
for p in glob.glob(os.path.expanduser("~/geosvr/**/*.py"), recursive=True):
    s = open(p).read()
    if "** (1 / remain_subdiv_times)" in s:
        s = s.replace("** (1 / remain_subdiv_times)",
                      "** (1 / max(remain_subdiv_times, 1))")
        open(p, "w").write(s)
        hits.append(p)
print("patched:", hits)
assert hits, "pattern not found"
PY
