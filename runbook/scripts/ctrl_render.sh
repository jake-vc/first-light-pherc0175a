#!/bin/bash
# ctrl_render.sh - P9 positive control, CPU part: the 66-layer VC3D render of the 343 winner's published letter segment
# (PHerc. 343, w047-w048, z 9500-11000), CT streamed from the open-data bucket, then per-layer hashes (render_hash.py)
# for comparing builds. The models run later on a GPU pod (speed_test.sh, then the screen models). Run via launch.sh.
set -euo pipefail
W=/workspace; S=$W/p8/scripts; C=$W/ctrl; N=concat_w047-w048_R5B2_z9500-11000
CT=https://vesuvius-challenge-open-data.s3.us-east-1.amazonaws.com/PHerc0343/volumes/20250521140437-8.640um-1.2m-116keV-masked.zarr
mkdir -p $C
# pod memory cap is 32 GB: VC3D cache 12 GB
[ -d $C/${N}_66.zarr/0 ] || env QT_QPA_PLATFORM=offscreen OMP_NUM_THREADS=8 $W/vc3d/squashfs-root/AppRun vc_render_tifxyz \
  --volume "$CT" --group-idx 0 --scale 1 --segmentation $W/pherc343/outputs/$N.tifxyz \
  --num-slices 66 --slice-step 1 --cache-gb 12 --zarr-output $C/${N}_66.zarr
du -sh $C/${N}_66.zarr
$W/venv/bin/python $S/render_hash.py $C/${N}_66.zarr | tee $W/p8/out/ctrl_render_hash.txt
du -sh $HOME/.VC3D 2>/dev/null || true
