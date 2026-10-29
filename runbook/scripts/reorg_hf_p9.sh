#!/bin/bash
# reorg_hf_p9.sh - turn the staged dataset (work/release/hf_pherc0175a, pod staging layout) into the final layout, one
# folder per window, and merge the fit extras (work/release/hf_extras, from stage_hf_p9_extras.sh). Moves only: files
# that are not uploaded go to work/release/hf_not_uploaded/ (nothing is deleted). Then rebuilds MANIFEST.tsv.
set -euo pipefail
R=~/vesuvius-kit/work/release; H=$R/hf_pherc0175a; E=$R/hf_extras; X=$R/hf_not_uploaded
cd $H; mkdir -p $X
for win in P W2; do
  D=window_$win; mkdir -p $D/fit $D/meshes
  for f in fit.log curve.tsv metrics.jsonl overrides.json villa_commit.txt fit_time.tsv windings.txt prepW2.log; do
    [ -f fits/$win/$f ] && mv fits/$win/$f $D/fit/
  done
  [ -d fits/$win/snap_check ] && mv fits/$win/snap_check $X/snap_check_$win      # = meshes/placement_snapped.tsv + copies
  [ -f fits/$win/README.md ] && mv fits/$win/README.md $X/README_first_publication_$win.md
  mv flat/$win $D/meshes/flattened
  mv $E/$D/fit/checkpoint $D/fit/
  for f in $E/$D/fit/*; do mv "$f" $D/fit/; done
  mv $E/$D/meshes/exported $E/$D/meshes/snapped $E/$D/meshes/placement_exported.tsv $E/$D/meshes/placement_snapped.tsv $D/meshes/
done
mv screen/Pf window_P/screen; mv maps/Pf window_P/ink_maps; mv seg_big/Pf window_P/judged_windings
mkdir -p analysis; mv gate analysis/gate_ranking; mv rescreen_A1 analysis/rescreen_self_calibrated; mv bench analysis/speed_benchmark
mv control control_343
mv MANIFEST.tsv $X/MANIFEST_staging_layout.tsv
rmdir fits/P fits/W2 fits flat screen maps seg_big 2>/dev/null || true
find . -type f ! -name MANIFEST.tsv -print0 | sort -z | xargs -0 shasum -a 256 | sed 's/  /\t/' | sort -k2 > MANIFEST.tsv
echo "$(wc -l < MANIFEST.tsv) files, $(du -sh . | cut -f1)"; ls
