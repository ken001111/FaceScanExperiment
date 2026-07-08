set -e
SRC=/mnt/c/Users/m352395/Downloads
for f in prep.py finish_mesh.py run_all.sh; do
  tr -d '\r' < "$SRC/$f" > "$HOME/FaceScan/bin/$f"
done
chmod +x "$HOME/FaceScan/bin/run_all.sh"
PY="$HOME/miniconda3/envs/facescan/bin/python"
"$PY" -m py_compile "$HOME/FaceScan/bin/prep.py" && echo "prep.py OK"
"$PY" -m py_compile "$HOME/FaceScan/bin/finish_mesh.py" && echo "finish_mesh.py OK"
bash -n "$HOME/FaceScan/bin/run_all.sh" && echo "run_all.sh OK"
echo "--- quick prep test with FRAMES=120 ---"
t0=$(date +%s)
FRAMES=120 "$PY" "$HOME/FaceScan/bin/prep.py" 2>&1 | grep -E 'Subsampled|Applied|OK data ready'
t1=$(date +%s)
echo "prep took $((t1-t0))s (was ~4min at 297 frames)"
