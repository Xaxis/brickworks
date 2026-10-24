#!/usr/bin/env python3
"""Which colours a part is made in, and which parts of a model are in one they never were.

    python3 tools/house_models/colours.py PART [PART...]
    python3 tools/house_models/colours.py --check MODEL.ldr

From the catalogue (assets/generated/catalogue.json and colors.json), the same
colour lists the Tested mark's "parts" test reads (PartInfo.never_made_in).
--check lists each part line of a flat model in a colour its part was never
made in, with the colours it was, so the line can be recoloured (or the part
swapped for a twin made in that colour) with sed before fixsteps.gd runs.

Used by seed211 (2026-10-24) on the house models: the fox's inverted 2 x 2
slopes (3660b, never orange) became 3660c, the same shape without the stopper
ring; the rover's 2 x 2 bracket went from dark to light bluish grey; the
bakery's ponytail hair (only ever flat silver) became 23187 in reddish brown;
the treehouse's 4 x 3 leaves went from bright green to lime.
"""
import json
import sys
from pathlib import Path

G = Path(__file__).resolve().parents[2] / "assets" / "generated"
parts = {p["id"]: p for p in json.load(open(G / "catalogue.json"))["parts"]}
names = {c["code"]: c["name"] for c in json.load(open(G / "colors.json"))}


def made_in(pid):
    p = parts.get(pid)
    return None if p is None else p.get("colors", [])


if len(sys.argv) < 2:
    sys.exit(__doc__)
if sys.argv[1] == "--check":
    bad = 0
    for n, line in enumerate(open(sys.argv[2]).read().split("\n"), 1):
        f = line.split()
        if len(f) < 15 or f[0] != "1":
            continue
        pid, colour = f[-1].lower().removesuffix(".dat"), int(f[1])
        colours = made_in(pid)
        if colours and not parts[pid].get("colors_partial") and colour not in colours:
            bad += 1
            print("line %d: %s %s never made in %d %s; made in %s" % (n, pid, parts[pid]["name"], colour,
                  names.get(colour, "?"), ", ".join("%d %s" % (c, names.get(c, "?")) for c in colours)))
    print("%d part%s in a colour never made" % (bad, "" if bad == 1 else "s"))
    sys.exit(1 if bad else 0)
for pid in sys.argv[1:]:
    colours = made_in(pid)
    if colours is None:
        print(pid, "not in the catalogue")
        continue
    print("%s %s: %s%s" % (pid, parts[pid]["name"], ", ".join("%s %s" % (c, names.get(c, "?")) for c in colours),
          " (partial)" if parts[pid].get("colors_partial") else ""))
