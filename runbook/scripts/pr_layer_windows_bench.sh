#!/bin/bash
# pr_layer_windows_bench.sh - real-data proof for the villa --layer-windows PR: PHerc. 343's published letter segment
# (66-layer render), reader-v3, depths d -4..+4 (17-layer windows starting at 21..29), both directions.
#   before: one `python -m vesuvius.ink_detection.inference.infer` per depth (--layer-start/--layer-end): 9 model
#           loads and compiles, as villa main needs today;
#   after:  one command with --layer-windows 21:38,...,29:46 on the PR branch.
# Same branch code for both (the PR does not change the single-window path). Prints wall seconds and, per output, the
# max |difference| and the share of differing pixels between before and after.
set -uo pipefail
W=/workspace; PY=$W/venv/bin/python; B=$W/tmp/prbench; Z=$W/ctrl/concat_w047-w048_R5B2_z9500-11000_66.zarr
CK=$W/ckpt/reader-v3.pth
export PYTHONPATH=$W/tmp/prbranch/vesuvius/src TMPDIR=/dev/shm TORCHINDUCTOR_CACHE_DIR=/root/.cache/torchinductor
rm -rf $B && mkdir -p $B/before $B/after
common="--overlap 0.5 --blend-mode hann --batch-size 4 --direction both"
t0=$(date +%s)
for s in 21 22 23 24 25 26 27 28 29; do
  $PY -m vesuvius.ink_detection.inference.infer $Z $CK $B/before/out_L$s-$((s + 17)).tif --layer-start $s --layer-end $((s + 17)) $common > $B/before_$s.log 2>&1 || { echo "before s=$s FAILED"; exit 1; }
done
t1=$(date +%s); echo "before (9 commands): $((t1 - t0)) s"
wins=$(for s in 21 22 23 24 25 26 27 28 29; do printf '%s:%s,' $s $((s + 17)); done); wins=${wins%,}
$PY -m vesuvius.ink_detection.inference.infer $Z $CK $B/after/out.tif --layer-windows $wins $common > $B/after.log 2>&1 || { echo "after FAILED"; exit 1; }
t2=$(date +%s); echo "after (1 command, --layer-windows): $((t2 - t1)) s"
$PY - $B <<'EOF'
import glob, os, sys, numpy as np, tifffile
b = sys.argv[1]; n = 0
for f in sorted(glob.glob(f"{b}/before/*.tif")):
    g = f.replace("/before/", "/after/"); n += 1
    x = tifffile.imread(f).astype(np.int32); y = tifffile.imread(g).astype(np.int32); d = np.abs(x - y)
    print(os.path.basename(f), "max diff", d.max(), "differing share %.5f" % (d > 0).mean())
print(n, "outputs compared")
EOF
