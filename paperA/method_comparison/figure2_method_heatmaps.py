#!/usr/bin/env python
"""
Figure 2 -- qualitative surface comparison across methods on one specimen.

For each reconstruction method, computes the per-point surface error (frame
points vs CAD, facial points vs structured light -> each point scored against
its nearest reference) and renders a heat-map montage on a shared 0..vmax mm
scale, plus a colored error point cloud (.ply) per method for 3D viewing.

Headless-safe: uses an orthographic 2D projection (matplotlib) for the montage
rather than fragile offscreen 3D rendering.

Data layout:
  <data>/<specimen>/methods/{raw_lidar,3dgs,sugar,2dgs,structured_light}.ply
  <data>/<specimen>/reference/cad_frame.ply, reference/structured_light.ply
  <data>/<specimen>/input.png            (optional -- shown as the input column)

Usage:
  python figure2_method_heatmaps.py --data EXPDATA --specimen cad01 --out results/
  python figure2_method_heatmaps.py --selftest
"""
import argparse
import tempfile
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))
import eval_common as ec
import report_util as ru

VIEWS = {'front': (0, 1), 'side': (2, 1), 'top': (0, 2)}


def per_point_error(recon_path, cad_mesh, sl_mesh, sample=120_000):
    pts = ec.as_points(recon_path, sample)
    ref_pts = np.vstack([ec.as_points(cad_mesh, sample // 2),
                         ec.as_points(sl_mesh, sample // 2)])
    pts = ec.apply_T(pts, ec.rigid_align(pts, ref_pts))
    d = np.minimum(ec.point_to_mesh_mm(pts, cad_mesh),
                   ec.point_to_mesh_mm(pts, sl_mesh))
    return pts, d


def run(data, specimen, out, vmax=5.0, view='front'):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    d = Path(data) / specimen
    cad = ec.load_mesh(d / 'reference' / 'cad_frame.ply')
    sl = ec.load_mesh(d / 'reference' / 'structured_light.ply')
    methods = [(k, lab) for k, lab in ec.METHODS]
    has_input = (d / 'input.png').exists()
    ncol = len(methods) + (1 if has_input else 0)
    ax_i, ay_i = VIEWS[view]

    fig, axes = plt.subplots(1, ncol, figsize=(2.5 * ncol, 3.0))
    if ncol == 1:
        axes = [axes]
    col = 0
    if has_input:
        axes[col].imshow(plt.imread(str(d / 'input.png'))); axes[col].set_title('Input RGB')
        axes[col].axis('off'); col += 1
    sc = None
    for key, label in methods:
        mp = d / 'methods' / f'{key}.ply'
        ax = axes[col]; col += 1
        ax.set_title(label, fontsize=9); ax.axis('off'); ax.set_aspect('equal')
        if not mp.exists():
            ax.text(0.5, 0.5, 'missing', ha='center', va='center'); continue
        pts, err = per_point_error(mp, cad, sl)
        sc = ax.scatter(pts[:, ax_i], pts[:, ay_i], c=err, cmap='turbo',
                        vmin=0, vmax=vmax, s=1, linewidths=0)
        ax.invert_yaxis()
        ec.save_error_heatmap_ply(pts, err, out / f'fig2_{specimen}_{key}_heat.ply', vmax)
    if sc is not None:
        cbar = fig.colorbar(sc, ax=axes, fraction=0.025, pad=0.01)
        cbar.set_label('surface error (mm)')
    fig.suptitle(f'Figure 2 -- method comparison ({specimen}); per-point error, 0-{vmax:g} mm')
    png = out / f'figure2_method_heatmaps_{specimen}.png'
    fig.savefig(png, dpi=160, bbox_inches='tight'); plt.close(fig)
    print('Wrote', png, 'and per-method *_heat.ply')
    return png


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data'); ap.add_argument('--specimen')
    ap.add_argument('--out', default='results'); ap.add_argument('--vmax', type=float, default=5.0)
    ap.add_argument('--view', choices=list(VIEWS), default='front')
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='f2_'))
        ru.make_synthetic_dataset(tmp, specimens=('cad01',))
        run(tmp, 'cad01', tmp / 'results', a.vmax, a.view)
        print('\nSELFTEST OK.')
        return
    if not (a.data and a.specimen):
        ap.error('--data and --specimen required (or use --selftest)')
    run(a.data, a.specimen, a.out, a.vmax, a.view)


if __name__ == '__main__':
    main()
