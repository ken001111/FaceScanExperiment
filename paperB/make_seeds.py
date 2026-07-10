#!/usr/bin/env python
"""Back-project a workdir's (fused) depth maps into a world-frame seed cloud
for GeoSVR's seeded voxel init (cfg.init.init_mode=seeded).

Component 3 of the Metric GeoSVR pipeline: D_fused -> world points; the fork
Morton-encodes them at the init level and allocates the octree only there.

Usage: python make_seeds.py <workdir> [--out seeds.npy] [--frame_stride 3]
       [--px_step 2] [--voxel 0.03] [--conv opengl]
"""
import argparse, json, os
import numpy as np
import imageio.v2 as iio

ap = argparse.ArgumentParser()
ap.add_argument("workdir")
ap.add_argument("--out", default=None, help="default: <workdir>/seeds.npy")
ap.add_argument("--frame_stride", type=int, default=3)
ap.add_argument("--px_step", type=int, default=2)
ap.add_argument("--voxel", type=float, default=0.03, help="dedupe voxel (m)")
ap.add_argument("--zmin", type=float, default=0.05)
ap.add_argument("--zmax", type=float, default=4.5)
ap.add_argument("--conv", choices=["opengl", "opencv"], default="opengl",
                help="camera convention of transform_matrix (adapter=opengl)")
args = ap.parse_args()

wd = os.path.expanduser(args.workdir)
out = args.out or f"{wd}/seeds.npy"
t = json.load(open(f"{wd}/transforms_train.json"))
frames = t["frames"][::args.frame_stride]

chunks = []
for f in frames:
    d = iio.imread(os.path.join(wd, f["depth_png"])).astype(np.float32) / 1000.0
    fx, fy, cx, cy = f["fl_x"], f["fl_y"], f["cx"], f["cy"]
    v, u = np.mgrid[0:d.shape[0]:args.px_step, 0:d.shape[1]:args.px_step]
    z = d[::args.px_step, ::args.px_step]
    ok = (z > args.zmin) & (z < args.zmax)
    u, v, z = u[ok], v[ok], z[ok]
    x = (u - cx) / fx * z
    y = (v - cy) / fy * z
    if args.conv == "opengl":
        Pc = np.stack([x, -y, -z], 1)
    else:
        Pc = np.stack([x, y, z], 1)
    T = np.array(f["transform_matrix"])
    chunks.append((Pc @ T[:3, :3].T + T[:3, 3]).astype(np.float32))

pts = np.concatenate(chunks)
n_raw = len(pts)

# voxel-grid dedupe (pure numpy; keep one point per occupied cell)
ijk = np.floor(pts / args.voxel).astype(np.int64)
_, idx = np.unique(ijk, axis=0, return_index=True)
pts = pts[np.sort(idx)]

np.save(out, pts)
print(f"{n_raw} raw -> {len(pts)} seeds @ {args.voxel*100:.0f}cm "
      f"({len(frames)} frames, conv={args.conv}) -> {out}")
print("bbox min", pts.min(0).round(2), "max", pts.max(0).round(2))
