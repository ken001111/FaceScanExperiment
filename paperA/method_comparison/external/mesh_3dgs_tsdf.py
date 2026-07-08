#!/usr/bin/env python
"""TSDF surface mesh from a trained 3DGS model (the "3DGS+TSDF" baseline).

Renders each training view from a vanilla 3D Gaussian Splatting model, converts
the rasterizer's inverse-depth output to metric depth, masks the background with
the prep masks, and fuses everything into an Open3D ScalableTSDFVolume — mirroring
the 2DGS pipeline's mesh step (voxel 0.01, sdf_trunc 0.04) so the methods are
compared on equal footing.

Run from inside the graphdeco gaussian-splatting repo (imports scene/, arguments/).
  python mesh_3dgs_tsdf.py -m <model_path> --iteration <it> --mask_dir <dir> --out mesh.ply
"""
import os, glob, copy, argparse
import numpy as np
import torch
import open3d as o3d
from PIL import Image
from tqdm import tqdm

from scene import Scene, GaussianModel
from gaussian_renderer import render
from arguments import ModelParams, PipelineParams, get_combined_args


def post_process_mesh(mesh, cluster_to_keep=1):
    """Keep the largest `cluster_to_keep` connected components (drop floaters)."""
    m = copy.deepcopy(mesh)
    with o3d.utility.VerbosityContextManager(o3d.utility.VerbosityLevel.Error):
        tc, nt, _ = m.cluster_connected_triangles()
    tc = np.asarray(tc); nt = np.asarray(nt)
    if len(nt) == 0:
        return m
    keep = min(cluster_to_keep, len(nt))
    thresh = max(int(np.sort(nt)[-keep]), 50)
    m.remove_triangles_by_mask(nt[tc] < thresh)
    m.remove_unreferenced_vertices()
    m.remove_degenerate_triangles()
    return m


def to_cam_open3d(cams):
    traj = []
    for cam in cams:
        W, H = cam.image_width, cam.image_height
        ndc2pix = torch.tensor([[W / 2, 0, 0, (W - 1) / 2],
                                [0, H / 2, 0, (H - 1) / 2],
                                [0, 0, 0, 1]]).float().cuda().T
        intrins = (cam.projection_matrix @ ndc2pix)[:3, :3].T
        intr = o3d.camera.PinholeCameraIntrinsic(
            width=W, height=H,
            cx=intrins[0, 2].item(), cy=intrins[1, 2].item(),
            fx=intrins[0, 0].item(), fy=intrins[1, 1].item())
        params = o3d.camera.PinholeCameraParameters()
        params.extrinsic = np.asarray((cam.world_view_transform.T).cpu().numpy())
        params.intrinsic = intr
        traj.append(params)
    return traj


def load_mask(mask_dir, image_name, H, W):
    """Masks are named like '<image_name>.heic.png' — match by stem prefix."""
    if not mask_dir or not os.path.isdir(mask_dir):
        return None
    cands = [c for c in glob.glob(os.path.join(mask_dir, image_name + "*"))
             if not c.lower().endswith("thumbs.db")]
    if not cands:
        return None
    m = Image.open(sorted(cands)[0]).convert("L").resize((W, H), Image.NEAREST)
    return torch.from_numpy(np.asarray(m).astype(np.float32) / 255.0).cuda()


if __name__ == "__main__":
    parser = argparse.ArgumentParser("3DGS TSDF mesh extraction")
    model = ModelParams(parser, sentinel=True)
    pipeline = PipelineParams(parser)
    parser.add_argument("--iteration", default=-1, type=int)
    parser.add_argument("--voxel", default=0.01, type=float)
    parser.add_argument("--sdf_trunc", default=0.04, type=float)
    parser.add_argument("--depth_trunc", default=-1.0, type=float)
    parser.add_argument("--mask_dir", default="", type=str)
    parser.add_argument("--num_cluster", default=1, type=int)
    parser.add_argument("--scale_factor", default=1.0, type=float,
                        help="prep scale_factor.txt; mesh is scaled by 1000/scale_factor to millimetres")
    parser.add_argument("--out", required=True, type=str)
    args = get_combined_args(parser)

    ds = model.extract(args)
    pp = pipeline.extract(args)
    gaussians = GaussianModel(ds.sh_degree)
    scene = Scene(ds, gaussians, load_iteration=args.iteration, shuffle=False)
    bg = torch.tensor([1, 1, 1] if ds.white_background else [0, 0, 0],
                      dtype=torch.float32, device="cuda")
    cams = scene.getTrainCameras()

    centers = np.array([c.camera_center.detach().cpu().numpy() for c in cams])
    radius = float(np.linalg.norm(centers - centers.mean(0), axis=1).max())
    depth_trunc = args.depth_trunc if args.depth_trunc > 0 else radius * 3.0
    print(f"[3dgs-tsdf] {len(cams)} cams  radius={radius:.3f}  depth_trunc={depth_trunc:.3f}  "
          f"voxel={args.voxel}  sdf_trunc={args.sdf_trunc}")

    vol = o3d.pipelines.integration.ScalableTSDFVolume(
        voxel_length=args.voxel, sdf_trunc=args.sdf_trunc,
        color_type=o3d.pipelines.integration.TSDFVolumeColorType.RGB8)
    traj = to_cam_open3d(cams)

    dbg_raw, dbg_depth = [], []
    for i, cam in enumerate(tqdm(cams, desc="TSDF")):
        with torch.no_grad():
            pkg = render(cam, gaussians, pp, bg)
        rgb = pkg["render"].clamp(0, 1)
        invd = pkg["depth"][0]                                  # rasterizer returns inverse depth
        depth = torch.where(invd > 1e-6, 1.0 / invd, torch.zeros_like(invd))
        H, W = depth.shape
        mask = load_mask(args.mask_dir, cam.image_name, H, W)
        if mask is None and getattr(cam, "alpha_mask", None) is not None and float(cam.alpha_mask.mean()) < 0.99:
            mask = cam.alpha_mask.squeeze()
        if mask is not None:
            depth = depth * (mask > 0.5)
        if i < 3:
            pos = invd[invd > 1e-6]
            if pos.numel():
                dbg_raw.append(float(pos.median())); dbg_depth.append(float(depth[depth > 0].median()))

        rgb_np = np.ascontiguousarray((rgb.permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8))
        d_np = np.ascontiguousarray(depth.cpu().numpy().astype(np.float32))
        rgbd = o3d.geometry.RGBDImage.create_from_color_and_depth(
            o3d.geometry.Image(rgb_np), o3d.geometry.Image(d_np),
            depth_scale=1.0, depth_trunc=depth_trunc, convert_rgb_to_intensity=False)
        vol.integrate(rgbd, intrinsic=traj[i].intrinsic, extrinsic=traj[i].extrinsic)

    if dbg_raw:
        print(f"[3dgs-tsdf] sample median inv-depth={np.mean(dbg_raw):.4f} -> metric depth={np.mean(dbg_depth):.4f}")
    mesh = vol.extract_triangle_mesh()
    mesh.compute_vertex_normals()
    mesh = post_process_mesh(mesh, args.num_cluster)

    # match finish_mesh.py: training-space -> millimetres, xyz-only PLY
    to_mm = 1000.0 / args.scale_factor
    if to_mm != 1.0:
        mesh.scale(to_mm, center=(0, 0, 0))
    mesh.vertex_colors = o3d.utility.Vector3dVector()
    mesh.vertex_normals = o3d.utility.Vector3dVector()
    mesh.triangle_normals = o3d.utility.Vector3dVector()

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    o3d.io.write_triangle_mesh(args.out, mesh, write_vertex_colors=False,
                               write_vertex_normals=False, write_ascii=False)
    ext = np.asarray(mesh.get_axis_aligned_bounding_box().get_extent())
    diag = float(np.linalg.norm(ext))
    print(f"[3dgs-tsdf] wrote {args.out}: {len(mesh.vertices)} verts, {len(mesh.triangles)} tris, "
          f"extent(mm)={np.round(ext,1)} diag={diag:.1f} "
          f"[{'OK head-sized' if 80 < diag < 1000 else 'CHECK scale'}]")
