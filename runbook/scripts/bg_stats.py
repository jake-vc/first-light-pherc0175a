"""bg_stats.py <screen band dir> <out tsv> - why does the screen flag so much? Per screened winding, model and direction:
median, p90 and p99 of the ink map over the rendered papyrus (map > 0), next to the PHerc0343 control's background
median (calib JSON). If the target scroll's background sits near the control's letter level, the control-derived
thresholds fire on plain papyrus. Reads only the saved maps; no model run."""
import glob, json, os, sys
import numpy as np, tifffile

band, out = sys.argv[1:3]
rows = []
for d in sorted(glob.glob(f"{band}/*/maps")):
    w = d.split("/")[-2]
    for f in sorted(glob.glob(f"{d}/*.tif")):
        model = f.split("__")[1]; direction = "reverse" if f.endswith("_reverse.tif") else "forward"
        p = tifffile.imread(f).astype(np.float32) / 255; v = p[p > 0]
        if v.size == 0:
            continue
        q = np.percentile(v, [50, 90, 99])
        rows.append((w, model, direction, v.size, *[round(float(x), 4) for x in q]))
with open(out, "w") as fh:
    fh.write("winding\tmodel\tdirection\tn_px\tp50\tp90\tp99\n")
    for r in rows:
        fh.write("\t".join(map(str, r)) + "\n")
print(len(rows), "rows ->", out)
