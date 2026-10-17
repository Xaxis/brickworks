#!/usr/bin/env python3
"""How close the booklet's worked-out steps come to the steps real set authors chose.

    tools/steps_score.py sample [--which tune|proof]
    tools/steps_score.py run --which tune|proof --out DIR [--shards 4] [--parallel 2]
    tools/steps_score.py report --out DIR [--json FILE]
    tools/steps_score.py compare BEFORE_DIR AFTER_DIR

The LDraw model repository's files (vendor/omr/files, tools/omr.py fetch)
carry their authors' 0 STEP lines, and its rule is that those steps should
make "any instructions generated ... as close to the official instructions
as possible". So they are the nearest thing to a printed booklet's order
that a program can read.

`sample` chooses the files, the same every time: sets in the order of a
hash of their number, a set's files all in one sample, a file at most
2,500 parts with at least three of its author's steps, the same number from
each of four sizes, and within a size the themes taken in turn. `tune` is
what the planner may be tuned on; `proof` is a second sample it never saw.

`run` scores each file with src/dev/steps_score.gd, in shards, each a
headless Godot under ~/.claude/claude-core/bin/heavy: one JSON line a file,
with each part's step in five builds of it (the author's, ours, ours with
the sub-models taken away too, file order and bottom up) and what a builder
meets in each. A shard that dies is started again after the file it died
on, which is recorded as crashed.

`report` turns the lines into the measures, each with a 95% interval from
resampling the files (2,000 times, seeded):

- Kendall's tau-b between each part's step in a build and in the author's,
  as Graph Transformer sequence planning scored LEGO build orders (0.44);
- how many parts the author put in one step that the build also does, and
  the other way round;
- how many steps, and how big: things a step, and the share over MEPNet's
  10 parts or 5 kinds;
- the author's sub-assemblies (every copy of a sub-model) the build makes on
  the side: a copy it builds apart with at least 80% of the same parts;
- new parts hidden from the front and the back, parts put in under one
  already there, and parts floating at their step: held to nothing on the
  table at the end of it, the table holding the model's first parts and the
  first parts of each piece of the finished model a step begins (a second
  vehicle), and again with only the model's first parts; and again with no
  stud from the side holding anything, as the probe read it until 2026-10-17.

`compare` pairs two runs of one sample file by file: the change in each
measure and its interval.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import random
import re
import subprocess
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SETS = ROOT / "vendor" / "omr" / "files"
INDEX = ROOT / "vendor" / "omr" / "index.json"
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
PROBE = "src/dev/steps_score.gd"
OUT = ROOT / "build" / "steps_score"

SALT = "brickworks steps score 1"
## Parts in a file, by size: each gets the same share of a sample.
SIZES = [(10, 100), (100, 300), (300, 800), (800, 2501)]
PER_SIZE = 25
## The fewest author's steps a file may have: two STEP lines.
FEWEST_STEPS = 2
## A sub-assembly is matched by a copy built apart with this much of it
## (Jaccard), to allow a part the author put in the parent instead.
SAME_UNIT = 0.8
## MEPNet built its synthetic manuals' steps of at most this many parts
## and kinds.
MOST_PARTS = 10
MOST_KINDS = 5
ORDERS = ["author", "drawn", "ours", "flat", "file", "height"]
NAMES = {"author": "the author's steps", "drawn": "the author's, as the booklet draws them",
         "ours": "ours", "flat": "ours, no sub-models", "file": "file order",
         "height": "bottom up by height"}
RESAMPLES = 2000
## Seconds a shard may go without finishing a file before it is stopped.
STALL = 2400
RESTARTS = 20


# -- the sample ---------------------------------------------------------------

def survey(text: str) -> tuple[int, int]:
    """Parts in a model and the author's STEP lines in it, from its text.

    A sub-model a file carries is opened where it is placed; a part it
    carries (an !LDRAW_ORG part, not a model) counts as one part."""
    sections: dict[str, list[str]] = {}
    is_part: set[str] = set()
    order: list[str] = []
    current = None
    steps = 0
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        words = line.split()
        if words[0] == "0" and len(words) > 1:
            meta = words[1].upper()
            if meta == "FILE":
                current = line.split(None, 2)[2].strip().lower() if len(words) > 2 else ""
                sections.setdefault(current, [])
                order.append(current)
                continue
            if meta == "NOFILE":
                current = None
                continue
            if meta in ("STEP", "ROTSTEP"):
                steps += 1
            if meta == "!LDRAW_ORG" and current is not None and len(words) > 2 \
                    and not words[2].lower().startswith(("unofficial_model", "model")):
                is_part.add(current)
            continue
        if words[0] == "1" and len(words) >= 15:
            if current is None:
                current = ""
                sections.setdefault(current, [])
                order.append(current)
            name = line.split(None, 14)[14].strip().lower().replace("\\", "/")
            sections[current].append(name)
    if not order:
        return 0, steps
    memo: dict[str, int] = {}

    def count(name: str, depth: int = 0) -> int:
        if name not in sections or name in is_part or depth > 40:
            return 1
        if name not in memo:
            memo[name] = sum(count(child, depth + 1) for child in sections[name])
        return memo[name]

    return count(order[0]), steps


def set_of(file: str) -> str:
    """The set a file is from: "10022-1_Dining-Car.mpd" -> "10022-1"."""
    stem = file.rsplit(".", 1)[0]
    return stem.split("_", 1)[0]


def themes() -> dict[str, str]:
    if not INDEX.exists():
        return {}
    return {row["number"]: str(row.get("theme", "")).split(" > ")[0] or "Other"
            for row in json.loads(INDEX.read_text())}


def _rank(text: str) -> str:
    return hashlib.sha256((SALT + ":" + text).encode()).hexdigest()


def choose(info: dict[str, tuple[int, int]], theme_of: dict[str, str],
           per_size: int = PER_SIZE) -> dict[str, list[str]]:
    """The tune and proof samples: per size, per_size files each.

    [info] is file -> (parts, author's steps). Each size's files are taken
    in hash order, the theme taken least so far first, one file a set, and
    a set used in one sample is not in the other."""
    used: set[str] = set()
    out: dict[str, list[str]] = {"tune": [], "proof": []}
    for which in ("tune", "proof"):
        for low, high in SIZES:
            pool = sorted((f for f, (parts, steps) in info.items()
                           if low <= parts < high and steps >= FEWEST_STEPS),
                          key=_rank)
            taken: list[str] = []
            counts: Counter = Counter()
            while len(taken) < per_size:
                best = None
                for file in pool:
                    if set_of(file) in used:
                        continue
                    theme = theme_of.get(set_of(file), "Other")
                    if best is None or counts[theme] < counts[theme_of.get(set_of(best), "Other")]:
                        best = file
                        if counts[theme] == 0:
                            break
                if best is None:
                    break
                taken.append(best)
                used.add(set_of(best))
                counts[theme_of.get(set_of(best), "Other")] += 1
            out[which].extend(sorted(taken))
    return out


def sample(which: str) -> list[str]:
    info = {}
    for path in sorted(SETS.glob("*")):
        if path.suffix.lower() not in (".mpd", ".ldr"):
            continue
        info[path.name] = survey(path.read_text(errors="replace"))
    return choose(info, themes())[which]


# -- run ------------------------------------------------------------------------

def _rows(path: Path) -> list[dict]:
    rows = []
    if not path.exists():
        return rows
    for line in path.read_text().splitlines():
        line = line.strip()
        if line:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def _crashed_on(path: Path) -> str | None:
    begun = None
    for row in _rows(path):
        if row.get("begin"):
            begun = row["file"]
        elif row.get("file") == begun:
            begun = None
    return begun


def run(which: str, out: Path, shards: int, parallel: int, project: Path = ROOT,
        files: list[str] | None = None, extra: list[str] | None = None) -> int:
    files = files or sample(which)
    out.mkdir(parents=True, exist_ok=True)
    (out / "sample.json").write_text(json.dumps({"which": which, "files": files}, indent=1))
    env = dict(os.environ, XDG_DATA_HOME=str(project / ".scratch-data"))
    mine = {k: files[k::shards] for k in range(shards)}
    live: dict[int, subprocess.Popen] = {}
    restarts: Counter = Counter()
    waiting = list(range(shards))

    def left(shard: int) -> list[str]:
        path = out / f"shard-{shard}.jsonl"
        done = {r["file"] for r in _rows(path) if not r.get("begin")}
        return [f for f in mine[shard] if f not in done]

    def start(shard: int) -> None:
        todo = left(shard)
        if not todo:
            return
        log = open(out / f"shard-{shard}.log", "a")
        command = [str(HEAVY), "godot", "--headless", "--path", str(project), "--script", PROBE,
                   "--", f"--out={out / f'shard-{shard}.jsonl'}"] + (extra or [])
        command += ["res://vendor/omr/files/" + f for f in todo]
        live[shard] = subprocess.Popen(command, cwd=project, env=env, stdout=log,
                                       stderr=subprocess.STDOUT)

    started = time.time()
    while live or waiting:
        while waiting and len(live) < max(1, parallel):
            shard = waiting.pop(0)
            start(shard)
        time.sleep(10)
        for shard, process in list(live.items()):
            path = out / f"shard-{shard}.jsonl"
            if process.poll() is None:
                if _crashed_on(path) and time.time() - path.stat().st_mtime > STALL:
                    process.kill()
                    process.wait()
                else:
                    continue
            del live[shard]
            crashed = _crashed_on(path)
            if crashed:
                with path.open("a") as f:
                    f.write(json.dumps({"file": crashed, "error": "crashed"}) + "\n")
                restarts[shard] += 1
            if left(shard) and restarts[shard] < RESTARTS:
                waiting.append(shard)
        done = sum(len(mine[k]) - len(left(k)) for k in range(shards))
        print(f"  {done}/{len(files)} files, {time.time() - started:.0f} s", flush=True)
    return 0


# -- the measures -------------------------------------------------------------------

def kendall_tau_b(x: list, y: list) -> float:
    """Kendall's tau-b of two rankings with ties, in n log n (Knight 1966).

    1 when every pair is in the same order in both, -1 when every pair is
    the other way round. Pairs tied in one ranking count in neither the
    agreements nor the disagreements, and the ties shrink the denominator,
    as scipy.stats.kendalltau does."""
    n = len(x)
    if n != len(y):
        raise ValueError("rankings of different lengths")
    if n < 2:
        return float("nan")
    pairs = sorted(zip(x, y))
    total = n * (n - 1) // 2

    def tied(values: list) -> int:
        out = 0
        run = 1
        for i in range(1, len(values)):
            if values[i] == values[i - 1]:
                run += 1
            else:
                out += run * (run - 1) // 2
                run = 1
        return out + run * (run - 1) // 2

    tied_x = tied([a for a, _ in pairs])
    tied_both = tied(pairs)
    ys = [b for _, b in pairs]
    swaps = _swaps(ys)
    tied_y = tied(sorted(ys))
    concordant_minus = total - tied_x - tied_y + tied_both - 2 * swaps
    denominator = math.sqrt((total - tied_x) * (total - tied_y))
    return concordant_minus / denominator if denominator else float("nan")


def _swaps(values: list) -> int:
    """How many pairs a stable merge sort has to swap: the pairs out of
    order, ties not counted. Sorts [values] in place."""
    swaps = 0
    width = 1
    n = len(values)
    buffer = values[:]
    while width < n:
        for start in range(0, n, 2 * width):
            middle = min(start + width, n)
            end = min(start + 2 * width, n)
            i, j, k = start, middle, start
            while i < middle and j < end:
                if values[j] < values[i]:
                    buffer[k] = values[j]
                    swaps += middle - i
                    j += 1
                else:
                    buffer[k] = values[i]
                    i += 1
                k += 1
            buffer[k:end] = values[i:middle] + values[j:end]
        values, buffer = buffer, values
        width *= 2
    return swaps


def together(author: list, other: list) -> tuple[int, int, int]:
    """Pairs of parts in one step: (the author's, the other's, both's)."""
    def pairs(counts: Counter) -> int:
        return sum(c * (c - 1) // 2 for c in counts.values())
    return (pairs(Counter(author)), pairs(Counter(other)),
            pairs(Counter(zip(author, other))))


def matched_units(units: list[list[int]], copies: list[list[int]],
                  at: float = SAME_UNIT) -> tuple[int, int]:
    """(Author's sub-assemblies a copy built apart matches, copies built
    apart that match one): matched when they share at least [at] of their
    parts together (Jaccard)."""
    unit_sets = [set(u) for u in units]
    copy_sets = [set(c) for c in copies]
    by_part: dict[int, list[int]] = defaultdict(list)
    for n, c in enumerate(copy_sets):
        for part in c:
            by_part[part].append(n)

    def best(unit: set) -> tuple[float, int]:
        seen: set[int] = set()
        top = (0.0, -1)
        for part in unit:
            for n in by_part.get(part, []):
                if n in seen:
                    continue
                seen.add(n)
                share = len(unit & copy_sets[n]) / len(unit | copy_sets[n])
                top = max(top, (share, n))
        return top

    found = 0
    matched_copies: set[int] = set()
    for unit in unit_sets:
        share, n = best(unit)
        if share >= at:
            found += 1
    unit_index: dict[int, list[int]] = defaultdict(list)
    for n, u in enumerate(unit_sets):
        for part in u:
            unit_index[part].append(n)
    for n, c in enumerate(copy_sets):
        seen: set[int] = set()
        for part in c:
            for m in unit_index.get(part, []):
                if m in seen:
                    continue
                seen.add(m)
                if len(c & unit_sets[m]) / len(c | unit_sets[m]) >= at:
                    matched_copies.add(n)
    return found, len(matched_copies)


def quantile(values: list[float], q: float) -> float:
    if not values:
        return float("nan")
    ordered = sorted(values)
    at = (len(ordered) - 1) * q
    low = math.floor(at)
    high = math.ceil(at)
    return ordered[low] + (ordered[high] - ordered[low]) * (at - low)


def interval(values: list, statistic, resamples: int = RESAMPLES,
             seed: int = 1) -> tuple[float, float]:
    """A 95% percentile interval of statistic(values) from resampling the
    values (files) with replacement."""
    if not values:
        return (float("nan"), float("nan"))
    rng = random.Random(seed)
    got = []
    for _ in range(resamples):
        drawn = [values[rng.randrange(len(values))] for _ in values]
        value = statistic(drawn)
        if not math.isnan(value):
            got.append(value)
    return (quantile(got, 0.025), quantile(got, 0.975))


def mean(values: list[float]) -> float:
    kept = [v for v in values if not math.isnan(v)]
    return sum(kept) / len(kept) if kept else float("nan")


def ratio(rows: list[tuple[float, float]]) -> float:
    top = sum(a for a, _ in rows)
    bottom = sum(b for _, b in rows)
    return top / bottom if bottom else float("nan")


def names_in(orders: dict) -> list[str]:
    """The builds a run scored: the usual ones in their order, then any more."""
    return [n for n in ORDERS if n in orders] + sorted(n for n in orders if n not in ORDERS)


def per_file(row: dict) -> dict[str, dict]:
    """Each build's numbers for one file."""
    orders = row["orders"]
    author_rank = orders["author"]["rank"]
    out = {}
    for name in names_in(orders):
        if name not in orders:
            continue
        order = orders[name]
        rank = order["rank"]
        both = [i for i in range(len(rank)) if rank[i] >= 0 and author_rank[i] >= 0]
        a = [author_rank[i] for i in both]
        b = [rank[i] for i in both]
        mine, theirs, shared = together(a, b)
        sizes = order["sizes"]
        kinds = order["kinds"]
        steps = [s for s in sizes if s > 0]
        # Copies of one part, or of nearly the whole model, are no more a
        # sub-assembly than the author's are (src/dev/steps_score.gd _units).
        copies = [c for c in order.get("copies", []) if 2 <= len(c) and len(c) * 10 < len(rank) * 9]
        found, matching = matched_units(row.get("units", []), copies)
        out[name] = {
            "tau": kendall_tau_b(a, b),
            "together": (shared, mine),
            "kept_apart": (shared, theirs),
            "steps": len(steps),
            "sizes": steps,
            "over": sum(1 for s, k in zip(sizes, kinds) if s > MOST_PARTS or k > MOST_KINDS),
            "units": (found, len(row.get("units", []))),
            "copies": (matching, len(copies)),
            "hidden": (order["hidden"], order["items"]),
            "hidden_steps": (order["hidden_steps"], len(steps)),
            "blocked": (order["blocked"], order["items"]),
            "floating": (order["floating"], order["measured"]),
            "floating_steps": (order["floating_steps"], len(steps)),
            # A step that begins a piece of the finished model begins it on
            # the table (src/dev/steps_score.gd Pieces.apart), as the
            # authors' own books do; "floating" holds only the model's first
            # parts to it. Runs from before the first have the second only.
            "floating_pieces": (order.get("floating_pieces", order["floating"]),
                                order.get("measured_pieces", order["measured"])),
            "floating_pieces_steps": (order.get("floating_pieces_steps", order["floating_steps"]),
                                      len(steps)),
        }
        # The same with no stud from the side holding anything, as the probe's
        # graph read it until 2026-10-17. A run from before has only that.
        old = order.get("without_side", order)
        out[name]["floating_no_side"] = (old.get("floating_pieces", old["floating"]),
                                         old.get("measured_pieces", old["measured"]))
        out[name]["floating_no_side_steps"] = (old.get("floating_pieces_steps",
                                                       old["floating_steps"]), len(steps))
        checked = row.get("checked", {}).get(name)
        out[name]["checked"] = (checked["floating"], checked["parts"]) if checked else (0, 0)
        out[name]["checked_steps"] = (checked["steps_floating"], checked["cuts"]) \
            if checked else (0, 0)
    return out


## What each measure is called in the tables, and how it is summed over
## files: "mean" a mean of per-file values, "ratio" a pooled share.
MEASURES = [
    ("tau", "Kendall tau-b against the author", "mean"),
    ("together", "author's same-step pairs kept together", "ratio"),
    ("steps_ratio", "steps for each of the author's", "median"),
    ("size_median", "things a step, median", "pooled_median"),
    ("over", "steps over 10 parts or 5 kinds", "ratio_steps"),
    ("units", "author's sub-assemblies built on the side", "ratio"),
    ("copies", "built on the side that are an author's", "ratio"),
    ("hidden", "new things hidden front and back", "ratio"),
    ("hidden_steps", "steps with a hidden new thing", "ratio"),
    ("blocked", "things put in under one already there", "ratio"),
    ("floating_pieces", "things floating at their step", "ratio"),
    ("floating_pieces_steps", "steps with a floating thing", "ratio"),
    ("floating", "things floating, only the model's first parts on the table", "ratio"),
    ("floating_steps", "steps with a floating thing, only the model's first parts on the table",
     "ratio"),
    ("floating_no_side", "things floating, no stud from the side holding, as before", "ratio"),
    ("floating_no_side_steps", "steps with a floating thing, no stud from the side holding, as before",
     "ratio"),
    ("checked", "parts the build check calls floating at sampled steps", "ratio"),
    ("checked_steps", "sampled steps with a part the build check calls floating", "ratio"),
]


def summarise(rows: list[dict]) -> dict:
    """Every measure for every build: its value and 95% interval."""
    files = [per_file(r) for r in rows if "orders" in r]
    out: dict = {"files": len(files), "parts": sum(r["parts"] for r in rows if "orders" in r)}
    for name in names_in(files[0] if files else {}):
        mine = [f[name] for f in files if name in f]
        if not mine:
            continue
        authors = [f["author"]["steps"] for f in files if name in f]
        got: dict = {}

        def add(key: str, stat, values: list) -> None:
            value = stat(values)
            low, high = interval(values, stat)
            got[key] = {"value": value, "low": low, "high": high}

        add("tau", mean, [m["tau"] for m in mine])
        add("together", ratio, [m["together"] for m in mine])
        add("steps_ratio", lambda v: quantile(v, 0.5),
            [m["steps"] / a for m, a in zip(mine, authors) if a])
        add("size_median", lambda v: quantile([s for one in v for s in one], 0.5),
            [m["sizes"] for m in mine])
        add("over", ratio, [(m["over"], m["steps"]) for m in mine])
        for key in ("units", "copies", "hidden", "hidden_steps", "blocked", "floating",
                    "floating_steps", "floating_pieces", "floating_pieces_steps",
                    "floating_no_side", "floating_no_side_steps", "checked", "checked_steps"):
            add(key, ratio, [m[key] for m in mine])
        sizes = [s for m in mine for s in m["sizes"]]
        got["sizes"] = {str(k): v for k, v in sorted(Counter(min(s, 13) for s in sizes).items())}
        got["steps"] = sum(m["steps"] for m in mine)
        out[name] = got
    return out


def _cell(measure: dict, share: bool) -> str:
    value, low, high = measure["value"], measure["low"], measure["high"]
    if math.isnan(value):
        return "–"
    if share:
        return f"{100 * value:.1f}% ({100 * low:.1f}–{100 * high:.1f})"
    return f"{value:.2f} ({low:.2f}–{high:.2f})"


def table(summary: dict) -> str:
    names = names_in({k: v for k, v in summary.items() if isinstance(v, dict)})
    lines = ["| Measure | " + " | ".join(NAMES.get(n, n) for n in names) + " |",
             "|---|" + "---:|" * len(names)]
    for key, said, how in MEASURES:
        share = how in ("ratio", "ratio_steps")
        lines.append(f"| {said} | " + " | ".join(_cell(summary[n][key], share)
                                                   for n in names) + " |")
    lines.append("| steps in all | " + " | ".join(f"{summary[n]['steps']:,}" for n in names) + " |")
    return "\n".join(lines)


def size_table(summary: dict) -> str:
    names = names_in({k: v for k, v in summary.items() if isinstance(v, dict)})
    lines = ["| Things a step | " + " | ".join(NAMES.get(n, n) for n in names) + " |",
             "|---|" + "---:|" * len(names)]
    for k in range(1, 14):
        cells = []
        for n in names:
            counts = summary[n]["sizes"]
            total = sum(counts.values())
            cells.append(f"{100 * counts.get(str(k), 0) / total:.1f}%" if total else "–")
        lines.append(f"| {k if k < 13 else '13 or more'} | " + " | ".join(cells) + " |")
    return "\n".join(lines)


def load(out: Path) -> list[dict]:
    rows: dict[str, dict] = {}
    for path in sorted(out.glob("shard-*.jsonl")):
        for row in _rows(path):
            if row.get("begin"):
                continue
            rows[row["file"]] = row
    return [rows[k] for k in sorted(rows)]


def report(out: Path, json_out: Path | None) -> int:
    rows = load(out)
    good = [r for r in rows if "orders" in r]
    bad = [r for r in rows if "orders" not in r]
    summary = summarise(good)
    print(f"{len(good)} files scored, {summary['parts']:,} parts; "
          f"{len(bad)} not: " + ", ".join(f"{r['file']} ({r.get('error', '?')})" for r in bad))
    print()
    print(table(summary))
    print()
    print(size_table(summary))
    if json_out:
        json_out.write_text(json.dumps(summary, indent=1))
    return 0


def compare(before: Path, after: Path) -> int:
    """The change in our measures, file by file over the files both scored."""
    one = {r["file"]: per_file(r) for r in load(before) if "orders" in r}
    two = {r["file"]: per_file(r) for r in load(after) if "orders" in r}
    common = sorted(set(one) & set(two))
    print(f"{len(common)} files in both")
    for name in ("drawn", "ours", "flat"):
        if not common or name not in one[common[0]] or name not in two[common[0]]:
            continue
        print(f"\n{NAMES[name]}")
        pairs = [(one[f][name], two[f][name]) for f in common]
        diffs = [b["tau"] - a["tau"] for a, b in pairs
                 if not math.isnan(a["tau"]) and not math.isnan(b["tau"])]
        low, high = interval(diffs, mean)
        better = sum(1 for d in diffs if d > 1e-9)
        worse = sum(1 for d in diffs if d < -1e-9)
        print(f"  tau: {mean([a['tau'] for a, _ in pairs]):.3f} -> "
              f"{mean([b['tau'] for _, b in pairs]):.3f}, change {mean(diffs):+.3f} "
              f"({low:+.3f} to {high:+.3f}); better in {better}, worse in {worse}")
        for key in ("together", "units", "copies", "hidden", "hidden_steps", "blocked",
                    "floating", "floating_steps", "floating_pieces", "floating_pieces_steps",
                    "floating_no_side", "floating_no_side_steps", "checked"):
            a_rows = [a[key] for a, _ in pairs]
            b_rows = [b[key] for _, b in pairs]
            paired = list(zip(a_rows, b_rows))
            delta = lambda v: ratio([y for _, y in v]) - ratio([x for x, _ in v])  # noqa: E731
            low, high = interval(paired, delta)
            print(f"  {key}: {100 * ratio(a_rows):.1f}% -> {100 * ratio(b_rows):.1f}% "
                  f"(change {100 * delta(paired):+.1f}, {100 * low:+.1f} to {100 * high:+.1f})")
        sa = [a["steps"] for a, _ in pairs]
        sb = [b["steps"] for _, b in pairs]
        print(f"  steps: {sum(sa):,} -> {sum(sb):,}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("sample")
    one.add_argument("--which", default="tune", choices=["tune", "proof"])
    two = sub.add_parser("run")
    two.add_argument("--which", default="tune", choices=["tune", "proof"])
    two.add_argument("--out", type=Path, default=OUT)
    two.add_argument("--shards", type=int, default=4)
    two.add_argument("--parallel", type=int, default=2)
    two.add_argument("--check", action="store_true",
                     help="also the build check on sampled steps (files up to 300 parts)")
    two.add_argument("files", nargs="*")
    three = sub.add_parser("report")
    three.add_argument("--out", type=Path, default=OUT)
    three.add_argument("--json", type=Path)
    four = sub.add_parser("compare")
    four.add_argument("before", type=Path)
    four.add_argument("after", type=Path)
    args = parser.parse_args(argv)
    if args.command == "sample":
        files = sample(args.which)
        info = {f: survey((SETS / f).read_text(errors="replace")) for f in files}
        theme_of = themes()
        for f in files:
            print(f"{f}\t{info[f][0]} parts\t{info[f][1]} steps\t{theme_of.get(set_of(f), 'Other')}")
        print(f"{len(files)} files")
        return 0
    if args.command == "run":
        return run(args.which, args.out.resolve(), args.shards, args.parallel,
                   files=args.files or None,
                   extra=["--check"] if args.check else None)
    if args.command == "report":
        return report(args.out, args.json)
    return compare(args.before, args.after)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
