"""seg_yellow_p9.py <segment dir> - P9 whole-winding yellow view (prereg "Models": yellow = the mean of the per-model
z-scores, over the dimmed CT; see seg_big_p9.sh). PRIVATE.
Six models at d 0 (reader-v2, reader-v3, dense_native, ink_9um seeds 42/43, Hecate resized from 9.6 um). Each map is
z-scored over the winding's papyrus (mean and standard deviation, as review_images.py in P8), the six z-maps averaged; yellow ramps from z 1.5 to 3.0
over the dimmed CT (mean of the 5 surface layers), same colours as seg_yellow.py. Reading side (reverse) and, as a
control, the blind side (forward). Writes yellow.png, yellow_small.png, yellow_blind_small.png (2000 px wide), 1 cm
bar, and yellow.json (models used, per-model mean/std)."""
import glob, json, sys
import cv2, numpy as np, tifffile, zarr

LO, HI, DIM, YELLOW = 1.5, 3.0, 0.45, np.array([130, 220, 245], np.float32)
BAR = int(round(10 / 8.64e-3))
MODELS = ("readerv2", "readerv3", "dnative", "hybrid_3d2d-seed42", "hybrid_3d2d-seed43", "hecate")
d = sys.argv[1]
z = zarr.open(f"{d}/render.zarr", mode="r"); a = z["0"] if "0" in z else z
ct = np.asarray(a[31:36]).astype(np.float32).mean(0); valid = ct > 0
lo, hi = np.percentile(ct[valid], [1, 99]); scan = np.clip((ct - lo) / max(hi - lo, 1e-6), 0, 1)
info = {"models": {}, "ramp_z": [LO, HI]}


def load(m, rev):
    suf = "_reverse" if rev else ""
    if m == "hecate":
        f = [g for g in glob.glob(f"{d}/maps/*__hecate__L66zc32.50{suf}.png") if rev or not g.endswith("_reverse.png")]
        return cv2.resize(cv2.imread(f[0], 0), (ct.shape[1], ct.shape[0])).astype(np.float32) / 255 if f else None
    f = [g for g in glob.glob(f"{d}/maps/*__{m}__L66s25{suf}.tif") if rev or not g.endswith("_reverse.tif")]
    return tifffile.imread(f[0]).astype(np.float32) / 255 if f else None


for rev, name in ((True, "yellow"), (False, "yellow_blind")):
    zs = []
    for m in MODELS:
        p = load(m, rev)
        if p is None or p.shape != ct.shape:
            print(f"{d}: {m} {'reading' if rev else 'blind'} missing or shape {None if p is None else p.shape} != {ct.shape}")
            continue
        v = p[valid]; mu = float(v.mean()); sd = max(float(v.std()), 1e-6)
        zs.append((p - mu) / sd); info["models"][f"{m}/{'reading' if rev else 'blind'}"] = [round(mu, 4), round(sd, 4)]
    if not zs:
        sys.exit(f"{d}: no maps")
    zm = np.mean(zs, axis=0)
    al = cv2.GaussianBlur(np.clip((zm - LO) / (HI - LO), 0, 1), (0, 0), 1.5)[..., None] * valid[..., None]
    img = (np.repeat((scan * 255 * DIM)[..., None], 3, 2) * (1 - al) + YELLOW * al).astype(np.uint8)
    cv2.rectangle(img, (20, img.shape[0] - 30), (20 + BAR, img.shape[0] - 20), (255, 255, 255), -1)
    cv2.putText(img, f"1 cm  {len(zs)} models  {'reading' if rev else 'blind'} side", (30 + BAR, img.shape[0] - 18),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
    if rev:
        cv2.imwrite(f"{d}/yellow.png", img)
    s = 2000 / img.shape[1]
    cv2.imwrite(f"{d}/{name}_small.png", cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA))
    info[f"n_models_{'reading' if rev else 'blind'}"] = len(zs)
json.dump(info, open(f"{d}/yellow.json", "w"), indent=1)
area = valid.sum() * (8.64e-3) ** 2 / 100
print(f"{d}: {ct.shape[1]}x{ct.shape[0]} px, {area:.1f} cm2 of papyrus, models {info['n_models_reading']} reading / {info['n_models_blind']} blind")
