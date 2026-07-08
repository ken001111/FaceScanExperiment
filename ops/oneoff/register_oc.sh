source ~/miniconda3/etc/profile.d/conda.sh; conda activate facescan
python - <<'PY'
import open3d as o3d, numpy as np, copy, os
def load(f): return o3d.io.read_triangle_mesh(os.path.expanduser(f))
twodgs=load("~/FaceScan/results/Face_Mesh_MetricScale_exp_kentest_2dgs_nn.ply")
oc=load("/mnt/c/Users/m352395/Downloads/Scan_Ken _20260611_163306_cropped-299678C5-5256-4751-98C5-B6382F71F9D7/Scan_Ken _20260611_163306_cropped/photogrammetry/face_nn.ply")
# OC largest component
c=oc.cluster_connected_triangles(); tc,nt=np.asarray(c[0]),np.asarray(c[1])
oc.remove_triangles_by_mask(tc!=int(np.argmax(nt))); oc.remove_unreferenced_vertices()

src=oc.sample_points_uniformly(60000)          # OC head
tgt=twodgs.sample_points_uniformly(60000)      # our frame
# coarse: align centroids
src.translate(tgt.get_center()-src.get_center())
vs=5.0
sd=src.voxel_down_sample(vs); td=tgt.voxel_down_sample(vs)
for p in (sd,td): p.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=vs*2,max_nn=30))
fs=o3d.pipelines.registration.compute_fpfh_feature(sd,o3d.geometry.KDTreeSearchParamHybrid(radius=vs*5,max_nn=100))
ft=o3d.pipelines.registration.compute_fpfh_feature(td,o3d.geometry.KDTreeSearchParamHybrid(radius=vs*5,max_nn=100))
res=o3d.pipelines.registration.registration_ransac_based_on_feature_matching(
    sd,td,fs,ft,True,vs*1.5,
    o3d.pipelines.registration.TransformationEstimationPointToPoint(False),3,
    [o3d.pipelines.registration.CorrespondenceCheckerBasedOnEdgeLength(0.9),
     o3d.pipelines.registration.CorrespondenceCheckerBasedOnDistance(vs*1.5)],
    o3d.pipelines.registration.RANSACConvergenceCriteria(400000,1000))
icp=o3d.pipelines.registration.registration_icp(src,tgt,8.0,res.transformation,
    o3d.pipelines.registration.TransformationEstimationPointToPlane()) if src.has_normals() else None
src.estimate_normals(); tgt.estimate_normals()
icp=o3d.pipelines.registration.registration_icp(src,tgt,8.0,res.transformation,
    o3d.pipelines.registration.TransformationEstimationPointToPlane())
print(f"RANSAC fitness={res.fitness:.3f} rmse={res.inlier_rmse:.2f}")
print(f"ICP    fitness={icp.fitness:.3f} rmse={icp.inlier_rmse:.2f}mm  (fitness=overlap frac, want >0.3)")
PY
