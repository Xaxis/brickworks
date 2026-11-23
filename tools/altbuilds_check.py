#!/usr/bin/env python3
"""Whether each model the count calls an alternate build really is one, from the files.

    python3 tools/altbuilds_check.py PRECISION.json [--out=REPORT.txt]

PRECISION.json is tools/web/altbuilds_probe.mjs's: (model file, the set or
sets it is called an alternate build of) pairs. Each is checked here with a
reader of its own, not the count's: the model's LDraw file read line by line
(its sub-models placed through, colour 16 the colour it is placed in), each
part spelled as the app spells it (tools/collection_data.py _Owning:
PartLibrary.resolve, plain_code, Collection.ownable; a mould's letter off,
Collection.family_of), and the sets' own lots read from their shards. A pair
holds when, for every part and colour the model needs, the set or sets hold
at least as many: one copy of each, no spares. Exits 1 when any does not,
naming the part.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from collection_data import _Owning, family_of, shard_of  # noqa: E402

OMR = ROOT / "vendor" / "omr" / "files"
SETS = ROOT / "assets" / "generated" / "sets"


def blocks(text: str) -> tuple[str, dict[str, list[str]], set[str]]:
    """An LDraw file's blocks: (the first, its name -> its lines, the names that are parts)."""
    files: dict[str, list[str]] = {}
    parts: set[str] = set()
    first = ""
    name = ""
    for raw in text.replace("﻿", "").splitlines():
        line = raw.strip()
        words = line.split()
        if len(words) >= 3 and words[0] == "0" and words[1].upper() == "FILE":
            name = line.split(None, 2)[2].strip().lower()
            if name not in files:
                files[name] = []
                first = first or name
            continue
        if len(words) >= 2 and words[0] == "0" and words[1].upper() == "!LDRAW_ORG" and len(words) >= 3 \
                and any(kind in words[2].lower() for kind in ("part", "shortcut", "primitive", "subpart")):
            parts.add(name)
        if name not in files:
            files[name] = []
            first = first or name
        files[name].append(line)
    for named in files:
        if named.endswith(".dat"):
            parts.add(named)
    return first, files, parts


def needs(text: str, owning: _Owning) -> dict[str, int]:
    """What the model needs: part and colour -> pieces, as the app would own them."""
    first, files, parts = blocks(text)
    out: dict[str, int] = {}

    def place(name: str, colour: str, depth: int = 0) -> None:
        for line in files.get(name, []):
            words = line.split()
            if len(words) < 15 or words[0] != "1":
                continue
            ref = " ".join(line.split(None, 14)[14:]).strip().lower().replace("\\", "/")
            given = colour if words[1] == "16" else words[1]
            if ref in files and ref not in parts and depth < 32:
                place(ref, given, depth + 1)
                continue
            if not given.lstrip("-").isdigit():
                continue
            key = owning.key(ref.removesuffix(".dat").split("/")[-1], int(given))
            if key is None:
                continue
            part, colour_code = key.split("/")
            key = f"{family_of(part)}/{colour_code}"
            out[key] = out.get(key, 0) + 1

    place(first, "16")
    return out


def held(number: str, owning: _Owning) -> dict[str, int]:
    """One copy of a set, no spares, by the same spelling."""
    shard = json.loads((SETS / f"{shard_of(number):03d}.json").read_text())
    record = shard["sets"].get(number.lower())
    out: dict[str, int] = {}
    for part, colour, qty in (record or {}).get("p", []):
        key = owning.key(str(part).lower(), int(colour))
        if key is None:
            continue
        name, code = key.split("/")
        key = f"{family_of(name)}/{code}"
        out[key] = out.get(key, 0) + int(qty)
    return out


def main(argv: list[str]) -> int:
    given = [a for a in argv[1:] if not a.startswith("--")]
    if not given:
        print(__doc__)
        return 2
    report = next((a[6:] for a in argv[1:] if a.startswith("--out=")), "")
    catalogue = json.loads((ROOT / "assets" / "generated" / "catalogue.json").read_text())
    colours = json.loads((ROOT / "assets" / "generated" / "colors.json").read_text())
    owning = _Owning(catalogue["parts"], colours)
    pairs = json.loads(Path(given[0]).read_text())["pairs"]
    lines = []
    wrong = 0
    for pair in pairs:
        need = needs((OMR / pair["file"]).read_text(encoding="utf-8", errors="replace"), owning)
        sets = [held(number, owning) for number in pair["sets"]]
        short = []
        for key, n in sorted(need.items()):
            have = sum(one.get(key, 0) for one in sets)
            if have < n:
                short.append(f"{key} needs {n}, the sets hold {have}")
        pieces = sum(need.values())
        verdict = "holds" if not short else "WRONG"
        wrong += bool(short)
        lines.append(f"{verdict}  {pair['file']} from {' + '.join(pair['sets'])} ({pair['how']}): {pieces} pieces, "
                     f"{len(need)} parts and colours{'; ' + '; '.join(short[:5]) if short else ''}")
    lines.insert(0, f"{len(pairs) - wrong} of {len(pairs)} pairs called alternate builds hold every part, "
                    "read from the files with a reader of this script's own")
    text = "\n".join(lines) + "\n"
    print(text, end="")
    if report:
        Path(report).write_text(text)
    return 1 if wrong else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
