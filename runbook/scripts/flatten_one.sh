#!/bin/bash
# flatten_one.sh <snapped winding dir> <out dir> - the winner's flattening step (pherc343 mesh/README.md step 4):
# villa lasagna fit.py with configs/flatten_fast_nofilter.json on one snapped winding; the flattened mesh is written to
# <out dir>/tifxyz/flatten.tifxyz. Prints the wall time.
set -euo pipefail
M=$(cd "$1" && pwd); O=$2; L=/workspace/villa/lasagna; PY=${FLAT_PY:-/workspace/venv/bin/python}  # P9: the ink venv holds lasagna (P8 used villa 0fb38c45's VC venv)
mkdir -p "$O"; echo "{\"external_surfaces\": [{\"path\": \"$M\"}]}" > "$O/flatten_input.json"
t0=$(date +%s)
# default device: cuda only where a GPU exists (P9 10/29: a CPU pod launch without FLAT_DEVICE=cpu failed every winding)
DEV=${FLAT_DEVICE:-$(command -v nvidia-smi >/dev/null && echo cuda || echo cpu)}
(cd $L && $PY fit.py configs/flatten_fast_nofilter.json "$O/flatten_input.json" --device $DEV --out-dir "$O") > "$O/flatten.log" 2>&1
ls "$O/tifxyz/flatten.tifxyz/x.tif" >/dev/null && rm -rf "$O/model_snapshots" "$O/model_final.pt" && echo "flattened $(basename $M) in $(( $(date +%s) - t0 ))s -> $O/tifxyz/flatten.tifxyz"
