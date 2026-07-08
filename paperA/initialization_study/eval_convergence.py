#!/usr/bin/env python
"""
Surface-RMS-vs-iteration convergence for a trained 2DGS model.

For each saved checkpoint iteration, renders + TSDF-meshes that iteration and
scores its surface RMS (mm) against a reference mesh, writing convergence.csv
(iter, rms_mm). Invoked by run_init_study.sh when REF_PLY + CONV_ITERS are set.

  python eval_convergence.py --model OUT --data DATA_ROOT --reference ref.ply \
         --iters 2000,5000,10000,20000 --out init/lidar/convergence.csv
"""
import argparse
import csv
import os
import subprocess
import sys
from pathlib import Path

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "common"))
import eval_common as ec

GS = os.path.expanduser('~/2d-gaussian-splatting')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--model', required=True)
    ap.add_argument('--data', required=True)
    ap.add_argument('--reference', required=True)
    ap.add_argument('--iters', required=True, help='comma-separated checkpoint iters')
    ap.add_argument('--render-res', default='-r 2')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    ref = ec.load_mesh(a.reference)
    iters = [int(x) for x in a.iters.split(',') if x.strip()]
    rows = []
    for it in iters:
        cmd = [sys.executable, f'{GS}/render.py', '-m', a.model, '--skip_test',
               '--iteration', str(it), '--depth_trunc', '5.0', '--sdf_trunc', '0.05',
               '--voxel_size', '0.01', '--num_cluster', '20'] + a.render_res.split()
        try:
            subprocess.run(cmd, cwd=GS, check=True, capture_output=True, timeout=1800)
        except Exception as e:
            print(f'iter {it}: render failed ({e})'); continue
        mesh = Path(a.model) / 'train' / f'ours_{it}' / 'fuse_post.ply'
        if not mesh.exists():
            print(f'iter {it}: no mesh'); continue
        try:
            m, _, _ = ec.evaluate(mesh, ref, align=True)
            rows.append((it, round(m['rms'], 4)))
            print(f'iter {it}: RMS {m["rms"]:.4f} mm')
        except Exception as e:
            print(f'iter {it}: eval failed ({e})')
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    with open(a.out, 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['iter', 'rms_mm']); w.writerows(rows)
    print(f'wrote {a.out} ({len(rows)} points)')


if __name__ == '__main__':
    main()
