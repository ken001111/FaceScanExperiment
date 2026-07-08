set -e
TOKEN="$1"
WORK=/tmp/gh_clean
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
git clone "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
echo "=== repo top-level ==="
ls -1
echo ""
echo "=== local_pipeline/ ==="
ls -la local_pipeline/
echo ""
echo "=== main README.md (first 30 lines) ==="
head -30 README.md 2>/dev/null || echo "(no README.md)"
echo ""
echo "=== local_pipeline/README.md (first 20 lines) ==="
head -20 local_pipeline/README.md 2>/dev/null
