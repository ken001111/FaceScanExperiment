~/miniconda3/envs/facescan/bin/pip install -q py-spy 2>&1 | tail -1
PID=$(pgrep -f 'python train.py' | head -1)
echo "PID=$PID"
echo "--- current iter ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1
echo "--- py-spy stack dump (no sudo) ---"
"$HOME/miniconda3/envs/facescan/bin/py-spy" dump --pid "$PID" 2>&1 | head -45
