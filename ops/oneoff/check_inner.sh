for d in "/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped" \
         "/mnt/c/Users/m352395/Downloads/Scan_ken2_20260611_173913_cropped-E657D0B3-7317-4077-B715-F79FFB641FA6/Scan_ken2_20260611_173913_cropped"; do
  echo "=== $d ==="
  ls "$d" 2>/dev/null | head
  echo "  images: $(ls "$d/images" 2>/dev/null | wc -l)  masks: $(ls "$d/masks" 2>/dev/null | wc -l)  points3D.ply: $([ -f "$d/points3D.ply" ] && echo yes || echo NO)  transforms.json: $([ -f "$d/transforms.json" ] && echo yes || echo NO)"
done
