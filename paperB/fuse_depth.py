#!/usr/bin/env python
"""Metric GeoSVR component 1: per-frame DAv2 <- LiDAR metric fusion.

For each frame, fit (s, t) in DISPARITY space (DAv2 outputs relative inverse
depth) against the measured LiDAR depth, confidence-weighted with
sigma-clipping, then write D_fused = 1/(s*dav2 + t) as uint16 millimetres.

Builds a sibling scene dir (<scene>_fused) that hard-links images/confidence
and rewrites transforms_*.json with depth_png -> depth_fused/*.png, so the
existing lidar-fork loader consumes fused depth unchanged.

Requires mono_priors/depthanythingv2 already generated (the mono arm does
this as a side effect; frames are named frame_XXXXX in both).
"""
import argparse, json, os, shutil
import numpy as np
import imageio.v2 as iio


def fit_disparity(dav2, lidar_m, conf, clips=3):
    """Weighted LSQ of s*dav2 + t ~ 1/lidar with sigma-clipping. Returns s,t,stats."""
    ok = (lidar_m > 0.1) & (lidar_m < 8.0) & np.isfinite(dav2)
    w = np.where(conf >= 2, 1.0, np.where(conf >= 1, 0.5, 0.1)) if conf is not None else np.ones_like(lidar_m)
    x, y, w = dav2[ok], 1.0 / lidar_m[ok], w[ok]
    if x.size < 200:
        return None
    for _ in range(clips):
        sw = w.sum()
        mx, my = (w * x).sum() / sw, (w * y).sum() / sw
        cov = (w * (x - mx) * (y - my)).sum()
        var = (w * (x - mx) ** 2).sum()
        if var < 1e-12:
            return None
        s = cov / var
        t = my - s * mx
        r = s * x + t - y
        sig = np.sqrt((w * r * r).sum() / sw) + 1e-12
        keep = np.abs(r) < 3 * sig
        x, y, w = x[keep], y[keep], w[keep]
        if x.size < 200:
            return None
    if s <= 0:  # disparity must scale positively; else DAv2 failed on this frame
        return None
    return s, t, dict(inliers=int(x.size), sigma_disp=float(sig))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene", help="adapted scene dir (with depth/, mono_priors/)")
    ap.add_argument("--out", default=None, help="default: <scene>_fused")
    args = ap.parse_args()

    src = args.scene.rstrip("/")
    out = args.out or src + "_fused"
    prior_root = f"{src}/mono_priors/depthanythingv2"
    os.makedirs(f"{out}/depth_fused", exist_ok=True)
    for d in ("images", "confidence", "depth"):
        os.makedirs(f"{out}/{d}", exist_ok=True)

    stats, n_fallback = {}, 0
    tf = json.load(open(f"{src}/transforms_train.json"))
    for fr in tf["frames"]:
        name = os.path.basename(fr["file_path"])          # frame_XXXXX
        if not os.path.isfile(f"{src}/depth/{name}.png"):
            stats[name] = dict(fallback=True, no_lidar=True)
            n_fallback += 1
            for sub in ("images", "confidence"):
                sp, dp = f"{src}/{sub}/{name}.png", f"{out}/{sub}/{name}.png"
                if os.path.isfile(sp) and not os.path.exists(dp):
                    os.link(sp, dp)
            continue
        lidar = iio.imread(f"{src}/depth/{name}.png").astype(np.float32) / 1000.0
        conf_p = f"{src}/confidence/{name}.png"
        conf = iio.imread(conf_p).astype(np.float32) if os.path.isfile(conf_p) else None
        idx = iio.imread(f"{prior_root}/{name}.png")
        codebook = np.load(f"{prior_root}/{name}.npy")
        dav2 = codebook[idx].astype(np.float64)
        if dav2.shape != lidar.shape:  # DAv2 runs at its own res; bring to LiDAR grid
            from PIL import Image
            dav2 = np.asarray(Image.fromarray(dav2.astype(np.float32)).resize(
                (lidar.shape[1], lidar.shape[0]), Image.BILINEAR), np.float64)

        fit = fit_disparity(dav2, lidar, conf)
        if fit is None:
            fused = lidar  # fallback: raw LiDAR (still metric, still masked by >0)
            n_fallback += 1
            stats[name] = dict(fallback=True)
        else:
            s, t, st = fit
            disp = s * dav2 + t
            fused = np.where(disp > 1e-3, 1.0 / np.maximum(disp, 1e-3), 0.0)
            fused = np.clip(fused, 0.0, 10.0)
            fused[lidar <= 0] = fused[lidar <= 0]  # keep dense even where LiDAR missed
            stats[name] = dict(s=float(s), t=float(t), **st)
        iio.imwrite(f"{out}/depth_fused/{name}.png",
                    np.round(fused * 1000.0).astype(np.uint16))
        # hard-link passthrough assets
        for sub in ("images", "confidence", "depth"):
            sp, dp = f"{src}/{sub}/{name}.png", f"{out}/{sub}/{name}.png"
            if os.path.isfile(sp) and not os.path.exists(dp):
                os.link(sp, dp)

    for tf_name in ("transforms_train.json", "transforms_test.json"):
        t = json.load(open(f"{src}/{tf_name}"))
        for fr in t["frames"]:
            fr["depth_png"] = fr["depth_png"].replace("depth/", "depth_fused/")
        json.dump(t, open(f"{out}/{tf_name}", "w"), indent=1)
    if os.path.isfile(f"{src}/points3d.ply") and not os.path.exists(f"{out}/points3d.ply"):
        os.link(f"{src}/points3d.ply", f"{out}/points3d.ply")

    json.dump(stats, open(f"{out}/fusion_stats.json", "w"), indent=1)
    ss = [v["s"] for v in stats.values() if "s" in v]
    print(f"fused {len(stats)} frames, {n_fallback} fallbacks; "
          f"s median={np.median(ss):.4f} iqr=({np.percentile(ss,25):.4f},{np.percentile(ss,75):.4f})")


if __name__ == "__main__":
    main()
