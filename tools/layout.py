#!/usr/bin/env python3
"""How a model stands: its footprint, its height, and how its height varies.

    tools/layout.py model.ldr [more.ldr ...]

tools/texture.py says what a model is made of.  This says how it is laid
out, from a heightmap one stud square built from every part's box:

  footprint   studs across and deep
  tallest     the 95th percentile of its height, in bricks — a spire's
              tip is not the castle's height, its towers are
  typical     the median height of what stands more than two bricks up
  contrast    tallest over typical: towers over walls
  tall/wide   tallest over the longer side, both in the same units
  built       the share of the footprint more than two bricks up

Measured against real sets from LDraw's Official Model Repository
(https://library.ldraw.org/omr/sets, one .mpd per set at
https://library.ldraw.org/library/omr/<set>-1.mpd), 2026-10-09:

  real castles of 450-950 parts   tall/wide 0.34-0.74, contrast 1.4-3.3
                                  (10176, 6080 and 6085: 2.8-3.3)
  castles built here, runs 14-19  tall/wide 0.21-0.35, contrast 1.3-1.9
  modular buildings, 1,500-3,100  tall/wide 0.73-1.53, 28-43 bricks tall
  fire stations built here        tall/wide 0.65-0.76, 17-20 bricks tall

A real castle's towers stand about three times its walls; the ones
built here stand about one and a half.  Neither number is advice yet:
five castles and fourteen modular buildings are a direction, not a norm.

The boxes come from catalogue.json, so a part it does not know is not
counted and is reported; sub-models of an .mpd are followed, so a real
set's bags and a design's assemblies both read as one model.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"

STUD = 20.0            # LDU
BRICK = 24.0           # LDU
ABOVE = 2 * BRICK      # what stands higher than this is built, not ground
PRIMITIVE = re.compile(r"(\d+-\d+\w*|stud\w*)\.dat$")


def _boxes() -> dict[str, tuple[list[float], list[float]]]:
    """Part id -> its box in LDraw's own axes, y pointing down."""
    catalogue = json.loads(CATALOGUE.read_text())
    out = {}
    for entry in catalogue["parts"]:
        low, high = entry["bounds_min"], entry["bounds_max"]
        # The catalogue is +Y up; LDraw is +Y down.
        out[entry["id"]] = ([low[0], -high[1], low[2]],
                            [high[0], -low[1], high[2]])
    return out


def _box_of(part: str, boxes: dict) -> tuple | None:
    name = part.lower().removesuffix(".dat").replace("\\", "/").split("/")[-1]
    # A printed or lettered variant has its plain part's shape.
    for form in (name, re.sub(r"p[a-z0-9]{2,4}$", "", name),
                 re.sub(r"[a-z]$", "", name)):
        if form in boxes:
            return boxes[form]
    return None


def _read(path: Path) -> tuple[dict[str, list], str]:
    """Each file of a document -> its part lines, and the first file."""
    files: dict[str, list] = {}
    current = None
    first = None
    for line in path.read_text(errors="replace").splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            current = " ".join(bits[2:]).lower()
            files[current] = []
            first = first or current
            continue
        if current is None:
            current = first = "<main>"
            files[current] = []
        if len(bits) >= 15 and bits[0] == "1":
            files[current].append(([float(b) for b in bits[2:14]],
                                   " ".join(bits[14:]).lower()))
    return files, first or "<main>"


def _times(a: list[float], b: list[float]) -> list[float]:
    """Two LDraw placements, one inside the other: x y z then a 3x3."""
    ra = [a[3:6], a[6:9], a[9:12]]
    rb = [b[3:6], b[6:9], b[9:12]]
    turn = [[sum(ra[i][k] * rb[k][j] for k in range(3)) for j in range(3)]
            for i in range(3)]
    at = [a[i] + sum(ra[i][k] * b[k] for k in range(3)) for i in range(3)]
    return at + turn[0] + turn[1] + turn[2]


def _flatten(files: dict, name: str, where: list[float], boxes: dict,
             out: list, unknown: Counter, depth: int = 0) -> None:
    for placed, ref in files.get(name, []):
        here = _times(where, placed)
        if ref in files and depth < 12:
            _flatten(files, ref, here, boxes, out, unknown, depth + 1)
            continue
        box = _box_of(ref, boxes)
        if box is None:
            # A primitive — a quarter cylinder, a ring — drawn inside a
            # set's own sub-model is a surface, not a part.
            if not PRIMITIVE.match(ref):
                unknown[ref] += 1
            continue
        low, high = box
        x, y, z, *turn = here
        corners = [[x + turn[0] * cx + turn[1] * cy + turn[2] * cz,
                    y + turn[3] * cx + turn[4] * cy + turn[5] * cz,
                    z + turn[6] * cx + turn[7] * cy + turn[8] * cz]
                   for cx in (low[0], high[0]) for cy in (low[1], high[1])
                   for cz in (low[2], high[2])]
        out.append(([min(c[i] for c in corners) for i in range(3)],
                    [max(c[i] for c in corners) for i in range(3)]))


def measure(path: Path, boxes: dict) -> dict | None:
    files, first = _read(path)
    parts: list = []
    unknown: Counter = Counter()
    identity = [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
    _flatten(files, first, identity, boxes, parts, unknown)
    if not parts:
        return None
    ground = max(box[1][1] for box in parts)
    x0 = min(box[0][0] for box in parts)
    z0 = min(box[0][2] for box in parts)
    x1 = max(box[1][0] for box in parts)
    z1 = max(box[1][2] for box in parts)
    across = max(1, round((x1 - x0) / STUD))
    deep = max(1, round((z1 - z0) / STUD))
    height: dict = defaultdict(float)
    for low, high in parts:
        top = ground - low[1]
        for i in range(int((low[0] - x0) // STUD),
                       int((high[0] - x0 - 0.01) // STUD) + 1):
            for k in range(int((low[2] - z0) // STUD),
                           int((high[2] - z0 - 0.01) // STUD) + 1):
                height[i, k] = max(height[i, k], top)
    built = sorted(v for v in height.values() if v > ABOVE)
    tallest = built[int(len(built) * 0.95)] / BRICK if built else 0.0
    typical = built[len(built) // 2] / BRICK if built else 0.0
    return {
        "file": path.name, "parts": len(parts),
        "unknown": sum(unknown.values()),
        "footprint": f"{across}x{deep}",
        "tallest": round(tallest, 1), "typical": round(typical, 1),
        "contrast": round(tallest / typical, 1) if typical else 0.0,
        "tall_wide": round(tallest * BRICK / (max(across, deep) * STUD), 2),
        "built": round(len(built) / (across * deep), 2),
    }


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    boxes = _boxes()
    for name in sys.argv[1:]:
        found = measure(Path(name), boxes)
        if found is None:
            print(f"{name}: no parts in it", file=sys.stderr)
            continue
        print(f"{found['file']}: {found['parts']} parts on "
              f"{found['footprint']} studs, {found['tallest']} bricks tall "
              f"where most of it is {found['typical']} (contrast "
              f"{found['contrast']}), tall/wide {found['tall_wide']}, "
              f"{found['built']:.0%} of the footprint built up"
              + (f"; {found['unknown']} parts not in the catalogue"
                 if found["unknown"] else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
