#!/usr/bin/env python
"""Build a per-run report package from FaceScan training/render logs."""
import os, re, json, shutil, glob, datetime
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

RUN_ID      = os.environ['RUN_ID']
OUTPUT_PATH = os.environ['OUTPUT_PATH']
DATA_ROOT   = os.environ.get('DATA_ROOT', '')
HOME        = os.path.expanduser('~')
TRAIN_LOG   = f'{HOME}/FaceScan/train.log'
RENDER_LOG  = f'{HOME}/FaceScan/render.log'
RESULTS     = f'{HOME}/FaceScan/results'
SCALE       = 10.0

repdir = Path(f'{HOME}/FaceScan/reports/{RUN_ID}')
repdir.mkdir(parents=True, exist_ok=True)

def read_log(p):
    if not os.path.exists(p):
        return ''
    return open(p, 'rb').read().decode('utf-8', 'replace').replace('\r', '\n')

# ---- parse training progress lines ----
train = read_log(TRAIN_LOG)
pat = re.compile(
    r'(\d+)/(\d+) \[(\d+):(\d+)<[^,]*,\s*([\d.]+)it/s,\s*Loss=([\d.]+),'
    r'\s*distort=([\d.]+),\s*normal=([\d.]+),\s*Points=(\d+)\]')
rows = {}
total_iters = 0
for m in pat.finditer(train):
    it = int(m.group(1))
    total_iters = int(m.group(2))
    rows[it] = dict(
        iter=it,
        elapsed_s=int(m.group(3)) * 60 + int(m.group(4)),
        it_s=float(m.group(5)), loss=float(m.group(6)),
        distort=float(m.group(7)), normal=float(m.group(8)),
        points=int(m.group(9)))
series = [rows[k] for k in sorted(rows)]
init_pts = None
m = re.search(r'Number of points at initialisation :\s*(\d+)', train)
if m: init_pts = int(m.group(1))

train_time_s = series[-1]['elapsed_s'] if series else 0
final = series[-1] if series else {}
min_loss = min(series, key=lambda r: r['loss']) if series else {}
peak_pts = max((r['points'] for r in series), default=0)
avg_its  = (sum(r['it_s'] for r in series) / len(series)) if series else 0
complete = 'Training complete' in train

# ---- render time (sum of last elapsed per tqdm stage) ----
render = read_log(RENDER_LOG)
stages = {}
for m in re.finditer(r'([A-Za-z][A-Za-z ]+?):\s*\d+it \[(\d+):(\d+),', render):
    name = m.group(1).strip()
    sec = int(m.group(2)) * 60 + int(m.group(3))
    stages[name] = max(stages.get(name, 0), sec)
render_time_s = sum(stages.values())

# ---- GPU utilization (sampled into gpu.log during the run) ----
gpu_stats = {}
GPULOG = f'{HOME}/FaceScan/gpu.log'
if os.path.exists(GPULOG):
    utils, mems, powers = [], [], []
    for line in open(GPULOG):
        parts = [p.strip() for p in line.split(',')]
        if len(parts) >= 4:
            try:
                utils.append(float(parts[1])); mems.append(float(parts[2])); powers.append(float(parts[3]))
            except ValueError:
                pass
    if utils:
        active = [u for u in utils if u > 5]
        gpu_stats = dict(
            samples=len(utils), util_peak=max(utils),
            util_avg=round(sum(utils) / len(utils), 1),
            util_avg_active=round(sum(active) / len(active), 1) if active else 0,
            vram_peak_mib=int(max(mems)), vram_peak_pct=round(max(mems) / 16303 * 100, 1),
            power_peak_w=round(max(powers), 1), power_avg_w=round(sum(powers) / len(powers), 1))

# ---- config ----
cfg = {}
cfgp = Path(OUTPUT_PATH) / 'cfg_args'
if cfgp.exists():
    cfg['cfg_args'] = cfgp.read_text().strip()

# ---- mesh stats ----
mesh_stats = {}
nn = sorted(glob.glob(f'{RESULTS}/Face_Mesh_MetricScale_{RUN_ID}*_nn.ply'))
if nn:
    try:
        import numpy as np, open3d as o3d
        mesh = o3d.io.read_triangle_mesh(nn[0])
        ext = mesh.get_axis_aligned_bounding_box().get_extent()
        mesh_stats = dict(
            file=nn[0], size_mb=round(os.path.getsize(nn[0]) / 1e6, 1),
            vertices=len(mesh.vertices), triangles=len(mesh.triangles),
            extent_mm=[round(float(x), 1) for x in ext],
            diagonal_mm=round(float(np.linalg.norm(ext)), 1))
    except Exception as e:
        mesh_stats = {'error': str(e)}

# ---- input / output summary ----
prep = read_log(f'{HOME}/FaceScan/prep.log')
inp = {'scan': Path(DATA_ROOT).name or '(unknown)', 'data_dir': DATA_ROOT}
m = re.search(r'OK data ready \((\d+) frames\)', prep)
if m: inp['frames'] = int(m.group(1))
if not inp.get('frames'):
    try:
        tj = Path(DATA_ROOT) / 'transforms_train.json'
        if tj.exists():
            inp['frames'] = len(json.loads(tj.read_text()).get('frames', []))
    except Exception:
        pass
m = re.search(r'Loading:\s*(.+)', prep)
if m: inp['source_zip'] = m.group(1).strip()
m = re.search(r'Applied (\d+) depth masks', prep)
if m: inp['masks_applied'] = int(m.group(1))
m = re.search(r'WHITE_DIAG avg=([\d.]+)', prep)
if m: inp['avg_white_frac'] = float(m.group(1))
try:
    imgs0 = sorted(glob.glob(f'{DATA_ROOT}/images/*.png'))
    if imgs0:
        from PIL import Image as _Im
        try:
            from pillow_heif import register_heif_opener as _rh; _rh()
        except Exception:
            pass
        w, h = _Im.open(imgs0[0]).size
        inp['image_resolution'] = f'{w}x{h}'
except Exception:
    pass

metric_ply = f'{RESULTS}/Face_Mesh_MetricScale_{RUN_ID}.ply'
out = {'mesh_nn': mesh_stats, 'report_zip': f'FaceScan_Report_{RUN_ID}.zip'}
if os.path.exists(metric_ply):
    out['mesh_metric'] = {'file': metric_ply, 'size_mb': round(os.path.getsize(metric_ply) / 1e6, 1)}

# ---- GPU name ----
gpu = ''
try:
    import torch
    gpu = torch.cuda.get_device_name(0)
except Exception:
    pass

scan = Path(DATA_ROOT).name or '(unknown)'
now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')

# ---- plots ----
if series:
    its = [r['iter'] for r in series]
    plt.figure(figsize=(8, 4))
    plt.plot(its, [r['loss'] for r in series], lw=1)
    plt.xlabel('iteration'); plt.ylabel('loss'); plt.title(f'Loss — {RUN_ID}')
    plt.grid(alpha=.3); plt.tight_layout(); plt.savefig(repdir / 'loss_curve.png', dpi=120); plt.close()

    plt.figure(figsize=(8, 4))
    plt.plot(its, [r['points'] for r in series], lw=1, color='tab:green')
    plt.xlabel('iteration'); plt.ylabel('Gaussians'); plt.title(f'Point count — {RUN_ID}')
    plt.grid(alpha=.3); plt.tight_layout(); plt.savefig(repdir / 'points_curve.png', dpi=120); plt.close()

# ---- metrics.json ----
metrics = dict(
    run_id=RUN_ID, generated=now, scan=scan, gpu=gpu,
    output_path=OUTPUT_PATH, completed=complete,
    train=dict(
        iterations=f"{final.get('iter', 0)}/{total_iters}",
        train_time_s=train_time_s, train_time=f'{train_time_s//60}m{train_time_s%60}s',
        avg_it_s=round(avg_its, 2), init_points=init_pts,
        final_loss=final.get('loss'), min_loss=min_loss.get('loss'),
        min_loss_iter=min_loss.get('iter'),
        final_points=final.get('points'), peak_points=peak_pts),
    render=dict(render_time_s=render_time_s,
                render_time=f'{render_time_s//60}m{render_time_s%60}s',
                stages={k: f'{v//60}m{v%60}s' for k, v in stages.items()}),
    input=inp, output=out, gpu_usage=gpu_stats, mesh=mesh_stats, config=cfg,
    loss_by_iter=[[r['iter'], r['loss'], r['points']] for r in series])
(repdir / 'metrics.json').write_text(json.dumps(metrics, indent=2))

# ---- loss-by-iteration CSV ----
with open(repdir / 'loss_by_iteration.csv', 'w') as f:
    f.write('iteration,elapsed_s,it_per_s,loss,distort,normal,points\n')
    for r in series:
        f.write(f"{r['iter']},{r['elapsed_s']},{r['it_s']},{r['loss']},"
                f"{r['distort']},{r['normal']},{r['points']}\n")

# ---- milestones table ----
def milestones():
    if not series: return '(no data)'
    out, step = [], max(1, total_iters // 10)
    targets = list(range(0, total_iters + 1, step))
    for t in targets:
        r = min(series, key=lambda r: abs(r['iter'] - t))
        out.append(f"| {r['iter']:>5} | {r['loss']:.5f} | {r['points']:>8} | {r['elapsed_s']//60}m{r['elapsed_s']%60:02d}s |")
    return '\n'.join(out)

# ---- report.md ----
if gpu_stats:
    gpu_md = ("- Peak VRAM: **{vram_peak_mib} MiB** ({vram_peak_pct}% of 16 GB)\n"
              "- Utilization: avg **{util_avg}%** (avg-while-active {util_avg_active}%), peak **{util_peak:.0f}%**\n"
              "- Power: avg {power_avg_w} W, peak {power_peak_w} W  ({samples} samples @ 2s)").format(**gpu_stats)
else:
    gpu_md = "_(not logged for this run — use run_all.sh to capture GPU stats)_"

inp_md = (
    f"- **Scan:** `{inp.get('scan')}`  ({inp.get('frames','?')} frames)\n"
    f"- **Source zip:** `{inp.get('source_zip','(newest in raw_data)')}`\n"
    f"- **Image resolution:** {inp.get('image_resolution','?')}  (training caps width at ~1.6K)\n"
    f"- **Masking:** {inp.get('masks_applied','?')} masks applied, avg white-fraction {inp.get('avg_white_frac','?')}\n"
    f"- **Data dir:** `{inp.get('data_dir')}`")
_mm = mesh_stats if isinstance(mesh_stats, dict) else {}
_verts = _mm.get('vertices')
_nn_line = (f"{_mm.get('size_mb')} MB, {_verts:,} verts, {_mm.get('extent_mm')} mm, diag {_mm.get('diagonal_mm')} mm"
            if _verts else "(n/a)")
out_md = (
    f"- **Mesh (metric scale):** `{Path(metric_ply).name}`  ({out.get('mesh_metric',{}).get('size_mb','?')} MB)\n"
    f"- **Mesh (mm, NN format):** `{Path(_mm.get('file','')).name or '(n/a)'}`  ({_nn_line})\n"
    f"- **Report bundle:** `FaceScan_Report_{RUN_ID}.zip` (this package)")

# ---- file locations (WSL path + Windows path) ----
def _win(p):
    return '\\\\wsl.localhost\\Ubuntu' + str(p).replace('/', '\\')
DOWN = r'C:\Users\M352395\Downloads'
_nn_name = Path(_mm.get('file', '')).name
_src = inp.get('source_zip')
_loc = []
if _src:
    _loc.append(f"- **Input scan:** `{HOME}/FaceScan/raw_data/{_src}`\n  - Windows: `{_win(HOME + '/FaceScan/raw_data/' + _src)}`")
if _nn_name:
    _loc.append(f"- **Output mesh (mm, NN):** `{_mm.get('file')}`\n  - Windows: `{DOWN}\\{_nn_name}`  (also `{_win(_mm.get('file'))}`)")
_loc.append(f"- **Output mesh (metric):** `{metric_ply}`\n  - Windows: `{DOWN}\\{Path(metric_ply).name}`")
_loc.append(f"- **Trained model dir:** `{OUTPUT_PATH}`\n  - Windows: `{_win(OUTPUT_PATH)}`")
_loc.append(f"- **Report bundle:** `{DOWN}\\FaceScan_Report_{RUN_ID}.zip`")
loc_md = '\n'.join(_loc)

md = f"""# FaceScan Run Report — {RUN_ID}

**Generated:** {now}
**Scan:** `{scan}`
**GPU:** {gpu or '(n/a)'}
**Status:** {'✅ complete' if complete else '⚠️ incomplete'}

## 📥 Input
{inp_md}

## 📤 Output
{out_md}

## 📍 File locations
{loc_md}

## ⏱ Timing
| Phase | Time |
|---|---|
| Training | {train_time_s//60}m{train_time_s%60}s |
| Render + mesh | {render_time_s//60}m{render_time_s%60}s |
| **Total** | **{(train_time_s+render_time_s)//60}m{(train_time_s+render_time_s)%60}s** |

Avg training speed: **{avg_its:.1f} it/s**

## 🖥 GPU usage
{gpu_md}

## 📉 Training
- Iterations: **{final.get('iter',0)}/{total_iters}**
- Final loss: **{final.get('loss')}**  (min {min_loss.get('loss')} @ iter {min_loss.get('iter')})
- Points: init {init_pts} → final **{final.get('points')}** (peak {peak_pts})

### Loss / points by milestone
| iter | loss | points | elapsed |
|---:|---:|---:|---:|
{milestones()}

![loss](loss_curve.png)
![points](points_curve.png)

## 🧊 Mesh
{json.dumps(mesh_stats, indent=2)}

## ⚙️ Config
```
{cfg.get('cfg_args','(no cfg_args)')}
```

## 📦 Package contents
- `report.md` — this file
- `metrics.json` — all numbers, machine-readable
- `loss_by_iteration.csv` — full per-step loss/points
- `loss_curve.png`, `points_curve.png`
- `train.log` — raw training log
"""
(repdir / 'report.md').write_text(md)

# copy raw logs in
for src in (TRAIN_LOG, RENDER_LOG):
    if os.path.exists(src):
        shutil.copy(src, repdir / Path(src).name)

print('Report folder:', repdir)
print(f"  train {train_time_s//60}m{train_time_s%60}s | render {render_time_s//60}m{render_time_s%60}s | "
      f"final loss {final.get('loss')} | {final.get('points')} pts")
print('  files:', ', '.join(sorted(p.name for p in repdir.iterdir())))
