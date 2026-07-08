echo "=== how 2DGS inits (dataset_readers.py, readNerfSyntheticInfo) ==="
grep -n "points3d\|points3D\|random point cloud\|num_pts\|def readNerfSyntheticInfo\|fetchPly\|storePly\|ply_path" ~/2d-gaussian-splatting/scene/dataset_readers.py | head -40
echo ""
echo "=== prepped scan dir contents (look for LiDAR cloud) ==="
ls -la ~/FaceScan/work/face_scan/*/ 2>/dev/null | grep -iE 'ply|points|depth'
echo ""
echo "=== raw ken2 zip — does it ship a points3D.ply / depth? ==="
unzip -l /mnt/c/Users/m352395/Downloads/Scan_ken2_*.zip 2>/dev/null | grep -iE 'points3d|\.ply|depth|crop' | head -20
