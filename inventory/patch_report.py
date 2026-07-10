#!/usr/bin/env python
"""Fill Paper B ablation results into the inventory report."""
import os, re

p = os.path.expanduser("~/facescan-experiments/inventory/build_report.py")
s = open(p).read()

s = s.replace("living inventory · v3 (2026-07-08)", "living inventory · v4 (2026-07-09)")

s = s.replace(
    """<p class="sub">GeoSVR fork on ARKitScenes scene 47331963 (+ scene 2 TBD), scored vs Faro laser GT
with the validated §0 library. Raw frames throughout (no masking).</p>""",
    """<p class="sub">GeoSVR fork on ARKitScenes scene 41069021 (2,036 frames, Faro laser GT), 20k iters/arm,
identical configs except the depth term. Protocol: traversal-region crop (GT within 3&#8202;m of camera path),
100&#8202;mm laser-support crop on accuracy (GT lacks ceiling), per-arm 20&#8202;mm ICP. Scene 41069042 trained
(all 5 arms) awaiting proxy eval. Full protocol audit trail in paperB/score_41069021_v1&#8211;v6.py.</p>""")

old_tbl = re.search(
    r'<div class="tablewrap"><table>\n<tr><th>Depth source</th>.*?</table></div>', s, re.S).group(0)
new_tbl = """<div class="tablewrap"><table>
<tr><th>Depth source</th><th>Accuracy ↓</th><th>Completeness ↓</th><th>Chamfer ↓</th><th>F@1cm ↑</th><th>F@2cm ↑</th><th>Status</th></tr>
<tr><td>No depth term</td><td>41.6</td><td>307.6</td><td>174.6</td><td>0.104</td><td>0.212</td><td><span class="chip ok">done</span></td></tr>
<tr><td>Monocular (DepthAnythingV2)</td><td>46.3</td><td>397.7</td><td>222.0</td><td>0.088</td><td>0.178</td><td><span class="chip fail">worse than no depth</span></td></tr>
<tr><td><b>Measured LiDAR</b></td><td><b>34.2</b></td><td><b>266.8</b></td><td><b>150.5</b></td><td><b>0.166</b></td><td><b>0.336</b></td><td><span class="chip ok">best on rooms</span></td></tr>
<tr><td><b>Measured LiDAR + confidence</b></td><td>35.7</td><td>268.2</td><td>151.9</td><td>0.156</td><td>0.317</td><td><span class="chip ok">done</span></td></tr>
<tr><td><b>Fused mono+LiDAR (ours)</b></td><td>36.7</td><td>270.2</td><td>153.5</td><td>0.143</td><td>0.292</td><td><span class="chip warn">≈ LiDAR here; face-capture test pending</span></td></tr>
</table></div>
<p>mm / F-score. Read of record: <b>metric anchoring validated</b> (LiDAR-anchored arms halve median completeness,
82&#8211;96&#8202;mm &#8594; 39&#8211;44&#8202;mm in the well-observed region); <b>mono-alone is actively harmful</b> (scale drift shrinks
the scene); <b>fused &#8776; raw LiDAR in this LiDAR-optimal regime</b> &#8212; only 0.2% of observed GT is LiDAR-degraded,
so the fusion upside has no arena in rooms. Its test bed is the face captures (close range, hair, specular skin).</p>
{grid("paperb")}"""
s = s.replace(old_tbl, new_tbl)

s = s.replace(
    '''data/arkit (4.8G, downloading)                      ARKitScenes 47331963: RGB + LiDAR depth + confidence + Faro laser GT"""''',
    '''work/arkit_41069042 + 41069021 + _fused (3 dirs)    ARKitScenes converted: RGB+depth+conf+DAV2 priors+transforms (raw downloads deleted)
paperB/ablation + ablation_41069021 (2 scenes x 5)  20k checkpoints + TSDF meshes + eval_vs_laser_v6 / region_split JSONs
paperB/gt_cache/gt_41069021_highres.ply             Faro laser GT cloud (4.0M pts, frame-rendered coverage)"""''')

s = s.replace(
    '''    (f"{DL}/fig3_previews/init_lidar_0.png",     "Init: LiDAR seed (54.9k pts)", "init"),
]''',
    '''    (f"{DL}/fig3_previews/init_lidar_0.png",     "Init: LiDAR seed (54.9k pts)", "init"),
    (f"{DL}/ablation_figs/fig1_coverage.png",     "Coverage: 5 arms vs laser GT (mono shrinkage visible)", "paperb"),
    (f"{DL}/ablation_figs/fig2_comp_heatmap.png", "Completeness heatmap: where each arm misses", "paperb"),
    (f"{DL}/ablation_figs/fig3_metrics.png",      "F-scores · median completeness · support fraction", "paperb"),
    (f"{DL}/ablation_figs/fig4_elevation.png",    "Elevation: mono warp vs fused fit", "paperb"),
]''')

s = s.replace('cards = {"dtu": [], "ken": [], "dummy": [], "res": [], "init": []}',
              'cards = {"dtu": [], "ken": [], "dummy": [], "res": [], "init": [], "paperb": []}')

open(p, "w").write(s)
print("report patched")
