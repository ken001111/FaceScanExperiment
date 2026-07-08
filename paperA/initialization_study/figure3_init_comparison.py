#!/usr/bin/env python
"""
Figure 3 -- initialization determines surface quality.

Rows: SfM / random / LiDAR. Columns: init point cloud, rendered RGB, fused mesh,
per-point error heat-map (vs CAD/SL, shared 0..vmax mm). A bottom panel plots
surface-RMS vs iterations for the three seeds.

Headless-safe: orthographic 2D projections via matplotlib.

Data layout:
  <data>/<specimen>/init/<sfm|random|lidar>/{init_cloud.ply, mesh.ply, render.png, convergence.csv}
  <data>/<specimen>/reference/cad_frame.ply, reference/structured_light.ply

Usage:
  python figure3_init_comparison.py --data EXPDATA --specimen cad01 --out results/
  python figure3_init_comparison.py --selftest
"""
import argparse
import csv
import tempfile
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import gridspec

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))
import eval_common as ec
import report_util as ru

AX = (0, 1)  # front view (x, y)


def proj_scatter(ax, pts, c=None, vmax=5.0):
    ax.set_aspect('equal'); ax.axis('off')
    if pts is None or len(pts) == 0:
        ax.text(0.5, 0.5, 'missing', ha='center', va='center'); return None
    kw = dict(s=1, linewidths=0)
    if c is None:
        sc = ax.scatter(pts[:, AX[0]], pts[:, AX[1]], color='0.5', **kw)
    else:
        sc = ax.scatter(pts[:, AX[0]], pts[:, AX[1]], c=c, cmap='turbo', vmin=0, vmax=vmax, **kw)
    ax.invert_yaxis(); return sc


def per_point_error(mesh_path, cad, sl, sample=120_000):
    pts = ec.as_points(mesh_path, sample)
    ref = np.vstack([ec.as_points(cad, sample // 2), ec.as_points(sl, sample // 2)])
    pts = ec.apply_T(pts, ec.rigid_align(pts, ref))
    d = np.minimum(ec.point_to_mesh_mm(pts, cad), ec.point_to_mesh_mm(pts, sl))
    return pts, d


def load_pts(path):
    try:
        return ec.as_points(path, 6000)
    except Exception:
        return None


def run(data, specimen, out, vmax=5.0):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    d = Path(data) / specimen
    cad = ec.load_mesh(d / 'reference' / 'cad_frame.ply')
    sl = ec.load_mesh(d / 'reference' / 'structured_light.ply')
    inits = ec.INITS
    nr = len(inits)
    fig = plt.figure(figsize=(11, 2.6 * nr + 2.4))
    gs = gridspec.GridSpec(nr + 1, 4, height_ratios=[1] * nr + [1.1], hspace=0.25, wspace=0.05)
    col_titles = ['Init cloud', 'Rendered RGB', 'Fused mesh', 'Error vs CAD/SL']
    sc = None
    for r, (k, label) in enumerate(inits):
        di = d / 'init' / k
        a0 = fig.add_subplot(gs[r, 0]); proj_scatter(a0, load_pts(di / 'init_cloud.ply'))
        a0.set_ylabel(label, rotation=0, ha='right', va='center', fontsize=10)
        a1 = fig.add_subplot(gs[r, 1]); a1.axis('off')
        if (di / 'render.png').exists():
            a1.imshow(plt.imread(str(di / 'render.png')))
        else:
            a1.text(0.5, 0.5, '(no render)', ha='center', va='center', fontsize=8)
        a2 = fig.add_subplot(gs[r, 2]); proj_scatter(a2, load_pts(di / 'mesh.ply'))
        a3 = fig.add_subplot(gs[r, 3])
        if (di / 'mesh.ply').exists():
            pts, err = per_point_error(di / 'mesh.ply', cad, sl)
            sc = proj_scatter(a3, pts, c=err, vmax=vmax)
        else:
            proj_scatter(a3, None)
        if r == 0:                       # first-row axes carry the column titles
            for c, t in enumerate(col_titles):
                fig.axes[c].set_title(t, fontsize=10)

    # convergence curve (bottom row, spanning all columns)
    axc = fig.add_subplot(gs[nr, :])
    for k, label in inits:
        cc = d / 'init' / k / 'convergence.csv'
        if not cc.exists():
            continue
        it, rms = [], []
        for row in csv.DictReader(open(cc)):
            it.append(float(row['iter'])); rms.append(float(row['rms_mm']))
        axc.plot(it, rms, marker='o', label=label)
    axc.set_xlabel('iteration'); axc.set_ylabel('surface RMS (mm)')
    axc.set_title('Convergence'); axc.grid(alpha=.3); axc.legend(fontsize=8)
    if sc is not None:
        fig.colorbar(sc, ax=fig.axes[:nr * 4], fraction=0.012, pad=0.01).set_label('error (mm)')
    fig.suptitle(f'Figure 3 -- initialization determines surface quality ({specimen})')
    png = out / f'figure3_init_comparison_{specimen}.png'
    fig.savefig(png, dpi=160, bbox_inches='tight'); plt.close(fig)
    print('Wrote', png)
    return png


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data'); ap.add_argument('--specimen')
    ap.add_argument('--out', default='results'); ap.add_argument('--vmax', type=float, default=5.0)
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='f3_'))
        ru.make_synthetic_init(tmp, specimen='cad01')
        run(tmp, 'cad01', tmp / 'results', a.vmax)
        print('\nSELFTEST OK.')
        return
    if not (a.data and a.specimen):
        ap.error('--data and --specimen required (or use --selftest)')
    run(a.data, a.specimen, a.out, a.vmax)


if __name__ == '__main__':
    main()
