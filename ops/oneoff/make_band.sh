#!/bin/bash
python3 - <<'PY'
import os
src = os.path.expanduser("~/geosvr/mesh_extract/tsdf_mesh.py")
dst = os.path.expanduser("~/geosvr/mesh_extract/tsdf_mesh_band.py")
s = open(src).read()
s = s.replace("ref_depth[ref_depth > args.max_depth] = 0",
              "ref_depth[ref_depth > args.max_depth] = 0\n"
              "            ref_depth[ref_depth < args.min_depth] = 0")
s = s.replace('parser.add_argument("--max_depth", default=5.0, type=float)',
              'parser.add_argument("--max_depth", default=5.0, type=float)\n'
              '    parser.add_argument("--min_depth", default=0.0, type=float)')
# Fuse MEDIAN depth (channel 2) instead of expected depth (channel 0): semi-
# transparent floaters barely shift the median but corrupt the expectation.
s = s.replace("depth = render_pkg['depth'][0].squeeze()",
              "depth = render_pkg['depth'][2].squeeze()")
assert "min_depth" in s and "render_pkg['depth'][2]" in s
open(dst, "w").write(s)
print("patched ->", dst)
PY
