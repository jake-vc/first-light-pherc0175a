#!/bin/bash
# stage_test.sh <render zarr> - does the screen wait on reading renders from the network volume? reader-v3 on one
# rendered winding three ways, same pod, same load: (a) zarr on /workspace (as screen_fast.sh reads it now), (b) zarr
# copied to /dev/shm, (c) /dev/shm with VILLA_WORKERS=8. Copies the render first, so the screen may delete the original.
# Prints seconds per variant and the largest map difference vs (a) (P8 run-to-run noise: <= 1/255).
set -euo pipefail
Z=$1; W=/workspace; S=$W/p8/scripts; T=$W/tmp/stagetest; M=/dev/shm/stagetest
export CKPT_DIR=$W/ckpt PY=$W/venv/bin/python TMPDIR=/dev/shm/stagetest_tmp L0_ONLY=0 OMP_NUM_THREADS=5 MKL_NUM_THREADS=5
export TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor TRITON_CACHE_DIR=/root/.cache/triton MODEL=readerv3
rm -rf $T $M; mkdir -p $T $M $TMPDIR; trap 'rm -rf $M $TMPDIR' EXIT
n=$(basename $Z)
t=$(date +%s); cp -r $Z $T/$n; echo "copy to /workspace/tmp: $(( $(date +%s) - t ))s"
t=$(date +%s); cp -r $T/$n $M/$n; echo "copy to /dev/shm: $(( $(date +%s) - t ))s"
run() {  # <label> <zarr> <workers>
  mkdir -p $T/out_$1; printf '%s\t%s\n' "$2" "$T/out_$1" > $T/$1.list
  t=$(date +%s); VILLA_WORKERS=$3 $PY $S/multi_depth_infer.py @$T/$1.list $CKPT_DIR/reader-v3.pth /nonexistent 0 0 > $T/$1.log 2>&1
  echo "$1: $(( $(date +%s) - t ))s total; $(grep ' s$' $T/$1.log | tail -1)"
}
run a $T/$n 4; run b $M/$n 4; run c $M/$n 8
$PY - $T <<'EOF'
import sys, glob, numpy as np, tifffile
t = sys.argv[1]
for v in "bc":
    for f in sorted(glob.glob(f"{t}/out_a/*.tif")):
        a = tifffile.imread(f).astype(np.float64); b = tifffile.imread(f.replace("out_a", f"out_{v}")).astype(np.float64)
        print(v, f.split("/")[-1], "max diff", np.abs(a - b).max(), "of max", a.max())
EOF
ls -R $T/out_a | head
