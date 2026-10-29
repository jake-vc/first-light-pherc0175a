# P9 tall-window plan, PHerc0175A (12,748 slices; draft 2026-10-28, numbers UNVERIFIED unless marked)

Windows ~3,000 slices, 200-slice overlap (so a spot near an edge is whole in one window), windings 10-129 as the pilot.
Order: the pilot window first (already fitted: no fit cost), then outward from the middle, where papyrus is fullest.

| # | Window | Slices | Fit | Note |
|---|---|---|---|---|
| 1 | P | 4,800-7,800 | done (pilot; snapped median 74.3% on papyrus, VERIFIED) | snap, flatten, render, screen first |
| 2 | W2 | 7,600-10,600 | ~36 min, ~$0.20 | |
| 3 | W1 | 2,000-5,000 | ~36 min, ~$0.20 | |
| 4 | W3 | 10,400-12,748 | ~30 min | top end; check where papyrus stops |
| 5 | W0 | 0-2,200 | ~25 min | bottom end; check where papyrus stops |

Fit time from the pilot (2,162 s on an L4 shared with reviews; full 10k steps, the auto rule did not stop). Pod
$0.29/h with volume: ~$0.20 per fit. Render and screen time per window: unknown for 0175A until window P is done
(P8 screening was CPU-bound); measure on P, then quote the rest against the stop line.

Per window: fit -> snap -> **flatten every winding** -> 66-layer render -> screen (reader-v3, dense_native,
reader-v2; 2 of 3). Never run an ink model on an unflattened mesh.
Large segments: each turn is a whole winding of the tall fit; flagged turns also get a whole-winding six-model
yellow view (seg_big.sh, to be generalised from its 1218 paths). Where a spot sits near a window edge, join the
same winding across the 200-slice overlap.

Gates: after window P is screened, the five strongest flags go to the human (prereg "Gate") before any review or
further window.
