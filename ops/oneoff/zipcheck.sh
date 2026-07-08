#!/bin/bash
cd ~/FaceScan/data
file dtu_2dgs.zip
python3 - <<'PY'
import zipfile
print("is_zipfile:", zipfile.is_zipfile("dtu_2dgs.zip"))
PY
echo "--- head:"
head -c 64 dtu_2dgs.zip | xxd | head -4
echo "--- tail:"
tail -c 64 dtu_2dgs.zip | xxd | head -4
ls -la dtu_2dgs.zip
