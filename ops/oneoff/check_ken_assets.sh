K="/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped"
echo "=== photogrammetry/ (Object Capture output?) ==="
ls -la "$K/photogrammetry" 2>/dev/null
echo "=== any meshes (.ply/.obj/.usdz) anywhere in the scan ==="
find "$K" -maxdepth 2 -iregex '.*\.\(ply\|obj\|usdz\|stl\)$' 2>/dev/null
echo "=== crop.json ==="
cat "$K/crop.json" 2>/dev/null
