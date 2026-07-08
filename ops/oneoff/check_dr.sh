echo "=== ~/FaceScan/work/face_scan ==="
ls -la "$HOME/FaceScan/work/face_scan/" 2>/dev/null
echo "=== ken2 subdir (if any) ==="
DR="$HOME/FaceScan/work/face_scan/Scan_ken2_20260611_173913_cropped"
ls -la "$DR" 2>/dev/null | head
echo "  transforms_train.json: $([ -f "$DR/transforms_train.json" ] && echo yes || echo NO)"
echo "  images: $(ls "$DR/images" 2>/dev/null | wc -l)  points3D.ply: $([ -f "$DR/points3D.ply" ] && echo yes || echo NO)"
