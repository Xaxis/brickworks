#!/usr/bin/env python3
"""Learn the fits real sets are built with, for the exact check to forgive.

    tools/known_fits.py scan [--shards 3] [--parallel 2] [--out DIR] [--fits] [FILE.mpd ...]
    tools/known_fits.py build [--out DIR] [--write assets/ldraw/known_fits.json]
    tools/known_fits.py report [--out DIR] [--table assets/ldraw/known_fits.json]

A set the LEGO Group sold is buildable by definition, so where the exact
check (src/ai/exact_check.gd) finds two of its parts passing into each other
the parts meet that way in plastic: a beard through a figure's hair and
cape, hips sunk into a seat, a hand round a steering wheel, cloth and soft
hair giving way, or LDraw drawing a part a little fuller than it is.

`scan` judges every file of the LDraw model repository's official sets
(vendor/omr/files) as Tested's whole test judges collisions, in shards, each
src/dev/known_fits_scan.gd in a headless Godot under heavy, one JSON line a
file in DIR/shard-K.jsonl (connection_audit.py's runner: a shard that dies
is started again after the file it died on).

With --fits the table's fits are left out too, as the check leaves them: the
pairs the check still refuses, which `report --out` that folder counts.

`build` learns the table from those lines (see `learn`) and writes it with
every catalogue part's minifigure kind, for KnownFits to read.

`report` says how many files pass the collision part of the check without
the table and with it, and why each that still fails does.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import connection_audit  # noqa: E402

OUT = ROOT / "build" / "known_fits"
TABLE = ROOT / "assets" / "ldraw" / "known_fits.json"
PROBE = "src/dev/known_fits_scan.gd"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"


def scan(shards: int, out: Path, files: list[str], parallel: int, fits: bool = False) -> int:
    out = out.resolve()
    return connection_audit.run(shards, out, files, parallel, probe=PROBE, data=out / "data",
                                extra=("--fits",) if fits else ())


def rows(out: Path) -> list[dict]:
    """Each file's finished line, the last of each file's."""
    found: dict[str, dict] = {}
    for path in sorted(out.glob("shard-*.jsonl")):
        for row in connection_audit._rows(path):
            if row.get("begin"):
                continue
            found[row["file"]] = row
    return [found[f] for f in sorted(found)]


# -- learn -------------------------------------------------------------------

## What a minifigure is made of, by KnownFits.kind_for: a pair with one of
## these meets by what the two are, whatever the mould or print, as cloth,
## soft hair and a figure's grip and hips give in plastic. What it meets is
## another of these by its kind, a thing a figure holds or sits on ("held")
## by its mould, and any other part as "brick". A pair of two parts that are
## not a minifigure's is its two moulds (prints as their plain part), and
## meets only as the sets put them, the one where the other is.
BODY = {"hair", "headgear", "head", "beard", "neckwear", "back", "cape", "torso", "arm", "hand",
        "hips", "hipwear", "legs", "footwear"}
## How many sets (set numbers: a B-model is its set's) must meet so for it to
## be a fit: what one set alone does is that file's slip, not how the parts
## fit.
SETS_NEEDED = 2
## And how deep: as deep as all but this share of the sets that meet so
## reach (and at least SETS_NEEDED of them). The deepest few of many are
## figures drawn through what they sit on, a slip of the file's again: legs
## meet a part that is not a figure's in 53 of the first 794 files, 4 LDU
## deep at most in three in four, and up to 9 in the rest.
TAIL = 0.25
## Forgiven this much deeper than the sets reach, LDU.
MARGIN = 0.5
## Two poses of a pair are one where each part of the place is within this,
## LDU, and each entry of the turn within TURN.
PLACE = 1.0
TURN = 0.05


def family(pid: str) -> str:
    """A printed part's plain mould, 3039pc4 -> 3039: Minifig._family."""
    found = re.match(r"^([a-z]?\d+[a-z]?(?:-f\d)?)(p[0-9a-z]+)?$", pid)
    return found.group(1) if found else pid


def key_of(pid: str, kind: str, against_body: bool) -> str:
    if kind in BODY:
        return kind
    return "brick" if against_body and kind != "held" else family(pid)


def set_of(file: str) -> str:
    """10001-1_B-Model-from-Instruction.mpd -> 10001-1."""
    return file.split("_")[0].rsplit(".", 1)[0]


def inverse(rel: list[float]) -> list[float]:
    """b's place in a's frame -> a's in b's ([origin, the basis's columns])."""
    o = rel[:3]
    cols = [rel[3:6], rel[6:9], rel[9:12]]
    # R transposed: its columns are R's rows, and its rows R's columns.
    rows = [[cols[0][i], cols[1][i], cols[2][i]] for i in range(3)]
    origin = [-sum(cols[i][k] * o[k] for k in range(3)) for i in range(3)]
    return origin + rows[0] + rows[1] + rows[2]


def near(p: list[float], q: list[float]) -> bool:
    return all(abs(p[i] - q[i]) <= PLACE for i in range(3)) \
        and all(abs(p[i] - q[i]) <= TURN for i in range(3, 12))


def same_pose(p: list[float], q: list[float], same_part: bool) -> bool:
    return near(p, q) or (same_part and near(inverse(p), q))


def met(rows: list[dict]):
    """Each colliding pair, as (key a, key b, pose or None, depth, set, file,
    twice), a <= b; the pose (b's place in a's frame) only between two parts
    that are not a minifigure's. `twice` for one mould drawn twice in one
    place, turned or not: no set is built so, and LDraw files have it by
    mistake, so it is never learned as a fit."""
    for row in rows:
        for pair in row["pairs"]:
            body = pair["ka"] in BODY or pair["kb"] in BODY
            ka, kb = key_of(pair["a"], pair["ka"], body), key_of(pair["b"], pair["kb"], body)
            rel = pair["rel"]
            if ka > kb:
                ka, kb, rel = kb, ka, inverse(rel)
            twice = ka == kb and all(abs(v) <= PLACE for v in rel[:3])
            pose = None if body else rel
            yield ka, kb, pose, float(pair["m"]), set_of(row["file"]), row["file"], twice


def learn(rows: list[dict], needed: int = SETS_NEEDED, tail: float = TAIL) -> list[dict]:
    """The fits: each pair of kinds or moulds (and, between two moulds, each
    pose) that at least `needed` sets meet in, forgiven as deep as all but
    `tail` of them reach, and MARGIN more."""
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for ka, kb, pose, depth, number, _file, twice in met(rows):
        if twice:
            continue
        clusters = groups[(ka, kb)]
        home = None
        if pose is None:
            home = clusters[0] if clusters else None
        else:
            for cluster in clusters:
                if same_pose(pose, cluster["at"], ka == kb):
                    home = cluster
                    break
        if home is None:
            home = {"at": pose, "sets": {}}
            clusters.append(home)
        home["sets"][number] = max(home["sets"].get(number, 0.0), depth)
    fits = []
    for (ka, kb), clusters in sorted(groups.items()):
        for cluster in clusters:
            deepest = sorted(cluster["sets"].items(), key=lambda kv: -kv[1])
            if len(deepest) < needed:
                continue
            reached = deepest[max(needed, math.ceil(tail * len(deepest))) - 1][1]
            fit = {"a": ka, "b": kb}
            if cluster["at"] is not None:
                fit["at"] = [round(v, 3) for v in cluster["at"]]
            fit["depth"] = round(reached + MARGIN, 2)
            fit["seen"] = len(deepest)
            fit["sets"] = [number for number, _ in deepest[:12]]
            fits.append(fit)
    return fits


def allowed(fits: list[dict]):
    """A function (ka, kb, pose, depth) -> whether the fits forgive it."""
    plain: dict[tuple, float] = {}
    posed: dict[tuple, list] = defaultdict(list)
    for fit in fits:
        if "at" in fit:
            posed[(fit["a"], fit["b"])].append((fit["at"], fit["depth"]))
        else:
            plain[(fit["a"], fit["b"])] = fit["depth"]

    def forgives(ka: str, kb: str, pose, depth: float, twice: bool = False) -> bool:
        if twice:
            return False
        if pose is None:
            return depth <= plain.get((ka, kb), 0.0)
        return any(depth <= most and same_pose(pose, at, ka == kb) for at, most in posed[(ka, kb)])
    return forgives


def kinds_of_catalogue(out: Path) -> dict[str, str]:
    """Every catalogue part's minifigure kind, by Godot (KnownFits.kind_for),
    folded to its mould where every print of it is the same kind: what
    KnownFits keys a part by, as `met` does here from the scan's kinds."""
    path = out / "kinds.json"
    env = dict(os.environ, XDG_DATA_HOME=str(out / "data"))
    subprocess.run([str(HEAVY), "godot", "--headless", "--path", str(ROOT), "--script", PROBE,
                    "--", f"--kinds={path}"], cwd=ROOT, env=env, check=True)
    by_kind = json.loads(path.read_text())
    of: dict[str, str] = {}
    for kind, ids in by_kind.items():
        if kind in BODY or kind == "held":
            for pid in ids:
                of[pid] = kind
    moulds: dict[str, set] = defaultdict(set)
    for pid, kind in of.items():
        moulds[family(pid)].add(kind)
    # Not where a part of the mould is no minifigure's.
    for part in json.loads(CATALOGUE.read_text())["parts"]:
        if part["id"] not in of and family(part["id"]) in moulds:
            moulds[family(part["id"])].add("")
    folded: dict[str, str] = {}
    for mould, kinds in moulds.items():
        if len(kinds) == 1:
            folded[mould] = next(iter(kinds))
    for pid, kind in of.items():
        if folded.get(family(pid)) != kind:
            folded[pid] = kind
    return dict(sorted(folded.items()))


def build(out: Path, write: Path) -> int:
    found = rows(out)
    if not found:
        print(f"no scan in {out}: run `scan` first")
        return 1
    fits = learn(found)
    table = {
        "about": "Fits the LEGO Group's own sets are built with, which the exact check forgives "
                 "(src/ai/known_fits.gd). Made by tools/known_fits.py from "
                 f"{len(found)} files of the LDraw model repository's official sets; "
                 "do not edit by hand.",
        "sets_needed": SETS_NEEDED,
        "margin": MARGIN,
        "place": PLACE,
        "turn": TURN,
        "fits": fits,
        "kinds": kinds_of_catalogue(out),
    }
    write.write_text(json.dumps(table, indent=0, separators=(",", ":")) + "\n")
    print(f"{write}: {len(fits)} fits from {len(found)} files, "
          f"{sum(1 for f in fits if 'at' not in f)} by kind, {sum(1 for f in fits if 'at' in f)} by pose")
    return 0


# -- report ------------------------------------------------------------------

## Why a pair the table does not forgive is left, said in the report.
CAUSES = {
    "twice": "one part drawn twice in one place: the file's slip",
    "alone": "two parts not a minifigure's, met so by this set alone: a part drawn into "
             "another, or BrickNet's convex pieces filling what is hollow",
    "deeper": "deeper than the sets that meet so",
    "figure alone": "a minifigure's part against something no other set has it against",
}


def cause(fits: dict, plain: dict, ka: str, kb: str, pose, twice: bool) -> str:
    if twice:
        return "twice"
    if pose is None:
        return "deeper" if (ka, kb) in plain else "figure alone"
    return "deeper" if any(same_pose(pose, at, ka == kb) for at, _ in fits.get((ka, kb), [])) else "alone"


def report(out: Path, table: Path) -> int:
    found = rows(out)
    fits = json.loads(table.read_text())["fits"]
    forgives = allowed(fits)
    plain = {(f["a"], f["b"]): f["depth"] for f in fits if "at" not in f}
    posed: dict[tuple, list] = defaultdict(list)
    for f in fits:
        if "at" in f:
            posed[(f["a"], f["b"])].append((f["at"], f["depth"]))
    before = sum(1 for row in found if not row["pairs"])
    still: dict[str, list] = {}
    figures = figures_pass = 0
    for row in found:
        every = list(met([row]))
        left = [m for m in every if not forgives(m[0], m[1], m[2], m[3], m[6])]
        if left:
            still[row["file"]] = left
        theirs = [m for m in every if m[2] is None]
        if theirs:
            figures += 1
            figures_pass += not [m for m in left if m[2] is None]
    passed = len(found) - len(still)
    print(f"{len(found)} files: {before} pass the collision part before ({100 * before / len(found):.1f}%), "
          f"{passed} with the table ({100 * passed / len(found):.1f}%)")
    print(f"{figures} files have a minifigure's part in a colliding pair; every such pair is "
          f"forgiven in {figures_pass} ({100 * figures_pass / max(1, figures):.1f}%)")
    files: dict[str, set] = defaultdict(set)
    pairs: dict[str, int] = defaultdict(int)
    for file, left in still.items():
        for ka, kb, pose, _depth, _set, _file, twice in left:
            why = cause(posed, plain, ka, kb, pose, twice)
            files[why].add(file)
            pairs[why] += 1
    print(f"the {len(still)} that still fail, by what is left in them (a file can have several):")
    for why, said in CAUSES.items():
        only = sum(1 for f in files[why] if all(cause(posed, plain, m[0], m[1], m[2], m[6]) == why
                                               for m in still[f]))
        print(f"  {len(files[why]):5d} files ({only} by this alone), {pairs[why]:6d} pairs: {said}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[1])
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("scan")
    one.add_argument("--shards", type=int, default=3)
    one.add_argument("--parallel", type=int, default=2)
    one.add_argument("--out", type=Path, default=OUT)
    one.add_argument("--fits", action="store_true",
                     help="leave out what the table forgives too: what the check still refuses")
    one.add_argument("files", nargs="*")
    two = sub.add_parser("build")
    two.add_argument("--out", type=Path, default=OUT)
    two.add_argument("--write", type=Path, default=TABLE)
    three = sub.add_parser("report")
    three.add_argument("--out", type=Path, default=OUT)
    three.add_argument("--table", type=Path, default=TABLE)
    args = parser.parse_args()
    if args.command == "scan":
        return scan(args.shards, args.out, args.files, args.parallel, args.fits)
    if args.command == "build":
        return build(args.out, args.write)
    return report(args.out, args.table)


if __name__ == "__main__":
    sys.exit(main())
