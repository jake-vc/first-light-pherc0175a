#!/bin/bash
# stage_hf_p9.sh - build the P9 Hugging Face dataset folder (first-light-pherc0175a, P8's layout) on the volume:
# /workspace/release/hf_pherc0175a. Copies only (nothing on the volume is moved or deleted). Contents:
#   fits/{P,W2}/      fit logs, curve, metrics, overrides, villa commit, on-sheet (snap_check) reports
#   flat/{P,W2}/<w>/  flattened snapped meshes (tifxyz: x/y/z.tif + meta.json), ready to render
#   screen/Pf/        per-winding stats.json, contact sheet, crop, mesh path; summary.jsonl; batch logs
#   maps/Pf/<w>/      the three screen models' ink maps (d 0, both sides) when they fit under MAPS_MAX_GB (15)
#   seg_big/Pf/<w>/   whole-winding six-model yellow views (reading + blind), yellow.json, the six models' d 0 maps
#   gate/             ranking and background statistics behind the gate
#   rescreen_A1/      prereg amendment 1 re-screen (thresholds, per-winding table, control check)
#   bench/            screen speed benchmark (timings, map comparisons)
#   control/          PHerc. 343 positive control maps and calibration
#   pipeline_logs/    job logs and state markers as run
# Not included (re-creatable): CT, lasagna inputs, 66-layer renders, fit checkpoints. MANIFEST.tsv: sha256 + path.
set -uo pipefail
W=/workspace; O=$W/release/hf_pherc0175a; F=$W/p9/fit0175A; MAX=${MAPS_MAX_GB:-15}
log() { echo "=== $(date -u +%FT%TZ) $*"; }
mkdir -p $O && cd $O || exit 1
for win in P W2; do
  case $win in P) S=$F/pilot; K=$F/pilot/s10000 ;; W2) S=$F/W2_main/P9W2; K=$S/s10000 ;; esac
  mkdir -p fits/$win
  for f in fit.log curve.tsv metrics.jsonl overrides.json villa_commit.txt fit_time.tsv README.md; do [ -f $S/$f ] && cp $S/$f fits/$win/; done
  [ -d $K/snap_check ] && cp -r $K/snap_check fits/$win/
  [ -f $K/windings.txt ] && cp $K/windings.txt fits/$win/
  for m in $W/flat/$win/mesh/*; do w=$(basename $m); mkdir -p flat/$win/$w; cp -rL $m/. flat/$win/$w/; done
  log "$win: $(ls flat/$win | wc -l) flattened windings"
done
cp $W/p8/out/prepW2.log fits/W2/ 2>/dev/null
mkdir -p screen/Pf
cp $W/screen/Pf/summary.jsonl $W/screen/Pf/batch_*.log screen/Pf/ 2>/dev/null
for d in $W/screen/Pf/w*/; do w=$(basename $d); mkdir -p screen/Pf/$w
  for f in stats.json sheet.png render_crop.txt mesh_path.txt; do [ -f $d/$f ] && cp $d/$f screen/Pf/$w/; done; done
ms=$(du -sc --block-size=1G $W/screen/Pf/w*/maps | tail -1 | cut -f1)
if [ "$ms" -le "$MAX" ]; then
  for d in $W/screen/Pf/w*/maps; do w=$(basename $(dirname $d)); mkdir -p maps/Pf/$w; cp $d/*.tif maps/Pf/$w/; done
  log "screen maps included (${ms} GB)"
else log "screen maps NOT included: ${ms} GB > ${MAX} GB"; fi
for d in $W/seg_big/Pf/w*/; do w=$(basename $d); mkdir -p seg_big/Pf/$w/maps
  for f in yellow.png yellow_small.png yellow_blind_small.png yellow.json render.log hecate.log; do [ -f $d/$f ] && cp $d/$f seg_big/Pf/$w/; done
  cp -L $d/maps/* seg_big/Pf/$w/maps/ 2>/dev/null; done
mkdir -p gate rescreen_A1 bench control/maps pipeline_logs/state
cp $W/seg_big/Pf/rank_Pf.tsv $W/seg_big/Pf/bg_stats_Pf.tsv gate/
cp $W/p9/rescreen_A1/* rescreen_A1/
cp $W/tmp/bench/bench.tsv $W/tmp/bench/bench.log $W/tmp/bench/*.log bench/ 2>/dev/null
cp $W/ctrl/maps_p9/*.tif control/maps/ 2>/dev/null; cp -r $W/p8/out/ctrl_p9/. control/ 2>/dev/null
cp $W/p8/out/*.log pipeline_logs/ 2>/dev/null; cp $W/p8/state/*.done $W/p8/state/*.failed pipeline_logs/state/ 2>/dev/null
log "hashing"
find . -type f ! -name MANIFEST.tsv -print0 | sort -z | xargs -0 -P 8 -n 50 sha256sum | sed 's/  /\t/' | sort -k2 > MANIFEST.tsv
log "done: $(wc -l < MANIFEST.tsv) files, $(du -sh . | cut -f1)"
du -sh fits flat screen maps seg_big gate rescreen_A1 bench control pipeline_logs 2>/dev/null
