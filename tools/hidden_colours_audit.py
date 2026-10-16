#!/usr/bin/env python3
"""Add up the hidden colours audit (src/dev/hidden_colours_audit.gd).

    python3 tools/hidden_colours_audit.py FILE.jsonl [FILE.jsonl ...]
    python3 tools/hidden_colours_audit.py --lego FILE.jsonl ...   (src/dev/hidden_colours_lego.gd)

Each line is one real set of the LDraw model repository: which of its parts
nobody sees in the finished model on a table (measured from pictures,
SeenParts), each hidden part's colour, sub-model and place in the build, and
the colours of the rest. This prints, as Markdown, what docs/HIDDEN_COLOURS.md
quotes.

A set's accent colours are the ones it uses mostly where nobody sees them: a
vivid plain colour (HiddenColours.vivid: CIE chroma 28 or more, lightness 33
or more) with three or more hidden parts and at least two of every three of
its parts hidden. Hidden-only, stricter, is a colour no seen part of the set
has at all, which is what Brickworks makes.
"""

import json
import math
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Our own order of preference (HiddenColours.ACCENTS), to set against LEGO's.
OURS = [1, 14, 4, 2, 3, 27, 25, 322, 10, 73, 321, 191, 29, 5, 26, 30, 353, 212, 15, 19]


def lab(rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def chroma(rgb):
    _, a, b = lab(rgb)
    return math.hypot(a, b)


def iqr(values):
    values = sorted(values)
    if len(values) < 2:
        return 0.0
    return values[(3 * len(values)) // 4] - values[len(values) // 4]


def pct(a, b):
    return f"{100 * a / max(1, b):.1f}%"


class Corpus:
    def __init__(self, paths):
        self.colours = {int(c["code"]): c for c in json.load(open(ROOT / "assets/generated/colors.json"))}
        self.years = {}
        index = ROOT / "vendor/omr/index.json"
        if index.exists():
            for one in json.load(open(index)):
                try:
                    self.years[one["number"]] = int(one.get("year") or 0)
                except ValueError:
                    pass
        found = {}
        for path in paths:
            for line in open(path):
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if "begin" in row or "error" in row or not row.get("complete", False):
                    continue
                found[row["file"]] = row
        self.rows = list(found.values())
        self.by_file = found

    def name(self, code):
        c = self.colours.get(code)
        return c["name"] if c else str(code)

    def vivid(self, code):
        c = self.colours.get(code)
        return (c is not None and c.get("finish") == "solid" and c.get("group") == "solid"
                and chroma(c["rgb"]) >= 28.0 and lab(c["rgb"])[0] >= 33.0)

    def year(self, row):
        number = row["file"].split("_")[0].removesuffix(".mpd").removesuffix(".ldr")
        return self.years.get(number, 0)

    def accents(self, row):
        """The set's accent colours: code -> hidden parts in it."""
        out = {}
        for code, counts in row["colours"].items():
            code = int(code)
            seen, hidden = counts[0], counts[1]
            if hidden >= 3 and hidden * 3 >= (seen + hidden) * 2 and self.vivid(code):
                out[code] = hidden
        return out

    def hidden_only(self, row):
        seen = {int(c) for c, n in row["colours"].items() if n[0] > 0}
        return {int(c): n[1] for c, n in row["colours"].items() if n[1] > 0 and int(c) not in seen}


def main(paths):
    c = Corpus(paths)
    rows = c.rows
    parts = sum(r["parts"] for r in rows)
    on_table = sum(r.get("hidden_on_table", r["hidden"]) for r in rows)
    anywhere = sum(r.get("hidden_anywhere", 0) for r in rows)
    accent_parts = {r["file"]: sum(c.accents(r).values()) for r in rows}
    marking = [r for r in rows if accent_parts[r["file"]] >= 5]
    print("## Measured\n")
    print(f"{len(rows):,} sets of the LDraw model repository, {parts:,} parts, each measured from "
          f"48 sides at up to 1,024 pixels (a pixel 1 LDU on a small set, about 3 on the "
          f"largest). Hidden on a table, seen from no side but underneath: {on_table:,} "
          f"({pct(on_table, parts)}). Hidden from underneath too: {anywhere:,} "
          f"({pct(anywhere, parts)}).\n")
    total_hidden = sum(r["hidden"] for r in rows)
    total_accent = sum(accent_parts.values())
    strict = sum(sum(c.hidden_only(r).values()) for r in rows)
    strict_vivid = sum(sum(n for k, n in c.hidden_only(r).items() if c.vivid(k)) for r in rows)
    print(f"Of the hidden parts, {total_accent:,} ({pct(total_accent, total_hidden)}) are in a "
          f"colour the set uses mostly inside, vivid and at least two thirds hidden (an "
          f"**accent**). {strict:,} ({pct(strict, total_hidden)}) are in a colour no seen part "
          f"of the set has at all, {strict_vivid:,} of those vivid. {len(marking):,} sets "
          f"({pct(len(marking), len(rows))}) have five or more accent parts.\n")

    print("### By size and by year\n")
    print("| | sets | hidden on a table | of hidden, accents | sets with 5+ accent parts |")
    print("|---|---|---|---|---|")
    for low, high in [(0, 200), (200, 500), (500, 1000), (1000, 2000), (2000, 100000)]:
        some = [r for r in rows if low <= r["parts"] < high]
        if some:
            p = sum(r["parts"] for r in some)
            h = sum(r["hidden"] for r in some)
            a = sum(accent_parts[r["file"]] for r in some)
            m = sum(1 for r in some if r in marking)
            print(f"| {low:,}–{f'{high - 1:,}' if high < 100000 else ''} parts | {len(some)} | "
                  f"{pct(h, p)} | {pct(a, h)} | {m} ({pct(m, len(some))}) |")
    for low, high in [(1950, 1990), (1990, 2000), (2000, 2005), (2005, 2010), (2010, 2015),
                      (2015, 2020), (2020, 2030)]:
        some = [r for r in rows if low <= c.year(r) < high and r["parts"] >= 500]
        if some:
            p = sum(r["parts"] for r in some)
            h = sum(r["hidden"] for r in some)
            a = sum(accent_parts[r["file"]] for r in some)
            m = sum(1 for r in some if r in marking)
            print(f"| {low}–{high - 1}, 500+ parts | {len(some)} | {pct(h, p)} | {pct(a, h)} | "
                  f"{m} ({pct(m, len(some))}) |")
    print()

    print("### Which colours\n")
    total = Counter()
    hid = Counter()
    as_accent_sets = Counter()
    as_accent_parts = Counter()
    for r in rows:
        for code, n in r["colours"].items():
            total[int(code)] += n[0] + n[1]
            hid[int(code)] += n[1]
        for code, n in c.accents(r).items():
            as_accent_sets[code] += 1
            as_accent_parts[code] += n
    print("| colour | sets using it as an accent | accent parts | of all its parts, hidden | our rank |")
    print("|---|---|---|---|---|")
    for code, n in as_accent_sets.most_common(16):
        rank = OURS.index(code) + 1 if code in OURS else "–"
        print(f"| {c.name(code)} | {n} | {as_accent_parts[code]:,} | {pct(hid[code], total[code])} | {rank} |")
    print()

    # Sections.
    purity, baseline, spread = [], [], []
    for r in marking:
        names = r.get("names", [])
        if len([g for g, n in r["groups"].items() if g and n[0] >= 10]) < 2:
            continue
        hidden_by_group = Counter(p[2] for p in r.get("hidden_parts", []))
        if not hidden_by_group:
            continue
        base = max(hidden_by_group.values()) / sum(hidden_by_group.values())
        for code in c.accents(r):
            groups = Counter(p[2] for p in r["hidden_parts"] if p[0] == code)
            n = sum(groups.values())
            if n < 4:
                continue
            purity.append(max(groups.values()) / n)
            baseline.append(base)
            spread.append(len(groups))
    if purity:
        print("### By section\n")
        print(f"{len(purity)} accent colours of four or more parts, in sets of two or more "
              f"sub-models: the median keeps {100 * statistics.median(purity):.0f}% of its parts "
              f"in one sub-model, against {100 * statistics.median(baseline):.0f}% for the set's "
              f"hidden parts as a whole; {sum(1 for p in purity if p >= 0.9)} "
              f"({pct(sum(1 for p in purity if p >= 0.9), len(purity))}) keep nine tenths or more "
              f"to one, and the median is in {statistics.median(spread):.0f} sub-model(s).\n")

    # Stages.
    narrow, whole = [], []
    for r in marking:
        everything = [p[1] for p in r.get("hidden_parts", [])]
        if len(everything) < 8:
            continue
        for code in c.accents(r):
            places = [p[1] for p in r["hidden_parts"] if p[0] == code]
            if len(places) < 4:
                continue
            narrow.append(iqr(places))
            whole.append(iqr(everything))
    if narrow:
        tighter = sum(1 for a, b in zip(narrow, whole) if a <= b / 2)
        print("### By stage of the build\n")
        print(f"Where in the build (0 the first part, 1 the last) each of {len(narrow)} accent "
              f"colours' parts go: the middle half of them spans a median of "
              f"{100 * statistics.median(narrow):.0f}% of the build, against "
              f"{100 * statistics.median(whole):.0f}% for all the set's hidden parts; "
              f"{tighter} ({pct(tighter, len(narrow))}) are packed into half the span or less.\n")

    # Mirror halves.
    print("### Left and right, front and back\n")
    for axis, words in [("x", "left and right"), ("z", "front and back")]:
        pairs = same = coded = 0
        sets_coding = 0
        for r in rows:
            m = r["mirror"][axis]
            pairs += m[0]
            same += m[1]
            accents = c.accents(r)
            here = 0
            for key, n in (m[3] if len(m) > 3 else {}).items():
                a, b = (int(x) for x in key.split("|"))
                if a != b and a in accents and b in accents:
                    here += n
            coded += here
            sets_coding += 1 if here >= 2 else 0
        print(f"- {words}: {pairs:,} mirror pairs of hidden parts across the model's middle, "
              f"{pct(same, pairs)} of them the same colour; {coded} pairs in two different "
              f"accent colours, and {sets_coding} set{'' if sets_coding == 1 else 's'} with two "
              f"or more such pairs.")
    print()

    # Our measure against LEGO's own placing: the accent colours' parts,
    # hidden on a table and hidden from underneath too.
    every = table = below = 0
    for r in rows:
        for code in c.accents(r):
            n = r["colours"][str(code)]
            every += n[0] + n[1]
            table += n[1]
            below += n[2] if len(n) > 2 else 0
    print("### Our measure against where LEGO put its accents\n")
    print(f"Of the {every:,} parts in the sets' accent colours, the measure calls "
          f"{pct(table, every)} hidden on a table and {pct(below, every)} hidden from "
          f"underneath too: of those hidden on a table, {pct(table - below, table)} can be "
          f"seen from below once the model is picked up.\n" if every else "")

    print("### The sets the reviews name\n")
    print("| set | parts | hidden | its accents (hidden parts, share of that colour hidden) |")
    print("|---|---|---|---|")
    for number in ["10276-1", "10294-1", "21309-1", "10283-1", "42083-1", "42115-1", "42056-1",
                   "7191-1", "10179-1", "10221-1", "21321-1", "10261-1", "10182-1"]:
        r = c.by_file.get(number + ".mpd")
        if not r:
            continue
        accents = c.accents(r)
        said = ", ".join(
            f"{c.name(k)} ({n}, {pct(n, sum(r['colours'][str(k)][:2]))})"
            for k, n in sorted(accents.items(), key=lambda kv: -kv[1])[:6]) or "none"
        print(f"| {number} | {r['parts']:,} | {r['hidden']:,} | {said} |")
    print()


def lego(paths):
    """Our palette against LEGO's, from src/dev/hidden_colours_lego.gd lines."""
    colours = {int(c["code"]): c for c in json.load(open(ROOT / "assets/generated/colors.json"))}
    rows = {}
    for path in paths:
        for line in open(path):
            if line.strip():
                row = json.loads(line)
                rows[row["file"]] = row
    rows = [r for r in rows.values() if r["lego"]]
    soft = {29, 5, 26, 30, 353}  # the pinks, magenta, lavender and coral

    def name(code):
        return colours[code]["name"] if code in colours else str(code)

    print(f"### Our palette against LEGO's\n\n{len(rows)} sets that mark their insides, "
          f"each measured once and planned by both palettes, as display models.\n")
    print("| | sets given a colour | picks one of LEGO's | LEGO's colours picked (mean) "
          "| overlap (Jaccard, mean) | colours a set (mean) | pinks, magenta, coral |")
    print("|---|---|---|---|---|---|---|")
    for mode in ("stages", "sections"):
        for when, key in (("before", mode + "_before"), ("after", mode)):
            given = hit = 0
            recall = jaccard = count = 0.0
            soft_n = total_n = 0
            for r in rows:
                ours = set(r.get(key, []))
                if not ours:
                    continue
                theirs = set(r["lego"])
                given += 1
                both = ours & theirs
                hit += 1 if both else 0
                recall += len(both) / len(theirs)
                jaccard += len(both) / len(ours | theirs)
                count += len(ours)
                soft_n += len(ours & soft)
                total_n += len(ours)
            if not given:
                continue
            print(f"| by {mode[:-1] if mode == 'stages' else 'section'}, {when} | {given} | "
                  f"{hit} ({100 * hit / given:.0f}%) | {100 * recall / given:.0f}% | "
                  f"{jaccard / given:.2f} | {count / given:.1f} | "
                  f"{100 * soft_n / max(1, total_n):.0f}% of colours |")
    print()
    for f in ("10276-1.mpd", "10294-1.mpd", "21309-1.mpd", "10179-1.mpd"):
        r = next((x for x in rows if x["file"] == f), None)
        if r:
            print(f"- {f}: LEGO {', '.join(name(c) for c in r['lego'])}; before "
                  f"{', '.join(name(c) for c in r.get('stages_before', []))}; after "
                  f"{', '.join(name(c) for c in r.get('stages', []))} (by stage)")
    print()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        raise SystemExit(2)
    if sys.argv[1] == "--lego":
        lego(sys.argv[2:])
    else:
        main(sys.argv[1:])
