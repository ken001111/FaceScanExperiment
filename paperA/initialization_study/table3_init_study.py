#!/usr/bin/env python
"""
Table 3 -- initialization study for 2DGS (same poses, same scenes).

Compares SfM / random / LiDAR seeds on: final surface RMS, %<1mm, iterations to
convergence, Gaussian count, and training time.

Data layout:
  <data>/<specimen>/init/<sfm|random|lidar>/mesh.ply
  <data>/<specimen>/init/<...>/convergence.csv   (cols: iter, rms_mm)
  <data>/<specimen>/init/<...>/meta.json         ({"gaussians":N,"train_seconds":S})
  <data>/<specimen>/reference/cad_frame.ply, reference/structured_light.ply

Usage:
  python table3_init_study.py --data EXPDATA --out results/
  python table3_init_study.py --selftest
"""
import argparse
import csv
import json
import tempfile
from pathlib import Path

import numpy as np

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))
import eval_common as ec
import stats_util as st
import report_util as ru


def final_surface(mesh_path, cad, sl, sample=150_000):
    pts = ec.as_points(mesh_path, sample)
    ref = np.vstack([ec.as_points(cad, sample // 2), ec.as_points(sl, sample // 2)])
    pts = ec.apply_T(pts, ec.rigid_align(pts, ref))
    d = np.minimum(ec.point_to_mesh_mm(pts, cad), ec.point_to_mesh_mm(pts, sl))
    return ec.surface_metrics(d)


def iters_to_conv(conv_csv, tol=0.05):
    if not Path(conv_csv).exists():
        return np.nan
    it, rms = [], []
    with open(conv_csv) as f:
        for row in csv.DictReader(f):
            it.append(float(row['iter'])); rms.append(float(row['rms_mm']))
    if not rms:
        return np.nan
    final = rms[-1]
    for i, r in zip(it, rms):
        if r <= final * (1 + tol):
            return int(i)
    return int(it[-1])


def fmt_time(s):
    s = int(round(s)); return f'{s // 60}m{s % 60:02d}s'


def run(data, out):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    specimens = ru.discover_specimens(data)
    per = {k: {'rms': [], 'pct': [], 'iters': [], 'gauss': [], 'train': []}
           for k, _ in ec.INITS}
    for sid, arm, d in specimens:
        cadp, slp = d / 'reference' / 'cad_frame.ply', d / 'reference' / 'structured_light.ply'
        if not (cadp.exists() and slp.exists()):
            continue
        cad, sl = ec.load_mesh(cadp), ec.load_mesh(slp)
        for k, _ in ec.INITS:
            di = d / 'init' / k
            mp = di / 'mesh.ply'
            if mp.exists():
                m = final_surface(mp, cad, sl)
                per[k]['rms'].append(m['rms']); per[k]['pct'].append(m['pct_under_1mm'])
            per[k]['iters'].append(iters_to_conv(di / 'convergence.csv'))
            if (di / 'meta.json').exists():
                meta = json.load(open(di / 'meta.json'))
                per[k]['gauss'].append(meta.get('gaussians', np.nan))
                per[k]['train'].append(meta.get('train_seconds', np.nan))

    headers = ['Init', 'RMS (mm)', '%<1mm', 'Iters->conv', 'Gaussians', 'Train']
    rows = []
    for k, label in ec.INITS:
        rms = st.summarize(per[k]['rms']); pct = st.summarize(per[k]['pct'])
        it = np.nanmean(per[k]['iters']) if per[k]['iters'] else np.nan
        g = np.nanmean(per[k]['gauss']) if per[k]['gauss'] else np.nan
        tr = np.nanmean(per[k]['train']) if per[k]['train'] else np.nan
        rows.append([
            label,
            '--' if np.isnan(rms['mean']) else f"{rms['mean']:.2f} ± {rms['sd']:.2f}",
            '--' if np.isnan(pct['mean']) else f"{pct['mean']:.1f}",
            '--' if np.isnan(it) else f'{int(round(it))}',
            '--' if np.isnan(g) else f'{int(round(g)):,}',
            '--' if np.isnan(tr) else fmt_time(tr),
        ])
    paths = ru.write_tables(headers, rows, out / 'table3_init_study',
                            caption='Table 3. Initialization study for 2DGS '
                                    '(same poses, same scenes).')
    print('Wrote:', ', '.join(p.name for p in paths))
    print(open(out / 'table3_init_study.md').read())
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data'); ap.add_argument('--out', default='results')
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='t3_'))
        ru.make_synthetic_init(tmp)
        ru.discover_specimens  # noqa
        # write a specimens.csv so discovery finds cad01
        import csv as _csv
        with open(tmp / 'specimens.csv', 'w', newline='') as f:
            _csv.writer(f).writerows([['specimen', 'arm'], ['cad01', 'cadaver']])
        run(tmp, tmp / 'results')
        print('\nSELFTEST OK.')
        return
    if not a.data:
        ap.error('--data is required (or use --selftest)')
    run(a.data, a.out)


if __name__ == '__main__':
    main()
