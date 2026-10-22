#!/usr/bin/env python3
"""The app's pick between two designs of one brief, read against the real sets.

    env -u ANTHROPIC_API_KEY python3 tools/bench/pick_pairs.py run --out NAME \\
        --arms t2base:2026-10-19,t2plan3:2026-10-19 --subjects 40148-1,7410-1 [--jobs 3]
    python3 tools/bench/pick_pairs.py report --out NAME

`run` takes every pair of the arms' designs of each subject, shows it to the
app's picker (src/ai/design_pick.gd, through src/dev/pick_pair.gd) both ways
round, and writes each answer to bench/results/NAME/asks/. An answer on disk
is not asked again. Spends two asks of the subscription a pair.

`report` reads them against what each design won against its set overall
(record.json's two verdicts, the picker never sees them) and against the
bench's own head-to-head verdicts where a realset-*-vs-* round holds the pair.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import statistics
import subprocess
import sys
import tempfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from bench import run as bench  # noqa: E402

RESULTS = bench.RESULTS


def design(arm: str, number: str) -> dict:
    name, date = arm.split(":")
    where = RESULTS / f"realset-{date}-{name}" / number
    record = json.loads((where / "record.json").read_text())
    ours = record["keys"]["ours"]
    won = sum(v["winners"]["overall"] == ours for v in record.get("verdicts", []))
    return {"key": ours, "views": str(where / "views"), "brief": record["brief"],
            "won": won, "judged": len(record.get("verdicts", []))}


def ask(first: dict, second: dict, number: str, out: Path) -> dict:
    path = out / "asks" / number / f"{first['key']}__{second['key']}.json".replace(":", "_")
    if path.exists():
        return json.loads(path.read_text())
    env = {k: v for k, v in os.environ.items()
           if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    command = ["timeout", "--kill-after=10", "300", "godot", "--headless", "--path", str(ROOT),
               "--script", "src/dev/pick_pair.gd", "--", f"--brief={first['brief']}",
               f"--a={first['views']}", f"--b={second['views']}"]
    with tempfile.TemporaryDirectory(prefix="pick-data.") as data:     # its own user://
        done = subprocess.run(command, cwd=ROOT, env={**env, "XDG_DATA_HOME": data},
                              capture_output=True, text=True)
    line = next((l for l in done.stdout.splitlines() if l.startswith("pick ")), "")
    answer = json.loads(line[5:]) if line else {"error": done.stdout[-300:] + done.stderr[-300:]}
    found = {"number": number, "first": first["key"], "second": second["key"], **answer}
    if "keep" in answer:
        found["kept"] = first["key"] if answer["keep"] == "A" else second["key"]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(found, indent=1))
    return found


def run(args: argparse.Namespace) -> int:
    out = RESULTS / args.out
    tasks = []
    for number in args.subjects.split(","):
        made = [design(arm, number) for arm in args.arms.split(",")]
        for x, y in itertools.combinations(made, 2):
            tasks += [(x, y, number), (y, x, number)]
    with ThreadPoolExecutor(args.jobs) as pool:
        for found in pool.map(lambda t: ask(*t, out), tasks):
            print(found["number"], found["first"].split(":")[0], found["second"].split(":")[0],
                  "->", found.get("kept", "").split(":")[0] or found.get("error", "")[:120],
                  f"{found.get('seconds', 0):.1f}s", flush=True)
    return 0


def bench_verdicts(number: str) -> dict[tuple[str, str], str]:
    """The bench's head-to-head overall verdicts on a subject: (first, second) -> winner."""
    found = {}
    for f in RESULTS.glob(f"realset-*-vs-*/{number}/*.json"):
        v = json.loads(f.read_text())
        if "winners" in v:
            found[(v["first"], v["second"])] = v["winners"]["overall"]
    return found


def report(args: argparse.Namespace) -> int:
    out = RESULTS / args.out
    asks = [json.loads(f.read_text()) for f in sorted((out / "asks").glob("*/*.json"))]
    won = {}
    for a in asks:
        for key in (a["first"], a["second"]):
            if key not in won:
                name, date, number = key.split(":")
                won[key] = design(f"{name}:{date}", number)["won"]
    pairs: dict[tuple, list] = {}
    for a in asks:
        pairs.setdefault((a["number"], *sorted((a["first"], a["second"]))), []).append(a)

    # Each ask on a pair that split against the set: where the better was shown, what was kept.
    table, reasons_wrong = Counter(), []
    for a in asks:
        wa, wb = won[a["first"]], won[a["second"]]
        if wa == wb:
            continue
        better = "A" if wa > wb else "B"
        table[(better, a["keep"])] += 1
        if a["keep"] != better:
            reasons_wrong.append(a)
    n = sum(table.values())
    hits = table[("A", "A")] + table[("B", "B")]
    print(f"asks on pairs that split against the set: {n}, the better kept {hits} "
          f"({100 * hits / max(n, 1):.0f}%)")
    print("                  kept A   kept B")
    for better in ("A", "B"):
        print(f"  better shown {better}  {table[(better, 'A')]:6d}   {table[(better, 'B')]:6d}")
    kept_a = sum(a["keep"] == "A" for a in asks)
    print(f"order: kept the one shown first in {kept_a} of {len(asks)} asks")

    # Each pair, both orders: both name it, they split, or both name the other.
    by = Counter()
    credit = 0.0
    split_pairs = 0
    gain = []
    for (number, x, y), both in sorted(pairs.items()):
        if len(both) != 2:
            continue
        kept = {a["kept"] for a in both}
        agree = len(kept) == 1
        by["orders agree" if agree else "orders split"] += 1
        wx, wy = won[x], won[y]
        share = sum(won[a["kept"]] for a in both) / 4       # each ask's kept design, won of 2
        gain.append((share, (wx + wy) / 4, max(wx, wy) / 2))
        if wx == wy:
            continue
        split_pairs += 1
        better = x if wx > wy else y
        right = sum(a["kept"] == better for a in both) / 2
        credit += right
        by[{1.0: "both named the better", 0.5: "the orders split", 0.0: "both named the worse"}[right]] += 1
    print(f"\npairs: {len(pairs)}; {by['orders agree']} with both orders agreeing")
    print(f"pairs that split against the set: {split_pairs}: both named the better "
          f"{by['both named the better']}, the orders split {by['the orders split']}, "
          f"both named the worse {by['both named the worse']}; "
          f"the better named {credit:.1f} of {split_pairs} ({100 * credit / max(split_pairs, 1):.0f}%)")
    if gain:
        print(f"overall won against the set, per design kept: picked {100 * statistics.mean(g[0] for g in gain):.1f}%, "
              f"either {100 * statistics.mean(g[1] for g in gain):.1f}%, "
              f"the better {100 * statistics.mean(g[2] for g in gain):.1f}%")

    # Against the bench's own head-to-head judge, ask by ask in the same order.
    same = total = 0
    for a in asks:
        verdict = bench_verdicts(a["number"]).get((a["first"], a["second"]))
        if verdict:
            total += 1
            same += verdict == a["kept"]
    print(f"\nthe bench's head-to-head judge, same pair same order: agrees on {same} of {total}")

    secs = [a["seconds"] for a in asks]
    use = [a.get("usage", {}) for a in asks]
    tin = [u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
           + u.get("cache_creation_input_tokens", 0) for u in use]
    tout = [u.get("output_tokens", 0) for u in use]
    print(f"\ncost an ask: {statistics.median(secs):.1f} s median ({min(secs):.1f}-{max(secs):.1f}), "
          f"{statistics.mean(tin):,.0f} tokens in, {statistics.mean(tout):,.0f} out; "
          f"models {dict(Counter(a.get('model') for a in asks))}")

    if reasons_wrong:
        print("\nwhere it kept the worse:")
        for a in reasons_wrong:
            print(f"  {a['number']} {a['first'].split(':')[0]} v {a['second'].split(':')[0]} "
                  f"kept {a['keep']} ({a['kept'].split(':')[0]}, won {won[a['kept']]}/2 against "
                  f"{won[a['first'] if a['keep'] == 'B' else a['second']]}/2): {a['why']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="what", required=True)
    r = sub.add_parser("run")
    r.add_argument("--out", required=True)
    r.add_argument("--arms", required=True, help="name:date of each realset round, comma-separated")
    r.add_argument("--subjects", required=True, help="set numbers, comma-separated")
    r.add_argument("--jobs", type=int, default=3)
    p = sub.add_parser("report")
    p.add_argument("--out", required=True)
    args = parser.parse_args()
    return run(args) if args.what == "run" else report(args)


if __name__ == "__main__":
    sys.exit(main())
