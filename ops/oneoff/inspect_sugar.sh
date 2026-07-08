echo "=== SuGaR gaussian_splatting submodules ==="
ls ~/SuGaR/gaussian_splatting/submodules 2>/dev/null
echo "=== does SuGaR rasterizer differ from graphdeco? (check render return signature) ==="
grep -nE 'def forward|return|invdepth|num_rendered|radii' ~/SuGaR/gaussian_splatting/submodules/diff-gaussian-rasterization/diff_gaussian_rasterization/__init__.py 2>/dev/null | head -20
echo "=== SuGaR's renderer expectations ==="
grep -rnE 'rasterizer\(|GaussianRasterizer|render\(' ~/SuGaR/sugar_scene/sugar_model.py 2>/dev/null | head
echo "=== install.py (what it builds) ==="
grep -nE 'submodules|pip install|diff-gaussian|simple-knn|pytorch3d|nvdiffrast' ~/SuGaR/install.py | head -30
echo "=== iteration_to_load default in full pipeline ==="
grep -nE 'iteration_to_load|7000|iteration' ~/SuGaR/train_full_pipeline.py | head
