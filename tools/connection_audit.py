#!/usr/bin/env python3
"""How much of every real set the build check holds, and what it misses.

    tools/connection_audit.py run [--shards 6] [--parallel 2] [--out DIR] [FILE.mpd ...]
    tools/connection_audit.py report [--out DIR] [--write docs/CONNECTIONS.md]

Every set in the LDraw model repository (vendor/omr, tools/omr.py fetch)
holds together in reality. So every part the check calls floating in one
is a gap: a joint the check has no type for, a connector the parts
pipeline never recorded, or a part the reading cannot put where the file
has it. `run` checks every file as src/dev/connection_audit.gd does, in
shards, each a headless Godot under ~/.claude/claude-core/bin/heavy, one
JSON line a file in DIR/shard-K.jsonl. A shard that dies is started again
after the file it died on, which is recorded as crashed. A rerun carries
on where the last stopped; delete DIR to start over.

`report` reads the lines and says the coverage, the share of part
instances the check holds, then ranks the gaps: each cluster of floating
parts is put down to the joint between it and the held parts it touches,
by what the two parts are and which of their connectors meet there.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "connection_audit"
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
PROBE = "src/dev/connection_audit.gd"
SETS = ROOT / "vendor" / "omr" / "files"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
## Restarts of one shard before it is given up on.
RESTARTS = 40
## Seconds a running shard may go without finishing a file before it is
## stopped: the slowest file measured took six minutes.
STALL = 1800


# -- run ----------------------------------------------------------------------

def _rows(path: Path) -> list[dict]:
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def _crashed_on(path: Path) -> str | None:
    """The file a shard began and never finished, if it died on one."""
    begun = None
    for row in _rows(path):
        if row.get("begin"):
            begun = row["file"]
        elif row.get("file") == begun:
            begun = None
    return begun


def _shard_command(shard: int, shards: int, out: Path, files: list[str],
                   project: Path = ROOT) -> list[str]:
    command = [str(HEAVY), "godot", "--headless", "--path", str(project), "--script", PROBE,
               "--", f"--shard={shard}/{shards}", f"--out={out}"]
    return command + files


def run(shards: int, out: Path, files: list[str], parallel: int = 2,
        project: Path = ROOT) -> int:
    if not files and not SETS.is_dir():
        print(f"no {SETS}: tools/omr.py fetch brings the sets")
        return 1
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, XDG_DATA_HOME=str(ROOT / ".scratch-data"))
    named = [f if f.startswith("res://") else "res://" + str(Path(f).resolve().relative_to(ROOT))
             for f in files]
    live: dict[int, subprocess.Popen] = {}
    restarts: Counter = Counter()
    logs = {}

    def start(shard: int) -> None:
        path = out / f"shard-{shard}.jsonl"
        log = open(out / f"shard-{shard}.log", "a")
        logs[shard] = log
        # Named files go to shard 0 alone.
        mine = named if shard == 0 else []
        live[shard] = subprocess.Popen(_shard_command(shard, shards, path, mine, project),
                                       cwd=ROOT,
                                       env=env, stdout=log, stderr=subprocess.STDOUT)

    # The box is shared: at most `parallel` shards at once, the rest waiting
    # their turn here rather than in heavy's queue.
    waiting = list(range(1 if named else shards))
    started = time.time()
    while live or waiting:
        while waiting and len(live) < max(1, parallel):
            start(waiting.pop(0))
        time.sleep(15)
        for shard, process in list(live.items()):
            if process.poll() is None:
                # A file the check never finishes, or a script error that
                # leaves Godot running: stopped, and treated as a crash on
                # the file it was on. Only once it has begun a file, so
                # waiting for a slot is not stalling.
                path = out / f"shard-{shard}.jsonl"
                since = time.time() - (path.stat().st_mtime if path.exists() else started)
                if since > STALL and _crashed_on(path) is not None:
                    # SIGTERM: heavy stops its job on it; SIGKILL left Godot running.
                    process.terminate()
                    process.wait()
                else:
                    continue
            logs[shard].close()
            del live[shard]
            path = out / f"shard-{shard}.jsonl"
            died_on = _crashed_on(path)
            if died_on is None and process.returncode == 0:
                print(f"shard {shard}: done, {len(_finished(path))} files "
                      f"({(time.time() - started) / 60:.0f} min)")
                continue
            restarts[shard] += 1
            if died_on is not None:
                with path.open("a") as rows:
                    rows.write(json.dumps({"file": died_on, "crashed": True}) + "\n")
                print(f"shard {shard}: died on {died_on} (exit {process.returncode}); again")
            if restarts[shard] > RESTARTS:
                print(f"shard {shard}: given up after {RESTARTS} restarts")
                continue
            waiting.insert(0, shard)
    return 0


def _finished(path: Path) -> list[dict]:
    return [r for r in _rows(path) if not r.get("begin")]


# -- report -------------------------------------------------------------------

## What each connection type is, said in the table.
TYPES = [
    "read off its place",
    "clip on bar or handle",
    "bar in a hole or tube",
    "minifig hand grip",
    "minifig part on minifig part",
    "minifig on the model",
    "ball and socket",
    "towball",
    "click hinge",
    "hinge",
    "turntable",
    "Technic pin or axle",
    "Technic, no pin or axle at the contact",
    "hose, string or chain",
    "rubber band",
    "magnet",
    "tyre on wheel",
    "pane or door in its frame",
    "sticker",
    "electric",
    "studs that do not clutch",
    "no connector at the contact",
    "stands a little off the ground in the file",
    "stands on parts the catalogue does not have",
    "touches nothing held",
]
## How far above the ground a cluster that touches nothing held may stand
## and be a model drawn a little off it rather than one hanging from
## something, LDU: a plate. A minifigure's legs drawn 2 LDU under a car's
## tyres stand the car that far up, and a bucket's handle 1.6 under a
## baseplate the whole restaurant on it.
OFF_THE_GROUND = 8.0
## What is done about each kind of gap, said in the table.
STATUS: dict[str, str] = {
    "stands a little off the ground in the file":
        "Within a cell (2 LDU) of the ground a square part now stands on it "
        "(`Assistant._on_the_ground`): opening a file rounds its lift up to a whole cell, and "
        "a wheel's cover stops a cell above its tread. Left: 3 to 8 LDU up, a model drawn "
        "with something under the table (a figure's feet under a car's tyres); allowing that "
        "much would let a design's part hover.",
    "stands on parts the catalogue does not have":
        "Left: the file uses parts the catalogue has not got (unofficial treads, tyres, "
        "panels), and what stood on them has nothing under it. The catalogue's gap, not a "
        "joint's.",
    "touches nothing held":
        "Left: nothing held within a cell of the cluster: parts hung on strings and chains "
        "drawn as paths, held by a missing part, or placed apart in the file.",
    "read off its place":
        "Left: a part turned about two axes at once, which no section of one axis can say, so "
        "the reading puts it at the nearest square turn and its joints miss. Agent angles' "
        "sections at any angle are the fix.",
    "click hinge":
        "Fixed: LDraw's clh* primitives read as a finger and a fork on the line they turn on "
        "(`connectivity._HINGES`), paired by `Joints.rounds`.",
    "clip on bar or handle":
        "Fixed where the clip's eye is up to 1.5 LDU off the bar (`ROUND_OFF_AXIS`, was 1), "
        "as LDraw draws a clip turned to an odd angle. `attachment_points` lists bars and clips "
        "and a part goes on one by axis and joint.",
    "towball":
        "Fixed for a towball in a Joint-8 socket: a whole sphere 16 LDU across reads as a ball "
        "and `Joints.balls` holds it in a socket at its middle at any turn. Left: the older "
        "towball sockets (3491) are drawn from chords and have no socket connector.",
    "ball and socket":
        "Fixed where the ball is turned in its socket (`Joints.balls`). Left: Technic ball "
        "joints whose socket is drawn as plain cylinders.",
    "Technic pin or axle":
        "Fixed in part by agent axles: an axle holds every hole along it (`Joints.through`). "
        "Left: holes drawn without a hole primitive, and pins in parts read off their place.",
    "hose, string or chain":
        "Left: flexible parts (chain links, treads, strings) drawn segment by segment are held "
        "by what they wrap round, which no connector says.",
    "hinge":
        "Left: hinge panels (2440) and plates whose pin is a half cylinder under 2 LDU, and "
        "old finger hinges (4275/4276) drawn without clh primitives.",
    "turntable":
        "Left: Technic chain tread round a turntable (3873 on 18938), which is a chain.",
}
## The kinds that are not a joint: no part on either side to blame.
APART = ("stands a little off the ground in the file",
         "stands on parts the catalogue does not have", "touches nothing held")


class Parts:
    def __init__(self) -> None:
        self.info: dict[str, dict] = {}
        if CATALOGUE.exists():
            for entry in json.loads(CATALOGUE.read_text())["parts"]:
                self.info[entry["id"]] = entry

    def name(self, part: str) -> str:
        return str(self.info.get(part, {}).get("name", ""))

    def category(self, part: str) -> str:
        return str(self.info.get(part, {}).get("category", ""))


def _words(text: str, *words: str) -> bool:
    text = text.lower()
    return any(w in text for w in words)


def joint_type(edge: list, parts: Parts) -> str:
    """The joint a floating part should have had with the held part it
    touches: [floating part, held part, floating's connectors at the
    contact, held's connectors at the contact, floating misread, held
    misread]."""
    mine, theirs, my_kinds, their_kinds, my_misread, their_misread = edge[:6]
    if my_misread or their_misread:
        return "read off its place"
    names = [parts.name(mine), parts.name(theirs)]
    cats = [parts.category(mine), parts.category(theirs)]
    both = " | ".join(names).lower()
    kinds = set(my_kinds) | set(their_kinds)
    figure = [c.startswith("Minifig") for c in cats]
    hand = [_words(n, "minifig hand", "hand ") and figure[i] for i, n in enumerate(names)]
    if any(hand):
        return "minifig hand grip"
    if all(figure):
        return "minifig part on minifig part"
    if any(figure):
        return "minifig on the model"
    if any(c.startswith("Sticker") for c in cats):
        return "sticker"
    if _words(both, "tyre", "tire") and _words(both, "wheel", "rim", "hub"):
        return "tyre on wheel"
    if _words(both, "turntable"):
        return "turntable"
    if _words(both, "hinge") and _words(both, "locking", "finger", "click", "teeth"):
        return "click hinge"
    if _words(both, "hinge"):
        return "hinge"
    if _words(both, "towball", "tow ball"):
        return "towball"
    if kinds & {"ball", "socket"} or _words(both, "ball joint", "socket", " ball"):
        return "ball and socket"
    if _words(both, "hose", "string", "chain", "rope", "cable", "flex", "tube "):
        return "hose, string or chain"
    if _words(both, "rubber band", "belt"):
        return "rubber band"
    if _words(both, "magnet"):
        return "magnet"
    if any(c == "Electric" for c in cats):
        return "electric"
    if kinds & {"pin", "axle", "pin_hole", "axle_hole"}:
        return "Technic pin or axle"
    bar = any(k.startswith("shaft r4") or k.startswith("shaft r3.5") for k in kinds)
    clip = "clip" in kinds or any(k.startswith("bore r4") for k in kinds)
    if (bar and clip) or _words(both, "clip", "handle", "bar ", "bar,", "holder"):
        if _words(both, "clip") or "clip" in kinds:
            return "clip on bar or handle"
        return "bar in a hole or tube"
    if _words(both, "technic"):
        return "Technic, no pin or axle at the contact"
    if _words(both, "glass", "pane", "door", "window", "shutter"):
        return "pane or door in its frame"
    if kinds & {"stud", "tube", "ridge"}:
        return "studs that do not clutch"
    return "no connector at the contact"


def _cluster_type(cluster: dict, parts: Parts, missing: int = 0) -> tuple[str, list]:
    """The joint a cluster of floating parts is put down to, and the edge it
    is put down to: the first, in the order of TYPES, of its edges. One that
    touches nothing held stands a little off the ground, or on parts the
    catalogue does not have (when the file has any), or on nothing."""
    if not cluster.get("edges"):
        lowest = cluster.get("lowest") or []
        if lowest and float(lowest[0][1]) <= OFF_THE_GROUND:
            return "stands a little off the ground in the file", lowest[0][:1] + [""]
        if missing > 0:
            return "stands on parts the catalogue does not have", []
        return "touches nothing held", []
    best = None
    for edge in cluster["edges"]:
        kind = joint_type(edge, parts)
        if best is None or TYPES.index(kind) < TYPES.index(best[0]):
            best = (kind, edge)
    assert best is not None
    return best


def _measure(out: Path, parts: Parts, only: set[str] | None = None) -> dict:
    """What one run's lines say, over [only] those files if given."""
    rows: list[dict] = []
    for path in sorted(out.glob("shard-*.jsonl")):
        rows.extend(r for r in _finished(path))
    # The last line for a file wins: a rerun of one file replaces it.
    by_file: dict[str, dict] = {}
    for row in rows:
        by_file[row["file"]] = row
    rows = [r for f, r in by_file.items() if only is None or f in only]
    m: dict = {"rows": rows}
    m["crashed"] = [r["file"] for r in rows if r.get("crashed")]
    m["empty"] = [r["file"] for r in rows if r.get("error")]
    checked = [r for r in rows if not r.get("crashed") and not r.get("error")]
    m["checked"] = checked
    m["sets"] = {r["file"].split("_")[0].removesuffix(".mpd").removesuffix(".ldr") for r in checked}
    m["instances"] = sum(int(r["parts"]) for r in checked)
    m["floating"] = sum(int(r.get("floating", 0)) for r in checked)
    m["held"] = m["instances"] - m["floating"]
    m["share"] = 100.0 * m["held"] / max(1, m["instances"])
    m["missing"] = sum(int(r.get("missing", 0)) for r in checked)
    m["misread"] = sum(int(r.get("misread", 0)) for r in checked)
    m["misread_floating"] = sum(int(r.get("misread_floating", 0)) for r in checked)
    m["whole"] = sum(1 for r in checked if int(r.get("floating", 0)) == 0)

    by_type: dict[str, list] = defaultdict(lambda: [0, 0, set(), Counter()])
    by_part: dict[str, list] = defaultdict(lambda: [0, 0, set(), Counter()])
    kinds: Counter = Counter()
    part_overlaps: dict[str, list] = defaultdict(lambda: [0, Counter(), set()])
    overlaps = misread_overlaps = 0
    for row in checked:
        for kind, n in (row.get("kinds") or {}).items():
            kinds[kind] += int(n)
        for pair, (n, wrong) in (row.get("overlap_pairs") or {}).items():
            overlaps += int(n)
            misread_overlaps += int(wrong)
            a, b = pair.split("|", 1)
            for one, other in ((a, b), (b, a)) if a != b else ((a, b),):
                part_overlaps[one][0] += int(n) - int(wrong)
                part_overlaps[one][1][other] += int(n) - int(wrong)
                part_overlaps[one][2].add(row["file"])
        for cluster in row.get("clusters", []):
            kind, edge = _cluster_type(cluster, parts, int(row.get("missing", 0)))
            size = int(cluster["size"])
            entry = by_type[kind]
            entry[0] += size
            entry[1] += 1
            entry[2].add(row["file"])
            if edge:
                entry[3][(edge[0], edge[1])] += size
            for part, n in cluster["parts"].items():
                by_part[part][0] += int(n)
                by_part[part][2].add(row["file"])
            # Blocked: the cluster, put down to the part on its side of the
            # joint it is put down to.
            if edge and kind not in APART:
                by_part[edge[0]][1] += size
                by_part[edge[0]][3][kind] += size
    m.update(by_type=by_type, by_part=by_part, kinds=kinds, part_overlaps=part_overlaps,
             overlaps=overlaps, misread_overlaps=misread_overlaps)
    return m


def report(out: Path, write: Path | None, before: Path | None = None) -> int:
    parts = Parts()
    now = _measure(out, parts)
    if not now["rows"]:
        print(f"nothing in {out}: run first")
        return 1
    was = None
    if before is not None:
        # Over the files both runs checked, so the two numbers are of one thing.
        both = {r["file"] for r in now["checked"]} & {
            r["file"] for r in _measure(before, parts)["checked"]}
        was = _measure(before, parts, both)
        now = _measure(out, parts, both)

    lines: list[str] = []
    say = lines.append
    say("# Connections: what the build check holds in real sets")
    say("")
    say("Every set in the LDraw model repository holds together in reality, so every part")
    say("the build check calls floating in one is a gap in the connection data or the")
    say("joint types, and every pair it would refuse as overlapping is a collision cover")
    say("that is not the part. `tools/connection_audit.py run` checks every file as an")
    say("edit is checked for what it leaves hanging (only the ground holds), and `report`")
    say("writes this page. Rerun both after any change to `tools/ldraw/connectivity.py`,")
    say("`tools/ldraw/occupancy.py`, the catalogue or the checker's joints")
    say("(`src/assembly/joints.gd`).")
    say("")
    if was is not None:
        say(f"**Coverage: {now['share']:.2f}% of part instances held, from "
            f"{was['share']:.2f}%** — {now['held']:,} of {now['instances']:,} in "
            f"{len(now['checked']):,} files ({len(now['sets']):,} sets), where "
            f"{was['held']:,} were.")
        say("")
        say(f"- Floating: {now['floating']:,} part instances, from {was['floating']:,}.")
        say(f"- Files whole (nothing floating): {now['whole']:,}, from {was['whole']:,}.")
        say(f"- Overlapping pairs (covers that are not the part): {now['overlaps']:,}, from "
            f"{was['overlaps']:,}.")
    else:
        say(f"**Coverage: {now['share']:.2f}% of part instances held** — {now['held']:,} of "
            f"{now['instances']:,} in {len(now['checked']):,} files ({len(now['sets']):,} sets).")
        say("")
        say(f"- Floating: {now['floating']:,} part instances.")
        say(f"- Files whole (nothing floating): {now['whole']:,} of {len(now['checked']):,}.")
        say(f"- Overlapping pairs (covers that are not the part): {now['overlaps']:,}.")
    say(f"- Read off their place (the reading cannot put the part where the file has it, "
        f"most often a part turned about two axes at once): {now['misread']:,} instances, of "
        f"them {now['misread_floating']:,} floating.")
    say(f"- Not in the catalogue, so not checked: {now['missing']:,} distinct parts summed "
        "over files.")
    if now["crashed"] or now["empty"]:
        say(f"- Not checked: {len(now['crashed'])} files the probe died on"
            + (f" ({', '.join(now['crashed'][:8])})" if now["crashed"] else "")
            + f", {len(now['empty'])} with nothing to place.")
    say("")
    say("Each cluster of floating parts (floating parts touching each other) is put down")
    say("to one joint: of the joints between it and the held parts it touches, the first")
    say("in this table's order, read off what the two parts are and which of their")
    say("connectors meet there. *Instances* is the floating parts so put down.")
    say("")
    say("## By connection type")
    say("")
    if was is not None:
        say("| Connection | Instances | Before | Clusters | Files | Commonest joint (floating "
            "part on held part) | What is done about it |")
        say("|---|---:|---:|---:|---:|---|---|")
    else:
        say("| Connection | Instances | Clusters | Files | Commonest joint (floating part on "
            "held part) | What is done about it |")
        say("|---|---:|---:|---:|---|---|")
    order = sorted(set(now["by_type"]) | set(was["by_type"] if was else []),
                   key=lambda k: -max(now["by_type"][k][0], was["by_type"][k][0] if was else 0))
    for kind in order:
        entry = now["by_type"][kind]
        top = ", ".join(f"{a} on {b} ({n})" for (a, b), n in entry[3].most_common(3))
        status = STATUS.get(kind, "")
        if was is not None:
            say(f"| {kind} | {entry[0]:,} | {was['by_type'][kind][0]:,} | {entry[1]:,} | "
                f"{len(entry[2]):,} | {top} | {status} |")
        else:
            say(f"| {kind} | {entry[0]:,} | {entry[1]:,} | {len(entry[2]):,} | {top} | {status} |")
    say("")
    say("## By part: the gaps that block the most")
    say("")
    say("*Blocks* is the floating instances put down to a joint on this part's side;")
    say("*floating* is how many of this part itself float.")
    say("")
    say("| Part | Name | Blocks | Floating | Files | Joint |")
    say("|---|---|---:|---:|---:|---|")
    by_part = now["by_part"]
    for part in sorted(by_part, key=lambda p: (-by_part[p][1], -by_part[p][0]))[:80]:
        entry = by_part[part]
        joint = ", ".join(f"{k} {n}" for k, n in entry[3].most_common(2))
        say(f"| {part} | {parts.name(part)[:60]} | {entry[1]:,} | {entry[0]:,} | "
            f"{len(entry[2]):,} | {joint} |")
    say("")
    say("## False overlaps: covers that are not the part")
    say("")
    say("A real set's parts do not overlap either, so every pair the check would refuse")
    say("as overlapping is a collision cover wrong (`tools/ldraw/occupancy.py` builds them),")
    say("or the reading's: a part read a little off where the file has it. The check")
    say("excuses overlaps between parts already standing, and keeps them for this count")
    say("(`Assistant._standing_overlaps`).")
    say("")
    say(f"- Overlapping pairs: {now['overlaps']:,}, of them {now['misread_overlaps']:,} with a "
        "part read off its place.")
    say(f"- Files with none: {sum(1 for r in now['checked'] if not r.get('overlaps')):,} of "
        f"{len(now['checked']):,}.")
    say("")
    say("| Part | Name | Pairs | Before | Files | Commonest partner |" if was is not None
        else "| Part | Name | Pairs | Files | Commonest partner |")
    say("|---|---|---:|---:|---:|---|" if was is not None else "|---|---|---:|---:|---|")
    overlaps = now["part_overlaps"]
    for part in sorted(overlaps, key=lambda p: -overlaps[p][0])[:60]:
        entry = overlaps[part]
        if entry[0] <= 0:
            break
        top = ", ".join(f"{o} ({n})" for o, n in entry[1].most_common(3))
        if was is not None:
            say(f"| {part} | {parts.name(part)[:60]} | {entry[0]:,} | "
                f"{was['part_overlaps'][part][0]:,} | {len(entry[2]):,} | {top} |")
        else:
            say(f"| {part} | {parts.name(part)[:60]} | {entry[0]:,} | {len(entry[2]):,} | {top} |")
    say("")
    say("## What the check said, summed over files")
    say("")
    say(", ".join(f"{k} {n:,}" for k, n in now["kinds"].most_common()) or "nothing")
    say("")
    say("## The files with the most floating")
    say("")
    say("| File | Parts | Floating | Misread | Seconds |")
    say("|---|---:|---:|---:|---:|")
    for row in sorted(now["checked"], key=lambda r: -int(r.get("floating", 0)))[:20]:
        say(f"| {row['file']} | {row['parts']:,} | {row.get('floating', 0):,} | "
            f"{row.get('misread', 0):,} | {float(row.get('seconds', 0)):.0f} |")
    text = "\n".join(lines) + "\n"
    if write is not None:
        write.write_text(text)
        print(f"wrote {write}")
    said = (f"coverage {now['share']:.2f}%: {now['held']:,} of {now['instances']:,} held in "
            f"{len(now['checked']):,} files; {now['floating']:,} floating; "
            f"{now['overlaps']:,} overlapping pairs; {len(now['crashed'])} crashed")
    if was is not None:
        said += (f" (before: {was['share']:.2f}%, {was['floating']:,} floating, "
                 f"{was['overlaps']:,} overlapping pairs)")
    print(said)
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("run")
    one.add_argument("--shards", type=int, default=6)
    one.add_argument("--parallel", type=int, default=2,
                     help="shards running at once; the box is shared")
    one.add_argument("--out", type=Path, default=OUT)
    one.add_argument("--project", type=Path, default=ROOT,
                     help="the checkout whose check is run (a snapshot, for a baseline)")
    one.add_argument("files", nargs="*")
    two = sub.add_parser("report")
    two.add_argument("--out", type=Path, default=OUT)
    two.add_argument("--write", type=Path, default=None)
    two.add_argument("--before", type=Path, default=None,
                     help="a baseline run's out, to say each number against")
    args = parser.parse_args(argv)
    if args.command == "run":
        return run(args.shards, args.out, args.files, args.parallel, args.project.resolve())
    return report(args.out, args.write, args.before)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
