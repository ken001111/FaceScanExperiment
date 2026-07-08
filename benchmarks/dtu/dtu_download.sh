#!/bin/bash
# Download DTU benchmark data INSIDE WSL (reuses freed vhdx blocks, no C: growth).
# Scope: scans 24, 37, 65 only. Deletes each zip after extracting what's needed.
set -e
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
pip install -q gdown 2>&1 | tail -1 || true
D=~/FaceScan/data
mkdir -p "$D/DTU" "$D/DTU_2dgs"
cd "$D"

echo "=== [1/3] DTU_2dgs (2DGS-preprocessed training set) ==="
if [ ! -d "$D/DTU_2dgs/scan24" ]; then
  [ -f dtu_2dgs.zip ] || gdown 1ODiOu72tAGPTnhVn0cFZ9MvymDgcoHxQ -O dtu_2dgs.zip
  ls -la dtu_2dgs.zip
  unzip -q -o dtu_2dgs.zip -d dtu_2dgs_tmp
  find dtu_2dgs_tmp -maxdepth 3 -type d -name 'scan*' | head -20
  for s in scan24 scan37 scan65; do
    src=$(find dtu_2dgs_tmp -maxdepth 3 -type d -name "$s" | head -1)
    [ -n "$src" ] && mv "$src" "$D/DTU_2dgs/" && echo "kept $s"
  done
  rm -rf dtu_2dgs.zip dtu_2dgs_tmp
fi

echo "=== [2/3] Points.zip (official GT point clouds) ==="
if [ ! -f "$D/DTU/Points/stl/stl024_total.ply" ]; then
  wget -q --show-progress -O points.zip http://roboimagedata2.compute.dtu.dk/data/MVS/Points.zip
  mkdir -p "$D/DTU/Points/stl"
  unzip -o points.zip 'Points/stl/stl024*' 'Points/stl/stl037*' 'Points/stl/stl065*' -d pts_tmp
  mv pts_tmp/Points/stl/* "$D/DTU/Points/stl/"
  rm -rf points.zip pts_tmp
fi

echo "=== [3/3] SampleSet.zip (ObsMask) ==="
if [ ! -d "$D/DTU/ObsMask" ]; then
  wget -q --show-progress -O sample.zip http://roboimagedata2.compute.dtu.dk/data/MVS/SampleSet.zip
  mkdir -p "$D/DTU/ObsMask"
  unzip -o sample.zip 'SampleSet/MVS Data/ObsMask/ObsMask24*' 'SampleSet/MVS Data/ObsMask/ObsMask37*' 'SampleSet/MVS Data/ObsMask/ObsMask65*' 'SampleSet/MVS Data/ObsMask/Plane24*' 'SampleSet/MVS Data/ObsMask/Plane37*' 'SampleSet/MVS Data/ObsMask/Plane65*' -d obs_tmp
  mv "obs_tmp/SampleSet/MVS Data/ObsMask/"* "$D/DTU/ObsMask/"
  rm -rf sample.zip obs_tmp
fi

echo "=== DONE ==="
du -sh "$D"/*; ls "$D/DTU_2dgs"; ls "$D/DTU/Points/stl" | head; ls "$D/DTU/ObsMask" | head
df -h / | tail -1
echo DTU_DOWNLOAD_COMPLETE
