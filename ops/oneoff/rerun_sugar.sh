source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/sugar_dgr:${PYTHONPATH:-}"
export CUDA_HOME=/usr/local/cuda-12.8; export PATH="$CUDA_HOME/bin:$PATH"
# patch np.byte everywhere in SuGaR
grep -rl 'np\.byte' ~/SuGaR --include='*.py' | xargs -r sed -i 's/np\.byte/np.uint8/g'
echo "patched np.byte in: $(grep -rl 'np.uint8' ~/SuGaR --include='*.py' | wc -l) files (verify none left:)"
grep -rn 'np\.byte' ~/SuGaR --include='*.py' || echo "  none remaining"
cd ~/SuGaR
# reuse the already-trained 7k vanilla checkpoint to skip retraining
python train_full_pipeline.py -s ~/FaceScan/work/face_scan --gs_output_dir output/vanilla_gs/face_scan/ \
   -r dn_consistency -l 0.3 --refinement_time short \
   --export_obj False --export_ply False --white_background True --eval False \
   > ~/SuGaR/output/sugar_rerun.log 2>&1
echo "pipeline_exit=$?"
echo "=== coarse mesh produced? ==="
ls -la ~/SuGaR/output/coarse_mesh/face_scan/ 2>/dev/null || echo "(no coarse_mesh dir)"
echo "=== tail log ==="
grep -iE 'Mesh saved|sugarmesh|coarse mesh|Traceback|Error|FAILED|Cleaning|Final mesh' ~/SuGaR/output/sugar_rerun.log | tail -15
