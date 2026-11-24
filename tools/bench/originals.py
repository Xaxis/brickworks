#!/usr/bin/env python3
"""An original design judged blind beside real LEGO® sets of its kind and size.

    python3 tools/bench/originals.py judge --design FILE.ldr --key NAME --brief "WORDS" \
        --sets 40448-1,60017-1,3221-1 [--per-order 2] [--out DIR] [--judge-model opus]
    python3 tools/bench/originals.py summary --out DIR

realset.py measures the designer against the set a brief was taken from. An original has no
set of its own, so it is judged beside the real sets a person would put it next to: each set
of `--sets` (LDraw's Official Model Repository, vendor/omr), drawn by the same renderer from
the same views (run.render), and asked of the same pairwise judge in both orders, every
verdict under fresh random names in a fresh folder outside any checkout (realset.ask,
design34). `--brief` is what both answer to, so it names the kind, not the original's own
subject: "A working boat for a harbour, in the style of LEGO® City sets: 200 to 380 pieces."
A set's pictures are made once, in realset-sets/<set>/ as realset makes them; the design's
in OUT/<key>/. Its verdicts are kept in OUT/<key>/judged/<set>/ and read back on a rerun,
so a judging stopped part way asks only what is missing.

The answer, per dimension, is the share of verdicts the original won, with its 95% Wilson
interval over the verdicts (realset.win_rate), in OUT/<key>/verdict.json and on stdout:
"wins" where the interval's low end is over a half, "ties" where it spans a half, "loses"
where its high end is under. Used by billbuilds (2026-11-24) for the owner's own builds.
"""

from __future__ import annotations

import argparse
import functools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import realset  # noqa: E402
import run as bench  # noqa: E402

DIMS = realset.DIMS


@functools.cache
def _every() -> tuple[realset.Candidate, ...]:
    """The repository's sets, read once: candidates() reads every file."""
    return tuple(realset.candidates())


def _candidate(number: str) -> realset.Candidate:
    for one in _every():
        if one.number == number:
            return one
    raise SystemExit(f"originals: no set {number} in vendor/omr's index with a file")


def judged(out: Path, key: str) -> dict:
    """Every verdict kept for KEY, read back: per set and over all, the original's share."""
    found: dict[str, list] = {}
    for folder in sorted((out / key / "judged").glob("*")):
        verdicts = [realset.pairwise.Verdict.from_dict(json.loads(p.read_text()))
                    for p in sorted(folder.glob("fresh-*.json"))]
        found[folder.name] = verdicts
    mine = f"original:{key}"
    summary: dict = {"key": key, "sets": {}, "overall": {}}
    for dim in DIMS:
        every = [1.0 if v.winners[dim] == mine else 0.0 for vs in found.values() for v in vs]
        share, low, high = realset.win_rate(every)
        summary["overall"][dim] = {"share": round(share, 3), "low": round(low, 3),
                                   "high": round(high, 3), "verdicts": len(every),
                                   "says": "wins" if low > 0.5 else "loses" if high < 0.5 else "ties"}
    for number, verdicts in found.items():
        summary["sets"][number] = {dim: f"{sum(v.winners[dim] == mine for v in verdicts)}/{len(verdicts)}"
                                   for dim in DIMS}
        summary["sets"][number]["reasons_overall"] = [v.reasons.get("overall", "") for v in verdicts]
    return summary


def judge(args: argparse.Namespace) -> int:
    design = Path(args.design).resolve()
    out = Path(args.out).resolve()
    where = out / args.key
    where.mkdir(parents=True, exist_ok=True)
    views = bench.render(design, where / "design", where / "render.log")
    if len(views) != len(bench.VIEWS):
        raise SystemExit(f"originals: {design.name} drew {len(views)} of {len(bench.VIEWS)} views "
                         f"(see {where / 'render.log'})")
    mine = (f"original:{args.key}", realset.shown(f"original:{args.key}", views))
    for number in [n.strip() for n in args.sets.split(",") if n.strip()]:
        record = realset.set_side(_candidate(number), realset.style.Parts(), software=False,
                                  measure=False)
        theirs = (f"set:{number}", realset.shown(f"set:{number}", [Path(v) for v in record["views"]]))
        realset.both_orders(args.brief, number, mine, theirs, where / "judged" / number,
                            args.judge_model, per_order=args.per_order)
    summary = {**judged(out, args.key), "brief": args.brief, "design": str(design)}
    bench._write_json(where / "verdict.json", summary)
    print(_said(summary))
    return 0


def _said(summary: dict) -> str:
    lines = [f"{summary['key']}:"]
    for dim, one in summary["overall"].items():
        lines.append(f"  {dim:<11} {one['share']:.2f} ({one['low']:.2f}-{one['high']:.2f}) "
                     f"of {one['verdicts']}: {one['says']}")
    for number, said in summary["sets"].items():
        lines.append(f"  vs {number}: overall {said['overall']}, likeness {said['likeness']}")
    return "\n".join(lines)


def summary(args: argparse.Namespace) -> int:
    out = Path(args.out).resolve()
    for folder in sorted(p for p in out.iterdir() if (p / "judged").is_dir()):
        print(_said(judged(out, folder.name)))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("judge")
    one.add_argument("--design", required=True)
    one.add_argument("--key", required=True)
    one.add_argument("--brief", required=True)
    one.add_argument("--sets", required=True)
    one.add_argument("--per-order", type=int, default=2)
    one.add_argument("--out", default=str(bench.RESULTS / "originals"))
    one.add_argument("--judge-model", default="opus")
    every = sub.add_parser("summary")
    every.add_argument("--out", default=str(bench.RESULTS / "originals"))
    args = parser.parse_args()
    return judge(args) if args.command == "judge" else summary(args)


if __name__ == "__main__":
    sys.exit(main())
