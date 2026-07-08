set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads/paper_experiments
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_pe; mkdir -p /tmp/gh_pe; cd /tmp/gh_pe
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"
mkdir -p paper_experiments
for f in eval_common.py stats_util.py report_util.py \
         table1_tier0_frame_vs_cad.py table2_tier1_surface.py figure2_method_heatmaps.py \
         table3_init_study.py figure3_init_comparison.py README.md; do
  tr -d '\r' < "$SRC/$f" > "paper_experiments/$f"
done
git add paper_experiments
git status --short
git commit -m "Add paper_experiments/: runnable Table 1-3 + Figure 2-3 scripts" \
  -m "Evaluation/analysis code for the LiDAR-2DGS paper's results artifacts, ready to run when reference data arrives. Each artifact is its own script (table1 Tier-0 frame-vs-CAD, table2 Tier-1 frame/face, figure2 method heat-maps, table3 init study, figure3 init comparison + convergence) over a shared surface-metric engine (ICP align + point-to-surface mean/RMS/95th/Hausdorff/%<1mm) and stats module (bootstrap CI, paired Wilcoxon + Holm). Documented data layout + per-script --selftest on synthetic data (all five pass)." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_pe; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_pe
echo "DONE (clone + token scrubbed)"
