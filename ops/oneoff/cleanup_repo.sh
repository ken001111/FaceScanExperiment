set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads
PY="$HOME/miniconda3/envs/facescan/bin/python"
WORK=/tmp/gh_clean/Facescan_app
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
# always clone fresh to avoid partial-state issues
rm -rf /tmp/gh_clean; mkdir -p /tmp/gh_clean; cd /tmp/gh_clean
git clone "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd "$WORK"
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"

# 1) move the one-off patches into a subfolder
mkdir -p local_pipeline/patches
git mv local_pipeline/patch_sh.py      local_pipeline/patches/patch_sh.py
git mv local_pipeline/patch_densify.py local_pipeline/patches/patch_densify.py
tr -d '\r' < "$SRC/patches_readme.md" > local_pipeline/patches/README.md

# 2) refresh local_pipeline/README.md
tr -d '\r' < "$SRC/new_lp_readme.md" > local_pipeline/README.md

# 3) add the 'Run locally' section to the main README
tr -d '\r' < "$SRC/main_readme_section.md" > /tmp/main_readme_section.md
tr -d '\r' < "$SRC/readme_patch.py"        > /tmp/readme_patch.py
"$PY" /tmp/readme_patch.py

echo "=== changes ==="
git add -A
git status --short

git commit -m "Tidy local_pipeline (patches/ subfolder) + add local usage docs" \
  -m "Move the one-time 2DGS patch scripts into local_pipeline/patches/ with their own README; refresh local_pipeline/README.md with the current run knobs (ITERS/FRAMES/TRAIN_RES/RENDER_RES/DATA_DEVICE) and a masking-quality note; add a 'Run locally (RTX GPU + WSL2)' section to the main README." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_clean; exit 0; }

echo "=== pushing ==="
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_clean
echo "DONE (clone + token scrubbed)"
