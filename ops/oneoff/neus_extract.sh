#!/bin/bash
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
D=~/FaceScan/data
cd "$D"
unzip -o neus.zip data_DTU.zip
rm -f neus.zip
unzip -l data_DTU.zip | head -8
mkdir -p DTU_neus
unzip -o data_DTU.zip 'dtu_scan24/*' 'dtu_scan37/*' 'dtu_scan65/*' -d DTU_neus > /dev/null || \
  { echo "names differ:"; unzip -l data_DTU.zip | awk '{print $4}' | cut -d/ -f1-2 | sort -u | head; exit 1; }
rm -f data_DTU.zip
find DTU_neus -maxdepth 2 -type d | head
ls DTU_neus/dtu_scan24 2>/dev/null || true
pip install -q natsort 2>&1 | tail -1 || true
cd ~/svraster
grep -n "add_argument\|glob\|scene" scripts/dtu_preproc.py | head -6
df -h / | tail -1
echo NEUS_EXTRACT_DONE
