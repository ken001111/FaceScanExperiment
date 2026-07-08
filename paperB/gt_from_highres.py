#!/usr/bin/env python
"""Build laser-derived surface GT from ARKitScenes highres_depth frames.

highres_depth (1920x1440, uint16 mm) is the Faro laser mesh projected into
the wide camera per frame, pre-registered. lowres_wide is the same camera at
256x192, so K_highres = 7.5 * K_lowres_pincam, and poses come from
lowres_wide.traj. Back-projects all frames into the ARKit world frame ->
gt_cache/gt_<vid>_highres.ply (+ per-frame meta json for depth-map metrics).
"""
import glob, json, os, sys
import numpy as np
import imageio.v2 as iio
import open3d as o3d

VID = sys.argv[1] if len(sys.argv) > 1 else "41069021"
UPS = os.path.expanduser(f"~/FaceScan/data/arkit/upsampling/Validation/{VID}")
RAW = os.path.expanduser(f"~/FaceScan/data/arkit/raw/Validation/{VID}")
CACHE = os.path.expanduser("~/FaceScan/paperB/gt_cache")
SCALE = 1920 / 256.0   # highres wide / lowres wide


def rotmat(aa):
    th = np.linalg.norm(aa)
    if th < 1e-12: return np.eye(3)
    a = aa / th
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(th) * K + (1 - np.cos(th)) * (K @ K)


def main():
    traj = {}
    for line in open(f"{RAW}/lowres_wide.traj"):
        v = [float(x) for x in line.split()]
        w2c = np.eye(4); w2c[:3, :3] = rotmat(np.array(v[1:4])); w2c[:3, 3] = v[4:7]
        traj[round(v[0], 3)] = np.linalg.inv(w2c)          # c2w, OpenCV axes
    tkeys = np.array(sorted(traj.keys()))

    pin = sorted(glob.glob(f"{RAW}/lowres_wide_intrinsics/*.pincam"))
    pts_all, meta = [], {}
    for hp in sorted(glob.glob(f"{UPS}/highres_depth/*.png")):
        stem = os.path.splitext(os.path.basename(hp))[0]
        ts = round(float(stem.split("_")[-1]), 3)
        j = np.argmin(np.abs(tkeys - ts))
        if abs(tkeys[j] - ts) > 0.05:
            print(f"  {stem}: no pose within 50ms - skip"); continue
        c2w = traj[float(tkeys[j])]
        # nearest lowres pincam in time
        pts_ts = np.array([float(os.path.basename(p).rsplit("_", 1)[-1][:-7]) for p in pin])
        K_lo = [float(x) for x in open(pin[np.argmin(np.abs(pts_ts - ts))]).read().split()]
        _, _, fx, fy, cx, cy = K_lo
        fx, fy, cx, cy = fx * SCALE, fy * SCALE, cx * SCALE, cy * SCALE
        d = iio.imread(hp).astype(np.float32) / 1000.0
        yy, xx = np.mgrid[0:d.shape[0], 0:d.shape[1]]
        ok = (d > 0.1) & (d < 8.0)
        X = (xx[ok] - cx) / fx * d[ok]
        Y = (yy[ok] - cy) / fy * d[ok]
        P = np.c_[X, Y, d[ok], np.ones(ok.sum())] @ c2w.T
        pts_all.append(P[:, :3])
        meta[stem] = dict(ts=ts, fx=fx, fy=fy, cx=cx, cy=cy,
                          c2w=c2w.tolist(), valid_px=int(ok.sum()))
        print(f"  {stem}: {ok.sum()} px")

    pts = np.concatenate(pts_all)
    pc = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(pts))
    pc = pc.voxel_down_sample(0.004)
    os.makedirs(CACHE, exist_ok=True)
    out = f"{CACHE}/gt_{VID}_highres.ply"
    o3d.io.write_point_cloud(out, pc)
    json.dump(meta, open(f"{CACHE}/gt_{VID}_frames.json", "w"), indent=1)
    P = np.asarray(pc.points)
    print(f"GT: {len(P)} pts (4mm) bbox {P.min(0).round(2)} .. {P.max(0).round(2)} -> {out}")


if __name__ == "__main__":
    main()
