L=~/SuGaR/output/sugar_face_scan_coarse.log
echo "=== extract markers / errors (text mode) ==="
grep -ainE "foreground points|background points|poisson|Traceback|Error|RuntimeError|out of memory|Mesh saved|COARSE_MESH|cluster_connected|empty|Computing points|Decimating" "$L" | tr -d '\000' | tail -25
echo "=== last 8 non-blank lines ==="
tr -d '\000' < "$L" | tr '\r' '\n' | grep -av '^[[:space:]]*$' | tail -8
