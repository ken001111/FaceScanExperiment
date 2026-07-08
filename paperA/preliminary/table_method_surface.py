#!/usr/bin/env python
"""Method surface-agreement table (the face-region part of Table 2 that applies
when there is no localizer frame / CAD).

Scores each reconstruction against the reference proxy (here the 2DGS mesh, since
ken has no CT/CAD or structured-light scan): point-to-surface distance after
rigid ICP -- Mean / RMS / 95th / Hausdorff / %<1mm (mm).

  python table_method_surface.py --data EXPDATA --specimen ken --out results/
"""
import argparse
import os
import sys
from pathlib import Path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "common"))
import eval_common as ec
import report_util as ru


def run(data, specimen, out, ref_name='structured_light'):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    d = Path(data) / specimen
    ref_mesh = ec.load_mesh(d / 'reference' / f'{ref_name}.ply')
    headers = ['Method', 'Mean (mm)', 'RMS (mm)', '95th (mm)', 'Hausdorff (mm)', '%<1mm']
    rows = []
    for key, label in ec.METHODS:
        mp = d / 'methods' / f'{key}.ply'
        if not mp.exists():
            continue
        met, _, _ = ec.evaluate(str(mp), ref_mesh, align=True)
        rows.append([label, f"{met['mean']:.2f}", f"{met['rms']:.2f}",
                     f"{met['p95']:.2f}", f"{met['hausdorff']:.1f}", f"{met['pct_under_1mm']:.1f}"])
    paths = ru.write_tables(headers, rows, out / 'table_method_surface',
                            caption='Method surface agreement vs the 2DGS reference proxy '
                                    '(ken has no CT/CAD or structured-light reference); '
                                    'point-to-surface distance after rigid ICP, mm.')
    print('Wrote:', ', '.join(p.name for p in paths))
    print(open(out / 'table_method_surface.md').read())


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', required=True); ap.add_argument('--specimen', required=True)
    ap.add_argument('--out', default='results'); ap.add_argument('--ref', default='structured_light')
    a = ap.parse_args()
    run(a.data, a.specimen, a.out, a.ref)
