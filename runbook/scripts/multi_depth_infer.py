"""multi_depth_infer.py <surface.zarr> <checkpoint> <out_dir> <d0> <d1> [step] - one model load (and one torch.compile)
for many depths: villa's flat ink inference (vesuvius.ink_detection.inference.infer, same defaults as run_ink.sh:
overlap 0.5, hann blend, both directions) at every depth d0..d1, written under run_ink.sh's file names
(<name>__<model>__L66s<s>.tif = blind side, ..._reverse.tif = reading side, s = 33 + d - 8).

Same maps as one run_ink.sh call per depth, without the per-depth start-up (P8 reviews: ~4 min per model run).
Many segments with the same load: pass @<list file> as <surface.zarr>, one "<surface.zarr><TAB><out dir>" per line
(<out_dir> on the command line is then unused); each segment's maps go to its own out dir.
Environment: MODEL (name used in the file names, default readerv3), N_LAYERS (66), VILLA_BATCH (4), VILLA_WORKERS (4,
villa's default data-loader workers), L0_ONLY (1)."""
import os, shutil, sys, tempfile, time
from dataclasses import replace
from pathlib import Path

import torch
from vesuvius.ink_detection.inference import infer as I

tmp = None


def main():  # DataLoader workers start by re-importing this file (spawn): nothing may run at import time
    global tmp
    zarr_arg, ckpt, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    d0, d1 = int(sys.argv[4]), int(sys.argv[5]); step = int(sys.argv[6]) if len(sys.argv) > 6 else 1
    model_name = os.environ.get("MODEL", "readerv3"); N = int(os.environ.get("N_LAYERS", "66"))
    jobs = ([tuple(l.rstrip("\n").split("\t")) for l in open(zarr_arg[1:]) if l.strip()] if zarr_arg.startswith("@")
            else [(zarr_arg, str(out))])
    tmp = Path(tempfile.mkdtemp(dir=os.environ.get("TMPDIR")))

    def level0(zarr_in):  # run_ink.sh presents a full VC3D render (levels 0-5) as level 0 only, so villa selects the same patches
        if os.environ.get("L0_ONLY", "1") == "1" and Path(zarr_in, "1").is_dir() and Path(zarr_in, "0", ".zarray").is_file():
            l0 = Path(tempfile.mkdtemp(dir=tmp)) / "l0.zarr"; l0.mkdir(); (l0 / ".zgroup").write_text('{"zarr_format": 2}')
            os.symlink(Path(zarr_in, "0").resolve(), l0 / "0"); return str(l0)
        return zarr_in


    zin = level0(jobs[0][0])
    args = I.normalize_inference_paths(I.parse_args([zin, ckpt, str(tmp / "out.tif"), "--overlap", "0.5", "--blend-mode",
                                                     "hann", "--batch-size", os.environ.get("VILLA_BATCH", "4"), "--num-workers", os.environ.get("VILLA_WORKERS", "4"),
                                                     "--direction", "both", "--layer-start", "0", "--layer-end", "17"]))
    if hasattr(torch, "set_float32_matmul_precision"):
        torch.set_float32_matmul_precision("high")
    t = time.time()
    configured = I.configure_model(args)
    model, device = I.prepare_model_for_inference(configured.model, gpu_ids=args.gpu_ids,
                                                  compile_model=args.compile_model, compile_mode=args.compile_mode)
    configured = replace(configured, model=model)
    print(f"model ready in {time.time() - t:.0f} s", flush=True)

    for zarr_in, o in jobs:
        name = Path(zarr_in.rstrip("/")).stem; o = Path(o); o.mkdir(parents=True, exist_ok=True); zin = level0(zarr_in)
        for d in range(d0, d1 + 1, step):
            s = N // 2 + d - 8; e = s + 17
            assert 0 <= s and e <= N, f"d={d} gives layers {s}..{e - 1}, outside 0..{N - 1}"
            args.layer_start, args.layer_end = s, e
            t = time.time()
            for direction in I.resolve_run_directions("both"):
                tif = I.resolve_single_output_path(tmp / "out.tif", direction=direction, requested_direction="both")
                I.infer_single_zarr(args=args, input_zarr=zin, configured_model=configured, device=device,
                                    output_tiff=tif, layer_direction=direction)
            shutil.move(tmp / "out.tif", o / f"{name}__{model_name}__L{N}s{s}.tif")  # move: TMPDIR may be another device (RAM)
            shutil.move(tmp / "out_reverse.tif", o / f"{name}__{model_name}__L{N}s{s}_reverse.tif")
            print(f"{name} d={d:+d} s={s} {time.time() - t:.0f} s", flush=True)


if __name__ == "__main__":
    main()
