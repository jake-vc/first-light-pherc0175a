#!/bin/bash
# ctrl_p9.sh - P9 positive control (prereg "Positive control first"): the three screen models (reader-v3, dense_native,
# reader-v2) at d -1..+1 on PHerc. 343's published letter segment rendered with this volume's VC3D build
# (ctrl_render.sh), one model load each (multi_depth_infer.py), then calib_343.py: letter-vs-background separation per
# model. Pass = separation >= 0.10 for at least two models (plus letters legible by eye: the human, from the images).
set -euo pipefail
W=/workspace; S=$W/p8/scripts; C=$W/ctrl; N=concat_w047-w048_R5B2_z9500-11000; O=$C/maps_p9
export PY=$W/venv/bin/python TMPDIR=$W/tmp L0_ONLY=0 OMP_NUM_THREADS=8 VILLA_WORKERS=${VILLA_WORKERS:-4}
mkdir -p $O
for m in readerv3:reader-v3.pth dnative:dense_native-016000.rebuilt.pth readerv2:reader-v2-step040000.pth; do
  t=$(date +%s); MODEL=${m%%:*} $PY $S/multi_depth_infer.py $C/${N}_66.zarr $W/ckpt/${m#*:} $O -1 1 > $O/${m%%:*}.log 2>&1
  echo "${m%%:*}: $(( $(date +%s) - t ))s"
done
mkdir -p $W/p8/out/ctrl_p9
$PY $S/calib_343.py $O $W/pherc343 $W/p8/out/ctrl_p9
ls $W/p8/out/ctrl_p9
