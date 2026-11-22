#!/usr/bin/env python3
"""The sets wires is measured on (docs/APP_UX11.md, wires): KINEFUNCS' sets with motors and a
battery box, an IR receiver or a hub, each as its OMR file wires it, and each function KINEFUNCS
reads of them with what Simulate made of it there.

    tools/wires_sets.py OUT.json [SET ...]

Writes the listing src/dev/wires_probe.gd reads with --sets=: {"sets": [{set, file, functions:
[the row of kinefuncs' jobs.json, with "kinefuncs": Simulate's result in KINEFUNCS (r8g)]}]}. The
probe keeps the functions whose control turns with a motor's output.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

MAIN = Path("/mnt/Projects/brickworks")
JOBS = MAIN / "bench" / "results" / "kinefuncs-2026-11-09" / "jobs.json"
ROWS = MAIN / "bench" / "results" / "kinefuncs-2026-11-09" / "kinefuncs_r8g.jsonl"
# Each has motors and a battery box (or a receiver, or a hub) and its cables in its file, as LDCad
# drew them from the booklet; the first ten are the measure, the rest beside them.
SETS = ["42042-1", "42043-1", "42052-1", "42054-1", "42065-1", "42070-1", "42082-1", "42095-1",
        "42124-1", "8110-1", "42055-1", "42066-1", "42080-1", "42109-1", "42114-1", "42129-1", "8258-1"]


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    wanted = argv[1:] or SETS
    jobs = json.loads(JOBS.read_text())
    results: dict[tuple[str, int], str] = {}
    if ROWS.exists():
        for line in ROWS.read_text().splitlines():
            row = json.loads(line)
            if "n" in row and "result" in row:
                results[(row["set"], int(row["n"]))] = row["result"]
    out = []
    for model in jobs["sets"]:
        if model["set"] not in wanted:
            continue
        functions = []
        for fn in model["functions"]:
            if not fn.get("control"):
                continue
            fn = dict(fn)
            fn["kinefuncs"] = results.get((model["set"], int(fn["n"])), "")
            functions.append(fn)
        out.append({"set": model["set"], "file": model["file"], "functions": functions})
    out.sort(key=lambda m: wanted.index(m["set"]))
    Path(argv[0]).write_text(json.dumps({"sets": out}, indent=1))
    print(f"{len(out)} sets, {sum(len(m['functions']) for m in out)} functions: {argv[0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
