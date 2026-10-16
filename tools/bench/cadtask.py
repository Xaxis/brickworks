#!/usr/bin/env python3
"""The CAD task test: is building here as fast and as faithful as in Studio?

    python3 tools/bench/cadtask.py sample                 the files each part uses
    python3 tools/bench/cadtask.py roundtrip [--per-size 8] [--shards 2]
    python3 tools/bench/cadtask.py frames
    python3 tools/bench/cadtask.py build
    python3 tools/bench/cadtask.py report
    python3 tools/bench/cadtask.py all

Each writes into bench/results/cadtask-<date>/ (--out DIR to choose), and
`report` makes REPORT.md there from whatever has been run. The runs go
through ~/.claude/claude-core/bin/heavy, so run the tool bare.

roundtrip   Real sets' files (vendor/omr/files) in hash order across sizes,
            and every .io and .lxf the repository carries, opened, saved
            and opened again in each format the app writes, by
            src/dev/roundtrip_probe.gd. What survives is compared here: every
            part's id, colour, place and turn to the LDU, the sub-models, the
            author's steps, the meta commands.
frames      The frame times a builder feels at 100, 1,000 and 5,000 parts,
            on the desktop (src/dev/cadtask_frames.gd, windowed, under
            xvfb-run) and in a browser (tools/web/cad_frames.mjs, SwiftShader).
build       Three small real sets built from their steps through the UI a
            person has, in a browser (tools/web/cad_task_flow.mjs): the
            actions counted, the result checked part by part, and both apps
            modelled by the keystroke-level model for the same parts.

This box's clocks are this box's: SwiftShader is not a phone or a GPU, and
the machine is shared. The report gives times as measured here; a check in
the suite would compare ratios, never these.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import time
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from steps_score import set_of, survey  # noqa: E402

SETS = ROOT / "vendor" / "omr" / "files"
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
# Results live in the main checkout, git-ignored, whichever worktree ran.
MAIN = Path("/mnt/Projects/brickworks")
RESULTS = (MAIN if MAIN.exists() else ROOT) / "bench" / "results"

SALT = "brickworks cadtask 1"
## Parts in a file, by size: each gets the same share of the sample.
SIZES = [(1, 30), (30, 100), (100, 300), (300, 800), (800, 2501), (2501, 100000)]
PER_SIZE = 8
## The sets built by hand: this many parts, and the author's steps.
BUILD_PARTS = (20, 80)
BUILD_SETS = 3
## Every fixture of a format someone else's program wrote.
FIXTURE_GLOBS = ["tests/**/*.io", "tests/**/*.lxf", "models/**/*.io", "models/**/*.lxf",
                 "src/dev/fixtures/*.io", "src/dev/fixtures/*.lxf"]
## How near is the same place: a written file rounds its numbers.
EXACT = 0.01
TO_THE_LDU = 1.0
TURN = 0.002


def _rank(text: str, salt: str = SALT) -> str:
    return hashlib.sha256((salt + ":" + text).encode()).hexdigest()


# -- the sample -----------------------------------------------------------------

def choose(info: dict[str, tuple[int, int]], per_size: int = PER_SIZE,
           sizes: list[tuple[int, int]] = SIZES, salt: str = SALT) -> list[str]:
    """Per size, the first per_size files in hash order, one file a set.

    [info] is file -> (parts, author's steps). The same files every time for
    the same folder, and a new file joins at its hash's place, so a sample
    grows without reshuffling."""
    taken: list[str] = []
    used: set[str] = set()
    for low, high in sizes:
        pool = sorted((f for f, (parts, _steps) in info.items() if low <= parts < high),
                      key=lambda f: _rank(f, salt))
        mine = 0
        for file in pool:
            if mine >= per_size:
                break
            if set_of(file) in used:
                continue
            taken.append(file)
            used.add(set_of(file))
            mine += 1
    return taken


def choose_builds(info: dict[str, tuple[int, int]], subs: dict[str, int],
                  count: int = BUILD_SETS, parts: tuple[int, int] = BUILD_PARTS,
                  salt: str = SALT + " build") -> list[str]:
    """Small sets to build by hand: between parts[0] and parts[1] parts, the
    author's steps (two STEP lines at least), one model with no sub-models
    (a person builds those apart; that is a later test), in hash order."""
    pool = sorted((f for f, (n, steps) in info.items()
                   if parts[0] <= n <= parts[1] and steps >= 2 and subs.get(f, 0) <= 1),
                  key=lambda f: _rank(f, salt))
    out: list[str] = []
    used: set[str] = set()
    for file in pool:
        if set_of(file) in used:
            continue
        out.append(file)
        used.add(set_of(file))
        if len(out) == count:
            break
    return out


def survey_sets(folder: Path = SETS) -> tuple[dict[str, tuple[int, int]], dict[str, int]]:
    info: dict[str, tuple[int, int]] = {}
    subs: dict[str, int] = {}
    for path in sorted(folder.glob("*")):
        if path.suffix.lower() not in (".mpd", ".ldr"):
            continue
        text = path.read_text(errors="replace")
        info[path.name] = survey(text)
        subs[path.name] = sum(1 for line in text.splitlines()
                              if line.strip().upper().startswith("0 FILE"))
    return info, subs


def fixtures() -> list[Path]:
    found: set[Path] = set()
    for pattern in FIXTURE_GLOBS:
        found.update(p for p in ROOT.glob(pattern) if p.is_file())
    return sorted(found)


# -- comparing ------------------------------------------------------------------

class Part:
    """One placed part, from the probe's "id colour x y z a..i|steps|unit|group"."""

    __slots__ = ("id", "colour", "at", "turn", "steps", "unit", "group")

    def __init__(self, line: str) -> None:
        head, steps, unit, group = (line.split("|") + ["", "", ""])[:4]
        # From the right: a part a file carries may have spaces in its name.
        words = head.split()
        self.id = " ".join(words[:-13]).lower()
        self.colour = int(words[-13])
        numbers = [float(w) for w in words[-12:]]
        self.at = tuple(numbers[:3])
        self.turn = tuple(numbers[3:12])
        self.steps = tuple(int(float(s)) for s in steps.split(".")) if steps else ()
        self.unit = unit
        self.group = group

    def near(self, other: "Part", place: float, shift: float = 0.0) -> bool:
        return (abs(self.at[0] - other.at[0]) <= place
                and abs(self.at[1] - shift - other.at[1]) <= place
                and abs(self.at[2] - other.at[2]) <= place)

    def turned_as(self, other: "Part") -> bool:
        return all(abs(a - b) <= TURN for a, b in zip(self.turn, other.turn))


def _cell(part: Part, shift: float) -> tuple[int, int, int]:
    return (round(part.at[0] / 4), round((part.at[1] - shift) / 4), round(part.at[2] / 4))


def match(before: list[Part], after: list[Part], place: float = TO_THE_LDU,
          shift: float = 0.0) -> tuple[list[tuple[Part, Part]], list[Part], list[Part]]:
    """Pair each part before with one after: the same id and colour, within
    [place] LDU of where it was (less [shift], the lift up the Y axis in
    LDraw's terms), turned the same. Returns the pairs and the leftovers."""
    near: dict[tuple, list[Part]] = defaultdict(list)
    for part in after:
        near[(part.id, part.colour) + _cell(part, 0.0)].append(part)
    pairs: list[tuple[Part, Part]] = []
    lost: list[Part] = []
    for part in before:
        x, y, z = _cell(part, shift)
        found = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for other in near.get((part.id, part.colour, x + dx, y + dy, z + dz), []):
                        if part.near(other, place, shift) and part.turned_as(other):
                            found = other
                            break
                    if found:
                        break
                if found:
                    break
            if found:
                break
        if found is None:
            lost.append(part)
        else:
            near[(found.id, found.colour) + _cell(found, 0.0)].remove(found)
            pairs.append((part, found))
    added = [p for bucket in near.values() for p in bucket]
    return pairs, lost, added


LDRAW_PARTS = [ROOT / "vendor" / "ldraw" / "parts", ROOT / "vendor" / "ldraw" / "unofficial" / "parts"]
_stubs: dict = {}


def moved_to(part_id: str, folders: list[Path] = LDRAW_PARTS):
    """A retired number's stub ("0 ~Moved to 30028b"): the part it became and
    where the stub puts it, (id, turn as LDraw writes it, offset); None when
    [part_id] is not a stub."""
    if part_id in _stubs:
        return _stubs[part_id]
    found = None
    for folder in folders:
        path = folder / f"{part_id}.dat"
        if not path.exists():
            continue
        lines = path.read_text(errors="replace").splitlines()
        refs = [line.split() for line in lines if line.strip().startswith("1 ")]
        if lines and "~moved to" in lines[0].lower() and len(refs) == 1 and len(refs[0]) >= 15:
            words = refs[0]
            numbers = [float(w) for w in words[2:14]]
            found = (" ".join(words[14:]).lower().removesuffix(".dat"), tuple(numbers[3:12]),
                     tuple(numbers[0:3]))
        break
    _stubs[part_id] = found
    return found


def as_moved(part: Part, stub) -> Part:
    """[part] written as the part its stub moved it to: the stub's place and
    turn composed with the part's."""
    new_id, turn, offset = stub
    r = part.turn
    s = turn
    composed = tuple(sum(r[3 * i + k] * s[3 * k + j] for k in range(3))
                     for i in range(3) for j in range(3))
    at = tuple(sum(r[3 * i + k] * offset[k] for k in range(3)) + part.at[i] for i in range(3))
    words = [new_id, str(part.colour)] + [str(v) for v in at + composed]
    return Part(" ".join(words) + "|" + ".".join(str(v) for v in part.steps) + "|"
                + part.unit + "|" + part.group)


def explain(lost: list[Part], added: list[Part], shift: float = 0.0) -> Counter:
    """What happened to each part not found where it was: renumbered (the
    same place and colour, another id), recoloured, turned, moved, or lost
    outright; and what was added."""
    why: Counter = Counter()
    left = list(added)

    def take(test) -> bool:
        for n, other in enumerate(left):
            if test(other):
                del left[n]
                return True
        return False

    for part in lost:
        # A retired number written as the part it became, where its stub
        # puts it (PartLibrary.moved_by): the same shape in the same place.
        stub = moved_to(part.id)
        moved = as_moved(part, stub) if stub else None
        if moved is not None and take(
                lambda o, m=moved: o.id == m.id and o.colour == part.colour
                and m.near(o, TO_THE_LDU, shift) and m.turned_as(o)):
            why["renumbered"] += 1
        # Another number in the same place and colour, turned as its own
        # origin is: a renumbering the stub does not say, or no stub here.
        elif take(lambda o: o.colour == part.colour and o.id != part.id
                  and part.near(o, TO_THE_LDU, shift)):
            why["renumbered"] += 1
        elif take(lambda o: o.id == part.id and part.near(o, TO_THE_LDU, shift)
                  and part.turned_as(o)):
            why["recoloured"] += 1
        elif take(lambda o: o.id == part.id and o.colour == part.colour
                  and part.near(o, TO_THE_LDU, shift)):
            why["turned"] += 1
        elif take(lambda o: o.id == part.id and o.colour == part.colour and part.turned_as(o)):
            why["moved"] += 1
        else:
            why["lost"] += 1
    if left:
        why["added"] += len(left)
    return why


def _ordered_partition(pairs: list[tuple[Part, Part]], side: int, key) -> list[frozenset]:
    groups: dict = defaultdict(set)
    for n, pair in enumerate(pairs):
        groups[key(pair[side])].add(n)
    return [frozenset(groups[k]) for k in sorted(groups)]


def same_steps(pairs: list[tuple[Part, Part]]) -> bool:
    """Whether the paired parts go on in the same steps in the same order:
    the parts grouped by their step path (each sub-model copy's step, then
    the part's own), in order. Empty steps and renumbering do not count."""
    if not pairs:
        return False
    return (_ordered_partition(pairs, 0, lambda p: p.steps)
            == _ordered_partition(pairs, 1, lambda p: p.steps))


def same_submodels(pairs: list[tuple[Part, Part]]) -> bool:
    """Whether the paired parts are in the same sub-model copies, by
    membership, whatever the sub-models are called."""
    if not pairs:
        return False
    first = sorted(_ordered_partition(pairs, 0, lambda p: p.unit), key=sorted)
    second = sorted(_ordered_partition(pairs, 1, lambda p: p.unit), key=sorted)
    return first == second


def compare(before_lines: list[str], after_lines: list[str], shift: float = 0.0,
            steps: bool = True) -> dict:
    """Two readings of one model, compared: exact when every part is paired
    to the LDU with nothing lost or added, and (where the first has its
    author's steps) the steps and the sub-models kept."""
    before = [Part(line) for line in before_lines]
    after = [Part(line) for line in after_lines]
    pairs, lost, added = match(before, after, TO_THE_LDU, shift)
    why = explain(lost, added, shift)
    tight = sum(1 for a, b in pairs if a.near(b, EXACT, shift))
    kept_steps = same_steps(pairs) if steps else None
    kept_subs = same_submodels(pairs)
    parts_exact = not lost and not added and bool(pairs)
    kept = kept_subs and kept_steps is not False
    return {
        "before": len(before), "after": len(after), "paired": len(pairs),
        "within_0_01": tight, "why": dict(why), "parts_exact": parts_exact,
        "steps_kept": kept_steps, "submodels_kept": kept_subs,
        "exact": parts_exact and kept,
        # The same shapes where they were: nothing lost, added, moved,
        # turned or recoloured, only written under the current number.
        "same_shapes": bool(pairs) and kept and set(why) <= {"renumbered"},
    }


def judge_file(row: dict) -> dict:
    """One probe row: for each format written, the round trip from the file
    to the model opened from what was written, strict and up to the lift
    open puts on a model drawn below or above the ground."""
    out: dict = {"file": row["file"], "in": row["in"]}
    if row.get("error"):
        out["error"] = row["error"]
        return out
    truth: dict = row["truth"]
    opened: dict = row["open"]
    lift = float(opened.get("lifted_by", 0.0))
    authored = bool(truth.get("authored"))
    out["parts"] = len(truth["parts"])
    out["authored"] = authored
    out["lift"] = lift
    out["missing"] = opened.get("missing_ids", {})
    out["open_ms"] = opened.get("ms")
    out["save_ms"] = next((w.get("save_ms") for w in row.get("out", {}).values()), None)
    out["open"] = compare(truth["parts"], row["opened"], lift, authored)
    out["formats"] = {}
    for fmt, written in row.get("out", {}).items():
        if written.get("error"):
            out["formats"][fmt] = {"error": written["error"]}
            continue
        strict = compare(truth["parts"], written["reopened"], 0.0, authored)
        lifted = compare(truth["parts"], written["reopened"], lift, authored)
        own = compare(row["opened"], written["reopened"], 0.0, authored)
        before = Counter(truth.get("metas", {}))
        after = Counter(written["file"].get("metas", {}))
        metas_lost = {k: v - after.get(k, 0) for k, v in before.items() if v > after.get(k, 0)}
        out["formats"][fmt] = {
            "strict": strict, "up_to_lift": lifted, "app": own,
            "bytes": written.get("bytes"), "save_ms": written.get("save_ms"),
            "metas_lost": metas_lost,
            "author_kept": written["file"].get("author") == truth.get("author"),
        }
    return out


def summarise(judged: list[dict]) -> dict:
    """Per format: the share of files that round-trip exactly, strictly and
    up to the lift, and the commonest losses, by files and by parts."""
    fine = [j for j in judged if not j.get("error")]
    out: dict = {"files": len(judged), "unreadable": [j["file"] for j in judged if j.get("error")],
                 "formats": {}}
    for fmt in sorted({f for j in fine for f in j["formats"]}):
        rows = [j for j in fine if fmt in j["formats"] and not j["formats"][fmt].get("error")]
        losses_files: Counter = Counter()
        losses_parts: Counter = Counter()
        metas: Counter = Counter()
        for j in rows:
            f = j["formats"][fmt]
            for why, n in f["up_to_lift"]["why"].items():
                losses_files[why] += 1
                losses_parts[why] += n
            if f["up_to_lift"]["submodels_kept"] is False:
                losses_files["sub-models changed"] += 1
            if f["up_to_lift"]["steps_kept"] is False:
                losses_files["author's steps changed"] += 1
            if j["lift"]:
                losses_files["lifted onto the ground"] += 1
            if j["missing"]:
                losses_files["parts the app has not got"] += 1
            if not f["author_kept"]:
                losses_files["author line rewritten"] += 1
            for name in f["metas_lost"]:
                metas[name] += 1
        n = len(rows)
        out["formats"][fmt] = {
            "files": n,
            "exact": sum(1 for j in rows if j["formats"][fmt]["strict"]["exact"]),
            "exact_up_to_lift": sum(1 for j in rows if j["formats"][fmt]["up_to_lift"]["exact"]),
            "same_shapes_up_to_lift": sum(
                1 for j in rows if j["formats"][fmt]["up_to_lift"]["same_shapes"]),
            "parts_exact_up_to_lift": sum(
                1 for j in rows if j["formats"][fmt]["up_to_lift"]["parts_exact"]),
            "app_stable": sum(1 for j in rows if j["formats"][fmt]["app"]["parts_exact"]),
            "authored_files": sum(1 for j in rows if j["authored"]),
            "steps_kept": sum(1 for j in rows if j["authored"]
                              and j["formats"][fmt]["up_to_lift"]["steps_kept"]),
            "parts": sum(j["parts"] for j in rows),
            "parts_paired": sum(j["formats"][fmt]["up_to_lift"]["paired"] for j in rows),
            # Back where they were as the same shape: paired, or renumbered.
            "parts_back": sum(j["formats"][fmt]["up_to_lift"]["paired"]
                              + j["formats"][fmt]["up_to_lift"]["why"].get("renumbered", 0)
                              for j in rows),
            "by_input": {kind: {
                "files": sum(1 for j in rows if j["in"] == kind),
                "exact": sum(1 for j in rows if j["in"] == kind
                             and j["formats"][fmt]["strict"]["exact"]),
                "exact_up_to_lift": sum(1 for j in rows if j["in"] == kind
                                        and j["formats"][fmt]["up_to_lift"]["exact"]),
                "same_shapes_up_to_lift": sum(1 for j in rows if j["in"] == kind
                                              and j["formats"][fmt]["up_to_lift"]["same_shapes"]),
            } for kind in sorted({j["in"] for j in rows})},
            "losses_by_files": losses_files.most_common(),
            "losses_by_parts": losses_parts.most_common(),
            "metas_lost_by_files": metas.most_common(20),
        }
    return out


# -- running --------------------------------------------------------------------

def _godot_env(project: Path) -> dict:
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = str(project / ".scratch-data")
    env.pop("ANTHROPIC_API_KEY", None)
    return env


def run_roundtrip(out: Path, per_size: int = PER_SIZE, shards: int = 2,
                  timeout: int = 3600) -> Path:
    info, _subs = survey_sets()
    files = [SETS / f for f in choose(info, per_size)] + fixtures()
    out.mkdir(parents=True, exist_ok=True)
    (out / "roundtrip_sample.json").write_text(json.dumps(
        {"salt": SALT, "per_size": per_size, "sizes": SIZES,
         "files": [str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p) for p in files],
         "parts": {p.name: info.get(p.name, (None, None))[0] for p in files}}, indent=1))
    rows = out / "roundtrip.jsonl"
    done = {json.loads(line)["file"] for line in rows.read_text().splitlines()} \
        if rows.exists() else set()
    todo = [p for p in files if p.name not in done]
    print(f"roundtrip: {len(files)} files, {len(todo)} to do, in {shards} shards")
    live = []
    for k in range(shards):
        mine = todo[k::shards]
        if not mine:
            continue
        listing = out / f"roundtrip-list-{k}.txt"
        listing.write_text("\n".join(str(p) for p in mine) + "\n")
        log = open(out / f"roundtrip-{k}.log", "a")
        command = ["timeout", str(timeout), str(HEAVY), "godot", "--headless", "--path", str(ROOT),
                   "--script", "src/dev/roundtrip_probe.gd", "--",
                   f"--out={out / f'roundtrip-{k}.jsonl'}", f"--list={listing}"]
        live.append(subprocess.Popen(command, cwd=ROOT, env=_godot_env(ROOT), stdout=log,
                                     stderr=subprocess.STDOUT))
    for process in live:
        process.wait()
    seen = set(done)
    with rows.open("a") as joined:
        for k in range(shards):
            part = out / f"roundtrip-{k}.jsonl"
            if not part.exists():
                continue
            for line in part.read_text().splitlines():
                name = json.loads(line)["file"]
                if name not in seen:
                    joined.write(line + "\n")
                    seen.add(name)
            part.unlink()
    judged = [judge_file(json.loads(line)) for line in rows.read_text().splitlines()]
    summary = summarise(judged)
    summary["missing_from_run"] = sorted(p.name for p in files if p.name not in seen)
    (out / "roundtrip_judged.json").write_text(json.dumps(judged, indent=1))
    (out / "roundtrip_summary.json").write_text(json.dumps(summary, indent=1))
    return out / "roundtrip_summary.json"


# -- frames ---------------------------------------------------------------------

## The model sizes a builder's frames are timed at, and how near a real
## set's file must come to one.
FRAME_SIZES = (100, 1000, 5000)
FRAME_NEAR = 0.1
## The budgets: a frame at 60 a second on the desktop, 30 in a browser.
DESKTOP_BUDGET_MS = 16.7
WEB_BUDGET_MS = 33.0
## The interactions the budget is for, as each runner names them.
INTERACTIONS = ["idle", "orbit", "place", "select_100", "select_all", "delete", "undo", "step"]


def choose_frames(info: dict[str, tuple[int, int]], sizes=FRAME_SIZES,
                  near: float = FRAME_NEAR, salt: str = SALT + " frames") -> list[str]:
    """For each size, the first real set's file in hash order with that many
    parts, give or take [near]; one each, in the order of [sizes]."""
    out = []
    for size in sizes:
        pool = sorted((f for f, (parts, _steps) in info.items()
                       if (1 - near) * size <= parts <= (1 + near) * size),
                      key=lambda f: _rank(f, salt))
        if pool:
            out.append(pool[0])
    return out


def _dotenv(path: Path) -> dict:
    """KEY=VALUE lines, for the browser's sign-in. Never printed."""
    values: dict = {}
    if not path.exists():
        return values
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.removeprefix("export ").strip()
        values[key] = value.strip().strip('"').strip("'")
    return values


def _free_port() -> int:
    import socket
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def run_frames(out: Path, which: str = "both", timeout: int = 3600, only: str = "") -> Path:
    info, _subs = survey_sets()
    models = [SETS / f for f in choose_frames(info)]
    out.mkdir(parents=True, exist_ok=True)
    (out / "frames_sample.json").write_text(json.dumps(
        {f.name: info[f.name][0] for f in models}, indent=1))
    if which in ("both", "desktop"):
        log = open(out / "frames-desktop.log", "a")
        command = ["timeout", str(timeout), str(HEAVY), "xvfb-run", "-a",
                   "--server-args=-screen 0 1600x1000x24", "godot", "--path", str(ROOT),
                   "--resolution", "1400x900", "--script", "src/dev/cadtask_frames.gd", "--",
                   f"--frames-out={out / 'desktop_frames.json'}"] + [str(m) for m in models]
        subprocess.run(command, cwd=ROOT, env=_godot_env(ROOT), stdout=log,
                       stderr=subprocess.STDOUT)
    if which in ("both", "web"):
        _serve_and_run(out, ["tools/web/cad_frames.mjs", f"--out={out}"]
                       + ([f"--only={only}"] if only else []) + [str(m) for m in models],
                       "frames-web.log", timeout)
    return out


def _serve_and_run(out: Path, script: list[str], log_name: str, timeout: int) -> None:
    """The worktree's web export served on a port of its own (serve.py, the
    parts from this checkout's mesh cache), and [script] run against it in
    node under heavy, signed in from .env."""
    port = _free_port()
    server = subprocess.Popen(
        [sys.executable, "tools/web/serve.py", "build/web", str(port), "--parts",
         "assets/generated/parts", "--delay", "0"], cwd=ROOT,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(2)
        env = dict(os.environ)
        env.update(_dotenv(MAIN / ".env" if (MAIN / ".env").exists() else ROOT / ".env"))
        env.pop("ANTHROPIC_API_KEY", None)
        with open(out / log_name, "a") as log:
            subprocess.run(["timeout", str(timeout), str(HEAVY), "node"] + script
                           + [f"--url=http://127.0.0.1:{port}/"],
                           cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    finally:
        server.terminate()
        server.wait(10)


## Parts tried a set, and minutes of building a set: on this box a part
## takes about a minute in software drawing, so a whole set is an hour.
BUILD_MOST = 10
BUILD_MINUTES = 10


def run_build(out: Path, timeout: int = 7200, most: int = BUILD_MOST,
              minutes: int = BUILD_MINUTES, only: str = "") -> Path:
    """The three small sets built by hand in a browser (tools/web/
    cad_task_flow.mjs), one after another, into [out]/build; then both apps'
    keystroke-level models merged in (tools/bench/cadtask_klm.py)."""
    info, subs = survey_sets()
    sets = choose_builds(info, subs)
    if only:
        sets = [f for f in sets if any(f.startswith(k) for k in only.split(","))]
    (out / "build").mkdir(parents=True, exist_ok=True)
    _serve_and_run(out, ["tools/web/cad_task_flow.mjs", f"--out={out / 'build'}",
                         f"--sets={','.join(sets)}", f"--most={most}",
                         f"--minutes={minutes}"], "build.log", timeout)
    if (out / "build" / "build.json").exists():
        subprocess.run([sys.executable, "tools/bench/cadtask_klm.py",
                        str(out / "build" / "build.json"), "--merge"], cwd=ROOT)
    return out / "build"


def frame_table(desktop: dict | None, web: dict | None) -> list[dict]:
    """One row an interaction a model: the median and worst frame on each
    platform, and whether the worst is over its budget."""
    rows = []
    for platform, data, budget in (("desktop", desktop, DESKTOP_BUDGET_MS),
                                   ("web", web, WEB_BUDGET_MS)):
        for model in (data or {}).get("models", []):
            for name in INTERACTIONS:
                got = model.get(name)
                if not got:
                    continue
                # A step that left the timeline where it was is no step: the
                # first browser run pressed Right, which did not move it.
                if name == "step" and got.get("at") is not None \
                        and got.get("at") == model.get("timeline", {}).get("at"):
                    continue
                if not got.get("frames"):
                    # Not one frame finished in the time it was given: the
                    # frame is longer than that, which is a miss.
                    given = got.get("ms") or max((e.get("ms", 0) for e in got.get("each", [])),
                                                 default=0)
                    if given:
                        rows.append({"platform": platform, "file": model["file"], "act": name,
                                     "longer_than_ms": given, "budget_ms": budget,
                                     "p95_over": True, "max_over": True, "median_over": True})
                    continue
                rows.append({"platform": platform, "file": model["file"], "act": name,
                             "median_ms": got["median_ms"], "max_ms": got["max_ms"],
                             "p95_ms": got.get("p95_ms", got["max_ms"]),
                             "budget_ms": budget, "median_over": got["median_ms"] > budget,
                             "p95_over": got.get("p95_ms", got["max_ms"]) > budget,
                             "max_over": got["max_ms"] > budget,
                             "own_max_ms": got.get("own_max_ms")})
            opened = model.get("open", {})
            rows.append({"platform": platform, "file": model["file"], "act": "open",
                         "total_ms": opened.get("to_drawn_ms", opened.get("to_quiet_ms")),
                         "placed": opened.get("placed")})
            if "timeline_open_ms" in model:
                rows.append({"platform": platform, "file": model["file"], "act": "timeline opens",
                             "total_ms": model["timeline_open_ms"]})
    return rows


# -- the report -------------------------------------------------------------------

def _load(path: Path):
    return json.loads(path.read_text()) if path.exists() else None


def _pct(n: int, d: int) -> str:
    return f"{n} of {d} ({round(100 * n / d)}%)" if d else "none"


def report(out: Path) -> Path:
    """REPORT.md from whatever has been run into [out]."""
    lines = [f"# CAD task test, {out.name.removeprefix('cadtask-')}", "",
             f"Commit {_commit()}. This box: load {os.getloadavg()[0]:.0f} when written, "
             "SwiftShader in the browser, software GL under xvfb on the desktop. Times are "
             "this box's, to compare with each other, not with a phone or a graphics card.", ""]
    summary = _load(out / "roundtrip_summary.json")
    judged = _load(out / "roundtrip_judged.json") or []
    if summary:
        lines += ["## 1. Files opened, saved and opened again", "",
                  f"{summary['files']} files: real sets' files from the LDraw model repository, "
                  "hash-ordered across six sizes, and every .io and .lxf the repository "
                  "carries. Unreadable: " + (", ".join(summary["unreadable"]) or "none") + ".", "",
                  "Exact: every part's number, colour, place (to the LDU) and turn, its "
                  "sub-model and its author's step, against the file as the app reads it. "
                  "The lift is the whole model moved up or down onto the ground when it "
                  "opens; renumbered is a retired part number written as the part it became.",
                  "",
                  "| written as | files | exact | exact but for the lift | same shapes "
                  "but for the lift | parts back, the same shape in the same place | author's steps kept | "
                  "the app's model the same after |",
                  "|---|---|---|---|---|---|---|---|"]
        for fmt, f in summary["formats"].items():
            lines.append(
                f"| {'LDraw (.ldr/.mpd)' if fmt == 'ldr' else 'Studio (.io)'} | {f['files']} | "
                f"{_pct(f['exact'], f['files'])} | {_pct(f['exact_up_to_lift'], f['files'])} | "
                f"{_pct(f.get('same_shapes_up_to_lift', 0), f['files'])} | "
                f"{_pct(f['parts_back'], f['parts'])} | "
                f"{_pct(f['steps_kept'], f['authored_files'])} | "
                f"{_pct(f['app_stable'], f['files'])} |")
        first = next(iter(summary["formats"].values()), None)
        for fmt, f in summary["formats"].items():
            lines += ["", f"Written as {fmt}, by what was opened: " + "; ".join(
                f".{kind}: {b['files']} files, {b['exact']} exact, {b['exact_up_to_lift']} "
                f"exact but for the lift, {b['same_shapes_up_to_lift']} the same shapes"
                for kind, b in f.get("by_input", {}).items()) + "."]
        if first:
            lines += ["", "Commonest losses, by files (LDraw; .io is the same text in a zip):", ""]
            lines += [f"- {why}: {n} files" for why, n in first["losses_by_files"]]
            lines += ["", "By parts: " + ", ".join(f"{why} {n}" for why, n in
                                                     first["losses_by_parts"]) + "."]
            lines += ["", "Meta lines the saved file has fewer of: " + ", ".join(
                f"`0 {name}` ({n} files)" for name, n in first["metas_lost_by_files"]) + "."]
        timed = [j for j in judged if not j.get("error") and j.get("open_ms") is not None]
        if timed:
            lines += ["", "Opening and saving, headless on the desktop (the save works out "
                      "the build order of a file without the author's steps):", "",
                      "| parts | files | open, median ms | open, most | save, median ms | "
                      "save, most |", "|---|---|---|---|---|---|"]
            for low, high in SIZES:
                group = [j for j in timed if low <= j["parts"] < high]
                if not group:
                    continue
                opens = sorted(j["open_ms"] for j in group)
                saves = sorted(j["save_ms"] or 0 for j in group)
                lines.append(f"| {low}–{high - 1} | {len(group)} | {opens[len(opens) // 2]:,} | "
                             f"{opens[-1]:,} | {saves[len(saves) // 2]:,} | {saves[-1]:,} |")
        worst = sorted((j for j in judged if not j.get("error") and "ldr" in j["formats"]),
                       key=lambda j: -sum(v for k, v in j["formats"]["ldr"]["up_to_lift"]["why"]
                                          .items() if k != "renumbered"))[:8]
        if worst:
            lines += ["", "| file | parts | lift (LDU) | what changed (up to the lift) | "
                      "parts the app has not got |", "|---|---|---|---|---|"]
            for j in worst:
                f = j["formats"]["ldr"]["up_to_lift"]
                missing = ", ".join(f"{k} ×{v}" for k, v in list(j["missing"].items())[:3])
                lines.append(f"| {j['file']} | {j['parts']} | {j['lift']:g} | "
                             f"{', '.join(f'{k} {v}' for k, v in f['why'].items()) or 'nothing'}"
                             f"{'' if f['steps_kept'] is not False else '; steps changed'}"
                             f"{'' if f['submodels_kept'] else '; sub-models changed'} | "
                             f"{missing or '—'} |")
        lines.append("")
    desktop = _load(out / "desktop_frames.json")
    web = _load(out / "web_frames.json")
    if desktop or web:
        sample = _load(out / "frames_sample.json") or {}
        lines += ["## 2. Frames a builder feels", "",
                  "Models: " + ", ".join(f"{k} ({v} parts)" for k, v in sample.items()) + ". "
                  f"Budget {DESKTOP_BUDGET_MS} ms a frame on the desktop, {WEB_BUDGET_MS:g} ms "
                  "in a browser. The 95th percentile and the worst frame while it "
                  "happens, in ms (an engine frame that draws nothing costs a "
                  "millisecond, so a median says little); ✗ marks the 95th percentile "
                  "over budget, · the worst frame only.", ""]
        table = frame_table(desktop, web)
        files = list(dict.fromkeys(r["file"] for r in table))
        head = "| act | " + " | ".join(f"{p} {sample.get(f, '?')}" for p in ("desktop", "web")
                                          for f in files) + " |"
        lines += [head, "|---" * (1 + 2 * len(files)) + "|"]
        for act in INTERACTIONS + ["open", "timeline opens"]:
            cells = []
            for platform in ("desktop", "web"):
                for f in files:
                    hit = [r for r in table if r["platform"] == platform and r["file"] == f
                           and r["act"] == act]
                    if not hit:
                        cells.append("—")
                    elif "total_ms" in hit[0]:
                        cells.append(f"{hit[0]['total_ms']:,.0f}" if hit[0]["total_ms"] else "—")
                    elif "longer_than_ms" in hit[0]:
                        cells.append(f"> {hit[0]['longer_than_ms']:,.0f} ✗")
                    else:
                        r = hit[0]
                        cells.append(f"{r['p95_ms']:,.0f} / {r['max_ms']:,.0f}"
                                     + (" ✗" if r["p95_over"] else (" ·" if r["max_over"]
                                                                   else "")))
            lines.append(f"| {act} | " + " | ".join(cells) + " |")
        misses = [r for r in table if r.get("max_over")]
        lines += ["", f"Over budget at the worst frame: {len(misses)} of "
                  f"{sum(1 for r in table if 'max_over' in r)}; at the 95th percentile: "
                  f"{sum(1 for r in table if r.get('p95_over'))}.", "",
                  "The app's own work in its worst frame, the drawing taken out (the "
                  "browser: the frame less its time in WebGL; the desktop: the engine's "
                  "process time), in ms; ✗ over budget:", "",
                  head, "|---" * (1 + 2 * len(files)) + "|"]
        for act in INTERACTIONS:
            cells = []
            for platform, budget in (("desktop", DESKTOP_BUDGET_MS), ("web", WEB_BUDGET_MS)):
                for f in files:
                    hit = [r for r in table if r["platform"] == platform and r["file"] == f
                           and r["act"] == act and r.get("own_max_ms") is not None]
                    cells.append(f"{hit[0]['own_max_ms']:,.0f}"
                                 + (" ✗" if hit[0]["own_max_ms"] > budget else "")
                                 if hit else "—")
            lines.append(f"| {act} | " + " | ".join(cells) + " |")
        lines.append("")
    build = _load(out / "build" / "build.json")
    if build:
        lines += build_section(build.get("summary", {}),
                               _load(out / "build" / "klm_whole_sets.json") or {})
    path = out / "REPORT.md"
    path.write_text("\n".join(lines) + "\n")
    return path


def build_section(summary: dict, whole: dict) -> list[str]:
    """The build flow's results (cad_task_flow.mjs's summary, with
    cadtask_klm.py's model merged in) as the report's third section."""
    lines = ["## 3. Building a real set from its steps", "",
             f"Measured {summary.get('measured', '')}. Studio is modelled, not measured: a "
             "keystroke-level model (Card, Moran and Newell) from Studio's help pages, and "
             "Brickworks is modelled the same way.", "",
             "| set | parts | tried | put down | exact | actions | actions a part | "
             "seconds a part here |", "|---|---|---|---|---|---|---|---|"]
    for s in summary.get("sets", []):
        if s.get("error"):
            lines.append(f"| {s['set']} | | | | | failed: {s['error'][:80]} | | |")
            continue
        lines.append(f"| {s['set']} | {s.get('parts_in_file')} | {s.get('tried')} | "
                     f"{s.get('placed')} | {s.get('exact')} | {s.get('actions')} | "
                     f"{s.get('actions_per_part')} | {s.get('seconds_per_part')} |")
    klm = summary.get("klm", {})
    if klm.get("sets"):
        lines += ["", "Modelled, the parts tried, seconds a part (the same part list in both):",
                  "", "| set | parts | Brickworks | Brickworks, steps marked | Studio | "
                  "Studio, steps marked | measured actions a part | modelled |",
                  "|---|---|---|---|---|---|---|---|"]
        for k in klm["sets"]:
            m = k.get("measured_vs_model", {})
            lines.append(f"| {k['set']} | {k.get('parts')} | {k.get('brickworks_seconds_per_part')} | "
                         f"{k.get('brickworks_with_steps')} | {k.get('studio_seconds_per_part')} | "
                         f"{k.get('studio_with_steps')} | {m.get('measured_actions_per_part')} | "
                         f"{m.get('modelled_actions_per_part')} |")
    if whole.get("sets"):
        lines += ["", "Modelled, the whole sets, seconds a part:", "",
                  "| set | parts | Brickworks | with steps | Studio | with steps |",
                  "|---|---|---|---|---|---|"]
        for k in whole["sets"]:
            b = k["model"]["brickworks"]
            st = k["model"]["studio"]
            lines.append(f"| {k['set']} | {k['parts']} | {b['seconds_per_part']} | "
                         f"{b['with_steps']['seconds_per_part']} | {st['seconds_per_part']} | "
                         f"{st['with_steps']['seconds_per_part']} |")
    gaps = [g for s in summary.get("sets", []) for g in s.get("gaps", [])]
    if gaps:
        lines += ["", "Gaps, as the flow met them:", ""] + [f"- {g}" for g in gaps[:30]]
    lines.append("")
    return lines


def _commit() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True).stdout.strip()
    except OSError:
        return "?"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    parser.add_argument("what", choices=["sample", "roundtrip", "judge", "frames", "build",
                                         "report", "all"])
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--per-size", type=int, default=PER_SIZE)
    parser.add_argument("--shards", type=int, default=2)
    parser.add_argument("--platform", choices=["both", "desktop", "web"], default="both")
    # Seconds a run may take, waiting for heavy's slot included: on a busy
    # box the wait is most of it.
    parser.add_argument("--timeout", type=int, default=7200)
    # frames: measure again only these acts in the browser (step,undo,...),
    # keeping the rest of the run before.
    parser.add_argument("--only", default="")
    # build: parts tried a set, and minutes of building a set.
    parser.add_argument("--most", type=int, default=BUILD_MOST)
    parser.add_argument("--minutes", type=int, default=BUILD_MINUTES)
    args = parser.parse_args(argv)
    out = args.out or RESULTS / f"cadtask-{date.today().isoformat()}"
    if args.what == "sample":
        info, subs = survey_sets()
        for f in choose(info, args.per_size):
            print(f"roundtrip  {info[f][0]:5d} parts {info[f][1]:4d} steps  {f}")
        for p in fixtures():
            print(f"roundtrip  fixture  {p.relative_to(ROOT)}")
        for f in choose_builds(info, subs):
            print(f"build      {info[f][0]:5d} parts {info[f][1]:4d} steps  {f}")
        for f in choose_frames(info):
            print(f"frames     {info[f][0]:5d} parts {info[f][1]:4d} steps  {f}")
        return 0
    if args.what in ("roundtrip", "all"):
        print(run_roundtrip(out, args.per_size, args.shards, args.timeout))
    if args.what in ("frames", "all"):
        print(run_frames(out, args.platform, args.timeout, args.only))
    if args.what in ("build", "all"):
        print(run_build(out, args.timeout, args.most, args.minutes, args.only))
    if args.what == "judge":
        rows = (out / "roundtrip.jsonl").read_text().splitlines()
        judged = [judge_file(json.loads(line)) for line in rows]
        (out / "roundtrip_judged.json").write_text(json.dumps(judged, indent=1))
        (out / "roundtrip_summary.json").write_text(json.dumps(summarise(judged), indent=1))
        print(json.dumps(summarise(judged)["formats"], indent=1))
    if args.what in ("report", "all", "judge"):
        print(report(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
