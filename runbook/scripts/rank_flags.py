"""rank_flags.py <screen band dir> [bg_stats.tsv] - rank flagged windings for the prereg gate (five strongest first).
Rank (ink-review skill, a guide only): per direction, each model's 4 mm peak (max_window_mean) / its threshold; the
winding's strength is the SECOND-strongest model's ratio (2 of 3 must fire). Reading side = reverse (PHerc0343 control,
P8). With bg_stats.tsv (bg_stats.py) also prints the same peak above the winding's own p90 background, in units of
(p90 - p50), as a check of whether the top of the list is just bright papyrus. Prints a TSV; changes no rule."""
import csv, glob, json, os, sys
from collections import defaultdict

THR = {"readerv2": 0.3608, "dnative": 0.4235, "readerv3": 0.4000}  # prereg Calibration (screen_sheet.py)
band = sys.argv[1]; bg = defaultdict(dict)
if len(sys.argv) > 2:
    for r in csv.DictReader(open(sys.argv[2]), delimiter="\t"):
        bg[r["winding"]][(r["model"], r["direction"])] = (float(r["p50"]), float(r["p90"]))
rows = []
for f in sorted(glob.glob(f"{band}/*/stats.json")):
    s = json.load(open(f)); w = s["label"].split("/")[-1]
    if not s.get("candidate"):
        continue
    for direction in ("reverse", "forward"):
        ms = {m: s["maps"][f"{m}/{direction}"]["max_window_mean"] for m in THR if f"{m}/{direction}" in s["maps"]}
        if len(ms) < 3 or s["both_models_hit_frac"].get(direction, 0) <= 0:
            continue
        ratio = sorted((v / THR[m] for m, v in ms.items()), reverse=True)[1]
        lift = ""
        if w in bg and all((m, direction) in bg[w] for m in THR):
            ls = sorted(((ms[m] - bg[w][(m, direction)][1]) / max(bg[w][(m, direction)][1] - bg[w][(m, direction)][0], 1e-3)
                         for m in THR), reverse=True)
            lift = round(ls[1], 2)
        rows.append((w, direction, round(ratio, 4), lift, s["both_models_hit_frac"][direction], s["valid_cm2"]))
rows.sort(key=lambda r: (r[1] != "reverse", -r[2]))
print("winding\tdirection\tsecond_model_peak_over_thr\tsecond_model_lift_over_p90\thit_frac\tvalid_cm2")
for r in rows:
    print("\t".join(map(str, r)))
