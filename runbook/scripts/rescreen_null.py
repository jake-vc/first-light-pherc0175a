"""rescreen_null.py <screen band dir> <ctrl maps dir> <pherc343 repo> <out dir> - P9 prereg Amendment 1: self-calibrated
re-screen from the saved screen maps (three models, d 0, both sides). No model run.
1. Per winding, model and side: z-map over the winding's papyrus (map > 0; mean, std), 4 mm x 4 mm window means (W = 463
   px at 8.64 um) where >= 90% of the window is papyrus. Blind-side window means pooled over all windings -> per-model
   threshold = 99.9th percentile (exact, from a 0.001-wide histogram over z -10..40).
2. Flag = window centre where >= 2 of 3 models pass their threshold, per side. Per winding: flagged area (cm2, centres x
   pixel area), strongest window (max over centres of the second-highest model z-mean), the flagged bounding boxes.
3. 343 control check (same z-scoring on its own maps, the target's thresholds): PASS when >= 9 of the 18 letter boxes
   hold a flagged centre and the flagged share inside letter boxes is >= 5x the share in the background area.
Writes <out>/thresholds.json, <out>/rescreen.tsv (both sides), <out>/flags.json, <out>/control.json."""
import glob, json, os, re, sys
import numpy as np, tifffile, cv2

band, ctrl, repo, out = sys.argv[1:5]
MODELS = ("readerv2", "dnative", "readerv3"); W = 463; PX_CM2 = (8.64e-4) ** 2
LO, HI, STEP = -10.0, 40.0, 0.001; NB = int((HI - LO) / STEP)
os.makedirs(out, exist_ok=True)


def zwin(p):  # p: map 0..1; returns (window-mean z map, ok mask)
    valid = (p > 0).astype(np.float32); v = p[valid > 0]
    z = np.where(valid > 0, (p - v.mean()) / max(v.std(), 1e-6), 0).astype(np.float32)
    den = cv2.boxFilter(valid, -1, (W, W), normalize=False)
    ok = den > 0.9 * W * W
    m = np.where(ok, cv2.boxFilter(z * valid, -1, (W, W), normalize=False) / np.maximum(den, 1), -np.inf)
    return m, ok


def load(d, model, rev):
    suf = "_reverse" if rev else ""
    f = [g for g in glob.glob(f"{d}/*__{model}__L66s25{suf}.tif") if rev or not g.endswith("_reverse.tif")]
    return tifffile.imread(f[0]).astype(np.float32) / 255 if f else None


wins = sorted(glob.glob(f"{band}/w*/maps"))
# pass 1: blind-side null histograms
hist = {m: np.zeros(NB, np.int64) for m in MODELS}
for d in wins:
    for m in MODELS:
        p = load(d, m, False)
        if p is None:
            continue
        zm, ok = zwin(p)
        hist[m] += np.histogram(np.clip(zm[ok], LO, HI - STEP), bins=NB, range=(LO, HI))[0]
thr = {}
for m in MODELS:
    c = np.cumsum(hist[m]); thr[m] = round(LO + STEP * (np.searchsorted(c, 0.999 * c[-1]) + 1), 3)
json.dump({"thresholds_z": thr, "windings": len(wins), "rule": "blind-side 99.9th percentile of 4 mm window z-means"},
          open(f"{out}/thresholds.json", "w"), indent=1)
print("thresholds (z):", thr, flush=True)


def flags(zs):  # zs: model -> (zm, ok)
    votes = sum((zs[m][0] >= thr[m]).astype(np.uint8) for m in zs)
    ok = np.logical_and.reduce([zs[m][1] for m in zs])
    f = (votes >= 2) & ok
    second = np.sort(np.stack([np.where(zs[m][1], zs[m][0], -9) for m in zs]), axis=0)[-2]
    return f, ok, float(second[ok].max()) if ok.any() else None


rows, boxes = [], {}
for d in wins:
    w = d.split("/")[-2]
    for rev, side in ((True, "reading"), (False, "blind")):
        zs = {}
        for m in MODELS:
            p = load(d, m, rev)
            if p is not None:
                zs[m] = zwin(p)
        if len(zs) < 3:
            continue
        f, ok, strongest = flags(zs)
        rows.append((w, side, round(float(f.sum()) * PX_CM2, 3), round(float(f.sum()) / max(ok.sum(), 1), 5),
                     None if strongest is None else round(strongest, 3)))
        if rev and f.any():
            n, lab, st, _ = cv2.connectedComponentsWithStats(f.astype(np.uint8))
            boxes[w] = sorted(([int(x) for x in st[i, :4]] + [round(float(st[i, 4]) * PX_CM2, 4)] for i in range(1, n)),
                              key=lambda b: -b[4])[:20]  # x, y, w, h, flagged-centre area cm2
with open(f"{out}/rescreen.tsv", "w") as fh:
    fh.write("winding\tside\tflagged_cm2\tflagged_share\tstrongest_second_model_z\n")
    for r in rows:
        fh.write("\t".join(map(str, r)) + "\n")
json.dump(boxes, open(f"{out}/flags.json", "w"), indent=1)
# 343 control check
N = "concat_w047-w048_R5B2_z9500-11000"
lb = json.load(open(f"{repo}/inputs/{N}_letter_boxes.json"))["letters"]
a = json.load(open(f"{repo}/outputs/{N}.json"))["area"]["raw_render_px"]
zs = {}
for m in MODELS:
    f = glob.glob(f"{ctrl}/{N}_66__{m}__L66s25_reverse.tif")
    if f:
        zs[m] = zwin(tifffile.imread(f[0]).astype(np.float32) / 255)
res = {"models": sorted(zs)}
if len(zs) == 3:
    fl, ok, _ = flags(zs)
    letters = np.zeros(fl.shape, bool); excl = np.zeros(fl.shape, bool); hit = 0
    for b in lb:
        x0, y0, x1, y1 = [int(round(v)) for v in b["box"]]
        letters[y0:y1, x0:x1] = True; excl[max(0, y0 - 40):y1 + 40, max(0, x0 - 40):x1 + 40] = True
        hit += bool(fl[y0:y1, x0:x1].any())
    area = np.zeros(fl.shape, bool); area[a["row0"]:a["row1"], a["col0"]:a["col1"]] = True
    bg = area & ~excl & ok; li = letters & ok
    sl = float(fl[li].mean()) if li.any() else 0.0; sb = float(fl[bg].mean()) if bg.any() else 0.0
    res.update(letter_boxes_hit=hit, letter_boxes=len(lb), share_in_letters=round(sl, 4), share_background=round(sb, 5),
               ratio=round(sl / sb, 2) if sb > 0 else None,
               PASS=bool(hit >= len(lb) / 2 and (sb == 0 and sl > 0 or sb > 0 and sl >= 5 * sb)))
json.dump(res, open(f"{out}/control.json", "w"), indent=1)
print("control:", res)
rd = [r for r in rows if r[1] == "reading"]; bl = [r for r in rows if r[1] == "blind"]
print(f"reading: {sum(r[2] > 0 for r in rd)}/{len(rd)} windings flagged, {sum(r[2] for r in rd):.2f} cm2; "
      f"blind: {sum(r[2] > 0 for r in bl)}/{len(bl)} windings flagged, {sum(r[2] for r in bl):.2f} cm2")
