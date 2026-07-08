"""
Shared surface-evaluation utilities for the LiDAR-Guided 2DGS paper experiments.

Implements the paper's surface metric: point-to-surface distance after rigid
registration, summarized as mean / RMS / 95th percentile / Hausdorff / %<1mm.
Used by Table 1 (Tier 0), Table 2 (Tier 1), Figure 2, Table 3, Figure 3.

All meshes/clouds are assumed to be in **millimeters** (the pipeline's `_nn.ply`
output already is). Requires: numpy, open3d.  Stats live in stats_util.py.
"""
import numpy as np
import open3d as o3d


# --------------------------------------------------------------------------- #
# Loading
# --------------------------------------------------------------------------- #
def load_mesh(path):
    """Read a triangle mesh (mm). Returns an Open3D legacy TriangleMesh."""
    m = o3d.io.read_triangle_mesh(str(path))
    if len(m.triangles) == 0:
        raise ValueError(f'{path}: no triangles (need a mesh, not a point cloud)')
    m.compute_vertex_normals()
    return m


def as_points(path_or_geom, n_sample=200_000):
    """Return an (N,3) float array of surface points.

    A mesh is densely surface-sampled; a point cloud is returned as-is.
    """
    if isinstance(path_or_geom, (str,)) or hasattr(path_or_geom, '__fspath__'):
        m = o3d.io.read_triangle_mesh(str(path_or_geom))
        if len(m.triangles) > 0:
            pcd = m.sample_points_uniformly(number_of_points=n_sample)
            return np.asarray(pcd.points)
        pcd = o3d.io.read_point_cloud(str(path_or_geom))
        return np.asarray(pcd.points)
    # already a geometry
    g = path_or_geom
    if isinstance(g, o3d.geometry.TriangleMesh):
        return np.asarray(g.sample_points_uniformly(n_sample).points)
    return np.asarray(g.points)


def _to_pcd(pts):
    p = o3d.geometry.PointCloud()
    p.points = o3d.utility.Vector3dVector(np.asarray(pts, dtype=np.float64))
    p.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=5.0, max_nn=30))
    return p


# --------------------------------------------------------------------------- #
# Registration
# --------------------------------------------------------------------------- #
def rigid_align(src_pts, dst_pts, threshold_mm=5.0, init=None):
    """Rigid (R,t) aligning src points onto dst points via point-to-plane ICP.

    Returns the 4x4 transform. Use before scoring (paper: 'after rigid
    registration'). For absolute-truth comparisons where the recon is already
    in the reference frame, pass align=False at the call site instead.
    """
    src = _to_pcd(src_pts)
    dst = _to_pcd(dst_pts)
    T0 = np.eye(4) if init is None else np.asarray(init)
    reg = o3d.pipelines.registration.registration_icp(
        src, dst, threshold_mm, T0,
        o3d.pipelines.registration.TransformationEstimationPointToPlane(),
        o3d.pipelines.registration.ICPConvergenceCriteria(max_iteration=200))
    return reg.transformation


def apply_T(pts, T):
    pts = np.asarray(pts)
    return (T[:3, :3] @ pts.T).T + T[:3, 3]


# --------------------------------------------------------------------------- #
# Distances + metrics
# --------------------------------------------------------------------------- #
def point_to_mesh_mm(points, ref_mesh):
    """Unsigned point-to-surface distance (mm) from points to a triangle mesh."""
    scene = o3d.t.geometry.RaycastingScene()
    scene.add_triangles(o3d.t.geometry.TriangleMesh.from_legacy(ref_mesh))
    q = o3d.core.Tensor(np.asarray(points, np.float32))
    return scene.compute_distance(q).numpy()


def surface_metrics(d_mm):
    """Paper's surface metrics from an array of point-to-surface distances (mm)."""
    d = np.asarray(d_mm, dtype=np.float64)
    return dict(
        mean=float(d.mean()),
        rms=float(np.sqrt(np.mean(d ** 2))),
        p95=float(np.percentile(d, 95)),
        hausdorff=float(d.max()),
        pct_under_1mm=float(np.mean(d < 1.0) * 100.0),
        n=int(d.size),
    )


def evaluate(recon, reference, align=True, sample=200_000, region_mask=None):
    """Score a reconstruction against a reference mesh.

    recon, reference : paths (or geometries). reference must be a mesh.
    region_mask      : optional boolean array over the sampled recon points
                       (e.g. frame-only or face-only) — see assign_region().
    Returns (metrics dict, per_point_distances_mm, aligned_points).
    """
    pts = as_points(recon, sample)
    ref_mesh = load_mesh(reference) if not isinstance(reference, o3d.geometry.TriangleMesh) else reference
    if region_mask is not None:
        pts = pts[np.asarray(region_mask, bool)]
    if align:
        ref_pts = as_points(ref_mesh, sample)
        T = rigid_align(pts, ref_pts)
        pts = apply_T(pts, T)
    d = point_to_mesh_mm(pts, ref_mesh)
    return surface_metrics(d), d, pts


def assign_region(points, frame_ref, face_ref):
    """Split points into frame vs face by nearest reference (both are meshes).

    Returns (frame_mask, face_mask) boolean arrays. Used when no explicit region
    labels are provided: a point belongs to whichever reference it is closer to.
    """
    df = point_to_mesh_mm(points, frame_ref)
    dc = point_to_mesh_mm(points, face_ref)
    frame_mask = df <= dc
    return frame_mask, ~frame_mask


# --------------------------------------------------------------------------- #
# Error → color (for heat-map figures, shared 0..vmax mm scale)
# --------------------------------------------------------------------------- #
def error_colors(d_mm, vmax=5.0, cmap='turbo'):
    import matplotlib.cm as cm
    import matplotlib.colors as mcolors
    norm = mcolors.Normalize(vmin=0.0, vmax=vmax, clip=True)
    return cm.get_cmap(cmap)(norm(np.asarray(d_mm)))[:, :3]


def save_error_heatmap_ply(points, d_mm, out_path, vmax=5.0):
    """Write a colored point cloud (per-point error heat-map) for 3D viewing."""
    pcd = o3d.geometry.PointCloud()
    pcd.points = o3d.utility.Vector3dVector(np.asarray(points, np.float64))
    pcd.colors = o3d.utility.Vector3dVector(error_colors(d_mm, vmax))
    o3d.io.write_point_cloud(str(out_path), pcd)


# Canonical method order / labels for the comparison tables & figures.
METHODS = [
    ('raw_lidar',      'Raw LiDAR mesh'),
    ('3dgs',           '3DGS + TSDF'),
    ('sugar',          'SuGaR'),
    ('2dgs',           '2DGS (ours)'),
    ('structured_light', 'Structured light (ref)'),
]
CONSUMER_METHODS = ['raw_lidar', '3dgs', 'sugar', '2dgs']
INITS = [('sfm', 'SfM (COLMAP)'), ('random', 'Random'), ('lidar', 'LiDAR (ours)')]


# --------------------------------------------------------------------------- #
# §0-complete metric set (Experiment_Plans_PaperA_and_PaperB): completeness,
# symmetric Chamfer, F-score at multiple thresholds, normal error, full stats.
# --------------------------------------------------------------------------- #
def full_stats(d_mm):
    """mean / RMS / median / p90 / p95 / hausdorff / %<0.5 / %<1mm."""
    d = np.asarray(d_mm, np.float64)
    return dict(
        mean=float(d.mean()),
        rms=float(np.sqrt(np.mean(d ** 2))),
        median=float(np.median(d)),
        p90=float(np.percentile(d, 90)),
        p95=float(np.percentile(d, 95)),
        hausdorff=float(d.max()),
        pct_under_05mm=float(np.mean(d < 0.5) * 100.0),
        pct_under_1mm=float(np.mean(d < 1.0) * 100.0),
        n=int(d.size),
    )


def fscore(d_acc, d_comp, taus=(0.25, 0.5, 1.0, 2.0)):
    """F-score at thresholds (mm): precision from recon->GT, recall from GT->recon."""
    out = {}
    for t in taus:
        p = float(np.mean(np.asarray(d_acc) < t))
        r = float(np.mean(np.asarray(d_comp) < t))
        out[f"fscore@{t}"] = 0.0 if (p + r) == 0 else 2 * p * r / (p + r)
    return out


def normal_error_deg(recon_mesh, ref_mesh, sample=100_000):
    """Mean angular error (deg) between recon normals and nearest-ref normals."""
    rp = recon_mesh.sample_points_uniformly(sample) if isinstance(recon_mesh, o3d.geometry.TriangleMesh) else None
    if rp is None:
        raise ValueError("normal_error_deg expects meshes")
    ref_p = ref_mesh.sample_points_uniformly(sample)
    ref_kd = o3d.geometry.KDTreeFlann(ref_p)
    rn = np.asarray(rp.normals); rq = np.asarray(rp.points)
    refn = np.asarray(ref_p.normals)
    angs = []
    for i in range(0, len(rq), 1):
        _, idx, _ = ref_kd.search_knn_vector_3d(rq[i], 1)
        c = abs(float(np.dot(rn[i], refn[idx[0]])))
        angs.append(np.degrees(np.arccos(np.clip(c, -1, 1))))
    return float(np.mean(angs))


def evaluate_full(recon, reference, align=True, sample=200_000, icp_threshold_mm=5.0,
                  taus=(0.25, 0.5, 1.0, 2.0), with_normals=False):
    """Complete §0 evaluation: accuracy, completeness, Chamfer, F-scores, stats.

    Returns dict with acc_* (recon->GT), comp_* (GT->recon), chamfer,
    fscore@tau, and optionally normal_deg. Alignment is scale-FIXED rigid ICP
    (recon -> reference); the applied transform is returned as 'T'.
    """
    recon_mesh = load_mesh(recon) if not isinstance(recon, o3d.geometry.TriangleMesh) else recon
    ref_mesh = load_mesh(reference) if not isinstance(reference, o3d.geometry.TriangleMesh) else reference
    pts = as_points(recon_mesh, sample)
    T = np.eye(4)
    if align:
        T = rigid_align(pts, as_points(ref_mesh, sample), threshold_mm=icp_threshold_mm)
        pts = apply_T(pts, T)
        recon_mesh = o3d.geometry.TriangleMesh(recon_mesh)
        recon_mesh.transform(T)
    d_acc = point_to_mesh_mm(pts, ref_mesh)                       # accuracy
    ref_pts = as_points(ref_mesh, sample)
    d_comp = point_to_mesh_mm(ref_pts, recon_mesh)                # completeness
    out = {("acc_" + k): v for k, v in full_stats(d_acc).items()}
    out.update({("comp_" + k): v for k, v in full_stats(d_comp).items()})
    out["chamfer"] = 0.5 * (out["acc_mean"] + out["comp_mean"])
    out.update(fscore(d_acc, d_comp, taus))
    if with_normals:
        out["normal_deg"] = normal_error_deg(recon_mesh, ref_mesh, sample=min(sample, 50_000))
    out["T"] = T.tolist()
    return out, d_acc, pts
