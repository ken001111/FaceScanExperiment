echo "############ SVRASTER ############"
echo "=== train.py head (CLI) ==="; sed -n '1,60p' ~/svraster/train.py | grep -nE "import|argparse|add_argument|cfg|config" | head -20
echo "=== cfg files ==="; ls ~/svraster/cfg/
echo "=== default cfg (voxel/bound params) ==="; grep -nE "voxel|bound|level|fov|scene|max_|init_|sh_deg|lambda|iteration|white" ~/svraster/src/config.py 2>/dev/null | head -40
echo "=== data loaders ==="; ls ~/svraster/src/dataloader/ 2>/dev/null; grep -rn "transforms_train\|blender\|nerf" ~/svraster/src/dataloader/*.py 2>/dev/null | head -8
echo "=== extract_mesh.py args ==="; grep -nE "add_argument" ~/svraster/extract_mesh.py | head -20
echo
echo "############ GEOSVR ############"
echo "=== environment.yml ==="; cat ~/geosvr/environment.yml
echo "=== cfg files ==="; ls ~/geosvr/cfg/
echo "=== default cfg (voxel/bound) ==="; grep -nE "voxel|bound|level|fov|scene|max_|init_|iteration|white" ~/geosvr/src/config.py 2>/dev/null | head -40
echo "=== mesh_extract ==="; ls ~/geosvr/mesh_extract/; grep -nE "add_argument" ~/geosvr/mesh_extract/*.py 2>/dev/null | head -20
