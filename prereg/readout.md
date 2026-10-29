# Readout rules — PHerc0175A (P9)

Fixed before the first ink run on PHerc0175A. Each later change is made before the results it affects, committed
here as an amendment, and listed under "Deviations" in the write-up.

- **Models (human decision: reader-v3 always included, not alone).** Screen: reader-v3, dense_native and reader-v2.
  Detail review, depth sweep and final images: six models, the 343 winner's four (dense_native, ink_9um seeds 42/43,
  Hecate 9.6 µm) plus reader-v2 and reader-v3; yellow = the mean of the per-model z-scores, over the dimmed CT.
- **Positive control first.** The same render and the three screen models run on PHerc. 343's published letter
  segment (same scan session; no model trained on 343). Pass: letters legible by eye and a letter-vs-background
  separation >= 0.10 for at least two models (P8: reader-v3 0.149, dense_native 0.129, reader-v2 0.102). Re-run only
  when a model, the renderer or the fitter changes.
- **Scope.** A turn is screened when >= 70% of its flattened mesh lies within ±2 voxels of the predicted sheet, and
  it covers >= 1 cm². Turns below that are "no data", not "no ink". Turns at 60-70% are an exploratory pass,
  reported separately.
- **Surfaces.** Villa main's spiral fitter with auto steps, no tracks, community lasagna inputs. Every winding is
  snapped and **flattened before the 66-layer render and before any ink model runs**, as the 343 winner did.
- **A flag.** In a 4 mm × 4 mm window on the reading side at the surface, the mean ink probability reaches that
  model's median inside 343's letters, in at least 2 of the 3 screen models.
- **What can count as letters (judged by eye).** Stroke-like marks 1.5-6 mm tall, along a row roughly parallel to the
  horizontal fibres, not repeated at the same place on the neighbouring turns.
- **What does not count.** Tile seams, render borders, mesh folds or holes, specks under 0.5 mm, fibre-grid texture,
  signal in only one model or at only one depth, the same pattern on a neighbouring turn.
- **Large segments (the organisers' advice: larger, better segments help find lines of text).** Each window is one
  tall fit (~3,000 slices, ~2.6 cm), so every screened turn is a whole flattened winding, not a 1,000-slice piece.
  Every flagged turn and every kept spot is also shown and judged as its whole winding (six-model yellow at d 0 over
  the dimmed CT), to see whether marks line up in rows across the sheet.
- **Gate.** The five strongest flags go to the human first; the rest of the review waits for the human's verdict.
- **Detail review.** Each kept spot is re-rendered at full resolution with both neighbouring turns and the six
  models at depths -8..+8; the strongest get a depth sweep -15..+15.

## Amendment 1 (2026-10-29 ~8:45 am ET, after the gate verdict, before any result of this rule): self-calibrated re-screen
Why: on PHerc0175A the papyrus background scores above PHerc. 343's, so the 343-derived thresholds flagged 111 of 117
windings on the reading side and 104 on the blind side; the human judged the five strongest and five more "no ink".
The re-screen uses only the saved screen maps (three models, d 0, both sides) of the 117 in-scope windings of window P.
- **Per-model z-maps.** Each map is z-scored over its own winding's papyrus (mean, standard deviation), per side.
- **Null from the blind side.** For each model, the threshold is the 99.9th percentile of all 4 mm × 4 mm window means
  of the z-maps on the BLIND side, pooled over the 117 windings (no ink is expected there; on 343 the blind side
  separated letters from background by only 0.03-0.05 vs 0.10-0.13 on the reading side).
- **A new flag.** A reading-side 4 mm window whose z-mean passes its model's blind-side threshold in at least 2 of the
  3 models at the same centre. The same rule on the blind side gives the false-flag rate, reported next to the result.
- **Check before use.** The rule must flag the letter area of the 343 positive control (its saved P9 maps, same
  z-scoring and the target scroll's thresholds); if it does not, the rule is not used and that is reported.
- **Ranking and gate.** Windings ranked by flagged area (cm²), then by the strongest window. The ten windings already
  judged "no ink" are listed but not re-shown. The next five go to the human first (same gate), as whole-winding
  yellow views; nothing else is reviewed before the verdict.
- Unchanged: models, scope, flatten-before-ink, what counts as letters, large segments.
- Clarification (same morning, before running): the control check PASSES when at least 9 of the 18 letter boxes hold a
  flagged window centre and the flagged share inside letter boxes is at least 5x the share in the background area.
  Thresholds: exact 99.9th percentile from a 0.001-wide z histogram. Script: rescreen_null.py.
