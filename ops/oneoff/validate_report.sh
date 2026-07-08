tr -d '\r' < /mnt/c/Users/m352395/Downloads/make_report.py > "$HOME/FaceScan/bin/make_report.py"
"$HOME/miniconda3/envs/facescan/bin/python" -m py_compile "$HOME/FaceScan/bin/make_report.py" && echo "make_report.py compiles OK"
bash "$HOME/FaceScan/bin/make_report.sh" 2>&1 | tail -3
echo "--- GPU section of report ---"
sed -n '/GPU usage/,/Training/p' "$HOME/FaceScan/reports/0609_1650/report.md"
