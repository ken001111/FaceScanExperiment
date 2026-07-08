#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export PYTHONPATH="$HOME/geosvr_cuda_lib:$HOME/geosvr"
cd ~/geosvr
echo "--- direct python import:"
python -c "import svraster_cuda; print('direct OK')" || true
echo "--- via child bash (like dtu_run.sh):"
bash -c 'python -c "import svraster_cuda; print(\"child OK\")"' || true
echo "--- via PYTHONPATH=./ override (mesh step):"
PYTHONPATH=./ python -c "import svraster_cuda; print('override OK')" || echo "override FAILS (expected)"
echo "--- what does the geosvr scan24 model dir contain:"
ls ~/FaceScan/bench/geosvr/scan24/ 2>/dev/null
echo "--- first traceback context in run log:"
grep -an -B4 "ModuleNotFoundError" ~/FaceScan/bench/geosvr/scan24_run.log | head -12
