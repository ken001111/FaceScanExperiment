source ~/miniconda3/etc/profile.d/conda.sh
echo "=== disk check ==="; df -h ~ | tail -1
echo "=== remove partial sugar env ==="
conda env remove -n sugar -y 2>/dev/null || true
rm -rf ~/miniconda3/envs/sugar 2>/dev/null || true
echo "=== retry clone facescan -> sugar ==="
CONDA_NO_PLUGINS=true conda create --clone facescan -n sugar -y 2>&1 | tail -8
echo "=== verify ==="
conda env list | grep sugar && ~/miniconda3/envs/sugar/bin/python -c "import torch, pytorch3d; print('sugar clone OK: torch',torch.__version__,'pytorch3d',pytorch3d.__version__)"
echo "RETRY_CLONE_DONE"
