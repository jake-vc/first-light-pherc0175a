#!/bin/bash
# bench_screen.sh - clean timing of the screen on an otherwise idle GPU pod (run after screenP; P9 night item "screen
# speed"). Four kept renders in $W/tmp/bench. Variants, each the production command of screen_fast.sh:
#   V4 : three models at once, VILLA_WORKERS=4, TMPDIR in RAM (screen_fast.sh today)
#   V8 : same with VILLA_WORKERS=8          V12: VILLA_WORKERS=12
#   R1ram / R1vol: reader-v3 alone, 4 workers, TMPDIR in RAM vs on the network volume (PR idea #6)
# Per variant: wall seconds, GPU busy % (nvidia-smi, 2 s samples), CPU throttled share (cgroup cpu.stat); every map
# compared with V4's (max abs difference, P8 run-to-run noise <= 1/255). Results: $W/tmp/bench/bench.tsv.
set -uo pipefail
W=/workspace; S=$W/p8/scripts; B=$W/tmp/bench; PY=$W/venv/bin/python
export CKPT_DIR=$W/ckpt L0_ONLY=0 OMP_NUM_THREADS=5 MKL_NUM_THREADS=5
export TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor TRITON_CACHE_DIR=/root/.cache/triton
[ -f $B/copy.ok ] || { echo "bench renders not copied"; exit 1; }
ck() { case $1 in readerv2) echo $CKPT_DIR/reader-v2-step040000.pth ;; readerv3) echo $CKPT_DIR/reader-v3.pth ;;
       dnative) echo $CKPT_DIR/dense_native-016000.rebuilt.pth ;; esac; }
CG=/sys/fs/cgroup/cpu/cpu.stat
thr() { awk '/nr_periods/{p=$2}/nr_throttled/{t=$2}END{print p, t}' $CG; }
run() {  # <variant> <workers> <tmpdir> <models...>
  local v=$1 wk=$2 td=$3; shift 3; local O=$B/out_$v L=$B/$v.list pids=()
  rm -rf $O $td; mkdir -p $O $td; : > $L
  for z in $B/Pf_*_main.zarr; do mkdir -p $O/$(basename $z .zarr); printf '%s\t%s\n' $z $O/$(basename $z .zarr) >> $L; done
  read p0 t0 < <(thr); nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -l 2 > $B/$v.gpu & g=$!
  local s=$(date +%s)
  for m in "$@"; do TMPDIR=$td VILLA_WORKERS=$wk MODEL=$m $PY $S/multi_depth_infer.py @$L "$(ck $m)" /nonexistent 0 0 > $B/$v.$m.log 2>&1 & pids+=($!); done
  local bad=0; for p in "${pids[@]}"; do wait $p || bad=1; done
  local e=$(( $(date +%s) - s )); kill $g; read p1 t1 < <(thr); rm -rf $td
  local gpu=$(awk '{s+=$1;n++}END{printf "%.0f", n?s/n:0}' $B/$v.gpu)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' $v $wk "$*" $e $gpu $(awk -v a=$((p1-p0)) -v b=$((t1-t0)) 'BEGIN{printf "%.2f", a?b/a:0}') >> $B/bench.tsv
  echo "$v: ${e}s gpu ${gpu}% rc_bad=$bad"
}
printf 'variant\tworkers\tmodels\tseconds\tgpu_pct\tthrottled_share\n' > $B/bench.tsv
run V4 4 /dev/shm/bench_V4 readerv2 dnative readerv3
run V8 8 /dev/shm/bench_V8 readerv2 dnative readerv3
run V12 12 /dev/shm/bench_V12 readerv2 dnative readerv3
run R1ram 4 /dev/shm/bench_R1 readerv3
run R1vol 4 $W/tmp/bench_R1vol readerv3
cat $B/bench.tsv
$PY - $B <<'EOF'
import sys, glob, numpy as np, tifffile
b = sys.argv[1]; n = 0
for f in sorted(glob.glob(f"{b}/out_V4/*/*.tif")):
    a = tifffile.imread(f).astype(np.int32)
    for v in ("V8", "V12", "R1ram", "R1vol"):
        g = f.replace("out_V4", f"out_{v}")
        try: c = tifffile.imread(g).astype(np.int32)
        except FileNotFoundError: continue
        d = np.abs(a - c); n += 1
        print(v, f.split("/")[-1], "max diff", d.max(), "share differing", round(float((d > 0).mean()), 5))
if n == 0: sys.exit("no maps compared")
EOF
