#!/bin/bash
# p9_pilot.sh - P9 pilot fit on PHerc0175A (one tall window, z 4800-7800): villa main + auto steps (patched
# checkout /workspace/villa_autostop), community lasagna field and center line, no surface tracks; snapped on-papyrus
# check of the final checkpoint against the public m7 prediction (autosteps_run.sh). Waits for p9_prep and for the
# PHerc. 343 fits so the GPU is not shared. Run via launch.sh.
set -uo pipefail
ST=/workspace/p8/state; S=/workspace/p8/scripts; D=/workspace/p9/fit0175A
fin() { [ -e $ST/$1.done ] || [ -e $ST/$1.failed ]; }
until fin p9_prep && fin autostop_343; do sleep 60; done
[ -e $ST/p9_prep.done ] || { echo "prep failed: not fitting"; exit 1; }
/workspace/venv/bin/python -c "
# villa's json_umbilicus_z_to_yx reads only control_points[].x/y/z (extra keys such as metadata are ignored)
import json; a=json.load(open('$D/umbilicus.json'))['control_points']; z=[p['z'] for p in a]
assert all(isinstance(p[k], (int, float)) for p in a for k in 'xyz') and len(set(z)) == len(z)
assert min(z) <= 4800 and max(z) >= 7800, (min(z), max(z))
print('umbilicus usable:', len(a), 'points, z', min(z), '-', max(z))" || { echo "umbilicus format differs"; exit 1; }
M7=https://vesuvius-challenge-open-data.s3.us-east-1.amazonaws.com/PHerc0175A/representations/predictions/surfaces/20250521115057-surface-20260413222639-surface-m7-L0-th0.2.zarr
env VS=/workspace/villa_autostop/spiral-fitting SRC=$D SCROLL=PHerc0175A SURF=$M7 NUM_WINDINGS= NAME=P9pilot \
  Z0=4800 Z1=7800 WLO=10 WHI=129 STEPS=10000 SNAP_STEPS="" CHECK_PENDING=0 \
  EXTRA='"optimizer_auto_steps": true, "input_use_tracks": false' bash $S/autosteps_run.sh
