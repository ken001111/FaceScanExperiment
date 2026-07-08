echo "=== svraster train.py argparse (update_argparser) ==="
grep -nE "def update_argparser|add_argument|cfg_files|source_path|model_path" ~/svraster/src/config.py | head -20
echo "=== bounding modes ==="
grep -nE "bound_mode|def |camera|forward|pcd" ~/svraster/src/utils/bounding_utils.py | head -25
echo "=== svraster README quickstart (train + mesh) ==="
grep -nE "python train|python extract_mesh|python render|--cfg|--source" ~/svraster/README.md | head -15
echo "=== synthetic_nerf.yaml ==="
cat ~/svraster/cfg/synthetic_nerf.yaml
echo "=== geosvr README quickstart ==="
grep -nE "python train|python mesh_extract|python render|--cfg|--source|prior|depth" ~/geosvr/README.md | head -25
echo "=== geosvr dtu_mesh.yaml ==="
cat ~/geosvr/cfg/dtu_mesh.yaml 2>/dev/null | head -50
