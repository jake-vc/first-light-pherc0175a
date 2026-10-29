#!/bin/bash
# after_screen.sh - GPU-pod work queued behind the pilot screen (P9 night log items 2, speed, 3), in priority order:
#  1. gate package: background stats + ranking over every screened winding (bg_stats.py, rank_flags.py), then the
#     whole-winding six-model yellow view of the five strongest reading-side flags (seg_big_p9.sh). PRIVATE.
#  2. bench_screen.sh: clean screen timings on the idle pod (data-loader workers, TMPDIR).
#  3. W2 fit (7,600-10,600, windings 10-129, villa main + auto steps, no tracks), once prepW2 has finished.
# Waits while screenP runs. Run on the GPU pod via launch.sh. The rest of the review waits for the human (prereg Gate).
set -uo pipefail
W=/workspace; S=$W/p8/scripts; ST=$W/p8/state; PY=$W/venv/bin/python; G=$W/seg_big/Pf
log() { echo "=== $(date -u +%FT%TZ) $*"; }
while [ -e $ST/screenP.running ]; do sleep 120; done
[ -e $ST/screenP.done ] || { log "screenP did not finish cleanly: stopping"; exit 1; }
log "screenP done: $(ls $W/screen/Pf/*/stats.json | wc -l) windings screened"
mkdir -p $G
$PY $S/bg_stats.py $W/screen/Pf $G/bg_stats_Pf.tsv && $PY $S/rank_flags.py $W/screen/Pf $G/bg_stats_Pf.tsv > $G/rank_Pf.tsv \
  || { log "ranking FAILED"; exit 1; }
top=$(awk -F'\t' 'NR > 1 && $2 == "reverse"' $G/rank_Pf.tsv | head -5 | cut -f1 | tr '\n' ' ')
log "five strongest (reading side): $top"
bash $S/seg_big_p9.sh $top && log "gate package done" || log "gate package had failures (see above)"
bash $S/bench_screen.sh > $W/tmp/bench/bench.log 2>&1 && log "bench done: $(tail -n +2 $W/tmp/bench/bench.tsv | tr '\n' ';')" \
  || log "bench FAILED (see $W/tmp/bench/bench.log)"
while [ -e $ST/prepW2.running ]; do sleep 60; done
[ -e $ST/prepW2.done ] || { log "prepW2 did not finish: no W2 fit"; exit 1; }
log "W2 fit starting"
M7=https://vesuvius-challenge-open-data.s3.us-east-1.amazonaws.com/PHerc0175A/representations/predictions/surfaces/20250521115057-surface-20260413222639-surface-m7-L0-th0.2.zarr
env VS=$W/villa_autosteps/spiral-fitting SRC=$W/p9/fit0175A/W2 SCROLL=PHerc0175A SURF=$M7 NUM_WINDINGS= NAME=P9W2 \
  Z0=7600 Z1=10600 WLO=10 WHI=129 STEPS=10000 SNAP_STEPS="" CHECK_PENDING=0 CHECK_PY=$PY \
  EXTRA='"optimizer_auto_steps": true, "input_use_tracks": false' bash $S/autosteps_run.sh && log "W2 fit done" || { log "W2 fit FAILED"; exit 1; }
