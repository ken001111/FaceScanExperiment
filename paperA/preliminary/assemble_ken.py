#!/usr/bin/env python
"""Assemble EXPDATA/ken for the no-CT/no-SL experiment.

References: ken has no CAD frame and no structured-light scan, so we use the
**2DGS reconstruction as an in-frame stand-in reference** (all our GS-family
reconstructions share the prep frame, so they are directly comparable). Object
Capture lives in a foreign frame and is registered in (RANSAC+ICP).
"""
import open3d as o3d, numpy as np, copy, os, shutil

HOME = os.path.expanduser("~")
EXP = os.path.join(HOME, "FaceScan/EXPDATA")
KEN = os.path.join(EXP, "ken")
RES = os.path.join(HOME, "FaceScan/results")
DR = os.path.join(HOME, "FaceScan/work/face_scan")
OC = "/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped/photogrammetry/face_nn.ply"
TWODGS = os.path.join(RES, "Face_Mesh_MetricScale_exp_kentest_2dgs_nn.ply")

for sub in ["methods", "reference", "init/lidar", "init/random"]:
    os.makedirs(os.path.join(KEN, sub), exist_ok=True)


def save_xyz(m, path):
    m.vertex_colors = o3d.utility.Vector3dVector()
    m.vertex_normals = o3d.utility.Vector3dVector()
    m.triangle_normals = o3d.utility.Vector3dVector()
    o3d.io.write_triangle_mesh(path, m, write_vertex_colors=False, write_vertex_normals=False)


def largest(m):
    c = m.cluster_connected_triangles(); tc, nt = np.asarray(c[0]), np.asarray(c[1])
    if len(nt):
        m.remove_triangles_by_mask(tc != int(np.argmax(nt))); m.remove_unreferenced_vertices()
    return m


def ext(m):
    return np.round(np.asarray(m.get_axis_aligned_bounding_box().get_extent()), 1)


sf = float(open(os.path.join(DR, "scale_factor.txt")).read())

# reference = 2DGS proxy (both slots) + 2dgs as a method (self-consistency baseline)
shutil.copy(TWODGS, os.path.join(KEN, "reference/cad_frame.ply"))
shutil.copy(TWODGS, os.path.join(KEN, "reference/structured_light.ply"))
shutil.copy(TWODGS, os.path.join(KEN, "methods/2dgs.ply"))
shutil.copy(os.path.expanduser("~/3dgs_test.ply"), os.path.join(KEN, "methods/3dgs.ply"))
shutil.copy(os.path.expanduser("~/sugar_test.ply"), os.path.join(KEN, "methods/sugar.ply"))
shutil.copy(os.path.join(RES, "Face_Mesh_MetricScale_ken_lidar_nn.ply"), os.path.join(KEN, "init/lidar/mesh.ply"))
shutil.copy(os.path.join(RES, "Face_Mesh_MetricScale_ken_random_nn.ply"), os.path.join(KEN, "init/random/mesh.ply"))
print("copied: 2dgs (ref+method), 3dgs, sugar, init lidar/random")

# raw_lidar: Poisson of the in-frame LiDAR seed (points3d.ply, training units) -> mm
cl = o3d.io.read_point_cloud(os.path.join(DR, "points3d.ply"))
cl.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=0.1, max_nn=30))
cl.orient_normals_consistent_tangent_plane(20)
m, dens = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(cl, depth=9)
dens = np.asarray(dens); m.remove_vertices_by_mask(dens < np.quantile(dens, 0.05))
m = largest(m); m.scale(1000.0 / sf, center=(0, 0, 0))
save_xyz(m, os.path.join(KEN, "methods/raw_lidar.ply"))
print("raw_lidar:", len(m.vertices), "verts, extent", ext(m))

open(os.path.join(EXP, "specimens.csv"), "w").write("specimen,arm\nken,cadaver\n")

# --- crop every mesh to a common region so distances measure SURFACE agreement,
#     not how much background/body each method happens to include ---
ref = o3d.io.read_triangle_mesh(os.path.join(KEN, "reference/structured_light.ply"))
bb = ref.get_axis_aligned_bounding_box()
margin = 15.0
box = o3d.geometry.AxisAlignedBoundingBox(bb.min_bound - margin, bb.max_bound + margin)
print(f"\ncrop box (2DGS bbox + {margin:.0f}mm): min {np.round(box.min_bound,0)} max {np.round(box.max_bound,0)}")
targets = [os.path.join(KEN, "methods", f) for f in os.listdir(os.path.join(KEN, "methods"))]
targets += [os.path.join(KEN, "init/lidar/mesh.ply"), os.path.join(KEN, "init/random/mesh.ply")]
for p in targets:
    m = o3d.io.read_triangle_mesh(p)
    n0 = len(m.vertices)
    m = m.crop(box)
    save_xyz(m, p)
    print(f"  cropped {os.path.basename(os.path.dirname(p))}/{os.path.basename(p):20s} {n0:>8} -> {len(m.vertices):>8} verts")

print("\nEXPDATA/ken assembled. methods:", sorted(os.listdir(os.path.join(KEN, "methods"))))
