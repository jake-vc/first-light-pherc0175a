#!/bin/bash
# p9_pull.sh - the P9 pilot fit outputs (public Hugging Face dataset Jake-vc/pherc0175a-pilot: final checkpoint,
# snapped meshes at step 10,000, run records) onto the volume, anonymously, then every file checked against the
# dataset's MANIFEST.tsv (sha256). Output /workspace/p9/fit0175A/pilot. Run via launch.sh.
set -euo pipefail
D=/workspace/p9/fit0175A/pilot; PY=/workspace/venv/bin/python
mkdir -p $D
$PY -c "
from huggingface_hub import snapshot_download
snapshot_download('Jake-vc/pherc0175a-pilot', repo_type='dataset', local_dir='$D', max_workers=8)"
cd $D && sha256sum -c --quiet MANIFEST.tsv && echo "MANIFEST: all $(wc -l < MANIFEST.tsv) files match"
du -sh $D; ls $D/s10000/snap | head -3; ls $D/s10000/snap | wc -l
