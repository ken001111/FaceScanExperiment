set -e
TOKEN="$1"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_fn2; mkdir -p /tmp/gh_fn2; cd /tmp/gh_fn2
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"

# revert the over-corrected line: masks/ + crop belong to the 2DGS pipeline (Pipeline 1), not photogrammetry
sed -i 's|masks/ + crop belong to Pipeline 3|masks/ + crop belong to Pipeline 1|' \
  Sources/NaviNeticsCapture/Views/PhotogrammetryView.swift

echo "=== final check: every 'Pipeline N' reference ==="
grep -rn 'Pipeline [0-9]' --include='*.swift' --include='*.md' --include='*.ipynb' . | grep -v '/.git/' | sort

git add -A
git status --short
git commit -m "Fix over-corrected Pipeline ref: masks/crop serve Pipeline 1 (2DGS)" \
  -m "PhotogrammetryView line 274 refers to masks/ + crop, which are data-prep for the 2DGS pipeline (Pipeline 1), not photogrammetry (Pipeline 3). Reverts that one line from the previous bulk rename." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_fn2; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_fn2
echo "DONE (clone + token scrubbed)"
