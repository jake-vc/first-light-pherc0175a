#!/bin/bash
# stage_hf_p9_extras.sh - the fit pieces not yet in the dataset, per window, in the final layout, under
# /workspace/release/hf_extras/window_<P|W2>/: fit/checkpoint/ (final fit checkpoint), fit/ logs of the export and
# checks, meshes/exported/ (the fit's exported meshes, the input to snapping), meshes/snapped/, and the two placement
# reports (before and after snapping). Copies only; the check steps' duplicate mesh copies are left out.
set -uo pipefail
W=/workspace; O=$W/release/hf_extras; F=$W/p9/fit0175A
rm -rf $O && mkdir -p $O
for win in P W2; do
  case $win in
    P)  R=$F/pilot; K=$R/s10000; EX=$K/export ;;
    W2) R=$F/W2_main/P9W2; K=$R/s10000; EX=$K/exportf ;;  # W2's fit run snaps the filtered export (autosteps_run.sh)
  esac
  D=$O/window_$win; mkdir -p $D/fit/checkpoint $D/meshes/exported $D/meshes/snapped
  cp $R/ck/step_10000.ckpt $D/fit/checkpoint/
  for f in export.log raw.log snap.log snapcheck.log windings.txt; do [ -f $K/$f ] && cp $K/$f $D/fit/; done
  (cd $EX && tar cf - .) | (cd $D/meshes/exported && tar xf -)
  (cd $K/snap && tar cf - .) | (cd $D/meshes/snapped && tar xf -)
  cp $K/raw/snap_report.tsv $D/meshes/placement_exported.tsv
  cp $K/snap_check/snap_report.tsv $D/meshes/placement_snapped.tsv
  echo "window_$win: $(du -sh $D | cut -f1), exported $(ls $D/meshes/exported | wc -l), snapped $(ls $D/meshes/snapped | wc -l)"
done
