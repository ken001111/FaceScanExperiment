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
  rel="${f#./}"
  mkdir -p "$DST/paper_experiments/$(dirname "$rel")"
  tr -d '\r' < "$f" > "$DST/paper_experiments/$rel"
done
cd "$DST"
git add -A paper_experiments
echo "=== change summary ==="
git status --short paper_experiments | sed -n '1,80p'
git commit -q -m "paper_experiments: reorganize into per-study folders" \
  -m "Two self-contained studies sharing common/: method_comparison/ (Tables 1-2, Fig 2, plus external 3DGS+TSDF and SuGaR baselines built for the RTX 5080 / Blackwell sm_120) and initialization_study/ (Table 3, Fig 3). Each study has its own README, data runner, and analyze.sh; run_specimen.sh runs both for one specimen. preliminary/ holds the ken no-CT/SL proxy tools. All shell scripts pass bash -n; all 5 analysis selftests pass." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh
echo "DONE (clone + token scrubbed)"
