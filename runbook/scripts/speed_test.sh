#!/bin/bash
# speed_test.sh - improvement item 1 on the PHerc. 343 control: reader-v3 at depths -8..+8 step 2 (a detail review's
# depths), (A) one run_ink.sh process per depth, as P8 did, vs (B) multi_depth_infer.py, one model load for all depths.
# Answers: wall time of each, and whether B's maps equal A's (byte-identical, else max abs difference).
# Also renders the control segment first if it is missing (the positive control of the P9 prereg). Run via launch.sh.
set -euo pipefail
W=/workspace; S=$W/p8/scripts; C=$W/ctrl; N=concat_w047-w048_R5B2_z9500-11000; O=$W/p8/out/speed_test
CT=https://vesuvius-challenge-open-data.s3.us-east-1.amazonaws.com/PHerc0343/volumes/20250521140437-8.640um-1.2m-116keV-masked.zarr
export CKPT_DIR=$W/ckpt PY=$W/venv/bin/python TMPDIR=$W/tmp L0_ONLY=0 OMP_NUM_THREADS=8 MKL_NUM_THREADS=8
mkdir -p $C $O $TMPDIR
step() { echo "=== $(date -u +%FT%TZ) $*"; }

step render control "(66 layers, CT streamed from the open-data bucket)"
if [ ! -d $C/${N}_66.zarr/0 ]; then
  env QT_QPA_PLATFORM=offscreen OMP_NUM_THREADS=12 $W/vc3d/squashfs-root/AppRun vc_render_tifxyz \
    --volume "$CT" --group-idx 0 --scale 1 --segmentation $W/pherc343/outputs/$N.tifxyz \
    --num-slices 66 --slice-step 1 --cache-gb 16 --zarr-output $C/${N}_66.zarr
fi
du -sh $C/${N}_66.zarr

step "A: one process per depth"
if [ -n "${A_SECONDS:-}" ] && [ "$(ls $O/A/*.tif 2>/dev/null | wc -l)" -eq 18 ]; then
  tA=$A_SECONDS; echo "A_seconds $tA (maps from the earlier run, reused)"
else
  t0=$(date +%s)
  for d in -8 -6 -4 -2 0 2 4 6 8; do bash $S/run_ink.sh $C/${N}_66.zarr readerv3 $d $O/A >/dev/null; done
  tA=$(( $(date +%s) - t0 )); echo "A_seconds $tA"
fi
rm -rf $O/B

step "B: one model load"
t0=$(date +%s)
MODEL=readerv3 $PY $S/multi_depth_infer.py $C/${N}_66.zarr $CKPT_DIR/reader-v3.pth $O/B -8 8 2
tB=$(( $(date +%s) - t0 )); echo "B_seconds $tB"

step compare
$PY - "$O" <<'EOF'
import sys, glob, os, numpy as np, tifffile
o = sys.argv[1]; a = sorted(glob.glob(f"{o}/A/*.tif")); same = diff = 0; worst = 0
for f in a:
    g = f"{o}/B/{os.path.basename(f)}"
    x, y = tifffile.imread(f), tifffile.imread(g)
    if x.shape == y.shape and np.array_equal(x, y): same += 1
    else:
        diff += 1; worst = max(worst, int(np.abs(x.astype(int) - y.astype(int)).max()) if x.shape == y.shape else 999)
print(f"maps {len(a)}: identical {same}, different {diff}, max abs diff {worst} (uint8)")
EOF
echo "A ${tA}s vs B ${tB}s"
step done
