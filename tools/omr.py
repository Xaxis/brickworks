#!/usr/bin/env python3
"""Real LEGO sets as geometry, from LDraw's Official Model Repository.

    tools/omr.py fetch [--themes "Castle,Modular Buildings"] [--min-parts 400]
    tools/omr.py names                      what real sets call their parts
    tools/omr.py harvest lamp tree --out DIR

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
as a standalone .ldr — 3 to 20 parts, square to the grid, no sub-models
of its own, standing on y=0 — with its set, modeller and licence on its
second line. Files marked free for non-commercial use are left out.
src/dev/harvest_probe.gd then opens each in the app and checks it.
"""

from __future__ import annotations

import argparse
import html
import json
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


def harvest(wanted: list[str], out: Path) -> int:
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
            if word is None or not 3 <= len(placed) <= 20:
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
    args = parser.parse_args()
    sys.path.insert(0, str(ROOT / "tools"))
    if args.command == "fetch":
        return fetch([t.strip() for t in args.themes.split(",")], args.min_parts)
    if args.command == "names":
        return names()
    return harvest([w.lower() for w in args.words], args.out)


if __name__ == "__main__":
    raise SystemExit(main())
