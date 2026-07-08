set -e
TOKEN="$1"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_read; mkdir -p /tmp/gh_read; cd /tmp/gh_read
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
echo "=== notebooks present ==="
ls -1 *.ipynb
echo ""
echo "=== FULL current README.md ==="
cat README.md
