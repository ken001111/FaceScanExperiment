#!/usr/bin/env python
"""ARKitScenes raw -> GeoSVR/nerf-format adapter (Paper B loader).

Reads: <scene>/lowres_wide (RGB pngs), lowres_depth (uint16 mm pngs),
       confidence (uint8 0-2 pngs), lowres_wide.traj, lowres_wide_intrinsics.
Writes: <out>/images, depth, confidence, transforms_train.json,
        transforms_test.json (every 8th), points3d.ply (back-projected LiDAR,
        the measured seed for LiDAR voxel init).

Frames are subsampled (--every) to keep training runs grind-sized.
Poses: traj rows are (ts, rx ry rz, tx ty tz) axis-angle world-from-camera?
ARKitScenes traj = timestamp, rotation(axis-angle) & translation of
camera-from-world per docs; convert to c2w OpenGL for the nerf loader.
"""
import argparse, json, os, glob
import numpy as np


def rotmat(axis_angle):
    theta = np.linalg.norm(axis_angle)
    if theta < 1e-12:
        return np.eye(3)
    a = axis_angle / theta
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(theta) * K + (1 - np.cos(theta)) * (K @ K)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("out")
    ap.add_argument("--every", type=int, default=5)
    args = ap.parse_args()

    import open3d as o3d
    from PIL import Image

    sc = args.scene.rstrip("/")
    vid = os.path.basename(sc)
    os.makedirs(args.out, exist_ok=True)
    for d in ("images", "depth", "confidence"):
        os.makedirs(f"{args.out}/{d}", exist_ok=True)

    # trajectory: ts rx ry rz tx ty tz  (camera-from-world / world axes per docs)
    traj = {}
    for line in open(f"{sc}/lowres_wide.traj"):
        v = [float(x) for x in line.split()]
        ts = round(v[0], 3)
        R = rotmat(np.array(v[1:4])); t = np.array(v[4:7])
        w2c = np.eye(4); w2c[:3, :3] = R; w2c[:3, 3] = t
        traj[ts] = np.linalg.inv(w2c)          # c2w, OpenCV axes

    flip = np.diag([1.0, -1.0, -1.0, 1.0])      # OpenCV -> OpenGL for nerf loader
    rgbs = sorted(glob.glob(f"{sc}/lowres_wide/*.png"))[:: args.every]
    frames, pts_all, cols_all = [], [], []
    K_cache = {}
    for i, rp in enumerate(rgbs):
        stem = os.path.splitext(os.path.basename(rp))[0]     # e.g. 47331963_3branch.244
        ts = round(float(stem.split("_")[-1]), 3)
        # nearest trajectory timestamp within 10ms
        cands = [k for k in (ts, round(ts - 0.001, 3), round(ts + 0.001, 3)) if k in traj]
        if not cands:
            keys = np.array(list(traj.keys()))
            j = np.argmin(np.abs(keys - ts))
            if abs(keys[j] - ts) > 0.05: continue
            cands = [keys[j]]
        c2w_cv = traj[cands[0]]
        # intrinsics file per frame (w h fx fy cx cy)
        ip = f"{sc}/lowres_wide_intrinsics/{stem}.pincam"
        if not os.path.isfile(ip):
            ip = sorted(glob.glob(f"{sc}/lowres_wide_intrinsics/*.pincam"))[0]
        w, h, fx, fy, cx, cy = [float(x) for x in open(ip).read().split()]
        name = f"frame_{i:05d}"
        os.link(rp, f"{args.out}/images/{name}.png") if not os.path.exists(f"{args.out}/images/{name}.png") else None
        dp = rp.replace("lowres_wide", "lowres_depth")
        cp = rp.replace("lowres_wide", "confidence")
        for src, dst in ((dp, f"{args.out}/depth/{name}.png"), (cp, f"{args.out}/confidence/{name}.png")):
            if os.path.isfile(src) and not os.path.exists(dst):
                os.link(src, dst)
        c2w_gl = c2w_cv @ flip
        import math
        frames.append(dict(file_path=f"images/{name}",
                           depth_png=f"depth/{name}.png",
                           confidence_png=f"confidence/{name}.png",
                           w=w, h=h, fl_x=fx, fl_y=fy, cx=cx, cy=cy,
                           camera_angle_x=2 * math.atan(w / (2 * fx)),
                           camera_angle_y=2 * math.atan(h / (2 * fy)),
                           cx_p=cx / w, cy_p=cy / h,
                           transform_matrix=c2w_gl.tolist()))
        # back-project depth (subsampled) into the measured seed cloud
        if os.path.isfile(dp) and i % 4 == 0:
            d = np.asarray(Image.open(dp), np.float32) / 1000.0       # m
            conf = np.asarray(Image.open(cp)) if os.path.isfile(cp) else None
            yy, xx = np.mgrid[0:d.shape[0], 0:d.shape[1]]
            ok = (d > 0.1) & (d < 5.0)
            if conf is not None: ok &= conf >= 2
            sx, sy = d.shape[1] / w, d.shape[0] / h
            X = (xx[ok] / sx - cx) / fx * d[ok]
            Y = (yy[ok] / sy - cy) / fy * d[ok]
            P = np.c_[X, Y, d[ok], np.ones(ok.sum())] @ c2w_cv.T
            pts_all.append(P[:, :3])
            im = np.asarray(Image.open(rp).convert("RGB"), np.float32) / 255.0
            iy = np.clip((yy[ok] / sy).astype(int), 0, im.shape[0]-1)
            ix = np.clip((xx[ok] / sx).astype(int), 0, im.shape[1]-1)
            cols_all.append(im[iy, ix])

    meta = dict(fl_x=frames[0]["fl_x"], fl_y=frames[0]["fl_y"],
                w=frames[0]["w"], h=frames[0]["h"])
    json.dump({**meta, "frames": frames}, open(f"{args.out}/transforms_train.json", "w"), indent=1)
    json.dump({**meta, "frames": frames[::8]}, open(f"{args.out}/transforms_test.json", "w"), indent=1)

    pts = np.concatenate(pts_all); cols = np.concatenate(cols_all)
    if len(pts) > 300_000:
        sel = np.random.default_rng(0).choice(len(pts), 300_000, replace=False)
        pts, cols = pts[sel], cols[sel]
    pc = o3d.geometry.PointCloud()
    pc.points = o3d.utility.Vector3dVector(pts)
    pc.colors = o3d.utility.Vector3dVector(cols)
    pc.normals = o3d.utility.Vector3dVector(np.zeros_like(pts))
    o3d.io.write_point_cloud(f"{args.out}/points3d.ply", pc)
    print(f"{vid}: {len(frames)} frames, seed cloud {len(pts)} pts -> {args.out}")


if __name__ == "__main__":
    main()
