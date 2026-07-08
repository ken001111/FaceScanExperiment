#!/usr/bin/env python
"""
Raw-LiDAR baseline mesh (paper's "bare-sensor floor"): Poisson surface from the
scan's LiDAR cloud (points3D.ply), no optimization. Output is a metric mesh in
millimetres, matching the other methods' _nn.ply convention.

Usage:
  python make_raw_lidar_mesh.py --cloud /path/Scan_.../points3D.ply --out methods/raw_lidar.ply
  python make_raw_lidar_mesh.py --selftest
"""
import argparse
import sys
import tempfile
from pathlib import Path

import numpy as np
import open3d as o3d


def raw_lidar_mesh(cloud_path, out_path, depth=9, m_to_mm=1000.0, density_quantile=0.05):
    pcd = o3d.io.read_point_cloud(str(cloud_path))
    if len(pcd.points) == 0:
        raise ValueError(f'{cloud_path}: empty point cloud')
    pcd.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=0.02, max_nn=30))
    pcd.orient_normals_consistent_tangent_plane(30)
    mesh, dens = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(pcd, depth=depth)
    # trim low-density (extrapolated) triangles
    dens = np.asarray(dens)
    mesh.remove_vertices_by_mask(dens < np.quantile(dens, density_quantile))
    # largest component, metres -> millimetres
    mesh.remove_unreferenced_vertices()
    tri_clusters, _, _ = mesh.cluster_connected_triangles()
    tri_clusters = np.asarray(tri_clusters)
    if tri_clusters.size:
        counts = np.bincount(tri_clusters)
        mesh.remove_triangles_by_mask(tri_clusters != counts.argmax())
        mesh.remove_unreferenced_vertices()
    mesh.scale(m_to_mm, center=(0, 0, 0))
    mesh.compute_vertex_normals()
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    o3d.io.write_triangle_mesh(str(out_path), mesh)
    print(f'raw LiDAR mesh: {len(mesh.vertices)} verts, {len(mesh.triangles)} tris -> {out_path}')
    return mesh


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--cloud'); ap.add_argument('--out')
    ap.add_argument('--depth', type=int, default=9)
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        tmp = Path(tempfile.mkdtemp(prefix='rl_'))
        s = o3d.geometry.TriangleMesh.create_sphere(radius=0.08, resolution=40)
        pc = s.sample_points_uniformly(20000)
        o3d.io.write_point_cloud(str(tmp / 'points3D.ply'), pc)
        m = raw_lidar_mesh(tmp / 'points3D.ply', tmp / 'raw_lidar.ply')
        assert len(m.vertices) > 0
        print('SELFTEST OK.')
        return
    if not (a.cloud and a.out):
        ap.error('--cloud and --out required (or --selftest)')
    raw_lidar_mesh(a.cloud, a.out, depth=a.depth)


if __name__ == '__main__':
    main()
