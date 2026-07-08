"""
Specimen discovery, table writing (CSV / Markdown / LaTeX), and synthetic-data
generators used by the paper-experiment scripts for their --selftest mode.
"""
import csv
import json
import os
from pathlib import Path

import numpy as np
import open3d as o3d


# --------------------------------------------------------------------------- #
# Discovery
# --------------------------------------------------------------------------- #
def discover_specimens(data_root):
    """Return [(specimen_id, arm, dir), ...].

    Uses <data>/specimens.csv (columns: specimen, arm) if present; otherwise
    every immediate sub-directory is a cadaver specimen.
    """
    data_root = Path(data_root)
    csvp = data_root / 'specimens.csv'
    out = []
    if csvp.exists():
        with open(csvp) as f:
            for row in csv.DictReader(f):
                sid = row['specimen'].strip()
                out.append((sid, row.get('arm', 'cadaver').strip(), data_root / sid))
    else:
        for d in sorted(p for p in data_root.iterdir() if p.is_dir()):
            out.append((d.name, 'cadaver', d))
    return out


# --------------------------------------------------------------------------- #
# Table writers
# --------------------------------------------------------------------------- #
def write_tables(headers, rows, out_base, caption=''):
    """Write rows (list of lists) to {out_base}.csv/.md/.tex. Returns the paths."""
    out_base = Path(out_base)
    out_base.parent.mkdir(parents=True, exist_ok=True)
    # CSV
    with open(out_base.with_suffix('.csv'), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(headers)
        w.writerows(rows)
    # Markdown
    with open(out_base.with_suffix('.md'), 'w') as f:
        if caption:
            f.write(f'**{caption}**\n\n')
        f.write('| ' + ' | '.join(map(str, headers)) + ' |\n')
        f.write('|' + '|'.join(['---'] * len(headers)) + '|\n')
        for r in rows:
            f.write('| ' + ' | '.join(map(str, r)) + ' |\n')
    # LaTeX
    with open(out_base.with_suffix('.tex'), 'w') as f:
        f.write('\\begin{table}[t]\\centering\n')
        if caption:
            f.write('\\caption{' + caption + '}\n')
        f.write('\\begin{tabular}{' + 'l' + 'r' * (len(headers) - 1) + '}\n\\hline\n')
        f.write(' & '.join(str(h).replace('%', '\\%') for h in headers) + ' \\\\\n\\hline\n')
        for r in rows:
            f.write(' & '.join(str(c).replace('%', '\\%') for c in r) + ' \\\\\n')
        f.write('\\hline\n\\end{tabular}\n\\end{table}\n')
    return [out_base.with_suffix(e) for e in ('.csv', '.md', '.tex')]


def bold_md(s):
    return f'**{s}**'


# --------------------------------------------------------------------------- #
# Synthetic data (for --selftest only)
# --------------------------------------------------------------------------- #
def _noisy_sphere(radius=80.0, n=60, noise_mm=0.0, seed=0):
    """A subdivided icosphere (mm) with optional per-vertex normal noise."""
    m = o3d.geometry.TriangleMesh.create_sphere(radius=radius, resolution=n)
    if noise_mm > 0:
        rng = np.random.default_rng(seed)
        v = np.asarray(m.vertices)
        nrm = v / (np.linalg.norm(v, axis=1, keepdims=True) + 1e-9)
        v = v + nrm * rng.normal(0, noise_mm, size=(len(v), 1))
        m.vertices = o3d.utility.Vector3dVector(v)
    m.compute_vertex_normals()
    return m


def make_synthetic_dataset(root, specimens=('cad01', 'cad02'),
                           method_noise=None):
    """Create a tiny fake dataset matching the documented layout so the
    experiment scripts can be run end-to-end without real data.

    method_noise maps method -> surface noise (mm); lower = better method.
    """
    root = Path(root)
    method_noise = method_noise or {
        'raw_lidar': 1.8, '3dgs': 1.0,
        'sugar': 0.8, '2dgs': 0.5, 'structured_light': 0.3}
    with open(root / 'specimens.csv', 'w', newline='') as f:
        w = csv.writer(f); w.writerow(['specimen', 'arm'])
        for i, s in enumerate(specimens):
            w.writerow([s, 'cadaver' if i % 2 == 0 else 'patient'])
    for si, s in enumerate(specimens):
        d = root / s
        (d / 'methods').mkdir(parents=True, exist_ok=True)
        (d / 'reference').mkdir(parents=True, exist_ok=True)
        # references: clean spheres (CAD frame + structured-light face proxy)
        o3d.io.write_triangle_mesh(str(d / 'reference' / 'cad_frame.ply'),
                                   _noisy_sphere(80, noise_mm=0, seed=si))
        o3d.io.write_triangle_mesh(str(d / 'reference' / 'structured_light.ply'),
                                   _noisy_sphere(80, noise_mm=0.1, seed=si + 99))
        for mi, (m, nz) in enumerate(method_noise.items()):
            o3d.io.write_triangle_mesh(
                str(d / 'methods' / f'{m}.ply'),
                _noisy_sphere(80, noise_mm=nz, seed=si * 10 + mi))
    return root


def make_synthetic_init(root, specimen='cad01',
                        init_noise=None, iters=(2000, 5000, 7000, 10000)):
    """Fake init-study layout: per-init final mesh, init cloud, convergence.csv."""
    root = Path(root)
    init_noise = init_noise or {'sfm': 1.4, 'random': 1.1, 'lidar': 0.5}
    d = root / specimen
    (d / 'reference').mkdir(parents=True, exist_ok=True)
    o3d.io.write_triangle_mesh(str(d / 'reference' / 'cad_frame.ply'),
                               _noisy_sphere(80, noise_mm=0))
    o3d.io.write_triangle_mesh(str(d / 'reference' / 'structured_light.ply'),
                               _noisy_sphere(80, noise_mm=0.1, seed=7))
    for k, nz in init_noise.items():
        di = d / 'init' / k
        di.mkdir(parents=True, exist_ok=True)
        o3d.io.write_triangle_mesh(str(di / 'mesh.ply'), _noisy_sphere(80, noise_mm=nz, seed=hash(k) % 1000))
        # init cloud + a render placeholder
        pcd = _noisy_sphere(80, noise_mm=nz * 2).sample_points_uniformly(3000)
        o3d.io.write_point_cloud(str(di / 'init_cloud.ply'), pcd)
        # convergence: RMS decays toward nz, faster for lidar
        speed = {'sfm': 1.0, 'random': 1.2, 'lidar': 2.2}.get(k, 1.0)
        rows = [[it, round(nz + 3.0 * np.exp(-speed * it / 5000.0), 4)] for it in iters]
        with open(di / 'convergence.csv', 'w', newline='') as f:
            w = csv.writer(f); w.writerow(['iter', 'rms_mm']); w.writerows(rows)
        json.dump({'gaussians': int(120000 - 20000 * (k == 'lidar')),
                   'train_seconds': 1191 + 60 * (k == 'sfm')},
                  open(di / 'meta.json', 'w'))
    return root
