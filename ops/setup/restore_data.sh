#!/bin/bash
ODIR="/mnt/c/Users/m352395/OneDrive - Mayo Clinic/PrecisionSurgery/2DGS/Experiment"
LOG="$HOME/restore.log"
echo "START $(date)" > "$LOG"
echo "ODIR=$ODIR" >> "$LOG"
ls -la "$ODIR"/*.tar >> "$LOG" 2>&1
cd "$HOME" || exit 1
rc=0
for t in "$ODIR"/*.tar; do
  echo "[extract] $(basename "$t") $(date)" >> "$LOG"
  if ! tar -xf "$t" >> "$LOG" 2>&1; then
    echo "  FAILED $(basename "$t")" >> "$LOG"
    rc=1
  fi
done
[ -d "$HOME/FaceScan/pe_verify" ] && mv "$HOME/FaceScan/pe_verify" "$HOME/" 2>/dev/null
[ -d "$HOME/pe_verify" ] || { [ -d "$HOME/FaceScan/paperB/pe_verify" ] && cp -r "$HOME/FaceScan/paperB/pe_verify" "$HOME/" 2>/dev/null; }
echo "ALLDONE rc=$rc $(date)" >> "$LOG"
echo "=== ~ after extract ===" >> "$LOG"
ls -la "$HOME" >> "$LOG" 2>&1
echo "=== ~/FaceScan ===" >> "$LOG"
ls -la "$HOME/FaceScan" >> "$LOG" 2>&1
exit $rc
