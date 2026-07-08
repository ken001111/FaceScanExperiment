"""
Statistics for the paper's results tables: mean +/- SD, 95% bootstrap CIs, and
paired Wilcoxon signed-rank tests (2DGS vs each baseline) with Holm correction.

Requires numpy; uses scipy.stats.wilcoxon if available, else a numpy fallback.
"""
import numpy as np

try:
    from scipy.stats import wilcoxon as _scipy_wilcoxon
    _HAVE_SCIPY = True
except Exception:
    _HAVE_SCIPY = False


def bootstrap_ci(values, n_boot=10000, alpha=0.05, seed=0):
    """Percentile bootstrap CI for the mean of `values`."""
    v = np.asarray(values, float)
    v = v[~np.isnan(v)]
    if v.size == 0:
        return (float('nan'), float('nan'))
    rng = np.random.default_rng(seed)
    means = v[rng.integers(0, v.size, size=(n_boot, v.size))].mean(axis=1)
    lo, hi = np.percentile(means, [100 * alpha / 2, 100 * (1 - alpha / 2)])
    return float(lo), float(hi)


def summarize(values, n_boot=10000):
    """mean, SD, n, and 95% bootstrap CI of a list of per-specimen values."""
    v = np.asarray(values, float)
    v = v[~np.isnan(v)]
    lo, hi = bootstrap_ci(v, n_boot)
    return dict(mean=float(v.mean()) if v.size else float('nan'),
                sd=float(v.std(ddof=1)) if v.size > 1 else 0.0,
                n=int(v.size), ci_lo=lo, ci_hi=hi)


def wilcoxon_p(a, b):
    """Two-sided paired Wilcoxon signed-rank p-value for paired samples a,b."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    m = ~(np.isnan(a) | np.isnan(b))
    a, b = a[m], b[m]
    if a.size < 1 or np.allclose(a, b):
        return float('nan')
    if _HAVE_SCIPY:
        try:
            return float(_scipy_wilcoxon(a, b, zero_method='wilcox', alternative='two-sided').pvalue)
        except Exception:
            return float('nan')
    # numpy fallback: normal approximation of the signed-rank statistic
    d = a - b
    d = d[d != 0]
    if d.size == 0:
        return float('nan')
    r = np.argsort(np.argsort(np.abs(d))) + 1.0
    W = float(np.sum(r[d > 0]))
    n = d.size
    mu = n * (n + 1) / 4.0
    sigma = np.sqrt(n * (n + 1) * (2 * n + 1) / 24.0)
    if sigma == 0:
        return float('nan')
    z = (W - mu) / sigma
    from math import erfc, sqrt
    return float(erfc(abs(z) / sqrt(2)))


def holm_correction(pvals):
    """Holm-Bonferroni step-down adjusted p-values (same order as input)."""
    p = np.asarray(pvals, float)
    order = np.argsort(np.where(np.isnan(p), np.inf, p))
    m = np.sum(~np.isnan(p))
    adj = np.full_like(p, np.nan)
    running = 0.0
    for rank, idx in enumerate(order):
        if np.isnan(p[idx]):
            continue
        val = (m - rank) * p[idx]
        running = max(running, val)
        adj[idx] = min(running, 1.0)
    return adj


def paired_tests_vs_reference(per_method_values, reference_key, baseline_keys):
    """Holm-corrected paired Wilcoxon of `reference_key` vs each baseline.

    per_method_values: {method: [per-specimen value, ...]} (aligned by specimen).
    Returns {baseline_key: holm_adjusted_p}.
    """
    ref = per_method_values[reference_key]
    raw = [wilcoxon_p(ref, per_method_values[k]) for k in baseline_keys]
    adj = holm_correction(raw)
    return {k: adj[i] for i, k in enumerate(baseline_keys)}
