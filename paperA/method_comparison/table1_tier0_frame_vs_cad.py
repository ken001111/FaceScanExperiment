#!/usr/bin/env python
"""
Table 1 (Tier 0) -- frame reconstruction vs CAD (absolute).

For every method, score the reconstructed FRAME mesh against the localizer CAD
and report Mean / RMS / 95th / %<1mm (mean +/- SD over specimens, with paired
Wilcoxon of 2DGS vs each consumer baseline, Holm-corrected).

Data layout (see paper_experiments/README.md):
  <data>/<specimen>/methods/{raw_lidar,3dgs,sugar,2dgs,structured_light}.ply
  <data>/<specimen>/reference/cad_frame.ply
Each methods/*.ply should be the frame-region reconstruction (crop to the frame).

Usage:
  python table1_tier0_frame_vs_cad.py --data /path/to/EXPDATA --out results/
  python table1_tier0_frame_vs_cad.py --selftest      # runs on synthetic data
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

METRICS = [('mean', 'Mean', False), ('rms', 'RMS', False),
           ('p95', '95th', False), ('pct_under_1mm', '%<1mm', True)]


def run(data, out, align=True):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    specimens = ru.discover_specimens(data)
    if not specimens:
        sys.exit(f'No specimens under {data}')
    # per_method[method][metric] = [value per specimen]
    per = {key: {m[0]: [] for m in METRICS} for key, _ in ec.METHODS}
    for sid, arm, d in specimens:
        cad = d / 'reference' / 'cad_frame.ply'
        if not cad.exists():
            print(f'  ! {sid}: missing reference/cad_frame.ply -> skipped'); continue
        for key, label in ec.METHODS:
            mp = d / 'methods' / f'{key}.ply'
            if not mp.exists():
                for m in METRICS: per[key][m[0]].append(np.nan)
                continue
            try:
                metrics, _, _ = ec.evaluate(mp, cad, align=align)
                for m in METRICS: per[key][m[0]].append(metrics[m[0]])
            except Exception as e:
                print(f'  ! {sid}/{key}: {e}')
                for m in METRICS: per[key][m[0]].append(np.nan)

    # aggregate
    agg = {key: {m[0]: st.summarize(per[key][m[0]]) for m in METRICS}
           for key, _ in ec.METHODS}
    # best consumer per metric (for bolding)
    best = {}
    for mk, _, higher in METRICS:
        vals = {k: agg[k][mk]['mean'] for k in ec.CONSUMER_METHODS}
        vals = {k: v for k, v in vals.items() if not np.isnan(v)}
        if vals:
            best[mk] = (max if higher else min)(vals, key=vals.get)

    headers = ['Method'] + [lab for _, lab, _ in METRICS]
    rows = []
    for key, label in ec.METHODS:
        cells = [label]
        for mk, _, _ in METRICS:
            s = agg[key][mk]
            txt = '--' if np.isnan(s['mean']) else f"{s['mean']:.2f} ± {s['sd']:.2f}"
            if key in ec.CONSUMER_METHODS and best.get(mk) == key:
                txt = ru.bold_md(txt)
            cells.append(txt)
        rows.append(cells)

    paths = ru.write_tables(headers, rows, out / 'table1_tier0_frame_vs_cad',
                            caption='Table 1. Tier 0 -- frame reconstruction vs CAD (absolute). '
                                    'Best consumer-device method in bold; structured light is a reference.')
    # stats: 2DGS vs each consumer baseline on RMS
    baselines = [k for k in ec.CONSUMER_METHODS if k != '2dgs']
    pv = st.paired_tests_vs_reference({k: per[k]['rms'] for k in ec.CONSUMER_METHODS},
                                      '2dgs', baselines)
    with open(out / 'table1_stats.txt', 'w') as f:
        f.write('Paired Wilcoxon (2DGS vs baseline), RMS, Holm-corrected:\n')
        for k in baselines:
            f.write(f'  2dgs vs {k:16s} p={pv[k]:.4g}\n')
    print('Wrote:', ', '.join(p.name for p in paths), '+ table1_stats.txt')
    print(open(out / 'table1_tier0_frame_vs_cad.md').read())
    return agg


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data', help='dataset root (see README data layout)')
    ap.add_argument('--out', default='results', help='output directory')
    ap.add_argument('--no-align', action='store_true',
                    help='skip ICP (use if recon is already in the CAD frame)')
    ap.add_argument('--selftest', action='store_true', help='run on synthetic data')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='t1_'))
        ru.make_synthetic_dataset(tmp)
        agg = run(tmp, tmp / 'results', align=True)
        assert agg['2dgs']['rms']['mean'] < agg['raw_lidar']['rms']['mean'], 'selftest sanity failed'
        print('\nSELFTEST OK (2DGS RMS < raw LiDAR RMS).')
        return
    if not a.data:
        ap.error('--data is required (or use --selftest)')
    run(a.data, a.out, align=not a.no_align)


if __name__ == '__main__':
    main()
