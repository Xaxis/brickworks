#!/usr/bin/env python3
"""A form's parts, read from real sets: what real sets build a curve, a taper,
a lean or an open frame of each size with, found by the form, not the name.

    tools/form_parts.py build      the snippets index -> assets/knowledge/form_parts.json.gz
    tools/form_parts.py show FORM [--size small|medium|large] [--theme Architecture]
    tools/form_parts.py reach SESSION.jsonl...   the forms sessions gave, and whether the table has them

design24 asked each feature's form before the first build (open, at an
angle, curved, twisted, tapering, slender) and won head to head twice, then
lost the proof on its surface: the forms were laid in plates stepped in,
where the sets turn them with curved slopes, wedges, SNOT and hinges
(docs/DESIGN_SCORES.md). So this reads the snippets index (tools/snippets.py:
the named sub-models and the clusters of craft of 1,185 real sets, every part
placed) by what each piece's own geometry is, not by what its modeller called
it, and for each form, each size and each theme lists the parts the pieces of
that form were made of and the technique they used.

A piece is of a form by what is in it and how it stands (FORMS, `forms_of`):
  curved    curved slopes, domes and dishes, a seventh of it or more;
  round     round bricks, plates and tiles, a fifth of it or more;
  arched    arch bricks, a tenth of it or more;
  tapering  two wedges or more, or courses whose footprint shrinks up three
            levels or more to under two thirds, with slopes in it;
  flaring   two inverted slopes or more, or a footprint that grows up the
            same way;
  leaning   a tenth of its parts or more tilted off upright, studs neither up
            nor level;
  turned    a seventh or more turned off the grid in plan, studs still up;
  twisted   turned in plan at three levels or more, by two angles or more;
  open      bars, clips, fences, frames and lattices a quarter of it or more,
            or under a fifth of its box filled;
  slender   four times as long one way as either other, two and a half
            studs across or less.
Its size is its longest side in studs (a brick is 1.2 studs tall): small to
4, medium to 10, large past that.

For each form x size x theme (the set's top theme, and "any") a cell says:
how many pieces, from which sets (credited: number, name, modeller), the
parts that make the form there ranked by how many of its pieces use them
over how many of all pieces do, and the share of its pieces using each
technique (TECHNIQUES). src/ai/form_parts.gd reads it; the feature pass's
close look lays the form's parts (Assistant._form_brief).

Held out: every set of realset.py's two halves, by number and by name (as
DesignMemory.holds reads a name), is left out as the index is read, so no
subject the bench measures against is in what the table says. The table
lists every set it read from and the sets it held out, and
src/dev/form_parts_probe.gd checks the two never meet.
"""

from __future__ import annotations

import argparse
import gzip
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "bench"))

import style  # noqa: E402

INDEX = ROOT / "assets" / "knowledge" / "snippets.json.gz"
OUT = ROOT / "assets" / "knowledge" / "form_parts.json.gz"

STUD = 20.0
BRICK = 24.0
SIZES = (("small", 4.0), ("medium", 10.0), ("large", math.inf))
# A cell's parts and sets, at most.
MOST_PARTS = 12
MOST_SETS = 8
MOST_EXAMPLES = 6
# A part is listed for a cell when this many of its pieces use it.
LEAST_USES = 2

# What a part is to a form, by its LDraw name (lower case).
ROLES: dict[str, re.Pattern[str]] = {
    "curved_slope": re.compile(r"^slope\b.*\bcurved\b|^slope curved\b|\bcurved\b.*\bslope\b"),
    "dome": re.compile(r"\bdome\b|\bdish\b|\bhemisphere\b|\bsphere\b"),
    "arch": re.compile(r"^arch\b|^brick arch\b|\barch \d"),
    "round": re.compile(r"\bround\b|\bmacaroni\b|\bcylinder\b|\bcone\b|\bcircle\b"
                        r"|\bquarter\b.*\bround\b|\bcorner round\b"),
    "wedge": re.compile(r"\bwedge\b"),
    "slope": re.compile(r"^slope\b(?!.*\bcurved\b)(?!.*\binverted\b)"),
    "inverted": re.compile(r"^slope\b.*\binverted\b"),
    "snot": style.CLASSES["snot_parts"],
    "hinge": re.compile(r"\bhinge\b|\bclick\b|\bturntable\b|\bball\b|\bsocket\b"),
    "bar": re.compile(r"^bar\b|\bbar \d|\bwith bar\b|\blightsaber\b|\bantenna\b|\bwhip\b"),
    "clip": re.compile(r"\bclips?\b"),
    "frame": re.compile(r"\bfence\b|\blattice\b|\bframe\b|\bladder\b|\brailing\b|\bgirder\b"
                        r"|\btruss\b|\bsupport\b|\bgate\b|\bwindow\b|\bpanel\b.*\bgrille\b"),
    "tile": re.compile(r"^tile\b"),
    "plain": re.compile(r"^(brick|plate) \d+ x \d+( x \d+)?$"),
}

# Each form: how a person says it (src/ai/form_parts.gd reads these words in
# a design's own), what it is in a line, and the roles of the parts that make
# it, best first.
FORMS: dict[str, dict] = {
    "curved": {
        "said": "curved in profile: a dome, a hood, a blade, a rounded roof",
        "words": ["curved", "curve", "curves", "curving", "dome", "domed", "domes", "hood",
                  "bonnet", "blade", "vault", "vaulted", "sweeping", "swept", "bowed",
                  "bulging", "rounded", "fairing", "hump", "onion", "bulb", "cupola",
                  "streamlined", "smooth curve"],
        "roles": ["curved_slope", "dome", "inverted", "slope", "snot", "tile"],
    },
    "round": {
        "said": "round in plan: a drum, a ring, a round tower, a rounded end",
        "words": ["round", "circular", "circle", "cylinder", "cylindrical", "drum", "drums",
                  "ring", "rings", "rotunda", "disc", "disk", "wheel", "wheels", "oval",
                  "ellipse", "elliptical", "spiral", "helix", "tube", "tubular", "barrel",
                  "ringed", "banded"],
        "roles": ["round", "curved_slope", "wedge", "snot", "dome", "tile"],
    },
    "arched": {
        "said": "arched: an arch, an arched opening or a colonnade",
        "words": ["arch", "arches", "arched", "archway", "arcade", "colonnade", "vaulted"],
        "roles": ["arch", "curved_slope", "round", "inverted", "snot"],
    },
    "tapering": {
        "said": "tapering: narrowing as it rises or toward a point",
        "words": ["tapering", "taper", "tapers", "tapered", "narrowing", "narrows", "pointed",
                  "point", "spire", "pyramid", "pyramidal", "wedge", "conical", "cone",
                  "setback", "setbacks", "tiered", "tiers", "stepped back", "obelisk",
                  "needle", "sharp"],
        "roles": ["slope", "wedge", "curved_slope", "inverted", "round", "snot", "tile"],
    },
    "flaring": {
        "said": "flaring: widening as it rises, a lip or a bell",
        "words": ["flaring", "flared", "flare", "flares", "widening", "widens", "bell",
                  "lip", "overhang", "overhanging", "corbelled", "trumpet", "funnel"],
        "roles": ["inverted", "curved_slope", "round", "snot", "slope"],
    },
    "leaning": {
        "said": "at an angle off upright: splayed legs, a raked mast, a tilted arm",
        "words": ["angle", "angled", "raked", "rake", "leaning", "lean", "leans", "splayed",
                  "splay", "slanted", "slant", "slanting", "tilted", "tilt", "cranked",
                  "inclined", "canted", "diagonal", "sloping legs", "braced", "bracing"],
        "roles": ["hinge", "clip", "bar", "round", "snot"],
    },
    "turned": {
        "said": "turned off the grid in plan: a wing, a wall or a roof at an angle",
        "words": ["turned", "rotated", "off the grid", "off-grid", "45", "skewed", "askew",
                  "angled in plan", "fanned", "radial", "radiating"],
        "roles": ["hinge", "round", "wedge", "clip", "bar"],
    },
    "twisted": {
        "said": "twisted: each level turned a little on the one below",
        "words": ["twisted", "twist", "twists", "twisting", "spiralling", "spiraling",
                  "corkscrew", "helical", "rotating"],
        "roles": ["round", "hinge", "wedge", "curved_slope", "snot"],
    },
    "open": {
        "said": "open: sky shows through it, a frame, a lattice, spokes",
        "words": ["open", "lattice", "latticed", "latticework", "frame", "framed", "framework",
                  "truss", "trussed", "girder", "girders", "spokes", "spoked", "cage", "caged",
                  "skeleton", "skeletal", "see-through", "see through", "sky", "gaps",
                  "railing", "railings", "mesh", "web", "cables", "cable", "suspension",
                  "hollow", "pierced", "openwork"],
        "roles": ["bar", "clip", "frame", "hinge", "round"],
    },
    "slender": {
        "said": "slender: a rod, a mast, a pole, a thin column",
        "words": ["slender", "thin", "rod", "rods", "mast", "masts", "pole", "poles",
                  "antenna", "column", "columns", "pillar", "pillars", "stick", "shaft",
                  "post", "posts", "pipe", "pipes", "spindly", "wire", "stalk", "boom"],
        "roles": ["bar", "round", "clip", "frame", "hinge"],
    },
}

# The techniques a cell's pieces are counted for: a piece uses one when it
# has parts of the kind (or, for SNOT, parts turned with studs sideways).
TECHNIQUES: dict[str, str] = {
    "snot": "SNOT: bricks with studs on the side or brackets, and parts laid on them",
    "curved_slopes": "curved slopes",
    "wedges": "wedge plates and slopes",
    "round_parts": "round bricks, plates and tiles",
    "arches": "arch bricks",
    "inverted": "inverted slopes under",
    "hinges": "hinges, clicks and turntables",
    "bars_clips": "bars held in clips",
    "turned": "parts turned off the grid",
    "tilted": "parts tilted off upright",
    "tiles": "tiles over the studs",
}


# -- the holdout ----------------------------------------------------------------

def words(text: str) -> set[str]:
    """A set's name as RealSnippets.words reads it, which DesignMemory.holds
    compares: stemmed, no filler, no word under three letters. Read any other
    way, "Imperial AT-ST" is not all words of "Imperial Hotel", and the app
    would hold out a set the table was read from."""
    import snippets  # noqa: E402
    return set(snippets.words(text))


def held_out() -> list[tuple[str, str]]:
    """Every subject of realset.py's two halves: (number, name)."""
    import realset  # noqa: E402  (reads vendor/omr; only for build)
    out = []
    for which in realset.HALVES:
        for c in realset.sample(which):
            out.append((c.number, realset.clean_name(c.name)))
    return out


def holds(number: str, name: str, held: list[tuple[str, str]]) -> bool:
    """DesignMemory.holds, for every held-out subject at once: the set's base
    number, or its name's words all a held name's, or a held name's all its."""
    base = number.split("-")[0]
    said = words(name)
    for held_number, held_name in held:
        if held_number.split("-")[0] == base:
            return True
        other = words(held_name)
        if said and other and (said <= other or other <= said):
            return True
    return False


# -- reading one piece ------------------------------------------------------------


def placed_of(entry: dict, parts: style.Parts) -> list[tuple[style.Placed, style.PartInfo]]:
    text = "\n".join("1 " + line for line in entry.get("ldr", []))
    model = style.read(text)
    return [(p, info) for p in model.placed
            for info in [parts.get(p.part, model.embedded)] if style.building(info)]


def roles_of(info: style.PartInfo) -> set[str]:
    name = info.name.lower()
    found = {role for role, rule in ROLES.items() if rule.search(name)}
    if "curved_slope" in found:
        found.discard("slope")
    if found & {"wedge"}:
        found.discard("slope")
    return found


def reading(entry: dict, parts: style.Parts) -> dict | None:
    """What a piece is made of and how it stands, or None when it has no parts."""
    placed = placed_of(entry, parts)
    if not placed:
        return None
    boxes = style._boxes(placed, parts)
    n = len(placed)
    roles = [roles_of(info) for _, info in placed]
    count = Counter(r for found in roles for r in found)
    oriented = [(p, info) for p, info in placed if info.oriented]
    faces = Counter(style.facing(p.matrix) for p, _ in oriented)
    turned_levels: dict[int, set] = defaultdict(set)
    turned = 0
    for p, info in oriented:
        if style.facing(p.matrix) == "up" and style.angled(p.matrix):
            turned += 1
            angle = round(math.degrees(math.atan2(p.matrix.c, p.matrix.a)) % 90.0)
            turned_levels[int(-p.matrix.y // BRICK)].add(angle)
    if not boxes:
        return None
    low = [min(b.centre[k] - b.half[k] for b in boxes) for k in range(3)]
    high = [max(b.centre[k] + b.half[k] for b in boxes) for k in range(3)]
    span = [high[k] - low[k] for k in range(3)]
    studs = (span[0] / STUD, span[1] / STUD, span[2] / STUD)
    volume = max(1.0, span[0] * span[1] * span[2])
    filled = sum(8.0 * b.half[0] * b.half[1] * b.half[2] for b in boxes) / volume
    # Footprints by course, bottom up (LDraw is y down): the stud cells under
    # each brick-tall band.
    levels: dict[int, set] = defaultdict(set)
    for b in boxes:
        bottom = int(math.floor(-(b.centre[1] + b.half[1]) / BRICK + 0.01))
        top = int(math.ceil(-(b.centre[1] - b.half[1]) / BRICK - 0.01))
        cells = {(x, z)
                 for x in range(int(math.floor((b.centre[0] - b.half[0]) / STUD + 0.01)),
                                int(math.ceil((b.centre[0] + b.half[0]) / STUD - 0.01)))
                 for z in range(int(math.floor((b.centre[2] - b.half[2]) / STUD + 0.01)),
                                int(math.ceil((b.centre[2] + b.half[2]) / STUD - 0.01)))}
        for level in range(bottom, max(bottom + 1, top)):
            levels[level] |= cells
    areas = [len(levels[k]) for k in sorted(levels)]
    return {"n": n, "count": count, "faces": faces, "oriented": len(oriented),
            "turned": turned, "turned_levels": turned_levels, "studs": studs,
            "filled": filled, "areas": areas,
            "parts": Counter(parts.canonical(p.part) for p, _ in placed),
            "names": {parts.canonical(p.part): info.name for p, info in placed}}


def _monotone(areas: list[int], shrinking: bool) -> bool:
    """Whether the footprints, bottom up, go one way over three levels or more
    to under two thirds of where they began, never back by more than a tenth."""
    if len(areas) < 3:
        return False
    seq = areas if shrinking else areas[::-1]
    start, end = seq[0], seq[-1]
    if start <= 0 or end > (2.0 / 3.0) * start:
        return False
    peak = seq[0]
    changes = 0
    for a, b in zip(seq, seq[1:]):
        if b > peak * 1.1:
            return False
        if b < a:
            changes += 1
        peak = min(peak, b) if b < peak else peak
    return changes >= 2


def forms_of(r: dict) -> list[str]:
    """The forms a piece is, by its parts and its geometry (see the module's head)."""
    n, c = r["n"], r["count"]
    out = []
    if c["curved_slope"] + c["dome"] >= max(2, n / 7):
        out.append("curved")
    if c["round"] >= max(2, n / 5):
        out.append("round")
    if c["arch"] >= max(1, n / 10):
        out.append("arched")
    if c["wedge"] >= 2 or (_monotone(r["areas"], True) and c["slope"] + c["wedge"] + c["curved_slope"] >= 2):
        out.append("tapering")
    if c["inverted"] >= 2 or (_monotone(r["areas"], False) and c["inverted"] + c["curved_slope"] >= 1):
        out.append("flaring")
    if r["faces"]["tilted"] >= max(2, r["oriented"] / 10):
        out.append("leaning")
    if r["turned"] >= max(2, r["oriented"] / 7):
        out.append("turned")
    angles = set().union(*r["turned_levels"].values()) if r["turned_levels"] else set()
    if len(r["turned_levels"]) >= 3 and len(angles) >= 2:
        out.append("twisted")
    if c["bar"] + c["clip"] + c["frame"] >= max(3, n / 4) or (r["filled"] < 0.2 and n >= 6):
        out.append("open")
    x, y, z = r["studs"]
    dims = sorted((x, y, z))
    if dims[2] >= 4.0 * dims[1] and dims[1] <= 2.5:
        out.append("slender")
    return out


def techniques_of(r: dict) -> set[str]:
    c, faces = r["count"], r["faces"]
    out = set()
    if c["snot"] >= 1 or faces["sideways"] + faces["down"] >= 2:
        out.add("snot")
    if c["curved_slope"] >= 1:
        out.add("curved_slopes")
    if c["wedge"] >= 1:
        out.add("wedges")
    if c["round"] >= 1:
        out.add("round_parts")
    if c["arch"] >= 1:
        out.add("arches")
    if c["inverted"] >= 1:
        out.add("inverted")
    if c["hinge"] >= 1:
        out.add("hinges")
    if c["bar"] >= 1 and c["clip"] >= 1:
        out.add("bars_clips")
    if r["turned"] >= 1:
        out.add("turned")
    if faces["tilted"] >= 1:
        out.add("tilted")
    if c["tile"] >= 1:
        out.add("tiles")
    return out


def size_of(studs: tuple[float, float, float]) -> str:
    longest = max(studs[0], studs[2], studs[1])
    for name, most in SIZES:
        if longest <= most + 0.01:
            return name
    return SIZES[-1][0]


# -- the table --------------------------------------------------------------------


def build(args: argparse.Namespace) -> int:
    document = json.loads(gzip.open(INDEX).read())
    held = held_out()
    parts = style.Parts()
    read_from: dict[str, list] = {}
    held_seen: set[str] = set()
    # form -> size -> theme -> [entry, reading]
    cells: dict[str, dict[str, dict[str, list]]] = {
        f: defaultdict(lambda: defaultdict(list)) for f in FORMS}
    uses_all: Counter = Counter()
    pieces = 0
    names: dict[str, str] = {}
    for entry in document["entries"]:
        if holds(str(entry.get("set", "")), str(entry.get("set_name", "")), held):
            held_seen.add(str(entry.get("set", "")))
            continue
        r = reading(entry, parts)
        if r is None:
            continue
        pieces += 1
        names.update(r["names"])
        for part in r["parts"]:
            uses_all[part] += 1
        found = forms_of(r)
        if not found:
            continue
        theme = str(entry.get("theme", "")).split(" > ")[0].strip() or "Other"
        size = size_of(r["studs"])
        read_from.setdefault(str(entry["set"]), [str(entry.get("set_name", "")),
                                                 str(entry.get("by", "")),
                                                 str(entry.get("licence", ""))])
        for form in found:
            for where in (theme, "any"):
                cells[form][size][where].append((entry, r))
    out_forms: dict = {}
    listed: set[str] = set()
    for form, by_size in cells.items():
        spec = FORMS[form]
        sized: dict = {}
        for size, by_theme in by_size.items():
            themed: dict = {}
            for theme, rows in by_theme.items():
                if theme != "any" and len(rows) < args.least:
                    continue
                themed[theme] = _cell(rows, spec, uses_all, pieces, parts)
                listed.update(row[0] for row in themed[theme]["parts"])
            if themed:
                sized[size] = themed
        out_forms[form] = {"said": spec["said"], "words": spec["words"], "sizes": sized}
    table = {
        "format": 1,
        "about": ("What real sets build each form with, read from the snippets index by each "
                  "piece's own geometry and parts, not its name (tools/form_parts.py). "
                  "Credited: each cell names the sets it came from; the pieces are CC BY, "
                  "credited to their modellers in the snippets index."),
        "pieces": pieces,
        "techniques": TECHNIQUES,
        "names": {p: names.get(p, "") for p in sorted(listed)},
        "sets": read_from,
        "held_out": sorted({number for number, _ in held}),
        "held_out_names": sorted({name for _, name in held}),
        "held_out_found": sorted(held_seen),
        "forms": out_forms,
    }
    OUT.write_bytes(gzip.compress(json.dumps(table, separators=(",", ":"),
                                             ensure_ascii=False).encode(), mtime=0))
    print(f"form_parts: {pieces} pieces read, {len(held_seen)} sets held out "
          f"({len(held)} subjects), {len(read_from)} sets in the table -> "
          f"{OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes)")
    for form, body in out_forms.items():
        counts = {s: body["sizes"][s]["any"]["entries"] for s in body["sizes"] if "any" in body["sizes"][s]}
        print(f"  {form}: {counts}")
    return 0


def _cell(rows: list, spec: dict, uses_all: Counter, pieces: int, parts: style.Parts) -> dict:
    """One form x size x theme: its pieces, sets, parts and techniques."""
    n = len(rows)
    uses: Counter = Counter()
    techniques: Counter = Counter()
    sets: Counter = Counter()
    by: dict[str, str] = {}
    for entry, r in rows:
        for part in r["parts"]:
            uses[part] += 1
        techniques.update(techniques_of(r))
        sets[str(entry["set"])] += 1
        by[str(entry["set"])] = str(entry.get("set_name", ""))
    roles = spec["roles"]
    ranked = []
    for part, count in uses.items():
        if count < LEAST_USES:
            continue
        info = parts.get(part)
        if info is None:
            continue
        found = roles_of(info)
        role = next((r for r in roles if r in found), None)
        if role is None:
            continue
        share = count / n
        lift = share / max(uses_all[part] / max(pieces, 1), 1e-6)
        # What makes the form, by its role's rank, then by how many of the form's
        # pieces use it, lifted over how common it is anywhere.
        score = share * min(lift, 8.0) ** 0.5 * (1.0 - 0.08 * roles.index(role))
        ranked.append((score, part, round(share, 3), role))
    ranked.sort(key=lambda t: (-t[0], t[1]))
    examples = sorted(rows, key=lambda row: (-len(techniques_of(row[1])), row[0]["id"]))
    return {
        "entries": n,
        "sets": [[s, by[s]] for s, _ in sets.most_common(MOST_SETS)],
        "set_count": len(sets),
        "parts": [[part, share, role] for _, part, share, role in ranked[:MOST_PARTS]],
        "technique": {k: round(v / n, 3) for k, v in techniques.most_common()},
        "examples": [str(e["id"]) for e, _ in examples[:MOST_EXAMPLES]],
    }


# -- reading it back ----------------------------------------------------------------


def load() -> dict:
    return json.loads(gzip.open(OUT).read())


def forms_said(text: str) -> list[str]:
    """The forms a design's own words name, first named first: form_parts.gd's
    FormParts.forms_in, the same words."""
    low = " " + re.sub(r"[^a-z0-9-]+", " ", text.lower()) + " "
    found = []
    for form, spec in FORMS.items():
        at = min((low.find(" " + w + " ") for w in spec["words"] if (" " + w + " ") in low),
                 default=-1)
        if at >= 0:
            found.append((at, form))
    return [f for _, f in sorted(found)]


def show(args: argparse.Namespace) -> int:
    table = load()
    body = table["forms"][args.form]
    for size, themed in body["sizes"].items():
        if args.size and size != args.size:
            continue
        cell = themed.get(args.theme) or themed.get("any")
        if not cell:
            continue
        print(f"{args.form} {size} ({args.theme if args.theme in themed else 'any'}): "
              f"{cell['entries']} pieces of {cell['set_count']} sets")
        for part, share, role in cell["parts"]:
            print(f"  {part:10} {share:5.0%} {role:13} {table['names'].get(part, '')}")
        print("  technique: " + ", ".join(f"{k} {v:.0%}" for k, v in cell["technique"].items()))
        print("  sets: " + ", ".join(f"{s} {n}" for s, n in cell["sets"]))
    return 0


def reach(args: argparse.Namespace) -> int:
    """For each session, the forms it gave its features in submit_design, and
    whether the table has each at the feature's size (any theme)."""
    table = load()
    total = 0
    covered = 0
    for path in args.sessions:
        given = []
        for line in Path(path).open():
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            content = (d.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for c in content:
                if c.get("type") == "tool_use" and str(c.get("name", "")).endswith("submit_design"):
                    for f in (c.get("input") or {}).get("features") or []:
                        if isinstance(f, dict) and f.get("form"):
                            given.append((str(f.get("name", "")), str(f["form"])))
        kinds = {k for _, form in given for k in forms_said(form)}
        has = [k for k in kinds if table["forms"].get(k, {}).get("sizes")]
        total += 1
        covered += 1 if has else 0
        print(f"{Path(path).parent.name}: {len(given)} formed features; forms {sorted(kinds)}; "
              f"in the table {sorted(has)}")
    print(f"reach: {covered} of {total} sessions gave a form the table has")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--least", type=int, default=4,
                   help="pieces a theme needs in a cell to have a row of its own")
    s = sub.add_parser("show")
    s.add_argument("form", choices=list(FORMS))
    s.add_argument("--size", default="")
    s.add_argument("--theme", default="any")
    r = sub.add_parser("reach")
    r.add_argument("sessions", nargs="+")
    args = parser.parse_args(argv)
    return {"build": build, "show": show, "reach": reach}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
