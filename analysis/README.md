# Analysis files

| File | What it is |
|---|---|
| `gate_verdicts.json` | The human's verdicts on the ten judged windings (all "no": not ink). |
| `gate_ranking.tsv` | Every flag of the preregistered screen (both sides): second-strongest model's 4 mm peak over its threshold, the same above the winding's own background, flagged share, papyrus area. |
| `control_343_calibration.json` | PHerc. 343 control, three screen models, depths -1..+1, letter vs background medians and separation, reading and blind side. |
| `control_343_calibration_readerv3.json` | The same for reader-v3 over depths -8..+8. |
| `rescreen_thresholds.json` | Prereg amendment 1: per-model thresholds (blind-side 99.9th percentile of 4 mm window z-means, 117 windings). |
| `rescreen_by_winding.tsv` | Amendment 1, per winding and side: flagged area, flagged share, strongest window. |
| `rescreen_control_check.json` | Amendment 1 on the 343 control: letter boxes hit (0 of 18), FAIL. |
| `bench.tsv` | Screen speed benchmark on an idle GPU pod (4 windings): seconds, GPU use, CPU throttling per variant. |
| `bench_map_comparison.txt` | Every benchmark map compared with the baseline (max difference, share of differing pixels). |
| `model_sha256.txt` | Checksums of the six ink model checkpoints used. |
