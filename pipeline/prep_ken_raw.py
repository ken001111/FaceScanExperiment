import os, zipfile, json, shutil, glob
import numpy as np
from pathlib import Path
from PIL import Image
try:
    from pillow_heif import register_heif_opener
    register_heif_opener()
    print('HEIC support: registered')
except Exception as e:
    print('HEIC support: NOT available -', e)

LOCAL_RAW       = Path(os.path.expanduser('~/FaceScan/raw_data'))
EXTRACT_DIR     = Path(os.path.expanduser('~/FaceScan/work/face_scan_raw'))
FACE_DISTANCE_M = 0.4
SCALE_FACTOR    = 10.0

SCAN_DIR = os.environ.get('SCAN_DIR', '').strip()
if EXTRACT_DIR.exists():
    shutil.rmtree(EXTRACT_DIR)
EXTRACT_DIR.mkdir(parents=True)
if SCAN_DIR:
    print(f'Loading scan folder: {SCAN_DIR}')
    shutil.copytree(SCAN_DIR, EXTRACT_DIR, dirs_exist_ok=True)
else:
    LOCAL_RAW.mkdir(parents=True, exist_ok=True)
    zips = sorted(LOCAL_RAW.glob('*.zip'), key=lambda p: p.stat().st_mtime, reverse=True)
    if not zips:
        raise FileNotFoundError(f'No .zip in {LOCAL_RAW}.')
    latest = zips[0]
    print(f'Loading: {latest.name}')
    with zipfile.ZipFile(latest) as z:
        z.extractall(EXTRACT_DIR)

DATA_ROOT = EXTRACT_DIR
if not (DATA_ROOT/'transforms.json').exists() and not (DATA_ROOT/'transforms_train.json').exists():
    subs = [d for d in DATA_ROOT.iterdir() if d.is_dir() and d.name not in {'images', 'masks'}]
    if subs:
        DATA_ROOT = subs[0]
print(f'Data root: {DATA_ROOT}')

src_json   = DATA_ROOT/'transforms.json'
train_json = DATA_ROOT/'transforms_train.json'
if src_json.exists() and not train_json.exists():
    src_json.rename(train_json)

with open(train_json) as f:
    meta = json.load(f)
for frame in meta.get('frames', []):
    p = frame['file_path']
    for ext in ('.jpg', '.jpeg', '.png', '.heic', '.HEIC'):
        if p.lower().endswith(ext):
            p = p[:-len(ext)]
            break
    frame['file_path'] = p

# Optional frame subsampling for speed (FRAMES env var; 0/unset = keep all)
FRAMES = int(os.environ.get('FRAMES', '0') or '0')
_allf = meta.get('frames', [])
if FRAMES and 0 < FRAMES < len(_allf):
    _idx = sorted(set(int(round(i)) for i in np.linspace(0, len(_allf) - 1, FRAMES)))
    meta['frames'] = [_allf[i] for i in _idx]
    print(f'Subsampled frames: {len(_allf)} -> {len(meta["frames"])}')
_kept = {Path(f['file_path']).name for f in meta['frames']}

images_dir = DATA_ROOT/'images'
renamed = 0
for img in images_dir.iterdir():
    if img.suffix.lower() in {'.jpg', '.jpeg', '.heic'}:
        img.rename(img.with_suffix('.png'))
        renamed += 1
print(f'Renamed {renamed} images to .png')

# --- sharpness gate (paper: drop frames below 45% of the median Laplacian variance) ---
SHARP_FRAC = float(os.environ.get('SHARP_FRAC', '0.45') or '0')
if SHARP_FRAC > 0 and len(meta['frames']) > 8:
    def _sharp(g):
        lap = (-4.0*g + np.roll(g, 1, 0) + np.roll(g, -1, 0)
               + np.roll(g, 1, 1) + np.roll(g, -1, 1))
        return float(lap.var())
    _shp = {}
    for f in meta['frames']:
        ip = images_dir/f'{Path(f["file_path"]).name}.png'
        if ip.exists():
            _shp[Path(f['file_path']).name] = _sharp(
                np.asarray(Image.open(ip).convert('L'), dtype=np.float64))
    if _shp:
        _med = float(np.median(list(_shp.values())))
        _thr = SHARP_FRAC * _med
        _before = len(meta['frames'])
        meta['frames'] = [f for f in meta['frames']
                          if _shp.get(Path(f['file_path']).name, _med) >= _thr]
        _kept = {Path(f['file_path']).name for f in meta['frames']}
        print('Sharpness gate: dropped %d/%d blurry frames (< %.2f x median); %d kept'
              % (_before - len(meta['frames']), _before, SHARP_FRAC, len(meta['frames'])))

masks_dir = DATA_ROOT/'masks_DISABLED'
if masks_dir.exists():
    applied = 0
    for img_path in sorted(images_dir.glob('*.png')):
        if img_path.stem not in _kept:
            continue
        mask_path = masks_dir/f'{img_path.stem}.png'
        if not mask_path.exists():
            cands = sorted(masks_dir.glob(f'{img_path.stem}.*png'))
            if cands:
                mask_path = cands[0]
            else:
                continue
        img  = np.array(Image.open(img_path).convert('RGB'))
        mask = np.array(Image.open(mask_path).convert('L'))
        if mask.shape != img.shape[:2]:
            mask = np.array(Image.fromarray(mask).resize((img.shape[1], img.shape[0]), Image.NEAREST))
        img[mask < 128] = [255, 255, 255]
        Image.fromarray(img).save(img_path)
        applied += 1
    print(f'Applied {applied} depth masks (background -> white)')
else:
    print('No masks/ folder found; training on un-masked images')

M0 = np.array(meta['frames'][0]['transform_matrix'])
face_world = (M0 @ np.array([0., 0., -FACE_DISTANCE_M, 1.0]))[:3]
for frame in meta['frames']:
    M = np.array(frame['transform_matrix'])
    M[:3, 3] = (M[:3, 3] - face_world) * SCALE_FACTOR
    frame['transform_matrix'] = M.tolist()

# --- LiDAR-guided init (paper Eq. 3): seed surfels from the LiDAR cloud ---
# 2DGS loads `points3d.ply` (lowercase); the scan ships `points3D.ply` in metres.
# Transform it with the SAME recenter + scale as the cameras so it stays aligned.
# Without it, 2DGS falls back to a random seed (the paper's baseline, not its method).
LIDAR_INIT = os.environ.get('LIDAR_INIT', '1').strip().lower() not in ('0', 'false', 'no', '')
_lidar_src = DATA_ROOT/'points3D.ply'
_lidar_dst = DATA_ROOT/'points3d.ply'
if LIDAR_INIT and _lidar_src.exists():
    from plyfile import PlyData, PlyElement
    _pv = PlyData.read(str(_lidar_src))['vertex']
    _names = [pr.name for pr in _pv.properties]
    _pts = np.c_[_pv['x'], _pv['y'], _pv['z']].astype(np.float64)
    _pts = (_pts - face_world) * SCALE_FACTOR
    if all(c in _names for c in ('red', 'green', 'blue')):
        _rgb = np.c_[_pv['red'], _pv['green'], _pv['blue']].astype(np.uint8)
    else:
        _rgb = np.full((_pts.shape[0], 3), 128, np.uint8)
    if _pts.shape[0] > 150000:                      # paper downsamples to ~100k
        _sel = np.random.default_rng(0).choice(_pts.shape[0], 100000, replace=False)
        _pts, _rgb = _pts[_sel], _rgb[_sel]
    _dt = [('x','f4'),('y','f4'),('z','f4'),('nx','f4'),('ny','f4'),('nz','f4'),
           ('red','u1'),('green','u1'),('blue','u1')]
    _el = np.zeros(_pts.shape[0], dtype=_dt)
    _el['x'], _el['y'], _el['z'] = _pts[:, 0], _pts[:, 1], _pts[:, 2]
    _el['red'], _el['green'], _el['blue'] = _rgb[:, 0], _rgb[:, 1], _rgb[:, 2]
    PlyData([PlyElement.describe(_el, 'vertex')]).write(str(_lidar_dst))
    print('LiDAR seed: %d points -> points3d.ply (paper Eq. 3 init)' % _pts.shape[0])
else:
    if _lidar_dst.exists():
        _lidar_dst.unlink()   # ensure 2DGS regenerates a random seed
    print('Init: random 100k (LiDAR seed %s)' %
          ('disabled' if not LIDAR_INIT else 'absent'))

with open(train_json, 'w') as f:
    json.dump(meta, f, indent=2)
shutil.copy(train_json, DATA_ROOT/'transforms_test.json')
(DATA_ROOT/'scale_factor.txt').write_text(str(SCALE_FACTOR))
print(f'OK data ready ({len(meta["frames"])} frames)')
print('DATA_ROOT=' + str(DATA_ROOT))

# --- white-fraction diagnostic ---
imgs = sorted(glob.glob(str(images_dir/'*.png')))
fracs = [(np.array(Image.open(f).convert('RGB')) > 250).all(2).mean() for f in imgs[::15]]
blank = sum(1 for x in fracs if x > 0.97)
print('WHITE_DIAG avg=%.3f  blank(>0.97)=%d/%d sampled  min=%.3f' % (
    sum(fracs)/len(fracs), blank, len(fracs), min(fracs)))
