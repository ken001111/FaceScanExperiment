source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/sugar_dgr:${PYTHONPATH:-}"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
cd ~/SuGaR
CKPT=$(ls -t output/coarse/*/*.pt | head -1); echo "ckpt: $CKPT"
rm -rf output/coarse_mesh/face_scan_mc
python extract_mesh.py -s ~/FaceScan/work/face_scan -c output/vanilla_gs/face_scan/ -i 7000 \
  -m "$CKPT" -l 0.3 -d 200000 -o output/coarse_mesh/face_scan_mc --use_marching_cubes True \
  --center_bbox True --eval False --gpu 0 > output/mc_extract.log 2>&1
echo "exit=$?"
grep -iE "marching|Mesh saved|Vertices|Foreground|Background|Traceback|Error" output/mc_extract.log | tail -10
ls -la output/coarse_mesh/face_scan_mc/ 2>/dev/null
