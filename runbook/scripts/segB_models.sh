#!/bin/bash
# segB_models.sh - models + yellow for the comparison set (top five by lift over each winding's own background) on the
# GPU pod, started only after afterscreen's bench is done (so bench timings stay clean); runs alongside the W2 fit.
W=/workspace; until grep -q "bench done\|bench FAILED\|gate package" $W/p8/out/afterscreen.log && grep -q "bench done\|bench FAILED" $W/p8/out/afterscreen.log; do
  [ -e $W/p8/state/afterscreen.running ] || break; sleep 60; done
PHASE=models bash $W/p8/scripts/seg_big_p9.sh "$@"
