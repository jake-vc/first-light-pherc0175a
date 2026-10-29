"""review_page_p9.py - P9 gate verdict page: evidence/P9/gate/review_page.html (PRIVATE: may show letters; open it from
the Mac, never publish it). Same page as P8's review_page.py (review_page_template.html: verdict keys 1-5, notes,
export/import), fed with the P9 gate images on the Mac: the five strongest flags (prereg gate) first, then the
comparison set (ranked above each winding's own background). Per winding: whole-winding six-model yellow, reading side
then blind side (control). Verdicts are stored under their own browser key and exported as p9_gate_verdicts.json."""
import csv, json, os

K = os.path.expanduser("~/vesuvius-kit"); G = f"{K}/evidence/P9/gate"
GATE = ["w114", "w113", "w112", "w103", "w105"]; COMPARE = ["w073", "w074", "w028", "w044", "w057"]
rank = {}
for r in csv.DictReader(open(f"{G}/rank_Pf.tsv"), delimiter="\t"):
    rank.setdefault(r["winding"].split("_")[0], {})[r["direction"]] = float(r["hit_frac"])
yj = lambda d, w: json.load(open(f"{G}/{d}{w}_yellow.json")) if os.path.exists(f"{G}/{d}{w}_yellow.json") else {}
items = []
for group, ws, d in (("gate: five strongest (preregistered rule)", GATE, ""), ("comparison: above own background", COMPARE, "compare/")):
    for w in ws:
        lights = [p for p in (f"{d}{w}_yellow_small.png", f"{d}{w}_yellow_blind_small.png") if os.path.exists(f"{G}/{p}")]
        items.append({"label": f"Pf/{w}_main", "window": "P", "pass": group, "main": d == "", "cm2": None,
                      "fwd": rank.get(w, {}).get("forward", 0), "rev": rank.get(w, {}).get("reverse", 0),
                      "sheet": None, "panels": [], "lights": lights, "cand": d == "", "whole": None, "xsec": None,
                      "same": []})
ctrl = [p for p in ("../control/ctrl_contact_3models.png", "../control/ctrl_contact.png") if os.path.exists(f"{G}/{p}")]
html = open(f"{K}/work/pod/review_page_template.html").read()
subs = {  # P9 wording and storage; every replaced string must exist in the template
    'const KEY = "inkReviewVerdicts";': 'const KEY = "inkReviewVerdictsP9gate";',
    'a.download = "ink_verdicts.json";': 'a.download = "p9_gate_verdicts.json";',
    "Average of the winner's four models in yellow over the dimmed scan.":
        "Mean of six models' z-scores (reader-v2, reader-v3, dense_native, ink_9um x2, Hecate) in yellow over the dimmed scan, whole winding. The second picture is the blind side, where no ink is expected: yellow that appears on both is background, not ink.",
    'const role = p => { const r = p.split("/").slice(-3, -2)[0]; return r === "target" ? "this turn" : "neighbour turn " + r; };':
        'const role = p => p.includes("_blind_") ? "blind side (control: no ink expected)" : "reading side (where ink would be)";',
    "Contact sheet not on the Mac yet (next backup).": "Contact sheet is on the pod volume (pods stopped); the yellow views above are the gate images.",
    "not screened (below the 70% scope)": "contact sheet on the pod volume (pods stopped)",
    "PHerc. 343 control (our fits)": "PHerc. 343 control (P9 render, three screen models)",
    # P8's default filter (a dated list of four new panels) shows nothing here: open on all ten, gate five first
    '<option value="newpanels" data-name="4 new detail panels (10/24)" selected>4 new detail panels</option>':
        '<option value="all" data-name="All ten (gate five first, then comparison)" selected>All ten</option>',
    '<option value="cand" data-name="Your candidates (detail review)">Your candidates</option>':
        '<option value="cand" data-name="Gate: the five strongest (preregistered)">Gate five</option>',
}
for a, b in subs.items():
    assert a in html, f"template changed: {a[:50]}"
    html = html.replace(a, b)
html = html.replace("/*DATA*/", "const ITEMS = " + json.dumps(items) + "; const CTRL = " + json.dumps(ctrl) +
                    "; const SHEETS = {}; const PRELOAD = {};")
open(f"{G}/review_page.html", "w").write(html)
print(f"{len(items)} windings ({sum(i['main'] for i in items)} gate, {len(items) - sum(i['main'] for i in items)} comparison), "
      f"{sum(len(i['lights']) for i in items)} images -> {G}/review_page.html")
