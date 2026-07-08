set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_rw; mkdir -p /tmp/gh_rw; cd /tmp/gh_rw
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"

# 1) new top-level README
tr -d '\r' < "$SRC/new_main_readme.md" > README.md

# 2) drop superseded notebooks (keep Rear_Camera_03_local.ipynb)
for nb in 20260507_final_02.ipynb Rear_Camera.ipynb Rear_Camera_02_clean.ipynb Rear_Camera_03_clean.ipynb; do
  git rm -q "$nb" 2>/dev/null || true
done
echo "=== notebooks remaining ==="
ls -1 *.ipynb

echo "=== changes ==="
git add -A
git status --short

git commit -m "Rewrite top-level README; drop superseded notebooks" \
  -m "Rewrite README as a project overview (iOS capture app + local 2DGS pipeline + reconstruction notes), pointing at the kept Rear_Camera_03_local.ipynb and local_pipeline/. Remove the older/duplicate notebooks (20260507_final_02, Rear_Camera, Rear_Camera_02_clean, Rear_Camera_03_clean); keep only the local notebook the pipeline is based on." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_rw; exit 0; }

echo "=== pushing ==="
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_rw
echo "DONE (clone + token scrubbed)"
