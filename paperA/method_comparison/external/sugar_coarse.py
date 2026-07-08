#!/usr/bin/env python
"""Drive SuGaR's coarse training + mesh extraction directly (the train.py recipe
minus refinement). Used by run_sugar.sh.

The dn_consistency regularizer is what train.py recommends and what extracts
cleanly here; the standalone train_coarse_sdf.py path leaves an empty foreground
on close-orbit face scans (everything lands in 'background' and Poisson OOMs).

  python sugar_coarse.py -s <scene> -c <vanilla_gs_dir> -i 7000 \
         -r dn_consistency -l 0.3 -d 200000
prints  COARSE_MESH_PATH:<path>
"""
import argparse, os, sys
sys.path.insert(0, os.path.expanduser("~/SuGaR"))     # SuGaR package root

from sugar_trainers.coarse_density_and_dn_consistency import coarse_training_with_density_regularization_and_dn_consistency
from sugar_trainers.coarse_sdf import coarse_training_with_sdf_regularization
from sugar_trainers.coarse_density import coarse_training_with_density_regularization
from sugar_extractors.coarse_mesh import extract_mesh_from_coarse_sugar


class AttrDict(dict):
    def __init__(self, *a, **k):
        super().__init__(*a, **k); self.__dict__ = self


def _bool(x): return str(x).lower() == "true"

p = argparse.ArgumentParser()
p.add_argument("-s", "--scene_path", required=True)
p.add_argument("-c", "--checkpoint_path", required=True)
p.add_argument("-i", "--iteration_to_load", type=int, default=7000)
p.add_argument("-r", "--regularization_type", default="dn_consistency")
p.add_argument("-l", "--surface_level", type=float, default=0.3)
p.add_argument("-d", "--decimation_target", type=int, default=200000)
p.add_argument("--center_bbox", type=_bool, default=True)
p.add_argument("--white_background", type=_bool, default=True)
p.add_argument("--gpu", type=int, default=0)
a = p.parse_args()

coarse_args = AttrDict({
    "checkpoint_path": a.checkpoint_path, "scene_path": a.scene_path,
    "iteration_to_load": a.iteration_to_load, "output_dir": None, "eval": False,
    "estimation_factor": 0.2, "normal_factor": 0.2, "gpu": a.gpu,
    "white_background": a.white_background,
})
trainer = {
    "dn_consistency": coarse_training_with_density_regularization_and_dn_consistency,
    "sdf": coarse_training_with_sdf_regularization,
    "density": coarse_training_with_density_regularization,
}[a.regularization_type]
coarse_path = trainer(coarse_args)

mesh_args = AttrDict({
    "scene_path": a.scene_path, "checkpoint_path": a.checkpoint_path,
    "iteration_to_load": a.iteration_to_load, "coarse_model_path": coarse_path,
    "surface_level": a.surface_level, "decimation_target": a.decimation_target,
    "project_mesh_on_surface_points": True, "mesh_output_dir": None,
    "bboxmin": None, "bboxmax": None, "center_bbox": a.center_bbox,
    "gpu": a.gpu, "eval": False, "use_centers_to_extract_mesh": False,
    "use_marching_cubes": False, "use_vanilla_3dgs": False,
})
mesh_path = extract_mesh_from_coarse_sugar(mesh_args)[0]
print("COARSE_MESH_PATH:" + mesh_path)
