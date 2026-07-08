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
git status --short paper_experiments | sed -n '1,60p'
git commit -q -m "paper_experiments: drop Apple Object Capture baseline; robust SuGaR wrapper" \
  -m "Object Capture removed from the method set per the paper revision (METHODS, run_methods.sh OBJCAP hook, run_specimen/READMEs, synthetic-data offsets). SuGaR wrapper reworked to drive train.py's dn_consistency coarse + Poisson extract directly (external/sugar_coarse.py), no refinement -- the standalone SDF path left an empty foreground and Poisson-OOMed. Documented that the dn-coarse pass is VRAM-marginal on a 16GB GPU (retry / use >=24GB / SUGAR_REG=density). Selftests pass." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh
echo "DONE (clone + token scrubbed)"
