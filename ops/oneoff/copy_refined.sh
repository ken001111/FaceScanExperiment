D=~/SuGaR/output/refined_mesh/face_scan
CMP=/mnt/c/Users/m352395/Downloads/mesh_compare
cp "$D"/*.obj "$CMP/sugar_refined_textured.obj"
cp "$D"/*.mtl "$CMP/sugar_refined_textured.mtl" 2>/dev/null
cp "$D"/*.png "$CMP/sugar_refined_textured.png" 2>/dev/null
echo "=== sugar/3dgs/2dgs files in mesh_compare ==="
ls -la "$CMP" | grep -iE "sugar|3dgs|2dgs"
