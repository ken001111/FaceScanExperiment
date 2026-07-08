set -e
TOKEN="$1"
USER=ken001111
REPO=Facescan_app
WORK=/tmp/gh_push
NOTES="/mnt/c/Users/m352395/Downloads/Facescan_app-main/Facescan_app-main/docs/LOCAL_SETUP_NOTES.md"
STAGE="$HOME/gh_stage/local_pipeline"
PIPE_README="/mnt/c/Users/m352395/Downloads/pipeline_README.md"

git config --global user.name  "ken001111"
git config --global user.email "ken001111@users.noreply.github.com"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt

rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
echo "--- cloning ---"
git clone "https://${USER}:${TOKEN}@github.com/${USER}/${REPO}.git" 2>&1 | sed "s/${TOKEN}/***/g"
cd "$REPO"
DEF=$(git rev-parse --abbrev-ref HEAD)
echo "default branch: $DEF"

mkdir -p docs local_pipeline
cp "$NOTES" docs/LOCAL_SETUP_NOTES.md
cp "$STAGE"/* local_pipeline/
cp "$PIPE_README" local_pipeline/README.md

git add docs/LOCAL_SETUP_NOTES.md local_pipeline
echo "--- staged changes ---"
git status --short

git add -A docs/LOCAL_SETUP_NOTES.md local_pipeline
git commit -m "Update local pipeline: speed knobs, CUDA data device, frame subsampling" \
  -m "run_all.sh now exposes ITERS/FRAMES/TRAIN_RES/RENDER_RES/DATA_DEVICE knobs (defaults tuned for speed: 10k iters, half-res, 120 frames, data_device=cuda which removed the CPU bottleneck: 17->35 it/s). prep.py adds frame subsampling + masks only kept frames; finish_mesh.py locates the saved iteration dynamically; make_report adds GPU-usage, input/output, and file-location sections." \
  -m "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>" || { echo "nothing to commit (already up to date)"; cd /; rm -rf "$WORK"; exit 0; }

echo "--- pushing ---"
git push origin "$DEF" 2>&1 | sed "s/${TOKEN}/***/g"

cd /; rm -rf "$WORK"
echo "PUSH_DONE branch=$DEF (local clone + token removed)"
