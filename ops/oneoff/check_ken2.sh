echo "=== ken2_lidar render.log (tail) ==="
tr '\r' '\n' < "$HOME/FaceScan/initstudy/out_ken2_lidar.render.log" 2>/dev/null | grep -vE '^$' | tail -8
echo "=== ken2_lidar model + mesh artifacts ==="
ls -la "$HOME/FaceScan/initstudy/out_ken2_lidar/point_cloud/"*/ 2>/dev/null | tail -3
ls -la "$HOME/FaceScan/initstudy/out_ken2_lidar/train/ours_10000/fuse_post.ply" 2>/dev/null || echo "no fuse_post.ply (render did not finish)"
echo "=== ken2 DATA_ROOT seed state ==="
DR="$HOME/FaceScan/work/face_scan/Scan_ken2_20260611_173913_cropped"
ls -la "$DR/points3d.ply" "$DR/points3D.ply" 2>/dev/null
echo "DR=$DR"
