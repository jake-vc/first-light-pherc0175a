# P9 night log (10/29, ET) - work items, enhancements tested, status lines

Priority: first letters on PHerc0175A. Enhancements only where they speed or cheapen that, each validated before use
(the human, 12:35 am 10/29: "review, validate, and implement if positive"; budget adherence).

## Work items (priority order)
| # | Item | State |
|---|------|-------|
| 1 | Pilot window P screened (screenP) -> gate: five strongest flags to the human | DONE: gate page evidence/P9/gate/index.html (5 am); waiting for the human's verdict |
| 2 | Gate package: rank flags + whole-winding yellow views (adapt seg_big.sh) | scripts done (rank_flags.py, seg_big_p9.sh, seg_yellow_p9.py); top-5 re-rendered (segrender done 1:20 am: w092 w028 w091 w075 w044); DONE 4:51 am (w114 yellow redone with mean/std at 4:55) |
| 3 | W2 fit (after screenP) | DONE: fit 0.723 on-sheet, flattened 113/113; screening waits for the verdict |
| 4 | Flag-rate note (100% vs P8 42%) and depth direction | DONE: background above 343's; blind side flags 104/117 vs reading 111/117; in the gate page and STATE |
| 5 | PR ideas (#3, #6, #7, #8) | #3, #6, #7 DROPPED by evidence; #8 (models side by side, 2.4x, identical maps) MEASURED |
| 6 | Clean screen benchmark | DONE 5:55 am (results below; all 64 map comparisons identical) |

## Enhancements: tested / found
- 12:28 am: "move render worker 2 off the GPU pod": REJECTED by evidence. The GPU-pod host is 76% idle; renders are
  ahead of the screen (17 waiting, both workers held by the 60 GB render budget); render on p9g 107-162 s vs 400-620 s
  on p9. Not the bottleneck.
- 12:30 am: screen bottleneck = data loading (GPU 16-35% busy, DataLoader workers 60-80% CPU each, ~130 s per winding
  per model). Test stagetest (stage_test.sh): reader-v3 on w105 from /workspace vs /dev/shm vs /dev/shm + 8 workers.
  Copy costs: 31 s to /workspace/tmp, 17 s to /dev/shm (3 GB). Result: pending.

- 12:45 am: CORRECTION to the 12:28 entry: the GPU pod's container is capped at 13.6 CPUs (cgroup quota) and was
  throttled in 94 of 101 periods: the screen IS CPU-bound (host idle % was misleading). Moving render worker 2 off it
  would still starve the screen (22 windings left to render; the CPU pod renders at 400-620 s each vs 107-162 s): kept.
  Consequence: the W2 fit waits for the screen to end instead of sharing the GPU pod.
- 12:50 am: stagetest result: reader-v3 on w105 175 s from /workspace vs 200 s from /dev/shm (c: pending). Staging
  renders in RAM: NO gain (same as tune_test 10/28). Rejected.
- 12:50 am: flag-rate analysis (bg_stats.py over 84 screened windings' saved maps, VERIFIED from raw maps): papyrus
  background on 0175A sits above the 343 control's: median p50 dense_native 0.333 (343 0.294), reader-v2 0.282
  (0.259), reader-v3 0.267 (0.251); the p90 already reaches the letter-median thresholds (dnative 0.455-0.463 vs 0.4235,
  reader-v2 0.365-0.371 vs 0.3608). So a 4 mm window over the brighter papyrus passes: near-universal flags.
  Reading side (reverse, as on 343 and P8) gives the large hit areas (up to 47% of a winding); blind side (forward)
  smaller (median 1.3%, max 12%).
- 12:55 am: ranking (rank_flags.py, the ink-review guide rule: second-strongest model's 4 mm peak / threshold, reading
  side): w092 1.51, w028 1.47, w091 1.44, w075 1.43, w044 1.43 (84 of 117 screened). Same flags measured above each
  winding's own background put w073, w074, w028, w044, w057 on top. Flags come in neighbouring pairs/runs
  (w028/29, w044/45, w073-75, w091-93): for the eye review (prereg "same pattern on a neighbouring turn").

- 12:52 am: stagetest c (RAM, VILLA_WORKERS=8): 99 s vs 175-200 s with 4 workers, maps identical (max diff 0). Noisy
  (screen alongside); a clean bench decides (screen speed is the cost lever: ~8 GPU-h per window now, so only about one
  more window fits the $18 line at this speed). Four renders kept in /workspace/tmp/bench (w105-w108, ~12 GB).
- 12:54 am: queued afterscreen on p9g: ranking over all 117 -> seg_big_p9.sh on the five strongest (gate package) ->
  bench_screen.sh -> W2 fit (when prepW2 is done). autosteps_run.sh: CHECK_PY (no VC venv on this volume; snap tool
  runs under /workspace/venv, help check passed). segrender (CPU pod) pre-renders the current top five (w092 258 s).
- 12:55 am: the stagetest ran alongside the screen and slowed batch 9 (1,295 s vs ~1,110 s): ~3 min lost. Lesson: no
  more side tests on the GPU pod while it screens.

## Status lines (each 30-min check appends one)
- 12:56 am ET | screenP 96/117 (batch 10 running), renderP_1/2, cache_trim x2, segrender, prepW2 (HF 429 backoff), afterscreen queued | P9 spend ~$5.2 (est.) | usage low | next: gate package ~2:00-2:45 am
- 1:00 am ET | night check clean (no failed/DEAD); volume 118 GB -> grown to 200 GB | RunPod billed 10/29 $4.39 (lags ~1 h) | usage 5-h 32% | next: screenP end ~2:00 am, then gate package
- 1:15 am ET | ALERT fixed: CPU pod own disk 7.6 GB free (two renders filling VC3D cache faster than cache_trim's 30-min rule): trimmed to 20 GB free; cache_trim.sh thresholds now env (OLD_MIN/HARD_AT/HARD_MIN), restarted on p9 with 10 min / 8 GB / 2 min (new PID 214380; old 113363 stopped by exact PID) | no jobs affected
- 1:24 am ET | screenP 104/117 (batch 11), renderP_1/2 (budget-held), prepW2 2/3 fields, afterscreen waiting; segrender DONE | RunPod billed 10/29 $4.95 (watchdog est. $6.0) | usage 5-h 35% | volume 134/200 GB | next: screenP end ~2:05 am
- 1:54 am ET | screenP 112/117 (last batch; batch 11 1,627 s: biggest outer windings + a render alongside), renderP_1/2, afterscreen waiting; prepW2 DONE | RunPod billed 10/29 $5.61 (watchdog est. $6.72) | usage 5-h 36% | volume 122/200 GB | next: screenP end ~2:10 am, gate package ~2:10-2:45
- 2:09 am ET | renderP_1 DONE (all windings rendered, 0 FAILED); screenP batch 12 done (w113-w120), last batch running (~2:30 am end) | CPU pod kept (W2 flatten after the fit; restart risk) though idle ~2 h (~$0.64)
- 2:24 am ET | screenP last batch (w121+) running since 2:02 am; renderP_1/2 DONE; afterscreen waiting | RunPod billed 10/29 $6.29 (watchdog est. $7.44) | usage 5-h 37% | volume 108/200 GB | next: screenP end ~2:30 am, gate package to ~3:00 am
- 2:40 am ET | screenP DONE 2:35 am: 117/117 in-scope windings screened (stats.json 117 = summary lines 117), 0 errors. Reading-side flags 111/117, blind-side flags 104/117 (the blind side works as a control: the flags look like background, not ink). Guide-rule top five: w114 1.65, w113 1.64, w112 1.62, w103 1.60, w105 1.60 (corr. guide strength vs winding area 0.43: the rule favours the big outer windings; w112-w114 are neighbours). Lift-over-own-background top five: w073 2.22, w074 1.89, w028 1.83, w044 1.66, w057 1.61. Gate package = guide-rule five (afterscreen, rendering on p9g now); comparison set B = lift five (segrenderB on the CPU pod; segmodelsB models after the bench, alongside the W2 fit). Earlier pre-renders w092 w091 w075 not in either set (~10 GB, scratch).
- 2:55 am ET | ALERT handled: GPU idle 20+ min while afterscreen renders the gate five one by one on p9g (~700 s each: big outer windings): w105 (last in its order) rendered in parallel on the CPU pod (segrenderA105), no collision possible (chain at w113 now); saves ~10 min GPU idle. Lesson for next windows: render the gate set on both pods, or keep the top windings' screen renders (KEEP_RENDERS for the top of the running ranking). | screenP done; RunPod billed 10/29 $6.95 (watchdog est. $8.17) | usage 5-h 39% | volume 87/200 GB | next: gate package ~3:40 am
- 3:24 am ET | gate five rendered (w105 on the CPU pod saved one render); afterscreen now running ink_9um x2 + Hecate on them; segrenderB DONE (set B waits for the bench) | RunPod billed 10/29 $7.62 | usage 5-h 40% | volume 99/200 GB | next: gate package ~3:45 am, then bench (~25 min), W2 fit + set B models
- 3:54 am ET | gate package: ink_9um x2 done on all five, Hecate + yellow per winding (w114 done); yellow z-scores switched to mean/std (P8 review_images.py statistic; median/MAD let Hecate's near-zero maps dominate: median 0.016, MAD 0.017) - w114 to be redone | RunPod billed 10/29 $8.29 | usage 5-h 41% | volume 99/200 GB | next: gate package ~4:10 am, bench, W2 fit
- 4:00 am ET | Hecate ~16 min per whole winding on the gate five (sequential -> ~5 am): started w105's Hecate in parallel (hecA105; the chain skips it when its output exists; it reaches w105 last)
- 4:24 am ET | gate package 2/5 yellow views (w114, w113), w112 in progress, hecA105 running alongside | RunPod billed 10/29 $8.96 (watchdog est. $10.0) | usage 5-h 43% | volume 100/200 GB | CPU pod idle: kept (W2 flatten after the fit: idle 2 h ~$0.64 + flatten ~$0.32 there, vs ~$1 flattening on the GPU pod; and no restart risk) | next: gate package ~4:50 am
- 4:56 am ET | GATE PACKAGE DONE: five strongest (w114 w113 w112 w103 w105), six-model whole-winding yellow, reading + blind side, private page evidence/P9/gate/index.html (committed in evidence/P9 git, local only); NEEDS_HUMAN updated; afterscreen now on the bench | RunPod billed 10/29 \$9.62 | usage 5-h 44% | volume 99/200 GB | next: bench ~5:20, W2 fit ~6:20, set B views alongside
- 5:24 am ET | bench (idle GPU pod, 4 windings w105-w108, 3 models at once): V4 (4 loader workers) 659 s, GPU 17%, CPU throttled 42% of periods; V8 853 s (SLOWER), throttled 35%. So more workers do not help in the production setup (the 12:52 single-model 99 s was contention noise); the screen is CPU-capped (13.6 cores). On an idle pod the screen runs ~6.3 s/cm2 (overnight ~14 s/cm2 with renders alongside) -> next windows: render on the CPU pod only, not on the GPU pod. V12, R1ram/R1vol pending (~5:45 am). | RunPod billed 10/29 $10.30 | Claude 5-h window reset (0%) | volume 100/200 GB
- 5:54 am ET | bench timings complete (map comparison running): V12 1,096 s (slower still: GPU 10%); R1ram (reader-v3 alone, TMPDIR in RAM) 536 s, R1vol (TMPDIR on the volume) 531 s -> TMPDIR location makes NO difference on an idle pod (the 10/28 gap was contention): PR idea #6 DROPPED. Three models at once (V4 659 s) vs one alone (536 s): 1.23x the time for 3x the work -> running the models side by side is the real gain (~2.4x vs one after another); keep 4 workers. | RunPod billed 10/29 $10.96 | volume 101/200 GB | next: bench compare, then W2 fit (~1 h) + set B views
- 6:00 am ET | bench maps: all 64 comparisons vs V4 have max diff 0 (V8, V12, R1ram, R1vol): identical maps (VERIFIED from bench.log). W2 fit STARTED 5:56 am (villa main a81b4f9 = main + auto-steps, z 7600-10600, windings 10-129); set B models start alongside
- 6:24 am ET | W2 FIT DONE 6:23 am (28 min, ~$0.46): 120 windings, snapped on-sheet median 0.723 (pilot 0.743); in scope 113 windings, ~1,902 cm2 (snapped area). W2 flatten: first start FAILED fast on every winding (my launch lacked FLAT_DEVICE=cpu on the GPU-less CPU pod: "Found no NVIDIA driver"); stopped the 4 workers by exact PID after 8 windings, removed the failed W2 debris, restarted with FLAT_DEVICE=cpu (4 workers x 2 threads): ~1 min per inner winding. Fix: flatten_one.sh now defaults to cpu where there is no nvidia-smi. Set B: ink_9um x2 done, w073 yellow done. W2 screening waits for the human's gate verdict. | RunPod billed 10/29 $11.64 | usage 5-h 3% | volume 114/200 GB | next: stop the GPU pod when set B is done (~7 am)
- 6:54 am ET | afterscreen DONE (gate package, bench, W2 fit); set B 4/5 views (w057 last, ~7:05 am); W2 flatten 56/113, 0 failed | RunPod billed 10/29 $12.30 | volume 115/200 GB | next: stop the GPU pod when set B ends (waiter running); W2 flatten done ~7:45 am, then the CPU pod idles until the verdict
- 6:58 am ET | set B DONE (5 views, copied to evidence/P9/gate/compare); GPU pod STOPPED (EXITED confirmed); cache_trim_p9g stopped by PID first | CPU pod: W2 flatten running
- 7:24 am ET | W2 flatten 93/113, 0 failed (outer windings ~4 min each); GPU pod stopped | RunPod billed 10/29 $12.98 (lags ~1 h) | usage 5-h 8% | volume 115/200 GB | next: W2 flatten done ~7:45 am, then stop the CPU pod (idle until the verdict)
- 7:50 am ET | W2 flatten DONE 113/113, 0 failed; CPU pod STOPPED; all pods stopped; monitoring off | RunPod billed 10/29 $13.53 (est. ~$14.0 final) | volume 116/200 GB | waiting for the human's gate verdict
- 8:30 am ET | GATE VERDICT (human): none of the ten windings have ink. Recorded (DECISIONS, evidence/P9/gate/p9_gate_verdicts.json). Waiting for the human's choice of next step; pods stopped.
- 9:15 am ET | amendment-1 re-screen done (11 min, p9c2): reading 34/117 vs blind 35/117 windings flagged; 343 control FAILED (0/18) -> rule not used; top windings = the already-judged ones. p9c2 STOPPED.
