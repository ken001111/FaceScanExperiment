set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads/paper_experiments
DST=/tmp/gh/Facescan_app
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh; mkdir -p /tmp/gh; cd /tmp/gh
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd "$DST"
git config user.name "ken001111"
git config user.email "ken001111@users.noreply.github.com"
git rm -r -q paper_experiments 2>/dev/null || rm -rf paper_experiments
mkdir -p paper_experiments
cd "$SRC"
find . -type f -not -path '*/__pycache__/*' | while read -r f; do
  rel="${f#./}"; mkdir -p "$DST/paper_experiments/$(dirname "$rel")"
  tr -d '\r' < "$f" > "$DST/paper_experiments/$rel"
done
cd "$DST"
git add -A paper_experiments
echo "=== change summary ==="; git status --short paper_experiments | sed -n '1,40p'
git commit -q -m "3dgs: also export pre-TSDF Gaussian cloud (before/after TSDF)" \
  -m "run_3dgs_tsdf.sh now writes <out>_pretsdf.ply (raw 3DGS Gaussian centres, mm) alongside the TSDF mesh, via mesh_3dgs_tsdf.py --points_out. Lets the method comparison show 3DGS's raw noisy geometry vs the fused mesh (Fig 2 narrative)." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh
echo "DONE (clone + token scrubbed)"
