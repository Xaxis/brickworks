#!/usr/bin/env python3
"""Every real set's other moving things, moved both ways and back (G11, docs/MECHANISMS.md §19).

    tools/move_sweep.py list                   the OMR sets with a turntable, a door or ramp, or a crane
    tools/move_sweep.py run LABEL [--jobs=N] [--only=SET,...] [--timeout=S]
                                               move each one, write the table
    tools/move_sweep.py table LABEL [--against=LABEL]

A set is tried when its file has a turntable (a part named Turntable), a
door, ramp, hatch, gate, tailgate, flap or lid, or its name says crane,
excavator or boom. What moves is read when the set is opened
(src/dev/grab_probe.gd -- --only=movesweep), from its joints, up to one of
each kind:

  turntable   the top of a turntable, carried round on it;
  door        a part named door, ramp, hatch, gate, tailgate, flap or lid,
              on a hinge, a click hinge or a pin;
  boom        the biggest body on a hinge, a click hinge, a pin or an axle
              that is not one of those, of 6 parts or more (a crane's boom,
              a digger's arm).

Each is moved over MCP as a session moves one (move_part at a part of it),
+30 and -60 degrees, then back by as far as the two turned (a turn stopped
by the model says how far it went). A thing moves both ways and back when
each turn moves it, what stays never moves, and the last turn puts the
thing's own parts back within 0.02 LDU (what hangs from it may have swung
down under its weight on the way). When a turn moves nothing, the row keeps what the
app said: the refusal names what holds it. Rows go to
bench/results/grab11-2026-10-18/movesweep_LABEL.jsonl and the table to
movesweep_LABEL.md.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter

import steer_sweep as steer

TURNTABLE = re.compile(r"Turntable")
DOOR = re.compile(r"\b(Door|Ramp|Hatch|Gate|Tailgate|Flap|Lid)\b")
CRANE = re.compile(r"crane|excavator|boom", re.IGNORECASE)


def candidates() -> list[str]:
    names = steer._names()
    out: list[str] = []
    for path in sorted(steer.OMR.iterdir()):
        if path.suffix.lower() not in (".mpd", ".ldr"):
            continue
        named = [names.get(p, "") for p in steer._parts_in(path)]
        named = [n for n in named if not n.startswith("~")]
        if any(TURNTABLE.search(n) for n in named) or any(DOOR.search(n) and "Frame" not in n for n in named) \
                or CRANE.search(path.stem):
            out.append(path.name)
    return out


def _rows(label: str) -> list[dict]:
    rows: dict[str, dict] = {}
    path = steer.OUT / f"movesweep_{label}.jsonl"
    if not path.exists():
        return []
    for line in path.read_text().splitlines():
        if line.strip():
            row = json.loads(line)
            if not row.get("begin"):
                rows[row["set"]] = row
    return [rows[k] for k in sorted(rows)]


def cause_of(thing: dict) -> str:
    """Why a thing did not move both ways and back, short enough to group by."""
    if thing.get("result") == "moves":
        return "moves both ways and back"
    said = str(thing.get("cause", ""))
    rules = [
        (r"what stays moved", "what stays moved"),
        (r"back to", "moves, not back where it stood"),
        (r"gears lock", "its gears lock"),
        (r"has no freedom", "its loop has no freedom"),
        (r"too many to solve", "its loops are too big to solve"),
        (r"Held by a worm|Held by its linear actuator", "held by a worm or a screw"),
        (r"will not move|held rigidly|is part of what stays", "held rigidly"),
        (r"through the floor at once", "it would go through the floor at once"),
        (r"in the way at once| meets .* at once", "something is in the way at once"),
        (r"stopped where it meets the model", "moves one way only (it meets the model)"),
        (r"did not move|moved nothing", "it did not move"),
    ]
    for pattern, short in rules:
        if re.search(pattern, said):
            return short
    return "other: " + said[:60]


def table(label: str, against: str = "") -> str:
    rows = _rows(label)
    before: dict[tuple, dict] = {}
    if against:
        for row in _rows(against):
            for thing in row.get("things", []):
                before[(row["set"], thing.get("kind"))] = thing
    things = [(row, thing) for row in rows for thing in row.get("things", [])]
    lines = [f"# Moving things sweep: {label}", ""]
    by_kind = Counter(t.get("kind") for _, t in things)
    moves = Counter(t.get("kind") for _, t in things if t.get("result") == "moves")
    either = Counter(t.get("kind") for _, t in things if t.get("moved_once"))
    lines.append(f"{len(rows)} sets tried, {sum(1 for r in rows if r.get('things'))} with something that moves on a"
                 f" joint; {len(things)} things moved.")
    lines.append("")
    lines.append("| kind | things | move at all | both ways and back |")
    lines.append("|---|---|---|---|")
    for kind in ("turntable", "door", "boom"):
        lines.append(f"| {kind} | {by_kind.get(kind, 0)} | {either.get(kind, 0)} | {moves.get(kind, 0)} |")
    if before:
        was = sum(1 for t in before.values() if t.get("result") == "moves")
        lines.append("")
        lines.append(f"Against {against}: {was} moved both ways and back then.")
    lines.append("")
    causes = Counter(cause_of(t) for _, t in things if t.get("result") != "moves")
    lines.append("| cause | things |")
    lines.append("|---|---|")
    for cause, count in causes.most_common():
        lines.append(f"| {cause} | {count} |")
    lines.append("")
    lines.append("| set | kind | moved at | joint | +30 | −30 | back, LDU | result |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for row, thing in things:
        steps = thing.get("steps", [])

        def went(step: dict) -> str:
            return f"{step.get('now', 0.0):+.0f}°" if step.get("moved") else "no"

        one = went(steps[0]) if len(steps) > 0 else ""
        other = went(steps[1]) if len(steps) > 1 else ""
        back = f"{thing['back_ldu']:.3f}" if "back_ldu" in thing else ""
        result = "moves" if thing.get("result") == "moves" else cause_of(thing)
        was = before.get((row["set"], thing.get("kind")))
        if was is not None and (was.get("result") == "moves") != (thing.get("result") == "moves"):
            result += " (was " + ("moves" if was.get("result") == "moves" else cause_of(was)) + ")"
        detail = "" if thing.get("result") == "moves" else " — " + str(thing.get("cause", ""))[:160].replace("|", "/")
        lines.append(f"| {row['set']} | {thing.get('kind')} | {thing.get('driver', '')} | {thing.get('joint', '')} |"
                     f" {one} | {other} | {back} | {result}{detail} |")
    quiet = [r for r in rows if not r.get("things")]
    if quiet:
        lines.append("")
        lines.append("Nothing on a joint to move: " + ", ".join(
            f"{r['set']} ({r.get('cause', '')})" if r.get("cause") else r["set"] for r in quiet) + ".")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("list", "run", "table"):
        print(__doc__)
        return 2
    flags = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else "") for a in argv[1:] if a.startswith("--")}
    words = [a for a in argv[1:] if not a.startswith("--")]
    if argv[0] == "list":
        for name in candidates():
            print(name)
        return 0
    if not words:
        print("a LABEL is needed")
        return 2
    if argv[0] == "table":
        print(table(words[0], flags.get("--against", "")))
        return 0
    only = [s if s.endswith((".mpd", ".ldr")) else s + ".mpd" for s in flags.get("--only", "").split(",") if s]
    steer.run(words[0], int(flags.get("--jobs", "4")), only, float(flags.get("--timeout", "300")),
              what="movesweep", sets=candidates(), table_of=table)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
