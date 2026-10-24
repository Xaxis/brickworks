#!/usr/bin/env python3
"""How big real minifigure-scale models are, measured.

plan_scale turned a length in metres into studs at a stud to the foot,
and real sets do not build at that: a 20 m harbour tug came to 60 studs
where City's tugs are 30 to 40 (walk180, 2026-10-23). A formula fitted to
six sets fixed that one and guesses at everything else. These are the
measurements themselves: every model in LDraw's Official Model Repository
(vendor/omr) whose set has a minifigure in it, each vehicle and building
of it on its own — the sub-models the set's file is built of, a fire
station apart from its fire engine — with its name and its size in studs.

A design is then sized against the real models of its kind: plan_scale
finds the fire engines, the cottages or the boats here by their names.

Writes assets/knowledge/set_sizes.json. tools/refresh_catalogue.py runs it
after each refresh.

    tools/set_sizes.py [--generated DIR] [--out FILE]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from ldraw.parser import Matrix, SubfileRef, normalise_filename, parse_line, read_text  # noqa: E402

OUT = ROOT / "assets" / "knowledge" / "set_sizes.json"
# A model of fewer parts is a figure, a tree or a sign, not a thing to size.
LEAST = 25
STUD = 20.0
PLATE = 8.0


def _files(text: str) -> tuple[list[str], dict[str, list[SubfileRef]], dict[str, str]]:
    order: list[str] = []
    files: dict[str, list[SubfileRef]] = {}
    titles: dict[str, str] = {}
    current: str | None = None
    for raw in text.splitlines():
        bits = raw.split()
        if not bits:
            continue
        if bits[0] == "0":
            word = bits[1].upper() if len(bits) > 1 else ""
            if word == "FILE":
                current = normalise_filename(" ".join(bits[2:]))
                order.append(current)
                files.setdefault(current, [])
            elif word == "NOFILE":
                current = None
            elif current is None and not order:
                current = "<main>"
                order.append(current)
                files[current] = []
            if current is not None and current not in titles and word not in ("FILE", "NOFILE"):
                titles[current] = " ".join(bits[1:])
            continue
        if bits[0] != "1":
            continue
        if current is None:
            if order:
                continue
            current = "<main>"
            order.append(current)
            files[current] = []
        try:
            command = parse_line(raw)
        except ValueError:
            continue
        if isinstance(command, SubfileRef):
            files[current].append(command)
    return order, files, titles


def _placed(name: str, files: dict, where: Matrix, depth: int = 0) -> list[tuple[str, Matrix]]:
    out: list[tuple[str, Matrix]] = []
    for ref in files.get(name, []):
        here = where @ ref.matrix
        if ref.filename in files and depth < 16:
            out.extend(_placed(ref.filename, files, here, depth + 1))
        else:
            out.append((style._part_id(ref.filename), here))
    return out


def _figure_part(info: style.PartInfo | None) -> bool:
    return info is not None and (info.name.startswith("Minifig") or info.category.startswith("Minifig"))


def _size(placed: list[tuple[str, Matrix]], parts: style.Parts) -> tuple[list[float], int] | None:
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    counted = 0
    for part, m in placed:
        info = parts.get(part)
        if info is None or info.box is None or _figure_part(info):
            continue
        a, b = info.box
        local = [(a[k] + b[k]) / 2 for k in range(3)]
        half = [(b[k] - a[k]) / 2 for k in range(3)]
        rows = ((m.a, m.b, m.c, m.x), (m.d, m.e, m.f, m.y), (m.g, m.h, m.i, m.z))
        for k, r in enumerate(rows):
            centre = r[0] * local[0] + r[1] * local[1] + r[2] * local[2] + r[3]
            reach = abs(r[0]) * half[0] + abs(r[1]) * half[1] + abs(r[2]) * half[2]
            low[k] = min(low[k], centre - reach)
            high[k] = max(high[k], centre + reach)
        counted += 1
    if counted < LEAST:
        return None
    across = sorted([(high[0] - low[0]) / STUD, (high[2] - low[2]) / STUD], reverse=True)
    return [round(across[0], 1), round(across[1], 1), round((high[1] - low[1]) / PLATE, 1)], counted


def main() -> None:
    ask = argparse.ArgumentParser(description="How big real minifigure-scale models are.")
    ask.add_argument("--generated", type=Path, default=ROOT / "assets" / "generated",
                     help="the catalogue.json to read parts' sizes from")
    ask.add_argument("--out", type=Path, default=OUT)
    args = ask.parse_args()
    parts = style.Parts(args.generated / "catalogue.json")
    index = {r["number"]: r for r in json.loads((style.OMR / "index.json").read_text())}
    rows = []
    for path in sorted((style.OMR / "files").glob("*")):
        number = style._number(path)
        row = index.get(number)
        if row is None:
            continue
        order, files, titles = _files(read_text(path))
        if not order:
            continue
        everything = _placed(order[0], files, Matrix.identity())
        if not any(_figure_part(parts.get(p)) and p.startswith("3626") for p, _ in everything):
            continue        # no minifigure: not minifigure scale
        # Each sub-model the set's file places directly is one of its
        # models; the parts it places loose are another.
        models: list[tuple[str, list]] = []
        loose: list[tuple[str, Matrix]] = []
        for ref in files.get(order[0], []):
            if ref.filename in files:
                models.append((titles.get(ref.filename, ref.filename),
                               _placed(ref.filename, files, ref.matrix)))
            else:
                loose.append((style._part_id(ref.filename), ref.matrix))
        if loose:
            models.append((titles.get(order[0], row["name"]), loose))
        whole = _size(everything, parts)
        for title, placed in models:
            measured = _size(placed, parts)
            if measured is None:
                continue
            size, counted = measured
            rows.append([number, row["name"], row["theme"], title, counted] + size)
        if whole is not None and len(models) != 1:
            rows.append([number, row["name"], row["theme"], "", whole[1]] + whole[0])
    args.out.write_text(json.dumps({
        "format": 1,
        "about": "Minifigure-scale models of LDraw's Official Model Repository, each "
                 "sub-model on its own and, with \"\" for its model, the whole set: "
                 "[set, set name, theme, model, parts, studs long, studs wide, plates "
                 "tall] (tools/set_sizes.py).",
        "models": rows,
    }, separators=(",", ":")) + "\n")
    print(f"{len(rows)} models of {len({r[0] for r in rows})} sets -> {args.out}")


if __name__ == "__main__":
    main()
