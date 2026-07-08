D="$HOME/FaceScan/work/face_scan/Scan__20260529_094706_cropped"
echo "--- dir contents ---"
ls -la "$D" | head -20
echo "--- masks count ---"
ls "$D/masks" 2>/dev/null | wc -l
echo "--- image count ---"
ls "$D/images" 2>/dev/null | wc -l
echo "--- file type of first images ---"
file "$D/images/frame_00000.png" "$D/images/frame_00001.png" 2>/dev/null
echo "--- transforms frames ---"
grep -c file_path "$D/transforms_train.json" 2>/dev/null
