set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_pr; mkdir -p /tmp/gh_pr; cd /tmp/gh_pr
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"
tr -d '\r' < "$SRC/new_main_readme.md" > README.md
git add README.md
git status --short
git commit -m "Rewrite README around the three reconstruction pipelines" \
  -m "Frame the project by Pipeline 1 (2DGS on RTX 5080 PC / WSL2 - this repo's local_pipeline), Pipeline 2 (2DGS on device, msplat-ios), and Pipeline 3 (on-device photogrammetry). Clarifies this repo holds the capture app + Pipeline 1." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_pr; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_pr
echo "DONE (clone + token scrubbed)"
