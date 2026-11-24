#!/usr/bin/env python3
"""Check the LDraw a part of one's own is written as, with tools that read LDraw.

    python3 tools/own_parts_check.py DIR

DIR holds what src/dev/mesh_part_probe.gd --write=DIR kept: each made part's
.dat and the figure models that carry them (figure-*.mpd). Each is read the
way LDCad and every LDraw reader reads a file, with tools/ldraw/parser.py in
its strict mode (a malformed line fails, where a renderer would skip it):

- every line is a line LDraw has: 0 to 5, each with its count of numbers,
  every number finite;
- a part file says what it is (title, Name:, !LDRAW_ORG) and certifies its
  winding (0 BFC CERTIFY CCW) before any geometry;
- no triangle is flat, and every reference (stud.dat, 4-4cyli.dat) turns
  space without flattening it and names a file the library has;
- a model's 0 FILE sections are named once each, its first is the model, and
  every part it places is in the library or among its own sections, its own
  parts carried whole (their text exactly the part's file);
- connectivity, the pipeline's own reader, reads every connector line the
  file states and finds a stud at each stud.dat it draws, as the app's
  PartForge does.

Prints what it found; exits 1 if any file breaks a rule.
"""
from __future__ import annotations

import math
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ldraw import connectivity, library  # noqa: E402
from ldraw.parser import EdgeLine, MetaLine, Polygon, SubfileRef, parse_line  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LDRAW = ROOT / "vendor" / "ldraw"


def _finite(points) -> bool:
    return all(math.isfinite(c) for p in points for c in (p.x, p.y, p.z))


def check_lines(name: str, lines: list[str], lib: library.Library, own: set[str],
                part: bool = True) -> list[str]:
    """What breaks LDraw's rules in one file's lines: a part's, or a model's
    (which certifies no winding of its own, as LDCad writes one)."""
    faults: list[str] = []
    certified = False
    geometry = False
    for number, raw in enumerate(lines, start=1):
        try:
            command = parse_line(raw)
        except ValueError as error:
            faults.append(f"{name}:{number}: {error}")
            continue
        if command is None:
            continue
        if isinstance(command, MetaLine):
            if command.keyword == "BFC" and command.text.upper().startswith("CERTIFY"):
                if geometry:
                    faults.append(f"{name}:{number}: BFC CERTIFY after geometry")
                certified = True
            continue
        geometry = True
        if isinstance(command, Polygon):
            if not _finite(command.points):
                faults.append(f"{name}:{number}: a number that is not finite")
                continue
            a, b, c = command.points[:3]
            u = (b.x - a.x, b.y - a.y, b.z - a.z)
            v = (c.x - a.x, c.y - a.y, c.z - a.z)
            cross = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            if math.sqrt(sum(x * x for x in cross)) < 1e-9:
                faults.append(f"{name}:{number}: a flat triangle")
        elif isinstance(command, EdgeLine):
            if not _finite(command.points):
                faults.append(f"{name}:{number}: a number that is not finite")
        elif isinstance(command, SubfileRef):
            m = command.matrix
            det = (m.a * (m.e * m.i - m.f * m.h) - m.b * (m.d * m.i - m.f * m.g)
                   + m.c * (m.d * m.h - m.e * m.g))
            if not math.isfinite(det) or abs(det) < 1e-9:
                faults.append(f"{name}:{number}: a reference that flattens space")
            if command.filename.lower() not in own and lib.resolve(command.filename) is None:
                faults.append(f"{name}:{number}: {command.filename} is nowhere")
    if part and not certified and geometry:
        faults.append(f"{name}: no 0 BFC CERTIFY")
    return faults


def sections(text: str) -> list[tuple[str, list[str]]]:
    """An MPD's 0 FILE sections in order: [(name, lines)]."""
    out: list[tuple[str, list[str]]] = []
    for raw in text.splitlines():
        words = raw.strip().split(None, 2)
        if len(words) >= 3 and words[0] == "0" and words[1].upper() == "FILE":
            out.append((words[2].strip(), []))
        elif raw.strip().upper() == "0 NOFILE":
            continue
        elif out:
            out[-1][1].append(raw)
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    folder = Path(sys.argv[1])
    parts = sorted(folder.glob("*.dat"))
    models = sorted(folder.glob("*.mpd"))
    if not parts or not models:
        print(f"own_parts_check: nothing to check in {folder} ({len(parts)} parts, {len(models)} models)")
        return 1
    with tempfile.TemporaryDirectory() as extra:
        for part in parts:
            (Path(extra) / part.name).write_bytes(part.read_bytes())
        lib = library.Library(LDRAW, extra=[extra])
        names = {p.name.lower() for p in parts}
        failed = 0
        for part in parts:
            lines = part.read_text().splitlines()
            faults = check_lines(part.name, lines, lib, names)
            header = lines[:4]
            if not (header[0].startswith("0 ") and header[1] == f"0 Name: {part.name}"
                    and any(line.startswith("0 !LDRAW_ORG") for line in lines[:8])):
                faults.append(f"{part.name}: no title, Name: or !LDRAW_ORG at its head")
            said = [line for line in lines if line.startswith("0 !BRICKWORKS CONNECTOR")]
            read = connectivity.said_connectors(lib, part.name)
            if len(read) != len(said):
                faults.append(f"{part.name}: states {len(said)} connectors, the pipeline reads "
                              f"{len(read)} of them")
            found = connectivity.extract(lib, part.name) + connectivity.rounds(lib, part.name)
            kinds: dict[str, int] = {}
            for c in found:
                kinds[c.kind.value] = kinds.get(c.kind.value, 0) + 1
            studs = sum(1 for line in lines if line.startswith("1 ") and line.endswith(" stud.dat"))
            if kinds.get("stud", 0) < studs:
                faults.append(f"{part.name}: draws {studs} studs, the pipeline finds "
                              f"{kinds.get('stud', 0)}")
            triangles = sum(1 for line in lines if line.startswith("3 "))
            print(f"  {'FAIL' if faults else 'ok  '}  {part.name}: {triangles} triangles, "
                  f"{len(said)} connector lines, {studs} studs; the pipeline reads {kinds}")
            for fault in faults[:6]:
                print(f"          {fault}")
            failed += bool(faults)
        for model in models:
            text = model.read_text()
            found = sections(text)
            faults: list[str] = []
            seen: set[str] = set()
            for name, _ in found:
                if name.lower() in seen:
                    faults.append(f"{model.name}: 0 FILE {name} twice")
                seen.add(name.lower())
            if not found:
                faults.append(f"{model.name}: no 0 FILE sections")
            elif found[0][0].lower() in names:
                faults.append(f"{model.name}: its first section is a part, not the model")
            for name, lines in found:
                faults += check_lines(f"{model.name}#{name}", lines, lib, seen,
                                      part=name.lower() in names)
            carried = [name for name, _ in found if name.lower() in names]
            for name, lines in found:
                if name.lower() in names:
                    own = (folder / name).read_text().strip("\n").splitlines()
                    if [line.rstrip() for line in lines if line.strip() != ""] != \
                            [line.rstrip() for line in own if line.strip() != ""]:
                        faults.append(f"{model.name}: its {name} is not the part's own text")
            if not carried:
                faults.append(f"{model.name}: carries none of the parts made")
            print(f"  {'FAIL' if faults else 'ok  '}  {model.name}: {len(found)} sections, "
                  f"carries {carried}")
            for fault in faults[:6]:
                print(f"          {fault}")
            failed += bool(faults)
    print(f"\nown_parts_check: {len(parts)} parts and {len(models)} models, {failed} breaking a rule")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
