source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export CC=/usr/bin/gcc-13 CXX=/usr/bin/g++-13
export TORCH_CUDA_ARCH_LIST="12.0"
export NVCC_PREPEND_FLAGS="-allow-unsupported-compiler"
cd ~/gaussian-splatting
pip install --no-build-isolation -v ./submodules/simple-knn > ~/sk_build.log 2>&1
echo "exit=$?"
echo "===== last 40 meaningful lines ====="
grep -iE 'error|fatal|undefined reference|cannot|No such file|expected |is not a member|RuntimeError|subprocess' ~/sk_build.log | tail -40
