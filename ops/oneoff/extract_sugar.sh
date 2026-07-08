source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/sugar_dgr:${PYTHONPATH:-}"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/SuGaR
# torch 2.11: torch.load defaults weights_only=True -> patch SuGaR's loads (trusted local ckpts)
sed -i 's/map_location=nerfmodel.device)/map_location=nerfmodel.device, weights_only=False)/g' sugar_extractors/coarse_mesh.py sugar_extractors/refined_mesh.py sugar_scene/sugar_model.py
sed -i 's/map_location=device)/map_location=device, weights_only=False)/g' sugar_scene/sugar_model.py
sed -i 's/map_location=nerfmodel_30k.device)/map_location=nerfmodel_30k.device, weights_only=False)/g' metrics.py
echo "=== patched ==="; grep -rn "weights_only=False" ~/SuGaR --include="*.py" | grep -v gaussian_splatting
CKPT=$(ls output/coarse/face_scan/*/15000.pt | head -1)
echo "coarse ckpt: $CKPT"
python extract_mesh.py -s ~/FaceScan/work/face_scan -c output/vanilla_gs/face_scan/ -i 7000 \
  -m "$CKPT" -l 0.3 -o output/coarse_mesh/face_scan --center_bbox True --eval False --gpu 0 \
  > output/extract_mesh.log 2>&1
echo "extract_exit=$?"
echo "=== coarse_mesh dir ==="; ls -la output/coarse_mesh/face_scan/
echo "=== log tail ==="; tail -15 output/extract_mesh.log
