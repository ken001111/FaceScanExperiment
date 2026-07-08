source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
echo "=== disk ==="; df -h ~ | tail -1
echo "=== torch / cuda / arch ==="
python - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("device", torch.cuda.get_device_name(0))
print("arch_list", torch.cuda.get_arch_list())
PY
echo "=== FaceScan tree (top) ==="
ls -1 ~/FaceScan 2>/dev/null
echo "=== existing 2dgs repo location ==="
ls -d ~/FaceScan/* 2>/dev/null | head -40
echo "=== any existing 3dgs / sugar clones ==="
find ~ -maxdepth 4 -iname '*gaussian-splatting*' -o -iname '*sugar*' 2>/dev/null | grep -vi miniconda | head
echo "=== nvcc ==="; which nvcc && nvcc --version | tail -2
echo "=== prepped data root sample ==="
ls ~/FaceScan/work/face_scan 2>/dev/null | head
