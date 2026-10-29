#!/bin/bash
# p9_prep.sh <dataset dir> <z0> <z1> - P9 pilot inputs for PHerc0175A (villa-main fit, no surface tracks):
# the community lasagna field (nx, ny, grad_mag; level 2) for z0..z1 plus a 1024-slice margin, copied unchanged from
# the SharpMeow Hugging Face bucket (read-only check passed 2026-10-24); the masked CT at level 4 (whole scan, the
# fitter's packing mask) from the open-data bucket; the community center line as umbilicus.json. Run via launch.sh.
set -euo pipefail
D=$1; Z0=$2; Z1=$3; S=/workspace/p8/scripts; PY=/workspace/venv/bin/python
B=buckets/SharpMeow/lasagna-fields/PHerc0175A/representations/predictions/lasagna/20250521115057-lasagna-de45f011
V=PHerc0175A/volumes/20250521115057-8.640um-1.2m-116keV-masked.zarr
L0=$(( (Z0 - 1024 > 0 ? Z0 - 1024 : 0) / 4 )); L1=$(( (Z1 + 1024) / 4 ))
mkdir -p $D/lasagna_inputs $D/src $D/tracks
for c in nx ny grad_mag; do
  $PY $S/hf_zarr_window.py $B/PHerc0175A_$c.ome.zarr 2 $L0 $L1 $D/lasagna_inputs/las_008_$c.ome.zarr 16
done
python3 $S/fetch_subzarr.py $V 4 0 797 $D/src/ct.zarr 16
$PY -c "
from huggingface_hub import HfFileSystem
open('$D/umbilicus.json', 'wb').write(HfFileSystem().cat(
    'datasets/SharpMeow/vesuvius-center-lines/lines/PHerc0175A/PHerc0175A_20250521115057_finder_umbilicus.json'))"
du -sh $D/lasagna_inputs $D/src
echo PREP_DONE
