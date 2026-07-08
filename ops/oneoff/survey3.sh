source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
echo "=== nvcc version ==="
/usr/local/cuda-12.8/bin/nvcc --version | tail -2
echo "=== gcc/g++ ==="
gcc --version | head -1; g++ --version | head -1
echo "=== relevant conda/pip pkgs ==="
pip list 2>/dev/null | grep -iE 'diff-gaussian|diff-surfel|simple-knn|pytorch3d|nvdiffrast|plyfile|open3d|torch '
echo "=== 2dgs submodules ==="
ls ~/2d-gaussian-splatting/submodules 2>/dev/null
echo "=== CUDA_HOME ==="
echo "CUDA_HOME=$CUDA_HOME"
python -c "from torch.utils.cpp_extension import CUDA_HOME; print('torch CUDA_HOME=',CUDA_HOME)"
