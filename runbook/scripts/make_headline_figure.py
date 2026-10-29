"""make_headline_figure.py <summary.jsonl> <out.svg> - the P9 headline figure, plain SVG (no plotting library).
Left: windings flagged on the front and the back of the sheet, under the 343-derived thresholds (111 vs 104) and under
thresholds set from the back of this scroll (34 vs 35). Right: median ink-model score of plain papyrus on PHerc0175A,
plain papyrus on PHerc. 343 and 343's letters (the screen thresholds), per model. Numbers: bg_stats (median of the
per-winding medians, reading side) and the 343 control calibration."""
import json, sys

summary, out = sys.argv[1:3]
rows = [json.loads(l) for l in open(summary)]
LEVELS = [("dense_native", 0.333, 0.294, 0.4235), ("reader-v2", 0.282, 0.259, 0.3608), ("reader-v3", 0.267, 0.251, 0.4000)]
C1, C2, C3 = "#2a78d6", "#eb6834", "#1baf7a"     # categorical slots 1-3 (reference palette; validated all-pairs)
INK, INK2, GRID, BG = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
W, H = 960, 420
s = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
     f'font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif">',
     f'<rect width="{W}" height="{H}" fill="{BG}"/>']
t = lambda x, y, txt, size=13, fill=INK, anchor="start", weight="normal": s.append(
    f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" font-weight="{weight}">{txt}</text>')
# left panel: windings flagged, front vs back, under the 343 thresholds and under thresholds set from the back itself
GREY = "#a8a69e"
GROUPS = [("343's thresholds", 111, 104), ("Thresholds set from this", 34, 35)]  # rank_flags / rescreen_by_winding
t(20, 28, "Windings flagged, front vs back of the sheet", 15, weight="600")
bx0, by0, bh, top = 70, 330, 250, 120
BY = lambda v: by0 - v / top * bh
for v in (0, 30, 60, 90, 120):
    s.append(f'<line x1="{bx0}" x2="{bx0 + 340}" y1="{BY(v):.1f}" y2="{BY(v):.1f}" stroke="{GRID}" stroke-width="1"/>')
    t(bx0 - 8, BY(v) + 4, str(v), 11, INK2, "end")
for g, (label, front, back) in enumerate(GROUPS):
    gx = bx0 + 30 + g * 170
    for k, (v, c, side) in enumerate(((front, C1, "front"), (back, GREY, "back"))):
        x = gx + k * 62
        s.append(f'<path d="M{x},{by0} V{BY(v) + 4:.1f} Q{x},{BY(v):.1f} {x + 4},{BY(v):.1f} H{x + 50} '
                 f'Q{x + 54},{BY(v):.1f} {x + 54},{BY(v) + 4:.1f} V{by0} Z" fill="{c}"/>')
        t(x + 27, BY(v) - 6, str(v), 12, INK, "middle", "600")
        t(x + 27, by0 + 16, side, 11, INK2, "middle")
    t(gx + 58, by0 + 36, label, 12, INK, "middle")
t(bx0 + 30 + 170 + 58, by0 + 51, "scroll's back of the sheet", 12, INK, "middle")
t(bx0 + 170, by0 + 76, "117 windings screened; the back has no writing", 11, INK2, "middle")
# right panel: dot plot of levels
L0, R0, lt, rt = 560, 920, 0.20, 0.45
LX = lambda v: L0 + (v - lt) / (rt - lt) * (R0 - L0)
t(500, 28, "Plain papyrus scores higher here than on PHerc. 343", 15, weight="600")
for v in (0.20, 0.25, 0.30, 0.35, 0.40, 0.45):
    s.append(f'<line x1="{LX(v):.1f}" x2="{LX(v):.1f}" y1="70" y2="300" stroke="{GRID}" stroke-width="1"/>')
    t(LX(v), 318, f"{v:.2f}", 11, INK2, "middle")
t((L0 + R0) / 2, 340, "Median ink-model score (0 to 1)", 12, INK2, "middle")
for i, (name, pap, p343, let343) in enumerate(LEVELS):
    yy = 110 + i * 75
    t(L0 - 12, yy + 4, name, 13, INK, "end")
    s.append(f'<line x1="{LX(min(pap, p343)):.1f}" x2="{LX(let343):.1f}" y1="{yy}" y2="{yy}" stroke="{GRID}" stroke-width="2"/>')
    for v, c in ((p343, C2), (pap, C1), (let343, C3)):
        s.append(f'<circle cx="{LX(v):.1f}" cy="{yy}" r="7" fill="{c}" stroke="{BG}" stroke-width="2"/>')
    t(LX(pap), yy - 14, f"{pap:.3f}", 11, INK2, "middle")
    t(LX(let343), yy - 14, f"{let343:.3f}", 11, INK2, "middle")
lg = [(C2, "PHerc. 343, plain papyrus"), (C1, "PHerc0175A, plain papyrus"), (C3, "PHerc. 343, letters (= flag threshold)")]
for i, (c, label) in enumerate(lg):
    yy = 372 + i * 17
    s.append(f'<circle cx="{L0 - 50}" cy="{yy - 4}" r="5" fill="{c}"/>')
    t(L0 - 40, yy, label, 12, INK)
s.append("</svg>")
open(out, "w").write("\n".join(s))
print(out)
