#!/bin/bash
set -e
cd ~/FaceScan/data
echo "--- archive top entries:"
tar -tzf dtu_2dgs.zip 2>/dev/null | head -8
ROOT=$(tar -tzf dtu_2dgs.zip 2>/dev/null | head -1 | cut -d/ -f1)
echo "--- root: $ROOT — extracting scan24/37/65"
tar -xzf dtu_2dgs.zip --wildcards "$ROOT/scan24/*" "$ROOT/scan37/*" "$ROOT/scan65/*"
mkdir -p DTU_2dgs
for s in scan24 scan37 scan65; do
  [ -d "$ROOT/$s" ] && rm -rf "DTU_2dgs/$s" && mv "$ROOT/$s" DTU_2dgs/ && echo "kept $s"
done
[ "$ROOT" != "DTU_2dgs" ] && rm -rf "$ROOT"
rm -f dtu_2dgs.zip
ls DTU_2dgs; ls DTU_2dgs/scan24 | head
df -h / | tail -1
echo UNTAR_DONE
