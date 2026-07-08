import numpy as np, glob, os
from PIL import Image
d = os.path.expanduser('~/FaceScan/work/face_scan/Scan__20260528_183911_cropped')
imgs = sorted(glob.glob(d + '/images/*.png'))
print('num images:', len(imgs))
fracs = []
for f in imgs[::20][:12]:
    a = np.array(Image.open(f).convert('RGB'))
    whitefrac = (a > 250).all(2).mean()
    fracs.append(whitefrac)
    print(os.path.basename(f), 'white_frac=%.3f' % whitefrac, 'mean=%.1f' % a.mean(), 'shape=', a.shape)
print('--- avg white fraction across sampled: %.3f ---' % (sum(fracs)/len(fracs)))
print('(>0.97 = face almost entirely masked away -> scene collapses to empty)')
