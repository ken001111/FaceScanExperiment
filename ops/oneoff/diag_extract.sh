L=~/SuGaR/output/sugar_face_scan_coarse.log
echo "=== extract markers / errors ==="
grep -inE "foreground points|background points|poisson|Traceback|Error|RuntimeError|out of memory|Mesh saved|COARSE_MESH|cluster_connected|empty|Computing points" "$L" | tail -25
echo "=== last 6 non-blank lines ==="
grep -v '^[[:space:]]*$' "$L" | tail -6
