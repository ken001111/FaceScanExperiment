#!/bin/bash
# NeuS-format DTU (for SVRaster's paper protocol): download Dropbox bundle,
# keep only dtu_scan24/37/65, run SVRaster's own dtu_preproc.py.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
D=~/FaceScan/data
mkdir -p "$D/DTU_neus"
cd "$D"
if [ ! -d "$D/DTU_neus/dtu_scan24" ]; then
  curl -L -o neus.zip 'https://www.dropbox.com/sh/w0y8bbdmxzik3uk/AAAaZffBiJevxQzRskoOYcyja?dl=1'
  ls -la neus.zip
  unzip -o neus.zip 'dtu_scan24/*' 'dtu_scan37/*' 'dtu_scan65/*' -d "$D/DTU_neus" || \
    { echo "top-level names differ; listing:"; unzip -l neus.zip | head -30; exit 1; }
  rm -f neus.zip
fi
pip install -q natsort 2>&1 | tail -1 || true
cd ~/svraster
python scripts/dtu_preproc.py --path "$D/DTU_neus" 2>/dev/null || python scripts/dtu_preproc.py "$D/DTU_neus" || \
  { grep -n 'add_argument\|args\.' scripts/dtu_preproc.py | head -8; exit 1; }
ls "$D/DTU_neus/dtu_scan24"
df -h / | tail -1
echo NEUS_DOWNLOAD_COMPLETE
