#!/bin/bash
# render_pool.sh <worker id> - CPU-only render worker for one window's flattened windings (P9): renders each in-scope
# winding (66 layers, VC3D, CT streamed, --auto-crop) as soon as its flattened mesh exists, into the path the GPU screen
# (screen_1218.sh, BAND=<window>f) looks for first, $W/renders/<window>f_<winding>.zarr, so the screen skips the render.
# Hand-off between workers on any pod: an atomic mkdir claim per winding in $W/renders/.claim_<window>f; a winding is
# rendered only once flatten_pool.sh has linked its flattened mesh (meta.json present). A render that fails is
# released for one retry, then marked FAILED.
# Disk: renders wait for the GPU screen, which deletes each after scoring, so rendering pauses while the renders take
# more than RENDER_BUDGET_GB (default 60) and resumes as the screen frees space. CPU: RENDER_THREADS per worker.
# Env: WIN (window, e.g. P), FIT (fit dir holding <WIN>/snap_check), CT (volume URL). Loops until every in-scope winding
# is rendered, screened or FAILED. Run via launch.sh.
set -uo pipefail
WK=$1; W=/workspace; S=$W/p8/scripts; PY=$W/venv/bin/python; B=${WIN:?}f; R=$W/renders; C=$R/.claim_$B
FL=$W/flat/$WIN; BUDGET=${RENDER_BUDGET_GB:-60}; T=${RENDER_THREADS:-3}
CT=${CT:?set CT}; mkdir -p $R $C
log() { echo "=== $(date -u +%FT%TZ) [$WK] $*"; }
mapfile -t WS < <($PY - "${FIT:?}/$WIN" <<'EOF'
import csv, json, sys
d = sys.argv[1]; rows = []
for r in csv.DictReader(open(f"{d}/snap_check/snap_report.tsv"), delimiter="\t"):
    s = float(r["frac_with_sheet"]); a = json.load(open(f"{d}/snap/{r['winding']}/meta.json"))["area_cm2"]
    if s >= 0.70 and a * s >= 1: rows.append(r["winding"])
print("\n".join(rows))
EOF
)
log "window $B: ${#WS[@]} in-scope windings; budget ${BUDGET} GB, ${T} threads"
while true; do
  left=0
  for w in "${WS[@]}"; do
    Z=$R/${B}_$w.zarr; D=$W/screen/$B/$w
    [ -d "$Z/0" ] || [ -s "$D/stats.json" ] || [ -f "$D/FAILED" ] || [ -f "$C/$w.FAILED" ] && continue
    left=1
    [ -f "$FL/mesh/$w/meta.json" ] || continue                       # not flattened yet
    used=$(du -s --block-size=1G $R 2>/dev/null | cut -f1)
    [ "${used:-0}" -ge "$BUDGET" ] && { log "renders use ${used} GB >= ${BUDGET} GB: waiting for the screen"; sleep 300; continue 2; }
    mkdir $C/$w 2>/dev/null || continue                              # another worker has it
    echo "$(hostname) $$ $(date -u +%FT%TZ)" > $C/$w/by
    t0=$(date +%s)
    if env QT_QPA_PLATFORM=offscreen OMP_NUM_THREADS=$T $W/vc3d/squashfs-root/AppRun vc_render_tifxyz --volume "$CT" \
         --group-idx 0 --scale 1 --segmentation "$FL/mesh/$w" --num-slices 66 --slice-step 1 --auto-crop --cache-gb 6 \
         --zarr-output "$Z.tmp" > "$Z.log" 2>&1 && [ -d "$Z.tmp/0" ]; then
      mv "$Z.tmp" "$Z"; log "$w rendered in $(( $(date +%s) - t0 ))s, $(du -sh $Z | cut -f1)"
    elif [ -f $C/$w.retried ]; then
      rm -rf "$Z.tmp"; touch $C/$w.FAILED; log "$w render FAILED twice; see $Z.log"
    else
      rm -rf "$Z.tmp" $C/$w; touch $C/$w.retried; log "$w render failed once: released for one retry"
    fi
  done
  [ $left = 0 ] && { log "window $B: nothing left to render"; exit 0; }
  sleep 60
done
