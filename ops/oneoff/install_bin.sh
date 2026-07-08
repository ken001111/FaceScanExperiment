mkdir -p "$HOME/FaceScan/bin"
SRC=/mnt/c/Users/m352395/Downloads
for f in prep.py finish_mesh.py make_report.py run_all.sh make_report.sh; do
  tr -d '\r' < "$SRC/$f" > "$HOME/FaceScan/bin/$f"
done
# point the bin copy of make_report.sh at the bin copy of make_report.py
sed -i 's#/mnt/c/Users/m352395/Downloads/make_report.py#$HOME/FaceScan/bin/make_report.py#' "$HOME/FaceScan/bin/make_report.sh"
chmod +x "$HOME/FaceScan/bin/"*.sh
echo "--- installed ---"
ls -la "$HOME/FaceScan/bin/"
echo "--- syntax checks ---"
bash -n "$HOME/FaceScan/bin/run_all.sh" && echo "run_all.sh OK"
bash -n "$HOME/FaceScan/bin/make_report.sh" && echo "make_report.sh OK"
