# Runbook: every script that produced a result

All scripts are in [`scripts/`](scripts/). Pod jobs ran through `launch.sh` (one job at a time per name, with
`.running` / `.done` / `.failed` markers); the logs are on Hugging Face under `pipeline_logs/`.

| # | Step | Scripts | Output |
|---|---|---|---|
| 0 | Pod and volume setup: ink environment (villa `0fb38c45` flat inference), six checkpoints, VC3D, villa main + auto steps | `setup_p9.sh` | environments on the network volume |
| 1 | Window P: fit inputs and fit | `p9_prep.sh`, `hf_zarr_window.py`, `fetch_subzarr.py`, `p9_pilot.sh`, `autosteps_run.sh`, `main_export_windings.py`; `p9_pull.sh` restores the fit from Hugging Face | `window_P/fit` |
| 2 | 343 positive control: render the published letter segment, screen it, measure letter vs background | `ctrl_render.sh`, `ctrl_p9.sh`, `calib_343.py`, `multi_depth_infer.py` | `control_343/` (dataset), `analysis/control_343_calibration*.json` (repo) |
| 3 | Speed test: one model load for many depths | `speed_test.sh`, `multi_depth_infer.py` | logs/DECISIONS.md |
| 4 | Flatten every in-scope winding (CPU) | `flatten_pool.sh`, `flatten_one.sh` | `window_*/meshes/flattened` |
| 5 | Render (CPU pod) and screen (GPU pod, three models side by side) | `render_pool.sh`, `cache_trim.sh`, `screen_fast.sh`, `multi_depth_infer.py`, `screen_sheet.py` | `window_P/screen`, `window_P/ink_maps` |
| 6 | Background statistics and ranking; gate package (whole-winding six-model views, reading + blind) | `bg_stats.py`, `rank_flags.py`, `after_screen.sh`, `seg_big_p9.sh`, `seg_yellow_p9.py`, `run_ink.sh`, `hecate_prep.py`, `segB_models.sh` | `analysis/gate_ranking`, `window_P/judged_windings`, `renders/` (repo) |
| 7 | Human verdict page (keys 1-5, export) | `review_page_p9.py`, `review_page_template.html` | `analysis/gate_verdicts.json` |
| 8 | Screen speed benchmark on an idle pod | `bench_screen.sh`, `stage_test.sh` | `analysis/speed_benchmark` (dataset), `analysis/bench.tsv` (repo) |
| 9 | Second window W2: inputs, fit, flatten | `p9_prep.sh`, `after_screen.sh` (fit step), `autosteps_run.sh`, `flatten_pool.sh` | `window_W2/fit`, `window_W2/meshes` |
| 10 | Prereg amendment 1: self-calibrated re-screen and 343 control check | `rescreen_null.py` | `analysis/rescreen_*` (repo), `analysis/rescreen_self_calibrated` (dataset) |
| 11 | Dataset staging, layout and manifest | `stage_hf_p9.sh`, `stage_hf_p9_extras.sh`, `reorg_hf_p9.sh` | Hugging Face dataset |

Software: villa main `7154682e1` + auto-steps merge `a81b4f912` (fit), villa `0fb38c45` (flat ink inference),
VC3D AppImage (render), PyTorch 2.11 (fit) and the ink environment's PyTorch (inference). Data: public PHerc0175A
volume `20250521115057-8.640um-1.2m-116keV-masked`, its m7 surface prediction, the community lasagna field and center
line (SharpMeow). Paths in the scripts assume a network volume at `/workspace`.
