#!/usr/bin/env python
"""
Table 2 (Tier 1) -- head+frame surface.

Scores the head-plus-frame reconstruction by region: the FRAME region against
the CAD localizer (absolute truth) and the FACIAL region against the
structured-light reference. Reports Mean / RMS / 95th / %<1mm (mean +/- SD).

Rows: 2DGS vs CAD (frame), Structured light vs CAD (frame),
      2DGS vs SL (face), best-baseline vs SL (face).

Data layout:
  <data>/<specimen>/methods/{2dgs, structured_light, <baselines>}.ply  (full head+frame meshes)
  <data>/<specimen>/reference/cad_frame.ply, reference/structured_light.ply
Region split is by proximity to each reference (or supply regions/ labels).

Usage:
  python table2_tier1_surface.py --data EXPDATA --out results/
  python table2_tier1_surface.py --selftest
"""
import argparse
import sys
import tempfile
from pathlib import Path

import numpy as np

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))
import eval_common as ec
import stats_util as st
import report_util as ru

METRICS = [('mean', 'Mean'), ('rms', 'RMS'), ('p95', '95th'), ('pct_under_1mm', '%<1mm')]


def eval_region(recon_path, cad_mesh, sl_mesh, which, align=True, sample=200_000):
    pts = ec.as_points(recon_path, sample)
    frame_mask, face_mask = ec.assign_region(pts, cad_mesh, sl_mesh)
    if which == 'frame':
        sub, ref = pts[frame_mask], cad_mesh
    else:
        sub, ref = pts[face_mask], sl_mesh
    if sub.shape[0] < 50:
        return {k: np.nan for k, _ in METRICS}
    if align:
        sub = ec.apply_T(sub, ec.rigid_align(sub, ec.as_points(ref, sample)))
    return ec.surface_metrics(ec.point_to_mesh_mm(sub, ref))


def run(data, out, align=True):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    specimens = ru.discover_specimens(data)
    if not specimens:
        sys.exit(f'No specimens under {data}')
    baselines = [k for k in ec.CONSUMER_METHODS if k != '2dgs']

    # collect per-specimen metrics for each comparison
    comp = {'2dgs_frame': [], 'sl_frame': [], '2dgs_face': []}
    base_face = {b: [] for b in baselines}
    for sid, arm, d in specimens:
        cadp = d / 'reference' / 'cad_frame.ply'
        slp = d / 'reference' / 'structured_light.ply'
        if not (cadp.exists() and slp.exists()):
            print(f'  ! {sid}: missing CAD or SL reference -> skipped'); continue
        cad = ec.load_mesh(cadp); sl = ec.load_mesh(slp)
        m2 = d / 'methods' / '2dgs.ply'
        slm = d / 'methods' / 'structured_light.ply'
        comp['2dgs_frame'].append(eval_region(m2, cad, sl, 'frame', align) if m2.exists() else {})
        comp['2dgs_face'].append(eval_region(m2, cad, sl, 'face', align) if m2.exists() else {})
        comp['sl_frame'].append(eval_region(slm, cad, sl, 'frame', align) if slm.exists() else {})
        for b in baselines:
            bp = d / 'methods' / f'{b}.ply'
            base_face[b].append(eval_region(bp, cad, sl, 'face', align) if bp.exists() else {})

    def series(lst, mk):
        return [x.get(mk, np.nan) for x in lst]

    # best baseline = lowest mean facial RMS
    bmean = {b: np.nanmean(series(base_face[b], 'rms')) if base_face[b] else np.nan
             for b in baselines}
    bmean = {b: v for b, v in bmean.items() if not np.isnan(v)}
    best_b = min(bmean, key=bmean.get) if bmean else (baselines[0] if baselines else None)

    row_defs = [
        ('2DGS vs CAD (frame region)', comp['2dgs_frame']),
        ('Structured light vs CAD (frame region)', comp['sl_frame']),
        ('2DGS vs SL (facial region)', comp['2dgs_face']),
        (f'{dict(ec.METHODS).get(best_b, best_b)} vs SL (facial region)',
         base_face.get(best_b, [])),
    ]
    headers = ['Comparison (region)'] + [lab for _, lab in METRICS]
    rows = []
    for label, lst in row_defs:
        cells = [label]
        for mk, _ in METRICS:
            s = st.summarize(series(lst, mk))
            cells.append('--' if np.isnan(s['mean']) else f"{s['mean']:.2f} ± {s['sd']:.2f}")
        rows.append(cells)

    paths = ru.write_tables(headers, rows, out / 'table2_tier1_surface',
                            caption='Table 2. Tier 1 -- head+frame surface: frame region vs CAD '
                                    '(absolute), facial region vs structured light.')
    print('Wrote:', ', '.join(p.name for p in paths))
    print(open(out / 'table2_tier1_surface.md').read())
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data'); ap.add_argument('--out', default='results')
    ap.add_argument('--no-align', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='t2_'))
        ru.make_synthetic_dataset(tmp)
        run(tmp, tmp / 'results', align=True)
        print('\nSELFTEST OK.')
        return
    if not a.data:
        ap.error('--data is required (or use --selftest)')
    run(a.data, a.out, align=not a.no_align)


if __name__ == '__main__':
    main()
