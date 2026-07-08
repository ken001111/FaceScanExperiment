echo "=== glibc ==="; ldd --version | head -1
echo "=== other cuda toolkits ==="; ls /usr/local/ | grep -i cuda
echo "=== is CUDA math_functions.h already patched for cospi noexcept? ==="
grep -n "cospi" /usr/local/cuda-12.8/include/crt/math_functions.h | head -4
echo "=== 2DGS surfel rasterizer .so (built when?) ==="
find ~/miniconda3/envs/facescan/lib -name '*surfel*' -o -name '*_C*.so' 2>/dev/null | grep -iE 'surfel|simple_knn' | head
python - <<'PY'
import importlib.util, os
for m in ["diff_surfel_rasterization","simple_knn"]:
    s=importlib.util.find_spec(m)
    print(m, "->", s.origin if s else None)
    if s and s.submodule_search_locations:
        for p in s.submodule_search_locations:
            for f in os.listdir(p):
                if f.endswith(".so"):
                    fp=os.path.join(p,f); print("   ", f, os.path.getmtime(fp))
PY
echo "=== conda sysroot/gcc packages present? ==="
ls ~/miniconda3/envs/facescan/x86_64-conda-linux-gnu 2>/dev/null && echo "HAS conda sysroot" || echo "no conda sysroot"
echo "=== nvcc default host glibc test: does any sysroot exist ==="
ls /opt/conda* 2>/dev/null; conda list 2>/dev/null | grep -iE 'sysroot|gcc_linux|gxx_linux|binutils'
