#!/bin/bash
# seg_big_p9.sh <winding>... - P9 whole-winding six-model yellow view (prereg "Large segments"; PRIVATE) for flagged
# windings of window P (band Pf). Per winding, under $W/seg_big/Pf/<w>/:
#  1. render.zarr: the 66-layer render of the flattened winding, same arguments as render_pool.sh (so the screen's maps
#     line up pixel for pixel); reuses $W/renders/Pf_<w>.zarr when the screen has not deleted it yet.
#  2. maps/: the three screen models' d 0 maps linked from $W/screen/Pf/<w>/maps, plus ink_9um seeds 42/43 (one model
#     load for all windings, multi_depth_infer.py) and Hecate 9.6 um (run_ink.sh), all at d 0, both directions.
#  3. seg_yellow_p9.py: mean of the six per-model z-scores in yellow over the dimmed CT, reading and blind side.
# PHASE=render (CPU pod: renders only) | models (GPU pod: models + yellow; renders must exist) | all (default).
set -uo pipefail
W=/workspace; S=$W/p8/scripts; B=$W/seg_big/Pf; PHASE=${PHASE:-all}
CT=${CT:-https://vesuvius-challenge-open-data.s3.us-east-1.amazonaws.com/PHerc0175A/volumes/20250521115057-8.640um-1.2m-116keV-masked.zarr}
export CKPT_DIR=$W/ckpt PY=$W/venv/bin/python HECATE_PY=$W/ckpt/hecate.py L0_ONLY=0 OMP_NUM_THREADS=5 MKL_NUM_THREADS=5
export TMPDIR=${SEG_TMP:-/dev/shm/segbig_$$} TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor TRITON_CACHE_DIR=/root/.cache/triton
mkdir -p $TMPDIR; trap 'rm -rf $TMPDIR' EXIT
log() { echo "=== $(date -u +%FT%TZ) $*"; }
bad=0
if [ $PHASE != models ]; then
  for w in "$@"; do
    D=$B/$w; mkdir -p $D/maps; [ -d $D/render.zarr/0 ] && continue
    if [ -d $W/renders/Pf_$w.zarr/0 ]; then cp -r $W/renders/Pf_$w.zarr $D/render.zarr.tmp && mv $D/render.zarr.tmp $D/render.zarr
      log "$w: render copied from the screen queue"; continue; fi
    t0=$(date +%s)
    env QT_QPA_PLATFORM=offscreen OMP_NUM_THREADS=${RENDER_THREADS:-3} $W/vc3d/squashfs-root/AppRun vc_render_tifxyz \
      --volume "$CT" --group-idx 0 --scale 1 --segmentation "$W/flat/P/mesh/$w" --num-slices 66 --slice-step 1 \
      --auto-crop --cache-gb 6 --zarr-output $D/render.zarr.tmp > $D/render.log 2>&1 && [ -d $D/render.zarr.tmp/0 ] \
      && mv $D/render.zarr.tmp $D/render.zarr && log "$w rendered in $(( $(date +%s) - t0 ))s" \
      || { rm -rf $D/render.zarr.tmp; log "$w render FAILED (see $D/render.log)"; bad=1; }
  done
  [ $PHASE = render ] && exit $bad
fi
L=$TMPDIR/seg.list; : > $L
for w in "$@"; do
  D=$B/$w; [ -d $D/render.zarr/0 ] || { log "$w: no render, skipped"; bad=1; continue; }
  for f in $W/screen/Pf/$w/maps/*.tif; do b=$(basename $f); ln -sf $f $D/maps/render__${b#*__}; done  # Pf_<w>__m__.. -> render__m__..
  printf '%s\t%s\n' $D/render.zarr $D/maps >> $L
done
for m in hybrid_3d2d-seed42 hybrid_3d2d-seed43; do
  t0=$(date +%s)
  MODEL=$m $PY $S/multi_depth_infer.py @$L $CKPT_DIR/${m}_step-075000.pth /nonexistent 0 0 > $B/$m.$$.log 2>&1 \
    && log "$m on $(wc -l < $L) windings in $(( $(date +%s) - t0 ))s" || { log "$m FAILED (see $B/$m.$$.log)"; bad=1; }
done
for w in "$@"; do
  D=$B/$w; [ -d $D/render.zarr/0 ] || continue
  ls $D/maps/*__hecate__*_reverse.png >/dev/null 2>&1 || bash $S/run_ink.sh $D/render.zarr hecate 0 $D/maps > $D/hecate.log 2>&1 \
    || { log "$w hecate FAILED (see $D/hecate.log)"; bad=1; }
  $PY $S/seg_yellow_p9.py $D && log "$w: $D/yellow_small.png" || bad=1
done
exit $bad
