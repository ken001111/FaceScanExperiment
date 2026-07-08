source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
PY="$HOME/miniconda3/envs/facescan/bin/python"
tr -d '\r' < /mnt/c/Users/m352395/Downloads/make_report.py > "$HOME/FaceScan/bin/make_report.py"
$PY -m py_compile "$HOME/FaceScan/bin/make_report.py" && echo "make_report.py OK"
echo "--- regenerating prep.log (populates Input section) ---"
$PY "$HOME/FaceScan/bin/prep.py" > "$HOME/FaceScan/prep.log" 2>&1
tail -3 "$HOME/FaceScan/prep.log"
echo "--- building report ---"
bash "$HOME/FaceScan/bin/make_report.sh" >/dev/null 2>&1
echo "=================== report.md PREVIEW ==================="
cat "$HOME/FaceScan/reports/0609_1650/report.md"
