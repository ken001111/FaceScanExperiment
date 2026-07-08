import os
F = os.path.expanduser('~/miniconda3/envs/facescan/lib/python3.11/site-packages/diff_surfel_rasterization/__init__.py')
src = open(F).read()
old = ("        if grad_sh.shape != sh.shape:\n"
       "            grad_sh = grad_sh.reshape(sh.shape) if grad_sh.numel() == sh.numel() else torch.zeros_like(sh)\n")
new = ("        if sh.numel() == 0:\n"
       "            grad_sh = torch.zeros_like(sh)\n")
if old in src:
    open(F, 'w').write(src.replace(old, new))
    print('PATCHED to minimal safe version')
elif 'if sh.numel() == 0:' in src:
    print('ALREADY minimal')
else:
    print('NO MATCH - manual check needed')
