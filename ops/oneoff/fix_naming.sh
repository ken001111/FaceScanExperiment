set -e
TOKEN="$1"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_fn; mkdir -p /tmp/gh_fn; cd /tmp/gh_fn
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"

echo "=== BEFORE: all 'Pipeline N' references ==="
grep -rn 'Pipeline [0-9]' --include='*.swift' --include='*.md' --include='*.ipynb' . | grep -v '/.git/' || true

# photogrammetry files: on-device photogrammetry is Pipeline 3, not 1
for f in \
  Sources/NaviNeticsCapture/Capture/PhotogrammetryRunner.swift \
  Sources/NaviNeticsCapture/Views/PhotogrammetryView.swift \
  Sources/NaviNeticsCapture/Views/SaveView.swift ; do
  sed -i 's/Pipeline 1/Pipeline 3/g' "$f"
done

echo ""
echo "=== AFTER: all 'Pipeline N' references (docs should stay 1, photogrammetry now 3) ==="
grep -rn 'Pipeline [0-9]' --include='*.swift' --include='*.md' --include='*.ipynb' . | grep -v '/.git/' || true

echo ""
git add -A
git status --short
git commit -m "Make Pipeline numbering consistent: on-device photogrammetry is Pipeline 3" \
  -m "The Swift photogrammetry files (PhotogrammetryRunner/PhotogrammetryView/SaveView) labeled on-device Apple Object Capture as 'Pipeline 1'. Per the project's scheme (1 = 2DGS on PC, 2 = 2DGS on device, 3 = photogrammetry on device) these are Pipeline 3. Docs' 'Pipeline 1' (local 2DGS) references are correct and unchanged." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_fn; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_fn
echo "DONE (clone + token scrubbed)"
