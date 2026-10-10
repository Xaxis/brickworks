#!/usr/bin/env python3
"""Real LEGO sets as geometry, from LDraw's Official Model Repository.

    tools/omr.py fetch [--themes "Castle,Modular Buildings"] [--min-parts 400]
    tools/omr.py names                      what real sets call their parts
    tools/omr.py harvest lamp tree --out DIR
    tools/omr.py clusters --out DIR         the craft inside big models

Set inventories say what a set is made of. They cannot say how it is put
together — where a lamp's lantern sits on its post, how a pane seats in
its frame — and the repository can: it has real sets as LDraw models,
most of them split into named sub-models.

`fetch` crawls the set list (about 60 pages) and downloads the sets of
the named themes with at least that many parts, one request a second,
into vendor/omr/. Kept: nothing is fetched twice. The zip the repository
used to serve is gone (404, 2026-10-09); this is the way in now.

`names` counts the words in sub-model names over every fetched set,
counted once per set: roof, door, seat, lamp, window and tree lead.
That ranked which worked examples to write.

`harvest` writes each small sub-model whose name has one of the words
as a standalone .ldr — 3 to 20 parts (or --most), square to the grid,
no sub-models of its own, standing on y=0 — with its set, modeller and
licence on its second line. A set's number is a word in every one of
its sub-models' names, so `harvest 21325 --most 40` takes them all.
Files marked free for non-commercial use are left out.
src/dev/harvest_probe.gd then opens each in the app and checks it.

`clusters` finds what nobody split out: the parts round each bracket,
hinge, clip, inverted or cheese slope, round, textured or organic part
in a castle, fantasy or building set (scored by tools/style.py's kinds;
--seeds narrows it to parts whose name matches), wholly inside a box a
few studs about it and held to it, the best few a set that do not
overlap, written the same way with a clusters.jsonl saying what each is.
"""

from __future__ import annotations

import argparse
import html
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HERE = ROOT / "vendor" / "omr"
SITE = "https://library.ldraw.org"
AGENT = {"User-Agent": "brickworks (https://brickworks.diy)"}
PAGES = 60


def _get(url: str) -> bytes:
    request = urllib.request.Request(url, headers=AGENT)
    return urllib.request.urlopen(request, timeout=120).read()


def _index() -> list[dict]:
    """Every set in the repository: number, name, theme, year, page id."""
    saved = HERE / "index.json"
    if saved.exists():
        return json.loads(saved.read_text())
    rows: list[dict] = []
    for page in range(1, PAGES + 1):
        text = _get(f"{SITE}/omr/sets?page={page}").decode(errors="replace")
        time.sleep(1.0)
        text = re.sub(r"<script.*?</script>", "", text, flags=re.S)
        ids: list[str] = []
        for found in re.finditer(rf'href="{re.escape(SITE)}/omr/sets/(\d+)"', text):
            if found.group(1) not in ids:
                ids.append(found.group(1))
        cells = [html.unescape(c.strip())
                 for c in re.sub(r"<[^>]+>", "\n", text).split("\n") if c.strip()]
        if "Models" not in cells:
            break
        at = cells.index("Models") + 1
        found_rows = []
        while at + 4 < len(cells) and re.match(r"[\w.]+-\d+$", cells[at]):
            found_rows.append(cells[at:at + 5])
            at += 5
        if not found_rows:
            break
        for (number, name, theme, year, models), page_id in zip(found_rows, ids):
            rows.append({"number": number, "name": name, "theme": theme,
                         "year": year, "models": models, "page": page_id})
    HERE.mkdir(parents=True, exist_ok=True)
    saved.write_text(json.dumps(rows, indent=0))
    return rows


def fetch(themes: list[str], least: int) -> int:
    sys.path.insert(0, str(ROOT / "tools"))
    import rebrickable
    parts = {r["set_num"]: int(r["num_parts"] or 0) for r in rebrickable._rows("sets")}
    files = HERE / "files"
    files.mkdir(parents=True, exist_ok=True)
    wanted = [row for row in _index()
              if row["theme"].split(" > ")[0] in themes
              and parts.get(row["number"], 0) >= least]
    got = 0
    for row in wanted:
        page = HERE / "pages" / f"{row['page']}.html"
        if not page.exists():
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_bytes(_get(f"{SITE}/omr/sets/{row['page']}"))
            time.sleep(1.0)
        links = sorted(set(re.findall(
            rf'href="({re.escape(SITE)}/library/omr/[^"]+\.(?:mpd|ldr))"',
            page.read_text(errors="replace"))))
        for url in links:
            out = files / urllib.parse.unquote(url.rsplit("/", 1)[1])
            if out.exists():
                continue
            try:
                out.write_bytes(_get(url))
                got += 1
            except OSError as error:
                print(f"  could not fetch {url}: {error}", file=sys.stderr)
            time.sleep(1.0)
    print(f"{len(wanted)} sets of {', '.join(themes)} with {least}+ parts; "
          f"{got} files fetched, {len(list(files.glob('*')))} kept in {files}")
    return 0


def _submodels(text: str) -> dict[str, list[list[str]]]:
    files: dict[str, list[list[str]]] = {}
    current = None
    for line in text.splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            current = " ".join(bits[2:])
            files[current] = []
        elif current is not None and len(bits) >= 15 and bits[0] == "1":
            files[current].append(bits)
    return files


IGNORED = set("the a an of and with for in on to set model main mpd ldr dat sub "
              "part parts assembly step bag new left right front back top bottom "
              "side upper lower inner outer small large big".split())


def names() -> int:
    words: Counter = Counter()
    sets = sorted((HERE / "files").glob("*"))
    for path in sets:
        seen: set[str] = set()
        for name in list(_submodels(path.read_text(errors="replace")))[1:]:
            name = re.sub(r"\.(ldr|dat|mpd)$", "", name.lower())
            for word in re.findall(r"[a-z]{3,}", name):
                if word not in IGNORED:
                    seen.add(word)
        words.update(seen)
    print(f"over {len(sets)} real models, how many name a sub-model with:")
    for word, count in words.most_common(40):
        print(f"  {word:14} {count}")
    return 0


def harvest(wanted: list[str], out: Path, most: int = 20) -> int:
    import layout
    boxes = layout._boxes()
    out.mkdir(parents=True, exist_ok=True)
    written = 0
    taken: dict[str, int] = {}
    for path in sorted((HERE / "files").glob("*")):
        text = path.read_text(errors="replace")
        if "non-commercial" in text.lower():
            continue
        lines = text.splitlines()
        author = next((l[9:].strip() for l in lines if l.startswith("0 Author:")), "?")
        licence = next((l[10:].strip() for l in lines if l.startswith("0 !LICENSE")), "?")
        number = path.name.split("_")[0].removesuffix(".mpd").removesuffix(".ldr")
        files = _submodels(text)
        known = {name.lower() for name in files}
        for name, placed in files.items():
            word = next((w for w in wanted if w in name.lower()), None)
            if word is None or not 3 <= len(placed) <= most:
                continue
            if any(" ".join(b[14:]).lower() in known for b in placed):
                continue
            if not all(abs(float(v)) in (0.0, 1.0) for b in placed for v in b[5:14]):
                continue
            corners = []
            for bits in placed:
                box = layout._box_of(" ".join(bits[14:]), boxes)
                if box is None:
                    break
                m = [float(v) for v in bits[2:14]]
                low, high = box
                corners += [[m[0] + m[3] * x + m[4] * y + m[5] * z,
                             m[1] + m[6] * x + m[7] * y + m[8] * z,
                             m[2] + m[9] * x + m[10] * y + m[11] * z]
                            for x in (low[0], high[0]) for y in (low[1], high[1])
                            for z in (low[2], high[2])]
            else:
                # Across by whole studs, so it stays on the grid it was built
                # on, and down exactly onto the ground. Rounded to whole
                # plates, a cluster whose lowest part sits half a plate off
                # its own grid hung half a plate in the air.
                dx = -20 * round(min(c[0] for c in corners) / 20)
                dz = -20 * round(min(c[2] for c in corners) / 20)
                dy = -max(c[1] for c in corners)
                body = [" ".join([b[0], b[1], f"{float(b[2]) + dx:g}",
                                  f"{float(b[3]) + dy:g}", f"{float(b[4]) + dz:g}"]
                                 + b[5:]) for b in placed]
                stem = re.sub(r"[^a-z0-9]+", "-", f"{word} {number} {name}".lower())
                stem = stem.strip("-")[:60]
                # Two sub-models can share a name once it is cut short.
                taken[stem] = taken.get(stem, 0) + 1
                if taken[stem] > 1:
                    stem += f"-{taken[stem]}"
                (out / f"{stem}.ldr").write_text(
                    f"0 {word}: {name}\n0 // from {number}, by {author}, "
                    f"LDraw OMR, {licence}\n" + "\n".join(body) + "\n")
                written += 1
    print(f"{written} sub-models written to {out}")
    return 0


# What a cluster is worth taking for: the kinds of part (tools/style.py)
# that are where a real set's craft is, against plain bricks and plates.
CRAFT = {"snot_parts": 1.0, "texture": 1.0, "curve": 1.0, "organic": 1.0,
         "angle_parts": 0.7, "slope": 0.5, "tile": 0.3}
# How far round a seed part to look, in LDU: across, then below and above.
REACH = [(across, below, above) for across in (20, 40, 60)
         for below, above in ((24, 8), (48, 24), (72, 48))]


def _compose(m: list[float], local: list[float]) -> list[float]:
    """Two LDraw transforms, x y z a..i, the local one applied first."""
    r = m[3:]
    s = local[3:]
    rot = [sum(r[row * 3 + k] * s[k * 3 + col] for k in range(3))
           for row in range(3) for col in range(3)]
    move = [sum(r[row * 3 + k] * local[k] for k in range(3)) + m[row] for row in range(3)]
    return move + rot


def _flatten(text: str) -> list[tuple[str, int, list[float], str]]:
    """Every part of the first model, sub-models followed: name, colour,
    world transform and the sub-model it sits in."""
    files: dict[str, list[list[str]]] = {}
    parts: set[str] = set()
    current = "main"
    for line in text.splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            current = " ".join(bits[2:]).lower()
            files.setdefault(current, [])
        elif bits[:2] == ["0", "!LDRAW_ORG"] and "part" in line.lower() \
                and "subpart" not in line.lower():
            parts.add(current)      # an unofficial part carried in the file
        elif len(bits) >= 15 and bits[0] == "1":
            files.setdefault(current, []).append(bits)
    out: list[tuple[str, int, list[float], str]] = []

    def walk(name: str, m: list[float], colour: int, depth: int) -> None:
        for bits in files.get(name, []):
            try:
                here = _compose(m, [float(v) for v in bits[2:14]])
                tint = colour if bits[1] == "16" else int(bits[1], 0)
            except ValueError:
                continue
            ref = " ".join(bits[14:]).lower().replace("\\", "/")
            if ref in files and ref not in parts and depth < 16:
                walk(ref, here, tint, depth + 1)
            else:
                out.append((ref, tint, here, name))

    if files:
        walk(next(iter(files)), [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1], 16, 0)
    return out


def _yaw(rot: list[float]) -> float | None:
    """The turn about the upright that squares a part to the grid, in
    degrees below 90, or None for a part tilted off the upright."""
    columns = [(rot[k], rot[3 + k], rot[6 + k]) for k in range(3)]
    if not all(abs(abs(c[1]) - 1) < 0.02 or abs(c[1]) < 0.02 for c in columns):
        return None
    level = next(c for c in columns if abs(c[1]) < 0.02)
    turn = math.degrees(math.atan2(level[2], level[0])) % 90.0
    return 0.0 if turn > 89.5 or turn < 0.5 else round(turn, 1)


def clusters(out: Path, groups: list[str], most: int, seeds: str = "") -> int:
    """Technique-rich groups of parts inside real sets, as standalone .ldr.

    A named sub-model is a lamp or a roof because its modeller split it
    out. The craft in a real set is mostly not split out: a bracket
    carrying tiles across a wall, an inverted slope under an oversail,
    a cheese-slope face, a plant on a rock. So round every part of those
    kinds (CRAFT, and anything facing sideways or down) this takes the
    parts wholly inside a box a few studs about it, keeps those held to
    it (_touch), scores them by how much of them is craft, and writes the best
    few of each set that do not overlap one another — square to the grid
    (a sub-assembly turned about the upright is turned back), standing
    on y=0, credited like harvest's.
    """
    import style
    parts = style.Parts()
    index = {r["number"]: r for r in _index()}
    out.mkdir(parents=True, exist_ok=True)
    seen: set[tuple] = set()
    written = 0
    rows = []
    for path in sorted((HERE / "files").glob("*")):
        text = path.read_text(errors="replace")
        if "non-commercial" in text.lower():
            continue
        number = path.name.split("_")[0].removesuffix(".mpd").removesuffix(".ldr")
        row = index.get(number, {"number": number, "name": path.stem, "theme": "?"})
        if style.group_of(row) not in groups:
            continue
        lines = text.splitlines()
        author = next((l[9:].strip() for l in lines if l.startswith("0 Author:")), "?")
        licence = next((l[10:].strip() for l in lines if l.startswith("0 !LICENSE")), "?")
        placed = []
        for ref, colour, m, sub in _flatten(text):
            info = parts.get(ref.removesuffix(".dat"))
            if info is None or info.box is None or not style.building(info):
                continue
            turn = _yaw(m[3:])
            if turn is None:
                continue
            # Turned back to the grid about the upright, the turn undone.
            c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))
            undo = [0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c]
            m = _compose(undo, m)
            low, high = info.box
            r = m[3:]
            centre = [sum(r[k * 3 + j] * (low[j] + high[j]) / 2 for j in range(3)) + m[k]
                      for k in range(3)]
            half = [sum(abs(r[k * 3 + j]) * (high[j] - low[j]) / 2 for j in range(3))
                    for k in range(3)]
            kinds = style.kinds(info)
            worth = min(1.5, sum(CRAFT.get(k, 0.0) for k in kinds))
            turned = style.facing(style.Matrix(*m[3:], *m[:3])) in ("sideways", "down")
            if turned:
                worth += 0.8
            placed.append({"ref": ref, "colour": colour, "m": m, "sub": sub,
                           "turn": turn, "lo": [centre[k] - half[k] for k in range(3)],
                           "hi": [centre[k] + half[k] for k in range(3)],
                           "worth": worth, "name": info.name, "kinds": sorted(kinds),
                           "side": turned or bool({"snot_parts", "angle_parts"} & kinds),
                           "part": parts.canonical(ref.removesuffix(".dat"))})
        cells: dict[tuple, list[int]] = {}
        for i, p in enumerate(placed):
            for cell in _cells(p["lo"], p["hi"]):
                cells.setdefault((p["turn"],) + cell, []).append(i)
        # Which parts touch which, once, rather than once a region.
        near: list[set[int]] = []
        for i, p in enumerate(placed):
            near.append({j for cell in _cells(p["lo"], p["hi"])
                         for j in cells[(p["turn"],) + cell]
                         if j != i and _touch(p, placed[j])})
        found = []
        for i, seed in enumerate(placed):
            if (re.search(seeds, seed["name"], re.I) is None) if seeds else seed["worth"] < 0.7:
                continue
            for across, below, above in REACH:
                lo = [seed["lo"][0] - across, seed["lo"][1] - above, seed["lo"][2] - across]
                hi = [seed["hi"][0] + across, seed["hi"][1] + below, seed["hi"][2] + across]
                inside = {j for cell in _cells(lo, hi)
                          for j in cells.get((seed["turn"],) + cell, [])
                          if all(lo[k] - 1 <= placed[j]["lo"][k]
                                 and placed[j]["hi"][k] <= hi[k] + 1 for k in range(3))}
                if len(inside) > 48:
                    continue
                group = _touching(near, inside, i)
                if not 5 <= len(group) <= 24:
                    continue
                worth = sum(placed[j]["worth"] for j in group) / len(group)
                shapes = len({placed[j]["part"] for j in group})
                if worth < (0.25 if seeds else 0.5):
                    continue
                found.append((worth * math.sqrt(len(group)) + 0.1 * shapes, i, group))
        found.sort(key=lambda f: -f[0])
        taken: set[int] = set()
        kept = 0
        for score, i, group in found:
            if kept >= most or len(group & taken) > 0.4 * len(group):
                continue
            body, signature = _standing(placed, group)
            if body is None or signature in seen:
                continue
            seen.add(signature)
            taken |= group
            kept += 1
            seed = placed[i]
            word = re.sub(r"[^a-z0-9]+", "-", seed["name"].lower()).strip("-")[:30]
            # The file, not the set: a set can have more than one model.
            stem = re.sub(r"[^a-z0-9]+", "-", f"cluster {path.stem} {kept:02d} {word}".lower())
            sub = re.sub(r"\.(ldr|dat|mpd)$", "", seed["sub"])
            (out / f"{stem}.ldr").write_text(
                f"0 cluster: {seed['name']} in {sub}\n0 // from {number}, by {author}, "
                f"LDraw OMR, {licence}\n" + "\n".join(body) + "\n")
            rows.append({"file": f"{stem}.ldr", "set": number, "set_name": row["name"],
                         "theme": row["theme"], "author": author, "licence": licence,
                         "sub": sub, "seed": seed["name"], "turn": seed["turn"],
                         "parts": len(group), "score": round(score, 2),
                         "shapes": len({placed[j]["part"] for j in group}),
                         "kinds": dict(Counter(k for j in group for k in placed[j]["kinds"]))})
            written += 1
    (out / "clusters.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
    print(f"{written} clusters written to {out}")
    return 0


def _cells(lo: list[float], hi: list[float]) -> list[tuple[int, int, int]]:
    """The 40 LDU cells a box reaches into."""
    span = [range(int(math.floor(lo[k] / 40)), int(math.floor(hi[k] / 40)) + 1)
            for k in range(3)]
    return [(x, y, z) for x in span[0] for y in span[1] for z in span[2]]


def _touch(one: dict, other: dict) -> bool:
    """Whether two parts hold each other: one on the other, or side by
    side where one of them has studs or a clip that faces that way. Two
    bricks merely beside each other do not, and a cluster joined only
    that way falls apart when it is cut out of its wall."""
    over = [min(one["hi"][k], other["hi"][k]) - max(one["lo"][k], other["lo"][k])
            for k in range(3)]
    if min(over) < -1:
        return False
    if over[0] > 2 and over[2] > 2 and over[1] >= -1:
        return True
    return (one["side"] or other["side"]) and over[1] > 2 and (
        (over[0] > 2 and over[2] >= -1) or (over[2] > 2 and over[0] >= -1))


def _touching(near: list[set[int]], inside: set[int], seed: int) -> set[int]:
    """The parts of a region that touch the seed, through one another."""
    if seed not in inside:
        return set()
    group = {seed}
    edge = [seed]
    while edge:
        for j in (near[edge.pop()] & inside) - group:
            group.add(j)
            edge.append(j)
    return group


def _standing(placed: list[dict], group: set[int]) -> tuple[list[str] | None, tuple]:
    """The group as LDraw lines on the ground, and what it is, to dedupe.

    Moved by whole studs from the corner of its widest brick or plate, so
    it stays on the grid it was built on, and down onto y=0.
    """
    members = [placed[j] for j in sorted(group)]
    flat = [p for p in members if "plain" in p["kinds"] or "tile" in p["kinds"]] or members
    anchor = max(flat, key=lambda p: (p["hi"][0] - p["lo"][0]) * (p["hi"][2] - p["lo"][2]))
    dx = -anchor["lo"][0] - 20 * round((min(p["lo"][0] for p in members) - anchor["lo"][0]) / 20)
    dz = -anchor["lo"][2] - 20 * round((min(p["lo"][2] for p in members) - anchor["lo"][2]) / 20)
    dy = -max(p["hi"][1] for p in members)
    body = []
    for p in members:
        m = p["m"]
        move = [m[0] + dx, m[1] + dy, m[2] + dz]
        # Square again exactly, where turning it back left 0.99999.
        turn = [float(round(v)) if abs(v - round(v)) < 0.02 else v for v in m[3:]]
        numbers = [f"{round(v, 3) + 0.0:g}" for v in move] + [f"{v + 0.0:g}" for v in turn]
        body.append(" ".join(["1", str(p["colour"])] + numbers + [p["ref"]]))
    signature = tuple(sorted(body))
    return body, signature


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("fetch")
    one.add_argument("--themes", default="Castle,Modular Buildings,Town,City,"
                     "LEGO Ideas and CUUSOO,Creator,Pirates,Harry Potter")
    one.add_argument("--min-parts", type=int, default=400)
    sub.add_parser("names")
    two = sub.add_parser("harvest")
    two.add_argument("words", nargs="+")
    two.add_argument("--out", type=Path, required=True)
    two.add_argument("--most", type=int, default=20, help="the most parts a sub-model may have")
    three = sub.add_parser("clusters")
    three.add_argument("--out", type=Path, required=True)
    three.add_argument("--groups", default="castle,fantasy,buildings",
                       help="tools/style.py's groups of set to look in")
    three.add_argument("--most", type=int, default=12, help="clusters kept a set")
    three.add_argument("--seeds", default="", help="only round parts whose name matches this")
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT / "tools"))
    if args.command == "fetch":
        return fetch([t.strip() for t in args.themes.split(",")], args.min_parts)
    if args.command == "names":
        return names()
    if args.command == "clusters":
        return clusters(args.out, [g.strip() for g in args.groups.split(",")], args.most,
                        args.seeds)
    return harvest([w.lower() for w in args.words], args.out, args.most)


if __name__ == "__main__":
    raise SystemExit(main())
