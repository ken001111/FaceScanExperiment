#!/usr/bin/env python
"""Gravity-aware 4DOF registration v3: ARKit world (y-up) -> Faro site (z-up).

Fixes over v2: multi-floor candidates, density-normalized correlation,
ICP-fitness-validated top-K candidates, and a synthetic self-test of the
transform composition. Writes gt_cache/T_arkit_to_site.txt on success.
"""
import os, sys
import numpy as np
import open3d as o3d
from scipy.signal import fftconvolve

CACHE = os.path.expanduser("~/FaceScan/paperB/gt_cache")
SCENE_DIR = os.path.expanduser("~/FaceScan/data/arkit/raw/Validation/47331963")
RES = 0.05
R_UP = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)   # y-up -> z-up


def floor_peaks(z, k=3, res=0.05, min_frac=0.25):
    h, e = np.histogram(z, bins=np.arange(z.min(), z.max() + res, res))
    idx = np.argsort(h)[::-1]
    out = []
    for i in idx:
        if h[i] < h[idx[0]] * min_frac: break
        c = e[i] + res / 2
        if all(abs(c - o) > 0.5 for o in out):
            out.append(float(c))
        if len(out) >= k: break
    return out


def occ(xy, bbox0, shape):
    ij = np.floor((xy - bbox0) / RES).astype(int)
    ok = (ij >= 0).all(1) & (ij < shape).all(1)
    m = np.zeros(shape, np.float32)
    m[ij[ok, 0], ij[ok, 1]] = 1.0
    return m


def compose_T(a, ctr, t2, dz):
    """world_zup point p: R2(p.xy - ctr) + t2, z + dz; input is ARKit y-up."""
    R2 = np.array([[np.cos(a), -np.sin(a), 0], [np.sin(a), np.cos(a), 0], [0, 0, 1]])
    T = np.eye(4)
    T[:3, :3] = R2
    T[:2, 3] = t2 - (R2[:2, :2] @ ctr)
    T[2, 3] = dz
    Tu = np.eye(4); Tu[:3, :3] = R_UP
    return T @ Tu


def candidates(P_zup, G, n_yaw=180, topk=3):
    """Yield (score, T) over floors x yaws x top-K shifts."""
    fz_src = floor_peaks(P_zup[:, 2], k=1)[0]
    g_bbox0 = G[:, :2].min(0) - 0.5
    g_shape = np.floor((G[:, :2].max(0) + 0.5 - g_bbox0) / RES).astype(int) + 1
    for fz_gt in floor_peaks(G[:, 2]):
        dz = fz_gt - fz_src
        Pz = P_zup.copy(); Pz[:, 2] += dz
        b = (Pz[:, 2] > fz_gt + 0.3) & (Pz[:, 2] < fz_gt + 2.2)
        print(f"    floor cand fz_gt={fz_gt:.2f} dz={dz:.2f} band_pts={int(b.sum())}")
        if b.sum() < 1000: continue
        gb = (G[:, 2] > fz_gt + 0.3) & (G[:, 2] < fz_gt + 2.2)
        gmap = occ(G[gb][:, :2], g_bbox0, g_shape)
        Pb = Pz[b]
        ctr = Pb[:, :2].mean(0)
        for yd in range(0, 360, 360 // n_yaw):
            a = np.radians(yd)
            R2 = np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
            xy = (Pb[:, :2] - ctr) @ R2.T
            s_bbox0 = xy.min(0) - 0.25
            s_shape = np.floor((xy.max(0) + 0.25 - s_bbox0) / RES).astype(int) + 1
            smap = occ(xy, s_bbox0, s_shape)
            overlap = fftconvolve(gmap, smap[::-1, ::-1], mode="full")
            local_n = fftconvolve(gmap, np.ones_like(smap), mode="full")
            score = overlap / np.sqrt(np.maximum(local_n, 1.0))
            flat = np.argsort(score, axis=None)[-topk:]
            for f in flat:
                k = np.unravel_index(f, score.shape)
                off = np.array(k) - (np.array(smap.shape) - 1)
                t2 = g_bbox0 + off * RES - s_bbox0
                yield float(score[k]), compose_T(a, ctr, t2, dz)


def fitness(src_ds, gt_ds, T, dist):
    ev = o3d.pipelines.registration.evaluate_registration(src_ds, gt_ds, dist, T)
    return ev.fitness


def self_test(S_yup):
    """Recover a known synthetic pose of the 3dod mesh itself."""
    a_true = np.radians(137.0)
    T_true = np.eye(4)
    T_true[:3, :3] = np.array([[np.cos(a_true), -np.sin(a_true), 0],
                               [np.sin(a_true), np.cos(a_true), 0], [0, 0, 1]])
    T_true[:3, 3] = [5.0, -9.0, 1.7]
    Tu = np.eye(4); Tu[:3, :3] = R_UP
    T_true = T_true @ Tu                      # y-up source -> synthetic z-up site
    G_syn = (np.c_[S_yup, np.ones(len(S_yup))] @ T_true.T)[:, :3]
    src = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(S_yup)).voxel_down_sample(0.1)
    tgt = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(G_syn)).voxel_down_sample(0.1)
    best = (-1.0, None)
    for s, T in sorted(candidates(S_yup @ R_UP.T, G_syn, n_yaw=90, topk=2), key=lambda x: -x[0])[:20]:
        f = fitness(src, tgt, T, 0.15)
        if f > best[0]: best = (f, T)
    print(f"  self-test best fitness={best[0]:.3f} (need >0.7)")
    return best[0] > 0.7


def main():
    gt = o3d.io.read_point_cloud(f"{CACHE}/gt_470831_5mm.ply").voxel_down_sample(RES)
    G = np.asarray(gt.points)
    mesh = o3d.io.read_triangle_mesh(f"{SCENE_DIR}/47331963_3dod_mesh.ply")
    src_pc = mesh.sample_points_uniformly(300_000)
    S_yup = np.asarray(src_pc.points)
    print("[self-test]")
    if not self_test(S_yup):
        print("SELF-TEST FAILED - composition bug, aborting"); sys.exit(2)

    P_zup = S_yup @ R_UP.T
    src_ds = src_pc.voxel_down_sample(0.10)
    gt_ds = gt.voxel_down_sample(0.10)

    print("[search]")
    cands = sorted(candidates(P_zup, G), key=lambda x: -x[0])[:50]
    print(f"  {len(cands)} candidates, top score {cands[0][0]:.1f}")
    best = (-1.0, None)
    for s, T in cands:
        f = fitness(src_ds, gt_ds, T, 0.15)
        if f > best[0]: best = (f, T)
    print(f"  best coarse fitness={best[0]:.3f}")
    T = best[1]
    for dist in (0.10, 0.04, 0.015):
        icp = o3d.pipelines.registration.registration_icp(
            src_pc, gt, dist, T,
            o3d.pipelines.registration.TransformationEstimationPointToPoint())
        T = icp.transformation
        print(f"  ICP@{dist*1000:.0f}mm fitness={icp.fitness:.3f} rmse={icp.inlier_rmse*1000:.1f}mm")
    if icp.fitness < 0.25:
        print("REGISTRATION LOW CONFIDENCE - not saving"); sys.exit(3)
    np.savetxt(f"{CACHE}/T_arkit_to_site.txt", T)
    print("saved T_arkit_to_site.txt")


if __name__ == "__main__":
    main()
