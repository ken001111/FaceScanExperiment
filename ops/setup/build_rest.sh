#!/bin/bash
# Build svraster, 2dgs, 3dgs stacks sequentially, pinned to RTX 5070 (index 0).
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export CUDA_VISIBLE_DEVICES=0     # RTX 5070; keep 5080 free for training
LOG="$HOME/build_rest.log"; echo "START $(date)" > "$LOG"
for s in build_svraster.sh build_2dgs.sh build_3dgs.sh; do
  echo "===== running $s $(date) =====" >> "$LOG"
  bash "$HOME/$s" >> "$LOG" 2>&1
  echo "----- $s returned $? -----" >> "$LOG"
done
echo "ALLDONE $(date)" >> "$LOG"
echo "==== SUMMARY ===="
grep -E "build_ext exit|surfel exit|diffgauss exit|simpleknn exit|fusedssim exit|smoke exit|OK|returned" "$HOME"/build_svraster.log "$HOME"/build_2dgs.log "$HOME"/build_3dgs.log 2>/dev/null
