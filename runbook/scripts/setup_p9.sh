#!/bin/bash
# setup_p9.sh - everything P9 needs on a fresh, empty network volume (run via launch.sh; log in /workspace/p8/out).
# Layout kept from P8 (/workspace/p8/{scripts,state,out}) so every script works unchanged; one project per volume.
#   ink env      villa 0fb38c45 (the 343 winner's, validated on the control) + venv; six checkpoints (P9 prereg)
#   renderer     VC3D "latest" AppImage (main build), name and sha256 recorded
#   fit env      villa main (blobless clone) + its spiral-fitting venv; /workspace/villa_autosteps = main with the
#                auto-steps branch (jake-vc/villa spiral-fitting-auto-steps, PR #2323) merged in
#   control      the 343 winner's repo (its published letter segment and lasagna flatten config; no checkpoints)
# Each step is skipped when its result exists, so a rerun resumes. Sizes are logged per step (volume quota is
# invisible to df: run the dd probe before this script).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 UV_LINK_MODE=copy UV_HTTP_TIMEOUT=600
export UV_CACHE_DIR=/workspace/.uv-cache UV_PYTHON_INSTALL_DIR=/workspace/.uv-python PATH=/workspace/bin:$PATH
W=/workspace; S=$W/p8/scripts; mkdir -p $W/p8/out $W/bin $W/ckpt $W/tmp
INK_COMMIT=0fb38c45b488e192566ea83ae36369cb6db92652
step() { echo "=== $(date -u +%FT%TZ) $*"; }
size() { du -sh "$@" 2>/dev/null | sed 's/^/    size /'; }

step apt; bash $S/aptlibs.sh
apt-get install -y -qq --no-install-recommends git build-essential cmake ninja-build pkg-config libgomp1 zstd pigz \
  file jq unzip >/dev/null

step uv
[ -x $W/bin/uv ] || { python3 -m pip install -q --break-system-packages --target $W/.uvpkg uv; ln -sf $W/.uvpkg/bin/uv $W/bin/uv; }
uv --version; uv python install 3.14

step ink villa $INK_COMMIT
if [ ! -d $W/villa/.git ]; then
  mkdir -p $W/villa && git -C $W/villa init -q && git -C $W/villa remote add origin https://github.com/ScrollPrize/villa.git
fi
git -C $W/villa fetch -q --depth 1 origin $INK_COMMIT && git -C $W/villa checkout -q FETCH_HEAD
test "$(git -C $W/villa rev-parse HEAD)" = "$INK_COMMIT"

step ink venv
# cu130 wheels need an NVIDIA driver for CUDA 13; on an older driver use the cu128 backend
# (a CPU-only setup pod has no nvidia-smi: install cu130, as on P8; the later GPU hosts in US-WA-1 report CUDA 13.2)
BACKEND=cu130
if command -v nvidia-smi >/dev/null && ! nvidia-smi | grep -q "CUDA Version: 1[3-9]"; then BACKEND=cu128; fi
# bootstrap_venv.py's final "CUDA available" check fails on a CPU-only pod: skip it there with its own
# --skip-cuda-check flag (villa has it; P9 first used an exit-code workaround); the import check below still runs
SKIP=""; command -v nvidia-smi >/dev/null || SKIP=--skip-cuda-check
if [ ! -x $W/venv/bin/python ]; then
  (cd $W/villa/lasagna && python3 scripts/bootstrap_venv.py --venv $W/venv --backend $BACKEND $SKIP) || { echo "bootstrap failed"; exit 1; }
fi
uv pip install -q --python $W/venv/bin/python tifffile zarr numpy numcodecs opencv-python-headless safetensors huggingface_hub
$W/venv/bin/python -c "import torch, vesuvius.ink_detection.inference.infer; print('ink env', '$BACKEND', torch.__version__, torch.cuda.is_available())"
size $W/venv

step winner repo + its four checkpoints "(dense_native, ink_9um seeds 42/43, Hecate)"
[ -d $W/pherc343 ] || git clone -q --depth 1 https://github.com/Nieuwlaar/pherc343-first-letters.git $W/pherc343
git -C $W/pherc343 log --oneline -1; chmod +x $W/pherc343/ink/scripts/*.sh $W/pherc343/ink/scripts/*.py
PY=$W/venv/bin/python bash $W/pherc343/ink/scripts/fetch_checkpoints.sh $W/pherc343/ink/models.tsv $W/ckpt

step reader-v2 + reader-v3
[ -s $W/ckpt/reader-v2-step040000.pth ] || $W/venv/bin/hf download domenicor046/reader-v2 reader-v2-step040000.pth --local-dir $W/ckpt >/dev/null
[ -s $W/ckpt/reader-v3.pth ] || $W/venv/bin/hf download domenicor046/reader-v3 reader-v3.pth --local-dir $W/ckpt >/dev/null
sha256sum $W/ckpt/*.pth | tee $W/p8/out/ckpt.sha256; size $W/ckpt $W/pherc343

step VC3D
mkdir -p $W/vc3d && cd $W/vc3d
if [ ! -x squashfs-root/AppRun ]; then
  URL=$(curl -sf https://api.github.com/repos/ScrollPrize/villa/releases/tags/latest | python3 -c '
import json, sys
print([a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith("linux-x86_64.AppImage")][0])')
  curl -sfL -o "$(basename "$URL")" "$URL"; chmod +x ./*.AppImage; ./*.AppImage --appimage-extract >/dev/null
fi
sha256sum ./*.AppImage | tee $W/p8/out/vc3d_build.txt; size $W/vc3d

step fit env: villa main + auto-steps
if [ ! -d $W/villa_main/.git ]; then
  git clone -q --filter=blob:none https://github.com/ScrollPrize/villa.git $W/villa_main
fi
git -C $W/villa_main fetch -q origin main && git -C $W/villa_main checkout -q --detach origin/main
git -C $W/villa_main log --oneline -1 | tee $W/p8/out/villa_main_commit.txt
(cd $W/villa_main/spiral-fitting && CMAKE_BUILD_PARALLEL_LEVEL=8 uv sync -q)
# named ref, not FETCH_HEAD: a worktree does not see the main checkout's FETCH_HEAD
git -C $W/villa_main fetch -q https://github.com/jake-vc/villa.git +spiral-fitting-auto-steps:refs/remotes/jake/auto-steps
[ -d $W/villa_autosteps ] || git -C $W/villa_main worktree add -q --detach $W/villa_autosteps origin/main
cd $W/villa_autosteps && git checkout -q --detach origin/main && \
  git -c user.name=p9 -c user.email=p9@localhost merge -q --no-edit refs/remotes/jake/auto-steps
grep -q auto_steps $W/villa_autosteps/spiral-fitting/fit_spiral.py
git -C $W/villa_autosteps log --oneline -3 | tee $W/p8/out/villa_autosteps_commit.txt
$W/villa_main/spiral-fitting/.venv/bin/python -c "import torch; print('fit env', torch.__version__, torch.cuda.is_available())"
size $W/villa_main $W/villa_autosteps

step clean caches; rm -rf $W/.uv-cache/*; size $W
step done
