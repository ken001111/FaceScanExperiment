#!/bin/bash
# Append the §0-complete metric set to pe_verify/common/eval_common.py
set -e
python3 - <<'PY'
import os
p = os.path.expanduser("~/pe_verify/common/eval_common.py")
s = open(p).read()
if "def evaluate_full" in s:
    print("already extended"); raise SystemExit
s += '''

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
'''
open(p, "w").write(s)
print("extended:", p)
PY
