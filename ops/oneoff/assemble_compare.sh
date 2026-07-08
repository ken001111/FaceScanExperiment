source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
OUT=/mnt/c/Users/m352395/Downloads/mesh_compare
mkdir -p "$OUT"
RES=~/FaceScan/results
EM=~/FaceScan/EXPDATA/ken/methods
cp_if(){ [ -f "$1" ] && cp "$1" "$2" && echo "  $2"; }
echo "=== gathering meshes (all millimetres) ==="
# in-frame, head-cropped set (best for overlaying together)
cp_if "$RES/Face_Mesh_MetricScale_exp_kentest_2dgs_nn.ply" "$OUT/2dgs_ours.ply"
cp_if "$EM/3dgs.ply"            "$OUT/3dgs_tsdf_3k_cropped.ply"
cp_if "$EM/sugar.ply"           "$OUT/sugar_coarse_cropped.ply"
cp_if "$EM/raw_lidar.ply"       "$OUT/raw_lidar.ply"
cp_if "$EM/object_capture.ply"  "$OUT/object_capture_registered.ply"
# full / uncropped individual meshes
cp_if ~/3dgs_test.ply           "$OUT/3dgs_tsdf_3k_full.ply"
cp_if ~/3dgs_30k.ply            "$OUT/3dgs_tsdf_30k_full.ply"
cp_if ~/sugar_test.ply          "$OUT/sugar_coarse_merged_full.ply"
cp_if ~/sugar_fg_full.ply       "$OUT/sugar_foreground_full.ply"
# init study meshes
cp_if "$RES/Face_Mesh_MetricScale_ken_lidar_nn.ply"  "$OUT/init_lidar.ply"
cp_if "$RES/Face_Mesh_MetricScale_ken_random_nn.ply" "$OUT/init_random.ply"
cat > "$OUT/README.txt" <<'TXT'
ken face-scan meshes — all in MILLIMETRES.

METHODS (the *_cropped.ply share the 2DGS frame + head crop, so they overlay):
  2dgs_ours.ply                 2DGS+TSDF (our pipeline) — used as the reference proxy
  3dgs_tsdf_3k_cropped.ply      3DGS+TSDF, 3k-iter quick run, head-cropped
  3dgs_tsdf_30k_full.ply        3DGS+TSDF, full 30k-iter run (best 3DGS quality)
  sugar_coarse_cropped.ply      SuGaR coarse mesh (fg+bg merged), head-cropped
  raw_lidar.ply                 Poisson surface of the raw LiDAR cloud
  object_capture_registered.ply Apple Object Capture (Pipeline 3), ICP-registered into frame

FULL / UNCROPPED variants (native extent, includes background where present):
  3dgs_tsdf_3k_full.ply         3k 3DGS, uncropped (note background skirt)
  sugar_coarse_merged_full.ply  SuGaR coarse, fg+bg merged (noisy, has background)
  sugar_foreground_full.ply     SuGaR foreground only (background removed; sparse/fragmented)

INITIALIZATION STUDY (same 2DGS pipeline, different seed):
  init_lidar.ply                LiDAR-guided init  (lower RMS, 2x sub-1mm coverage)
  init_random.ply               random init

No CT/CAD or structured-light reference available -> 2DGS is the stand-in reference.
Numbers in ../ken_experiment_results are cross-method AGREEMENT, not ground-truth accuracy.
TXT
echo "=== contents ==="; ls -la "$OUT"
