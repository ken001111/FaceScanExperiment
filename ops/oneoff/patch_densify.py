import os
F = os.path.expanduser('~/2d-gaussian-splatting/scene/gaussian_model.py')
src = open(F).read()
old = ("    def add_densification_stats(self, viewspace_point_tensor, update_filter):\n"
       "        self.xyz_gradient_accum[update_filter] += torch.norm(viewspace_point_tensor.grad[update_filter], dim=-1, keepdim=True)\n"
       "        self.denom[update_filter] += 1")
new = ("    def add_densification_stats(self, viewspace_point_tensor, update_filter):\n"
       "        grad = viewspace_point_tensor.grad\n"
       "        mask = update_filter.unsqueeze(-1) if update_filter.dim() == 1 else update_filter\n"
       "        grad_norm = torch.norm(grad, dim=-1, keepdim=True)\n"
       "        self.xyz_gradient_accum += torch.where(mask, grad_norm, torch.zeros_like(grad_norm))\n"
       "        self.denom += mask.to(self.denom.dtype)")
if old in src:
    open(F, 'w').write(src.replace(old, new))
    print('PATCHED add_densification_stats (dense, no boolean scatter)')
elif 'torch.where(mask, grad_norm' in src:
    print('ALREADY patched')
else:
    print('NO MATCH - manual check needed')
