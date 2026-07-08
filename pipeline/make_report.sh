#!/bin/bash
# Build + package the report for the most recent run (reads last_run.txt).
source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
"$PY" -c "import matplotlib" 2>/dev/null || "$PY" -m pip install -q matplotlib
. "$HOME/FaceScan/last_run.txt"
export RUN_ID OUTPUT_PATH DATA_ROOT
"$PY" "$HOME/FaceScan/bin/make_report.py"
"$PY" - "$RUN_ID" <<'PYZIP'
import shutil, os, sys
rid = sys.argv[1]
base = os.path.expanduser('~/FaceScan/reports/FaceScan_Report_' + rid)
shutil.make_archive(base, 'zip', os.path.expanduser('~/FaceScan/reports'), rid)
print('zip:', base + '.zip')
PYZIP
cp "$HOME/FaceScan/reports/FaceScan_Report_${RUN_ID}.zip" /mnt/c/Users/m352395/Downloads/
cp "$HOME/FaceScan/results/Face_Mesh_MetricScale_${RUN_ID}"*.ply /mnt/c/Users/m352395/Downloads/ 2>/dev/null && echo "meshes copied to Downloads"
echo "=== package ready ==="
ls -la /mnt/c/Users/m352395/Downloads/"FaceScan_Report_${RUN_ID}.zip"
