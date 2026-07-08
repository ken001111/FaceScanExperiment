set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_pp; mkdir -p /tmp/gh_pp; cd /tmp/gh_pp
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"

tr -d '\r' < "$SRC/prep.py"          > local_pipeline/prep.py
tr -d '\r' < "$SRC/new_lp_readme.md" > local_pipeline/README.md

git add local_pipeline/prep.py local_pipeline/README.md
git status --short
git commit -m "prep.py: LiDAR-guided init + sharpness gate (align with MICCAI paper)" \
  -m "Implements the two LiDAR mechanisms from the LiDAR-Guided 2DGS paper: (1) LiDAR-guided initialization (Eq. 3) - transform the scan's points3D.ply with the same recenter+scale as the cameras and write points3d.ply so 2DGS seeds from the LiDAR cloud instead of a random one (verified: init goes from random 100k to the 83k LiDAR points); (2) a sharpness gate that drops frames below SHARP_FRAC x the median Laplacian variance. Falls back to random init if no LiDAR cloud is present." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_pp; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_pp
echo "DONE (clone + token scrubbed)"
