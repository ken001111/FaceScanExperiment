#!/bin/bash
# Resume the interrupted seeded arm (iter 7500 -> 20000) on the RTX 5080.
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=1          # PCI index 1 = RTX 5080 (16GB)
export ABLATE_SRC=$HOME/FaceScan/work/arkit_41069021
export ABLATE_OUT=$HOME/FaceScan/paperB/ablation_41069021
export ABLATE_ARMS=seeded
bash ~/facescan-experiments/paperB/ablate_depth.sh
