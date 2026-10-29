#!/bin/bash
# screen_fast.sh <band, e.g. Pf> - GPU screen worker for renders made by render_pool.sh ($W/renders/<band>_<winding>.zarr).
# Takes up to BATCH rendered, unscreened windings at a time (atomic claim per winding), runs each screen model ONCE over
# the whole batch (multi_depth_infer.py @list, depth 0, both directions: one model load instead of one per winding),
# then screen_sheet.py per winding (same thresholds and rules as P8) -> $W/screen/<band>/<w>/stats.json + summary.jsonl.
# Deletes each render after it is scored (KEEP_RENDERS=1 keeps them). Loops until the render workers have finished and
# nothing rendered is left (or MAX_BATCHES batches). Env: SCREEN_MODELS (readerv2 dnative readerv3), BATCH (8).
set -uo pipefail
B=$1; W=/workspace; S=$W/p8/scripts; R=$W/renders; O=$W/screen/$B; C=$R/.screen_claim_$B; ST=$W/p8/state
# TMPDIR in RAM: villa accumulates every tile in a temporary zarr there; on the network volume that was the bottleneck
# (P9 tune_tmp: reader-v3 on 4 windings 62 s with /dev/shm vs 120-173 s on /workspace/tmp, identical maps)
export CKPT_DIR=$W/ckpt PY=$W/venv/bin/python TMPDIR=${SCREEN_TMP:-/dev/shm/screen_$$} L0_ONLY=0 OMP_NUM_THREADS=5 MKL_NUM_THREADS=5
# torch.compile's kernel cache defaults to TMPDIR, but /dev/shm is mounted noexec ("failed to map segment"): keep it on
# the pod's own disk
export TORCHINDUCTOR_CACHE_DIR=${TORCHINDUCTOR_CACHE_DIR:-/root/.cache/torchinductor} TRITON_CACHE_DIR=${TRITON_CACHE_DIR:-/root/.cache/triton}
MODELS=${SCREEN_MODELS:-readerv2 dnative readerv3}; N=${BATCH:-8}; nb=0
mkdir -p $O $C $TMPDIR; trap 'rm -rf $TMPDIR' EXIT
log() { echo "=== $(date -u +%FT%TZ) $*"; }
ck() { case $1 in readerv2) echo $CKPT_DIR/reader-v2-step040000.pth ;; readerv3) echo $CKPT_DIR/reader-v3.pth ;;
       dnative) echo $CKPT_DIR/dense_native-016000.rebuilt.pth ;; *) echo "unknown model $1" >&2; exit 2 ;; esac; }
while true; do
  L=$TMPDIR/screen_$B.$$.list; : > $L; ws=()
  for Z in $(ls -d $R/${B}_*.zarr 2>/dev/null); do
    w=$(basename $Z .zarr); w=${w#${B}_}
    [ ${#ws[@]} -ge $N ] && break
    [ -s $O/$w/stats.json ] && continue
    mkdir $C/$w 2>/dev/null || continue
    mkdir -p $O/$w/maps; printf '%s\t%s\n' "$Z" "$O/$w/maps" >> $L; ws+=($w)
  done
  if [ ${#ws[@]} = 0 ]; then
    if ls $ST/renderP_*.running >/dev/null 2>&1; then sleep 120; continue; fi
    log "$B: nothing left to screen"; exit 0
  fi
  t0=$(date +%s); pids=()
  # the three models at once: the GPU was 4-7% busy with one (P9 tune tests), so they share it
  for m in $MODELS; do
    MODEL=$m $PY $S/multi_depth_infer.py @$L "$(ck $m)" /nonexistent 0 0 > $O/batch_${nb}_$m.log 2>&1 & pids+=($!)
  done
  bad=0; for p in "${pids[@]}"; do wait $p || bad=1; done
  if [ $bad = 1 ]; then
    log "a model failed on batch $nb (see $O/batch_${nb}_*.log): releasing ${ws[*]}"; for w in "${ws[@]}"; do rm -rf $C/$w $O/$w/maps; done; exit 1
  fi
  log "batch $nb: $MODELS on ${#ws[@]} windings in $(( $(date +%s) - t0 ))s"
  for w in "${ws[@]}"; do
    Z=$R/${B}_$w.zarr; D=$O/$w
    grep -a -o "crop \[[^]]*\]" "$Z.log" | tail -1 > $D/render_crop.txt
    echo "$W/flat/${B%f}/mesh/$w" > $D/mesh_path.txt
    if line=$($PY $S/screen_sheet.py "$Z" $D/maps $D "$B/$w" 2>> $O/errors.log); then
      ( flock 7; echo "$line" >> $O/summary.jsonl ) 7>$O/.summary.lock
      [ "${KEEP_RENDERS:-0}" = 1 ] || rm -rf "$Z" "$Z.log"
    else log "$w: screen_sheet failed (see $O/errors.log)"; fi
  done
  log "batch $nb: ${#ws[@]} windings screened in $(( $(date +%s) - t0 ))s total: ${ws[*]}"
  nb=$((nb + 1)); [ -n "${MAX_BATCHES:-}" ] && [ $nb -ge $MAX_BATCHES ] && { log "MAX_BATCHES reached"; exit 0; }
done
