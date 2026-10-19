#!/usr/bin/env python3
"""Every real set's steering, turned both ways and back (G9, docs/MECHANISMS.md §18).

    tools/steer_sweep.py list                  the OMR sets with a steering
    tools/steer_sweep.py run LABEL [--jobs=N] [--only=SET,...] [--timeout=S] [--shots]
                                               turn each one, write the table; --shots runs
                                               windowed on the GPU lease and takes pictures
    tools/steer_sweep.py table LABEL [--against=LABEL]
                                               the table again, or two set side by side

A set has a steering when its file has a steering arm (a part named Steering
Arm, Steering Wheel Bearing, Wheel Spindle Steering Arm or Steering Wheel Hub)
or a steering rack (any Technic gear rack but the plain
1 x 4, which a lift or a slide uses as often), or a 1 x 4 rack and a gear that
may stand in it: whether one does is read when the set is opened, and a set
with none is said to have no steering and is not counted.

`run` opens each set in the app, headless (src/dev/grab_probe.gd -- --only=sweep),
and turns its steering over MCP as a session would: the steering wheel where
turning it reaches the rack, else the pinion's column, else a steering arm on
its kingpin; +30, -60 and +30 degrees from where it stands. A set steers when
each turn moves it, the rack (or the far arm) goes one way and then the other,
what stays never moves, and the last turn puts every part back within 0.02
LDU. Each job runs under ~/.claude/claude-core/bin/heavy, with a data folder
of its own (.scratch-data, never the owner's app data); a set that takes
longer than --timeout seconds (300) is stopped and said so, and its job goes on
from the next. Rows go to bench/results/grab12-2026-10-18/sweep_LABEL.jsonl and
the table to sweep_LABEL.md (Grab 9's are in grab9-2026-10-18, Grab 11's in
grab11-2026-10-18).
"""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OMR = ROOT / "vendor" / "omr" / "files"
PARTS = ROOT / "vendor" / "ldraw" / "parts"
TABLE = ROOT / "assets" / "ldraw" / "gears.json"
OUT = Path("/mnt/Projects/brickworks/bench/results/grab12-2026-10-18")
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
GPU = Path.home() / ".claude" / "claude-core" / "bin" / "gpu"

ARM = re.compile(r"Steering Arm|Steering Wheel Bearing|Wheel Spindle Steering|Steering Wheel Hub")
RACK = re.compile(r"Gear Rack|Steering Rack")


def _names() -> dict[str, str]:
    out: dict[str, str] = {}
    for path in PARTS.glob("*.dat"):
        with path.open(errors="replace") as handle:
            first = handle.readline().strip()
        out[path.stem.lower()] = first[2:] if first.startswith("0 ") else first
    return out


def _parts_in(path: Path) -> Counter:
    parts: Counter = Counter()
    with path.open(errors="replace") as handle:
        for line in handle:
            bits = line.split()
            if len(bits) >= 15 and bits[0] == "1":
                ref = " ".join(bits[14:]).lower().replace("\\", "/")
                if ref.endswith(".dat"):
                    parts[ref[:-4].split("/")[-1]] += 1
    return parts


def candidates() -> list[str]:
    """The OMR files with a steering arm, a steering rack, or a 1 x 4 rack and a gear."""
    names = _names()
    gears = set(json.loads(TABLE.read_text())["gears"])
    out: list[str] = []
    for path in sorted(OMR.iterdir()):
        if path.suffix.lower() not in (".mpd", ".ldr"):
            continue
        parts = _parts_in(path)
        named = {p: names.get(p, "") for p in parts}
        arm = any(ARM.search(n) and not n.startswith("~") for n in named.values())
        racks = [p for p, n in named.items() if RACK.search(n) and not n.startswith("~")]
        steering_rack = any(p != "3743" for p in racks)
        pinion_rack = "3743" in racks and any(p in gears for p in parts)
        if arm or steering_rack or pinion_rack:
            out.append(path.name)
    return out


def _rows(label: str) -> list[dict]:
    rows: dict[str, dict] = {}
    path = OUT / f"sweep_{label}.jsonl"
    if not path.exists():
        return []
    for line in path.read_text().splitlines():
        if line.strip():
            row = json.loads(line)
            if not row.get("begin"):
                rows[row["set"]] = row
    return [rows[k] for k in sorted(rows)]


def cause_of(row: dict) -> str:
    """A failure's cause, short enough to group sets by."""
    if row.get("steers"):
        return "steers"
    said = str(row.get("cause", ""))
    rules = [
        (r"timed out", "took longer than the sweep allows"),
        (r"not in the gear table", "its rack is not in the gear table"),
        (r"no pinion stands in its rack", "no pinion read in its rack"),
        (r"no rack and no steering arm", "no rack and no steering arm"),
        (r"what stays moved", "what stays moved"),
        (r"gears lock", "its gears lock"),
        (r"has no freedom", "its loop has no freedom"),
        (r"closes no further", "its loop closes no further"),
        (r"will not move|held rigidly", "held rigidly"),
        (r"on a ball in a closed loop", "its arm hangs on a ball in a loop"),
        (r"too many to solve", "its loops are too big to solve"),
        (r"Held by a worm|Held by its linear actuator", "held by a worm or a screw"),
        (r"did not go", "the rack (or far arm) did not move"),
        (r"back to", "not back where it stood"),
        (r"already there", "the pinion turned, its rack did not (one body with what it turns in)"),
        (r"through the floor at once", "it would go through the floor at once"),
        (r"in the way at once| meets .* at once", "something is in the way at once"),
        (r"did not move", "it did not move"),
    ]
    for pattern, short in rules:
        if re.search(pattern, said):
            return short
    return "other: " + said[:60]


def table(label: str, against: str = "") -> str:
    rows = _rows(label)
    before = {r["set"]: r for r in _rows(against)} if against else {}
    steering = [r for r in rows if r.get("kind") or cause_of(r) == "its rack is not in the gear table"
                or r.get("arms", 0)]
    steers = [r for r in steering if r.get("steers")]
    lines = [f"# Steering sweep: {label}", ""]
    lines.append(f"{len(steers)} of {len(steering)} sets with a steering steer both ways and back"
                 f" ({len(rows)} sets tried; {len(rows) - len(steering)} have a 1 x 4 rack no pinion stands in"
                 f" and no steering arm, and are not counted).")
    turning = [r for r in steers if r.get("arms", 0) and r.get("kind") != "arm"
               and any("arms_deg" in s for s in r.get("steps", []))]
    if turning:
        follow = [r for r in turning if all(s.get("arms_deg", 0.0) > 1.0 for s in r["steps"][:2])]
        lines.append(f"Of the {len(turning)} that steer at a pinion and have steering arms, the arms turn with"
                     f" the rack in {len(follow)}"
                     + (f" (not in {', '.join(r['set'] for r in turning if r not in follow)})."
                        if len(follow) < len(turning) else "."))
    if before:
        was = [r for r in before.values() if r.get("steers")]
        lines.append(f"Against {against}: {len(was)} steered then.")
    lines.append("")
    causes = Counter(cause_of(r) for r in steering if not r.get("steers"))
    lines.append("| cause | sets |")
    lines.append("|---|---|")
    for cause, count in causes.most_common():
        lines.append(f"| {cause} | {count} |")
    lines.append("")
    head = "| set | parts | turned at | +30 | −30 | back, LDU | what stays | result |"
    lines.append(head)
    lines.append("|---|---|---|---|---|---|---|---|")
    for row in steering + [r for r in rows if r not in steering]:
        steps = row.get("steps", [])

        def went(step: dict) -> str:
            if not step.get("moved"):
                return "no"
            if "rack_ldu" in step:
                return f"{step['rack_ldu']:+.2f}"
            if "follower_deg" in step:
                return f"{step['follower_deg']:.1f}°"
            return "yes"

        one = went(steps[0]) if len(steps) > 0 else ""
        other = went(steps[1]) if len(steps) > 1 else ""
        back = f"{row['back_ldu']:.3f}" if "back_ldu" in row else ""
        result = "steers" if row.get("steers") else cause_of(row)
        if before and row["set"] in before:
            was_ok = before[row["set"]].get("steers")
            if was_ok != row.get("steers"):
                result += " (was " + ("steers" if was_ok else cause_of(before[row["set"]])) + ")"
        detail = "" if row.get("steers") else " — " + str(row.get("cause", ""))[:160].replace("|", "/")
        stays = str(row.get("stays", ""))[:60].replace("|", "/")
        at = f"{row.get('kind', '')} {row.get('driver', '')}".strip()
        lines.append(f"| {row['set']} | {row.get('parts', '')} | {at} | {one} | {other} | {back} | {stays} |"
                     f" {result}{detail} |")
    return "\n".join(lines) + "\n"


def _run_job(sets: list[str], label: str, job: int, timeout: float, shots: bool = False,
             what: str = "sweep") -> None:
    rows_path = OUT / f"{what}_{label}_{job}.jsonl"
    log = (OUT / f"{what}_{label}_{job}.log").open("a")
    left = list(sets)
    while left:
        listing = OUT / f"{what}_{label}_{job}.list"
        listing.write_text("".join(f"vendor/omr/files/{s}\n" for s in left))
        done_before = len(rows_path.read_text().splitlines()) if rows_path.exists() else 0
        # Windowed on the GPU lease for pictures; else headless under heavy.
        command = ([str(GPU), "env", "MESA_VK_WSI_DEBUG=sw", "xvfb-run", "-a", "godot", "--path", str(ROOT),
                    "--resolution", "1400x900"] if shots else [str(HEAVY), "godot", "--headless", "--path", str(ROOT)])
        process = subprocess.Popen(
            command + ["--script", "src/dev/grab_probe.gd", "--", f"--only={what}", f"--list={listing}",
                       f"--sweep-out={rows_path}"] + (["--sweep-shots"] if shots else []),
            cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
            # A data folder of its own: user:// is otherwise the owner's app
            # data, and opening a real set saves the parts it carries there.
            env=dict(os.environ, XDG_DATA_HOME=str(ROOT / ".scratch-data")))
        began_at = 0.0
        began = ""
        while process.poll() is None:
            time.sleep(2)
            lines = rows_path.read_text().splitlines()[done_before:] if rows_path.exists() else []
            if lines:
                last = json.loads(lines[-1])
                if last.get("begin") and last["set"] != began:
                    began = last["set"]
                    began_at = time.time()
                elif not last.get("begin"):
                    began = ""
            if began and time.time() - began_at > timeout:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait()
                with rows_path.open("a") as handle:
                    handle.write(json.dumps({"set": began, "steers": False,
                                             "cause": f"timed out after {int(timeout)} s"}) + "\n")
                break
        finished = {json.loads(line)["set"] for line in rows_path.read_text().splitlines()
                    if line.strip() and not json.loads(line).get("begin")} if rows_path.exists() else set()
        rest = [s for s in left if Path(s).stem not in finished]
        if len(rest) == len(left):
            # Nothing finished: it failed before the first set. Say so and stop.
            with rows_path.open("a") as handle:
                for s in rest:
                    handle.write(json.dumps({"set": Path(s).stem, "steers": False,
                                             "cause": "the probe stopped before it"}) + "\n")
            break
        left = rest
    log.close()


def run(label: str, jobs: int, only: list[str], timeout: float, shots: bool = False,
        what: str = "sweep", sets: list[str] | None = None, table_of=None) -> None:
    import threading

    OUT.mkdir(parents=True, exist_ok=True)
    sets = only or (sets if sets is not None else candidates())
    table_of = table_of or table
    for old in OUT.glob(f"{what}_{label}_*"):
        old.unlink()
    sizes = {s: (OMR / s).stat().st_size for s in sets}
    shards: list[list[str]] = [[] for _ in range(jobs)]
    load = [0] * jobs
    for s in sorted(sets, key=lambda name: -sizes[name]):
        n = load.index(min(load))
        shards[n].append(s)
        load[n] += sizes[s]
    threads = [threading.Thread(target=_run_job, args=(shard, label, n, timeout, shots, what))
               for n, shard in enumerate(shards) if shard]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    merged = OUT / f"{what}_{label}.jsonl"
    with merged.open("w") as out:
        for n in range(jobs):
            part = OUT / f"{what}_{label}_{n}.jsonl"
            if part.exists():
                for line in part.read_text().splitlines():
                    if line.strip() and not json.loads(line).get("begin"):
                        out.write(line + "\n")
    (OUT / f"{what}_{label}.md").write_text(table_of(label))
    print((OUT / f"{what}_{label}.md").read_text().split("\n\n")[1])


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
    run(words[0], int(flags.get("--jobs", "4")), only, float(flags.get("--timeout", "300")), "--shots" in flags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
