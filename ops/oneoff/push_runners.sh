set -e
TOKEN="$1"
SRC=/mnt/c/Users/m352395/Downloads/paper_experiments
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
rm -rf /tmp/gh_pr; mkdir -p /tmp/gh_pr; cd /tmp/gh_pr
git clone -q "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd Facescan_app
git config user.name  "ken001111"
git config user.email "ken001111@users.noreply.github.com"
for f in make_raw_lidar_mesh.py run_methods.sh run_init_study.sh eval_convergence.py README.md; do
  tr -d '\r' < "$SRC/$f" > "paper_experiments/$f"
done
chmod +x paper_experiments/run_methods.sh paper_experiments/run_init_study.sh
git add paper_experiments
git status --short
git commit -m "paper_experiments: add experiment RUNNERS (generate the data)" \
  -m "run_methods.sh produces each method's mesh for a scan (2DGS via this repo's pipeline + raw-LiDAR Poisson here; Object Capture / 3DGS / SuGaR / structured-light / CAD plug in via env vars). run_init_study.sh trains 2DGS from LiDAR/random/SfM seeds into the init/ layout with meta + optional RMS-vs-iter convergence (eval_convergence.py). make_raw_lidar_mesh.py = Poisson mesh of a LiDAR cloud. Verified end-to-end on a real scan (2dgs.ply + raw_lidar.ply produced)." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit"; cd /; rm -rf /tmp/gh_pr; exit 0; }
git push "https://ken001111:${TOKEN}@github.com/ken001111/Facescan_app.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd /; rm -rf /tmp/gh_pr
echo "DONE (clone + token scrubbed)"
