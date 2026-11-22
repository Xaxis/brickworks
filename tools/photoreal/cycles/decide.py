"""decide.py SOLO_JSON [TREE ...] : the solo judge's verdicts for trees judged on several draws
(photoreal6). A label TREE_dN is draw N of TREE; each tree's mean chance of a photograph is over
all its draws, per round (all, close-ups, sets), with renders called a photograph in all rounds,
each shot's mean, and the judge's tells counted in its renders' reasons, as photoreal5's
decide.py counts them. Run with python3 (no numpy)."""
import json
import re
import sys
from collections import Counter, defaultdict

TELLS = {
    "logos": r"logo|lettering|letters|text on the stud|embossed|garbled|mirrored",
    "floating": r"float|hover|no contact|not resting|levitat|grounding|grounded",
    "seams": r"seamless|seam|joint|gap between|fused|merged|one piece|no gap",
    "edges": r"edge|bevel|corner|crisp|knife|razor",
    "wear": r"wear|scratch|scuff|dust|pristine|flawless|clean|new|mint|perfect",
    "backdrop": r"backdrop|background|surface|leather|stone|desk|table|paper",
    "speckle": r"speckl|nois|grain|mottl|blotch|denois|splotch",
    "colour": r"colou?r|saturat|hue|warm|cool|tint",
    "light": r"light|shadow|reflect|highlight|specular|gloss|sheen|illuminat",
    "plastic": r"plastic|cg material|material|subsurface|translucen|waxy|matte",
    "focus": r"depth of field|focus|bokeh|blur|sharp",
}


def tree_of(label: str) -> str:
    return re.sub(r"_d\d+$", "", label)


def mean(xs):
    return sum(xs) / len(xs) if xs else float("nan")


def main() -> int:
    data = json.load(open(sys.argv[1]))
    verdicts = [v for r in data["rounds"] for v in r["verdicts"] if "error" not in v]
    trees = sys.argv[2:] or sorted({tree_of(v["who"]) for v in verdicts} - {"photo", "reference render"})
    print("| tree | draws | all, per round | close-ups, per round | sets, per round | mean | called a photograph |")
    print("|---|---|---|---|---|---|---|")
    for tree in ["photo"] + trees:
        mine = [v for v in verdicts if tree_of(v["who"]) == tree]
        if not mine:
            continue
        draws = sorted({v["who"] for v in mine})
        cols = []
        for kind in (None, "closeup", "set"):
            per = []
            for r in data["rounds"]:
                vs = [v["p_photo"] for v in r["verdicts"] if "error" not in v
                      and tree_of(v["who"]) == tree and (kind is None or v["kind"] == kind)]
                per.append(f"{mean(vs):.3f}" if vs else "-")
            cols.append(" ".join(per))
        called = sum(v["answer"] == "photograph" for v in mine)
        print(f"| {tree} | {len(draws)} | {cols[0]} | {cols[1]} | {cols[2]} | "
              f"{mean([v['p_photo'] for v in mine]):.3f} | {called} of {len(mine)} |")
    shots = defaultdict(lambda: defaultdict(list))
    tells = defaultdict(Counter)
    counted = Counter()
    for v in verdicts:
        tree = tree_of(v["who"])
        shots[tree][v["shot"]].append(v["p_photo"])
        counted[tree] += 1
        text = " ".join(v.get("render_tells", [])).lower()
        for name, pattern in TELLS.items():
            if re.search(pattern, text):
                tells[tree][name] += 1
    names = sorted({s for t in shots for s in shots[t]})
    print()
    print("| shot | photo | " + " | ".join(trees) + " |")
    print("|---|---|" + "---|" * len(trees))
    for shot in names:
        row = [f"{mean(shots[t][shot]):.2f}" if shots[t][shot] else "-" for t in ["photo"] + trees]
        print(f"| {shot} | " + " | ".join(row) + " |")
    print()
    print("Verdicts whose render tells name each (of the tree's verdicts):")
    print("| tell | " + " | ".join(f"{t} ({counted[t]})" for t in trees) + " |")
    print("|---|" + "---|" * len(trees))
    for name in TELLS:
        print(f"| {name} | " + " | ".join(str(tells[t][name]) for t in trees) + " |")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
