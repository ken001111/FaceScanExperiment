D="$HOME/FaceScan/work/face_scan/Scan__20260529_094706_cropped"
echo "--- first 5 image names ---"
ls "$D/images" | head -5
echo "--- first 5 mask names ---"
ls "$D/masks" | head -5
echo "--- mask file type ---"
file "$D/masks/$(ls "$D/masks" | head -1)"
