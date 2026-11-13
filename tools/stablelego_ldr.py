#!/usr/bin/env python3
"""StableLego's built structures and a sample of StableText2Brick, as LDraw.

    tools/stablelego_ldr.py stablelego [--out DIR]
    uv run --no-project --with pyarrow python3 tools/stablelego_ldr.py s2b [--out DIR]

The ground truth for Stability.check (src/dev/stabletruth_probe.gd,
docs/RESEARCH.md unit 3). Both sources are MIT and fetched at a pinned
version.

`stablelego` fetches the test structures from StableLego's repository
(Liu et al., RA-L 2024, arXiv 2402.10711) and writes each as an .ldr on a
48 x 48 baseplate, with what it really did when built: the six of its
Fig. 1 and the README (stairs of 19 levels that stand, of 20 that come
apart at the second brick and of 20 braced that stand; a stick of 1-wide
bricks with two loads that stands, with three that comes apart at its
root and with three braced that stands) and the two of its Fig. 11, a
200 g weight on stairs of 3 levels, which hold it, and of 4, which come
apart at the second brick. stick_heavy_good_test_horizontal_force was
never reported built, so it is left out. Its 200 g weight, which the paper
weighs as a 2 x 2 brick of 200 g, is 148 2 x 2 bricks of 1.35 g
(Stability.grams) stacked on that footprint: the same weight on the same
place, and a column's height moves no moment about a level edge.

`s2b` reads StableText2Brick's test split (BrickGPT, Pun et al., ICCV
2025), whose stability scores StableLego's analysis computed: per voxel,
in [0, 1], 0 for a brick that fails and more for one that holds, empty
voxels 1. Every structure in it holds. It takes 100 structures in the
order of a hash of their ids, and the 50 with the lowest score of any of
their bricks (the most stressed, where a false alarm would show) that are
not among them, and writes each as an .ldr on a baseplate with
`scores.json`: structure id -> each brick's score, in the file's line
order. Those are computed, not built: they test agreement, not truth.

Coordinates: a structure's x and y are studs across, z courses up; the
LDraw parts lie long along X, so a brick longer along y is turned 90
degrees. A course is 24 LDU, a stud 20, and the bottom course stands on
the baseplate's top at y = 0. Course 0 is pressed onto the baseplate in
both sources: its studs hold it down.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "fixtures", "stability")

STABLELEGO_COMMIT = "0fe57b608838d7e503b6acf6c8ca00db774734ac"
STABLELEGO_RAW = ("https://raw.githubusercontent.com/intelligent-control-lab/StableLego/"
                  + STABLELEGO_COMMIT + "/")
S2B_REVISION = "fd4c7b12cf925325665b7d1117615a18f1296b7a"
S2B_TEST = ("https://huggingface.co/datasets/AvaLovelace/StableText2Brick/resolve/"
            + S2B_REVISION + "/data/test-00000-of-00001.parquet")
S2B_SHA256 = "45b1078801f2e1871c9444d186be089d77aa9354bc60a35ab3d8e82710e4ff3e"

# The parts, by their footprint (short side, long side) in studs.
PARTS = {(1, 1): "3005", (1, 2): "3004", (1, 4): "3010", (1, 6): "3009",
         (1, 8): "3008", (2, 2): "3003", (2, 4): "3001", (2, 6): "2456"}
BASEPLATE = "4186"          # Baseplate 48 x 48, its top at y = 0
BASEPLATE_STUDS = 48
GREEN = 2
STUD = 20
COURSE = 24
# StableLego's 200 g weight, as 2 x 2 bricks of Stability.grams' 1.35 g.
WEIGHT_GRAMS = 200.0
BRICK_2X2_GRAMS = 1.35

# What each built structure did, from the paper's figures and the README:
# file -> (stood, the brick whose joint under it let go (the json's key) or
# "", the colour, a line about it).
BUILT = {
    "stair_19": (True, "", 0, "19 levels of 2 x 4, each two studs on: stands "
                 "(Fig. 1(1), README)"),
    "stair_20": (False, "2", 0, "20 levels: comes apart where the second brick "
                 "stands on the first (Fig. 1(2), README)"),
    "stair_20_good": (True, "", 0, "20 levels with a 1 x 2 under the second "
                      "brick: stands (Fig. 1(3), README)"),
    "stick_light": (True, "", 4, "a stick of 1-wide bricks with two 1 x 4 loads "
                    "at its end: stands (Fig. 1(4), README)"),
    "stick_heavy": (False, "2", 4, "with three loads: comes apart where the 1 x 4 "
                    "stands on the 1 x 8 on the baseplate (Fig. 1(5), README)"),
    "stick_heavy_good": (True, "", 4, "three loads, a 1 x 2 under the root: "
                         "stands (Fig. 1(6), README)"),
    "external_weight_good": (True, "", 0, "200 g on stairs of 3 levels: holds "
                             "(Fig. 11, README)"),
    "external_weight_fail": (False, "2", 0, "200 g on stairs of 4 levels: comes "
                             "apart at the second brick, the one Fig. 11 marks"),
}


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as reply:
        return reply.read()


def brick_line(colour: int, h: int, w: int, x: int, y: int, z: int,
               shift: tuple[int, int]) -> str:
    """One brick h studs along x and w along y at (x, y), course z."""
    part = PARTS[(min(h, w), max(h, w))]
    cx = (x + h / 2.0 + shift[0]) * STUD
    cz = (y + w / 2.0 + shift[1]) * STUD
    cy = -COURSE * (z + 1)
    turn = "1 0 0 0 1 0 0 0 1" if h >= w else "0 0 1 0 1 0 -1 0 0"
    return "1 %d %s %d %s %s %s.dat" % (colour, _num(cx), cy, _num(cz), turn, part)


def _num(v: float) -> str:
    return str(int(v)) if v == int(v) else ("%.1f" % v)


def baseplate_line() -> str:
    return "1 %d 0 0 0 1 0 0 0 1 0 0 0 1 %s.dat" % (GREEN, BASEPLATE)


def _shift(bricks: list[tuple[int, int, int, int, int]]) -> tuple[int, int]:
    """Studs to move a structure by so its middle is the baseplate's."""
    xs = [b[2] for b in bricks] + [b[2] + b[0] for b in bricks]
    ys = [b[3] for b in bricks] + [b[3] + b[1] for b in bricks]
    return (-((min(xs) + max(xs)) // 2), -((min(ys) + max(ys)) // 2))


def stablelego(out: str) -> None:
    library = json.loads(fetch(STABLELEGO_RAW + "lego_library.json"))
    folder = os.path.join(out, "stablelego")
    os.makedirs(folder, exist_ok=True)
    for name, (stood, broke, colour, said) in BUILT.items():
        design = json.loads(fetch(STABLELEGO_RAW + "test_lego/%s.json" % name))
        bricks = []          # (h, w, x, y, z, key, brick id)
        for key, brick in design.items():
            kind = library[str(brick["brick_id"])]
            if brick["ori"] == 0:
                h, w = kind["height"], kind["width"]
            else:
                h, w = kind["width"], kind["height"]
            bricks.append((h, w, brick["x"], brick["y"], brick["z"], key, brick["brick_id"]))
        shift = _shift([b[:5] for b in bricks])
        lines = [
            "0 StableLego %s" % name,
            "0 Name: %s.ldr" % name,
            "0 Author: Brickworks, from StableLego (MIT, Intelligent Control Lab)",
            "0 // %s" % said,
            "0 // source: %stest_lego/%s.json" % (STABLELEGO_RAW, name),
            "0 // built: %s" % ("stands" if stood else "falls"),
        ]
        if broke:
            lines.append("0 // breaks at: the joint under brick %s (%s)" % (
                broke, _where(bricks, broke)))
        lines.append(baseplate_line())
        for h, w, x, y, z, key, brick_id in bricks:
            kind = library[str(brick_id)]
            if kind["mass"] >= 0.1:
                # The 200 g weight, as a column of 2 x 2 bricks.
                count = round(WEIGHT_GRAMS / BRICK_2X2_GRAMS)
                lines.append("0 // brick %s: the 200 g weight, as %d 2 x 2 bricks of %.2f g"
                             % (key, count, BRICK_2X2_GRAMS))
                for n in range(count):
                    lines.append(brick_line(72, h, w, x, y, z + n, shift))
                continue
            lines.append("0 // brick %s" % key)
            lines.append(brick_line(colour, h, w, x, y, z, shift))
        path = os.path.join(folder, name + ".ldr")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        print("wrote %s (%d bricks, %s)" % (os.path.relpath(path, ROOT), len(bricks),
                                            "stands" if stood else "falls"))


def _where(bricks: list, key: str) -> str:
    for h, w, x, y, z, k, _ in bricks:
        if k == key:
            return "%d x %d at course %d" % (min(h, w), max(h, w), z)
    return "?"


def s2b(out: str, parquet: str | None) -> None:
    try:
        import pyarrow.parquet as pq
    except ImportError:
        sys.exit("s2b reads parquet: uv run --no-project --with pyarrow python3 "
                 "tools/stablelego_ldr.py s2b")
    if parquet is None:
        data = fetch(S2B_TEST)
        if hashlib.sha256(data).hexdigest() != S2B_SHA256:
            sys.exit("StableText2Brick's test split is not the one pinned")
        parquet = os.path.join(out, ".s2b_test.parquet")
        with open(parquet, "wb") as f:
            f.write(data)
    table = pq.read_table(parquet, columns=["structure_id", "bricks", "stability_scores"])
    rows = []
    for i in range(table.num_rows):
        row = table.slice(i, 1).to_pylist()[0]
        bricks = []
        for line in row["bricks"].strip().splitlines():
            m = re.match(r"(\d+)x(\d+) \((\d+),(\d+),(\d+)\)", line.strip())
            h, w, x, y, z = map(int, m.groups())
            bricks.append((h, w, x, y, z))
        scores = row["stability_scores"]
        each = [scores[x][y][z] for (h, w, x, y, z) in bricks]
        rows.append((row["structure_id"], bricks, each))
    by_hash = sorted(rows, key=lambda r: hashlib.sha1(r[0].encode()).hexdigest())
    chosen = by_hash[:100]
    ids = {r[0] for r in chosen}
    stressed = sorted((r for r in rows if r[0] not in ids), key=lambda r: min(r[2]))[:50]
    folder = os.path.join(out, "stabletext2brick")
    os.makedirs(folder, exist_ok=True)
    kept = {}
    for sample, group in (("hashed", chosen), ("stressed", stressed)):
        for structure_id, bricks, each in group:
            shift = _shift(bricks)
            lines = ["0 StableText2Brick %s" % structure_id,
                     "0 Name: %s.ldr" % structure_id,
                     "0 Author: Brickworks, from StableText2Brick (MIT, CMU)",
                     "0 // %s sample; scores in scores.json, in line order" % sample,
                     baseplate_line()]
            for h, w, x, y, z in bricks:
                lines.append(brick_line(15, h, w, x, y, z, shift))
            with open(os.path.join(folder, structure_id + ".ldr"), "w") as f:
                f.write("\n".join(lines) + "\n")
            kept[structure_id] = {"sample": sample,
                                  "scores": [round(s, 4) for s in each]}
    with open(os.path.join(folder, "scores.json"), "w") as f:
        json.dump({"source": S2B_TEST, "structures": kept}, f, separators=(",", ":"))
        f.write("\n")
    print("wrote %d structures (%d hashed, %d most stressed), %d bricks, to %s" % (
        len(kept), len(chosen), len(stressed), sum(len(v["scores"]) for v in kept.values()),
        os.path.relpath(folder, ROOT)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("which", choices=["stablelego", "s2b"])
    parser.add_argument("--out", default=OUT)
    parser.add_argument("--parquet", help="StableText2Brick's test split, if already fetched")
    args = parser.parse_args()
    if args.which == "stablelego":
        stablelego(args.out)
    else:
        s2b(args.out, args.parquet)


if __name__ == "__main__":
    main()
