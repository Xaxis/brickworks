#!/usr/bin/env python3
"""What a model is made of, against a real set of its size.

    tools/texture.py model.ldr
    tools/texture.py model.ldr --brief "a medieval castle with a gatehouse"

Parts, different shapes, colours, part-and-colour lots and the commonest
piece, beside what a real LEGO set with that many parts has: the median,
and the fifth or ninety-fifth percentile the app's own advice fires on.
With a brief, also how many of the parts real sets of its kind reach for
the model uses.

This is how a design run is judged — rerun a brief and count the model,
never read the diff — and it was being counted by hand.  Two things went
wrong doing that: a model read before the run ended (``--out`` is
rewritten on every build), and a lookup against the catalogue that
resolved nothing and reported zero shaped parts in a model with 64.  So
this says when it cannot resolve something, rather than counting it.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"


def read_ldr(path: Path) -> list[tuple[str, int]]:
    """(part id, colour code) for every part line, in an .ldr or an .mpd.

    A design in assemblies is a multi-part document: the model's own
    lines refer to its sub-models by file name, and those references are
    not parts.  Counted as parts they read as five unknown shapes and
    inflated a cruiser's 49 to 54.
    """
    text = path.read_text(errors="replace").splitlines()
    files = {" ".join(line.split()[2:]).lower()
             for line in text if line.split()[:2] == ["0", "FILE"]}
    parts = []
    for line in text:
        bits = line.split()
        if len(bits) >= 15 and bits[0] == "1":
            name = " ".join(bits[14:]).lower()
            if name in files:
                continue
            parts.append((name.removesuffix(".dat"), int(bits[1])))
    return parts


def kinds_for(brief: str, kinds: dict, most: int = 3) -> list[str]:
    """The kinds a brief names, the way PartLibrary.kinds_for reads it."""
    found: list[tuple[int, str]] = []
    seen: set[str] = set()
    for place, word in enumerate(brief.lower().split()):
        bare = re.sub(r"[^a-z0-9]", "", word)
        tries = [bare, bare.removesuffix("s"), bare.removesuffix("es")]
        tries += [bare[:n] for n in range(len(bare) - 1, 3, -1)]
        for form in tries:
            if len(form) < 3 or form in seen or form not in kinds:
                continue
            seen.add(form)
            found.append((place, form))     # in the order the brief names them
            break
    return [kind for _, kind in sorted(found)[:most]]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("model", type=Path)
    parser.add_argument("--brief", default="")
    args = parser.parse_args()

    parts = read_ldr(args.model)
    if not parts:
        print(f"{args.model}: no parts in it", file=sys.stderr)
        return 1
    catalogue = json.loads(CATALOGUE.read_text())
    known = {entry["id"] for entry in catalogue["parts"]}
    unknown = sorted({p for p, _ in parts if p not in known})

    count = Counter(p for p, _ in parts)
    commonest, most = count.most_common(1)[0]
    colours = {c for _, c in parts}
    lots = set(parts)
    print(f"{args.model.name}: {len(parts)} parts, {len(count)} shapes, "
          f"{len(colours)} colours, {len(lots)} lots, {most} of {commonest}")
    if unknown:
        print(f"  {len(unknown)} shapes are not in the catalogue, so nothing "
              f"below knows them: {', '.join(unknown[:8])}")

    band = next((b for b in catalogue["set_norms"]["bands"]
                 if b["from"] <= len(parts) < b["to"]), None)
    if band is None:
        print("  no real sets of this size to compare with")
    else:
        print(f"  a real set of {len(parts)} parts, over {band['sets']}: "
              f"{band['shapes']} shapes (thin below {band['shapes_thin']}), "
              f"{band['colours']} colours, {band['lots']} lots, "
              f"{band['most_of_one']} of one (high above "
              f"{band['most_of_one_high']})")

    if args.brief:
        kinds = catalogue["kinds"]["kinds"]
        named = kinds_for(args.brief, kinds)
        if not named:
            print("  the brief names no kind of set")
        wanted: dict[str, None] = {}
        palette: dict[int, None] = {}
        for kind in named:
            for part, _lift in kinds[kind]["parts"]:
                wanted.setdefault(part)
            for code, _lift in kinds[kind]["colors"]:
                palette.setdefault(code)
        if wanted:
            used = [p for p in wanted if p in count]
            print(f"  {' and '.join(named)} parts: {len(used)} of "
                  f"{len(wanted)} used — {', '.join(used) or 'none'}")
            print(f"  {' and '.join(named)} colours: "
                  f"{len([c for c in palette if c in colours])} of "
                  f"{len(palette)} used")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
