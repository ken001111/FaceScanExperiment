set -e
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
cd ~
if [ ! -d ~/gaussian-splatting ]; then
  echo "[clone] graphdeco-inria/gaussian-splatting (recursive)"
  git clone --recursive https://github.com/graphdeco-inria/gaussian-splatting.git 2>&1 | tail -5
else
  echo "[clone] already present"
fi
echo "=== submodules ==="
ls ~/gaussian-splatting/submodules
echo "=== render API (depth output?) ==="
grep -nE "depth|render_depth|invdepth|\"render\"" ~/gaussian-splatting/gaussian_renderer/__init__.py | head -20
echo "=== rasterizer returns ==="
grep -nE "def forward|return|num_rendered" ~/gaussian-splatting/submodules/diff-gaussian-rasterization/diff_gaussian_rasterization/__init__.py | head -30
echo "=== available gcc versions (for nvcc host compiler) ==="
ls /usr/bin/gcc-* 2>/dev/null; ls /usr/bin/g++-* 2>/dev/null
