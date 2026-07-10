#!/usr/bin/env python
"""Explanatory figures for the 41069021 five-arm ablation."""
import json, os
import numpy as np
import open3d as o3d
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.spatial import cKDTree

ABLATION = os.path.expanduser("~/FaceScan/paperB/ablation_41069021")
GT_PLY = os.path.expanduser("~/FaceScan/paperB/gt_cache/gt_41069021_highres.ply")
WORK = os.path.expanduser("~/FaceScan/work/arkit_41069021")
OUT = "/mnt/c/Users/M352395/Downloads/ablation_figs"
os.makedirs(OUT, exist_ok=True)
ARMS = ["nodepth", "mono", "lidar", "lidarconf", "fused"]
NICE = {"nodepth": "no depth", "mono": "mono (DAV2)", "lidar": "raw LiDAR",
        "lidarconf": "LiDAR+conf", "fused": "fused (ours)"}

t = json.load(open(f"{WORK}/transforms_train.json"))
traj = np.array([np.array(f["transform_matrix"])[:3, 3] for f in t["frames"]])

gt = o3d.io.read_point_cloud(GT_PLY)
g = np.asarray(gt.points)
in_range = cKDTree(traj).query(g, workers=-1)[0] < 3.0
g_eval = g[in_range]
g_eval_mm = g_eval * 1000.0

recs = {}
for arm in ARMS:
    m = o3d.io.read_triangle_mesh(f"{ABLATION}/{arm}/mesh/tsdf/tsdf_fusion_post.ply")
    recs[arm] = np.asarray(m.sample_points_uniformly(600_000).points)

# ---- fig 1: coverage overlays (top-down) ----
fig, axes = plt.subplots(1, 5, figsize=(26, 6))
for ax, arm in zip(axes, ARMS):
    r = recs[arm]
    ax.scatter(g[::25, 0], g[::25, 1], s=0.02, c="lightgray")
    ax.scatter(r[::6, 0], r[::6, 1], s=0.02, c="crimson", alpha=0.25)
    ax.plot(traj[:, 0], traj[:, 1], c="royalblue", lw=0.8)
    ax.set_title(NICE[arm], fontsize=14)
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
axes[0].set_ylabel("reconstruction (red) on laser GT (gray), camera path (blue)")
plt.tight_layout(); plt.savefig(f"{OUT}/fig1_coverage.png", dpi=100, bbox_inches="tight"); plt.close()

# ---- fig 2: completeness error heatmaps on GT ----
fig, axes = plt.subplots(1, 5, figsize=(27, 6))
for ax, arm in zip(axes, ARMS):
    d = cKDTree(recs[arm] * 1000.0).query(g_eval_mm[::8], workers=-1)[0]
    sc = ax.scatter(g_eval[::8, 0], g_eval[::8, 1], s=0.05,
                    c=np.clip(d, 0, 150), cmap="turbo", vmin=0, vmax=150)
    ax.set_title(f"{NICE[arm]}   med={np.median(d):.0f}mm", fontsize=14)
    ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
cb = fig.colorbar(sc, ax=axes, fraction=0.012, pad=0.01)
cb.set_label("GT→recon distance (mm, clipped 150)")
plt.savefig(f"{OUT}/fig2_comp_heatmap.png", dpi=100, bbox_inches="tight"); plt.close()

# ---- fig 3: metric bars ----
V6, RS = {}, {}
for arm in ARMS:
    V6[arm] = json.load(open(f"{ABLATION}/{arm}/eval_vs_laser_v6.json"))
    RS[arm] = json.load(open(f"{ABLATION}/{arm}/region_split.json"))
fig, axes = plt.subplots(1, 4, figsize=(20, 4.5))
colors = ["#9e9e9e", "#e07b39", "#2a7fb8", "#67a9cf", "#1b9e77"]
panels = [
    ("F-score @10mm (higher=better)", [V6[a]["fscore@10.0"] for a in ARMS]),
    ("F-score @20mm (higher=better)", [V6[a]["fscore@20.0"] for a in ARMS]),
    ("median completeness, well-observed region (mm)", [RS[a]["comp_good_med"] for a in ARMS]),
    ("support fraction (recon near GT; higher=less fog)", [V6[a]["support_frac"] for a in ARMS]),
]
for ax, (title, vals) in zip(axes, panels):
    b = ax.bar([NICE[a] for a in ARMS], vals, color=colors)
    ax.bar_label(b, fmt="%.2f" if max(vals) < 10 else "%.0f", fontsize=11)
    ax.set_title(title, fontsize=11.5)
    ax.tick_params(axis="x", rotation=20)
plt.tight_layout(); plt.savefig(f"{OUT}/fig3_metrics.png", dpi=110, bbox_inches="tight"); plt.close()

# ---- fig 4: mono shrinkage + fog (elevation view) ----
fig, axes = plt.subplots(1, 2, figsize=(17, 5.5))
for ax, arm in zip(axes, ["mono", "fused"]):
    r = recs[arm]
    ax.scatter(g[::25, 0], g[::25, 2], s=0.02, c="lightgray")
    ax.scatter(r[::6, 0], r[::6, 2], s=0.02, c=("#e07b39" if arm == "mono" else "#1b9e77"), alpha=0.25)
    ax.plot(traj[:, 0], traj[:, 2], c="royalblue", lw=0.8)
    ax.set_title(f"{NICE[arm]} — side elevation (x–z)", fontsize=13)
    ax.set_aspect("equal")
plt.tight_layout(); plt.savefig(f"{OUT}/fig4_elevation.png", dpi=110, bbox_inches="tight"); plt.close()
print("figs written to", OUT)
