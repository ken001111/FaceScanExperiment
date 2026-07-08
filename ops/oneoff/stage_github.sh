set -e
STAGE="$HOME/gh_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/local_pipeline"
# working pipeline tools (the installed, clean versions)
cp ~/FaceScan/bin/prep.py          "$STAGE/local_pipeline/"
cp ~/FaceScan/bin/finish_mesh.py   "$STAGE/local_pipeline/"
cp ~/FaceScan/bin/make_report.py   "$STAGE/local_pipeline/"
cp ~/FaceScan/bin/make_report.sh   "$STAGE/local_pipeline/"
cp ~/FaceScan/bin/run_all.sh       "$STAGE/local_pipeline/"
# the 2DGS source patches (applied to the splatting repo, kept here for reference)
cp /mnt/c/Users/m352395/Downloads/patch_sh.py      "$STAGE/local_pipeline/" 2>/dev/null || true
cp /mnt/c/Users/m352395/Downloads/patch_densify.py "$STAGE/local_pipeline/" 2>/dev/null || true
echo "--- staged files ---"
ls -la "$STAGE/local_pipeline/"
