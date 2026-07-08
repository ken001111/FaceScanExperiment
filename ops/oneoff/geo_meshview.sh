#!/bin/bash
# Render the extracted mesh from training camera poses (frame 50 + 2 others).
source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import numpy as np, open3d as o3d, os, json
m = o3d.io.read_triangle_mesh(os.path.expanduser("~/geosvr_best.ply"))
m.compute_vertex_normals()
t = json.load(open(os.path.expanduser("~/FaceScan/work/face_scan/transforms_train.json")))
W, H = 960, 720
fx = 0.5 * W / np.tan(0.5 * t.get("camera_angle_x", 1.0)) if "camera_angle_x" in t else t.get("fl_x", 700.0)
if "fl_x" in t: fx = t["fl_x"]
fy = t.get("fl_y", fx)
# transforms use full-res intrinsics; renders were r2.0 (960x720 from 1920x1440)
sc = W / t.get("w", 1920)
intr = o3d.camera.PinholeCameraIntrinsic(W, H, fx*sc, fy*sc, W/2-0.5, H/2-0.5)
r = o3d.visualization.rendering.OffscreenRenderer(W, H)
mat = o3d.visualization.rendering.MaterialRecord(); mat.shader = "defaultLit"
mat.base_color = [0.75, 0.75, 0.78, 1.0]
r.scene.add_geometry("m", m, mat); r.scene.set_background([1, 1, 1, 1])
r.scene.scene.set_sun_light([0.3, -0.4, -0.6], [1, 1, 1], 90000)
r.scene.scene.enable_sun_light(True)
OUT = "/mnt/c/Users/m352395/Downloads/mesh_previews"
for idx in (50, 20, 75):
    c2w = np.array(t["frames"][idx]["transform_matrix"], dtype=np.float64)
    c2w[:3, 1] *= -1; c2w[:3, 2] *= -1          # nerf(OpenGL) -> OpenCV
    c2w[:3, 3] *= 100.0                          # scene units -> mm (mesh was scaled x100)
    extr = np.linalg.inv(c2w)
    r.setup_camera(intr, extr)
    o3d.io.write_image(f"{OUT}/meshcam_{idx}.png", r.render_to_image())
    print("rendered", idx, t["frames"][idx]["file_path"])
PY
