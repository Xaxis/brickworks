#!/usr/bin/env python3
"""The gear table, assets/ldraw/gears.json, checked against the parts.

    tools/gears.py check               the checks below; exit 1 if any fails
    tools/gears.py measure [N]         how far apart gears stand in the OMR's
                                       Technic sets (N of them; all by default)

src/assembly/mechanism.gd reads a gear's teeth, kind and hole from the
table, because the catalogue says how many teeth a gear has only in its
name. So the table is checked four ways:

  names    every Technic part the catalogue names with a tooth count ("Technic
           Gear 24 Tooth", "Turntable 60 Tooth Top", "Gear Ring Quarter ...
           with 35 Teeth") is in the table, or in its not_gears with the
           reason; and the table's count is the name's.
  holes    a gear the table says takes an axle by a hole has that hole on
           its axis in the part's own connectors, as tools/ldraw/
           connectivity.py reads them. A gear without one floats free of
           its axle in every model it is in.
  sizes    a spur gear's outside diameter is 2.5 (N + 2) LDU, module 1 mm:
           the 24 is 64.78 across against 65. The 16's teeth are short
           (43.28 against 45).
  spacing  in real sets, parallel gears in one plane that stand within 8
           LDU of meshing stand 1.25 LDU a tooth apart: 722 of 809 pairs to
           0.1 LDU and 42 more to 0.3 in the OMR's 354 Technic sets
           (docs/MECHANISMS.md, section 2). Needs vendor/omr (tools/omr.py
           fetch); measured by `measure`, and by the test on a few sets.
"""

from __future__ import annotations

import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

TABLE = ROOT / "assets" / "ldraw" / "gears.json"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
LDRAW = ROOT / "vendor" / "ldraw"
OMR = ROOT / "vendor" / "omr" / "files"

## A Technic part named with its teeth: "Technic Gear 24 Tooth", "... 9
## Large Tooth", "... with 35 Teeth". Names that begin "~" are pieces of
## other parts or hidden ones, and are not placed in a model.
TOOTHED = re.compile(r"^=?Technic\b.*?\b(\d+) (?:Large )?(?:Tooth|Teeth)\b")
## The diameter rule's slack, LDU: the 24 is 0.22 under, the 40 0.3, an 8
## 0.14; a 16 with short teeth 1.72.
SIZE_SLACK = 2.0


def load_table() -> dict:
    return json.loads(TABLE.read_text())


def toothed_parts(catalogue: dict) -> dict[str, tuple[str, int]]:
    """part -> (name, the tooth count the name gives), for every Technic part
    named with one."""
    out: dict[str, tuple[str, int]] = {}
    for part in catalogue["parts"]:
        found = TOOTHED.match(part["name"])
        if found and not part.get("moved_to"):
            out[part["id"]] = (part["name"], int(found.group(1)))
    return out


def check_names(table: dict, catalogue: dict) -> list[str]:
    """Every toothed Technic part is in the table or set aside with a
    reason, and the table's count is the name's."""
    gears: dict = table["gears"]
    aside: dict = table.get("not_gears", {})
    problems: list[str] = []
    for part_id, (name, teeth) in sorted(toothed_parts(catalogue).items()):
        if part_id in gears:
            said = int(gears[part_id].get("teeth", 0))
            also = [int(g.get("teeth", 0)) for g in gears[part_id].get("also", [])]
            if teeth != said and teeth not in also:
                problems.append(f"{part_id} '{name}': the table says {said} teeth")
        elif part_id not in aside:
            problems.append(f"{part_id} '{name}': not in the gear table")
    for part_id, reason in aside.items():
        if not str(reason).strip():
            problems.append(f"{part_id}: set aside without a reason")
    known = {p["id"] for p in catalogue["parts"]}
    for part_id in gears:
        if part_id not in known:
            problems.append(f"{part_id}: in the gear table but not in the catalogue")
    return problems


## The table's axes are the app's (+Y up): LDraw's with y and z turned
## round. A part's own axis is a direction, so only its line matters here.
def _ldraw_axis(word: str) -> tuple[float, float, float]:
    return {"x": (1.0, 0.0, 0.0), "y": (0.0, 1.0, 0.0)}.get(word, (0.0, 0.0, 1.0))


def check_holes(table: dict) -> list[str]:
    """A gear the table says has a hole has it on its axis, at its middle,
    in the connectors connectivity.py reads off the part."""
    from ldraw.connectivity import ConnectorKind, extract
    from ldraw.library import Library

    library = Library(LDRAW)
    wanted = {"axle": {ConnectorKind.AXLE_HOLE},
              # A round hole is a peg hole, or a bore an axle's size that an
              # axle turns in (src/assembly/mechanism.gd, ROUND_HOLE).
              "round": {ConnectorKind.PIN_HOLE, ConnectorKind.BORE}}
    problems: list[str] = []
    for part_id, spec in sorted(table["gears"].items()):
        hole = spec.get("hole", "none")
        if hole == "none":
            continue
        axis = _ldraw_axis(spec.get("axis", "z"))
        found = False
        for c in extract(library, part_id + ".dat"):
            if c.kind not in wanted[hole]:
                continue
            if c.kind is ConnectorKind.BORE and abs(c.radius - 6.0) > 0.6:
                continue
            way = (c.axis.x, c.axis.y, c.axis.z)
            if abs(abs(sum(a * b for a, b in zip(way, axis))) - 1.0) > 0.01:
                continue
            at = (c.position.x, c.position.y, c.position.z)
            along = sum(a * b for a, b in zip(at, axis))
            off = math.sqrt(max(sum(a * a for a in at) - along * along, 0.0))
            if off <= 1.5:
                found = True
                break
        if not found:
            problems.append(f"{part_id}: the table says it takes an axle by a {hole} hole, "
                            "and its connectors have none on its axis")
    return problems


def _moved_to(part: str) -> str:
    """The part a "~Moved to X" file stands for, else the part itself."""
    path = LDRAW / "parts" / f"{part}.dat"
    if path.exists():
        first = path.read_text(errors="replace").splitlines()[0]
        if "~Moved to " in first:
            return first.split("~Moved to ", 1)[1].strip()
    return part


def check_actuators(table: dict) -> list[str]:
    """Each actuator's rod stands where the library's own contracted and
    extended files put it: from and to along the body's axis, in the app's
    axes (LDraw's with y and z turned round), and nowhere off it."""
    problems: list[str] = []
    for body, spec in sorted(table.get("actuators", {}).items()):
        axis = _ldraw_axis(spec.get("axis", "z"))
        flip = (1.0, -1.0, -1.0)
        for drawn, want in zip(spec["drawn"], (spec["from"], spec["to"])):
            path = LDRAW / "parts" / f"{drawn}.dat"
            if not path.exists():
                problems.append(f"{body}: no {drawn}.dat to read its stroke from")
                continue
            placed: dict[str, tuple[list[float], list[float]]] = {}
            for line in path.read_text(errors="replace").splitlines():
                bits = line.split()
                if len(bits) >= 15 and bits[0] == "1":
                    part = _moved_to(bits[14].lower().removesuffix(".dat"))
                    placed[part] = ([float(v) for v in bits[2:5]], [float(v) for v in bits[5:14]])
            if body not in placed or spec["rod"] not in placed:
                problems.append(f"{body}: {drawn} does not place {body} and {spec['rod']}")
                continue
            (b, m), (r, _) = placed[body], placed[spec["rod"]]
            gap = [r[k] - b[k] for k in range(3)]
            # Into the body's own frame (its matrix's columns), then the app's axes.
            local = [sum(m[3 * k + j] * gap[k] for k in range(3)) * flip[j] for j in range(3)]
            along = sum(a * x for a, x in zip(axis, local))
            off = math.sqrt(max(sum(x * x for x in local) - along * along, 0.0))
            if abs(along - float(want)) > 0.01 or off > 0.01:
                problems.append(f"{body}: {drawn} puts {spec['rod']} {along:.2f} along its axis and "
                                f"{off:.2f} off it, where the table says {want}")
    return problems


def check_sizes(table: dict, catalogue: dict) -> list[str]:
    """A spur gear's outside diameter is 2.5 (N + 2) LDU."""
    by_id = {p["id"]: p for p in catalogue["parts"]}
    problems: list[str] = []
    for part_id, spec in sorted(table["gears"].items()):
        # "size" says why a part's box is not its teeth's: a clutch's hub.
        if spec.get("kind") != "spur" or spec.get("axis", "z") != "z" \
                or spec.get("also") or spec.get("size") or part_id not in by_id:
            continue
        size = by_id[part_id]["size_ldu"]
        across = max(size[0], size[1])
        want = 2.5 * (int(spec["teeth"]) + 2)
        if abs(across - want) > SIZE_SLACK:
            problems.append(f"{part_id}: {across:.2f} LDU across, where {spec['teeth']} teeth "
                            f"make {want:.1f}")
    return problems


# -- measuring real sets --------------------------------------------------------


def _set_files(most: int = 0) -> list[Path]:
    files = sorted(p for p in OMR.glob("*.mpd") if re.match(r"^(42|8)\d", p.name))
    return files[:most] if most else files


def _part_id(ref: str) -> str:
    """A reference's part: an OMR file carries parts that were unofficial
    when it was drawn as '42055 - 24121.dat'."""
    stem = ref[:-4] if ref.endswith(".dat") else ref
    return re.sub(r"^[0-9a-z]+(-\d+)? - ", "", stem)


def spacing(files: list[Path], table: dict) -> Counter:
    """Parallel pairs of the table's spur and double-bevel gears in one
    plane within 8 LDU of meshing, by how far off 1.25 LDU a tooth they
    stand: "0.1", "0.3", "1", "out"."""
    import omr

    per = float(table.get("ldu_per_tooth", 1.25))
    gears = {k: v for k, v in table["gears"].items()
             if v.get("kind") in ("spur", "double") and v.get("axis", "z") == "z"
             and not v.get("also") and v.get("hole") != "none"}
    tally: Counter = Counter()
    for path in files:
        placed = []
        for ref, _colour, m, _sub in omr._flatten(path.read_text(errors="replace")):
            part = _part_id(ref)
            if part in gears:
                axis = (m[5], m[8], m[11])
                placed.append((int(gears[part]["teeth"]), (m[0], m[1], m[2]), axis))
        for i, (n1, p1, a1) in enumerate(placed):
            for n2, p2, a2 in placed[i + 1:]:
                if abs(abs(sum(x * y for x, y in zip(a1, a2))) - 1.0) > 0.001:
                    continue
                gap = [b - a for a, b in zip(p1, p2)]
                along = sum(g * a for g, a in zip(gap, a1))
                if abs(along) > 0.5:
                    continue
                across = math.sqrt(max(sum(g * g for g in gap) - along * along, 0.0))
                off = abs(across - per * (n1 + n2))
                if off > 8.0:
                    continue
                tally["0.1" if off <= 0.1 else "0.3" if off <= 0.3 else "1" if off <= 1.0
                      else "out"] += 1
    return tally


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] not in ("check", "measure"):
        print(__doc__)
        return 2
    table = load_table()
    if argv[1] == "measure":
        most = int(argv[2]) if len(argv) > 2 else 0
        files = _set_files(most)
        if not files:
            print(f"no sets in {OMR}: tools/omr.py fetch")
            return 1
        tally = spacing(files, table)
        total = sum(tally.values())
        print(f"{len(files)} sets, {total} parallel pairs in one plane within 8 LDU of meshing:")
        for key in ("0.1", "0.3", "1", "out"):
            print(f"  {key:>4}  {tally[key]}")
        return 0
    problems: list[str] = []
    if CATALOGUE.exists():
        catalogue = json.loads(CATALOGUE.read_text())
        problems += check_names(table, catalogue)
        problems += check_sizes(table, catalogue)
    else:
        print(f"(no {CATALOGUE}: names and sizes not checked)")
    if (LDRAW / "parts").is_dir():
        problems += check_holes(table)
        problems += check_actuators(table)
    else:
        print(f"(no {LDRAW}: holes not checked)")
    for problem in problems:
        print("  " + problem)
    print(f"gear table: {len(table['gears'])} gears, {len(table.get('not_gears', {}))} set aside, "
          f"{len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
