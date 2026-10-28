#!/usr/bin/env python3
"""Owner-style ideas: our designer on complex original briefs, two arms head to head.

    python3 tools/bench/ideas.py list
    python3 tools/bench/ideas.py run --arm A [--checkout DIR] [--via port|relay]
                                 [--instructions all|none] [--first N | --subjects a,b]
                                 [--jobs 2] [--date D] [--timeout S] [--software] [--dry-run]
    python3 tools/bench/ideas.py report --arm A [--date D]
    python3 tools/bench/ideas.py compare --arms A,B [--dates D1,D2] [--jobs 2] [--dry-run]

realset.py measures our designs against real sets from a brief made of the
set's name, and many of its verdicts turned on how a name was read. The
owner names no set: they bring an idea of their own, mixed and detailed
(tools/bench/ideas_briefs.py). An idea has no right answer to draw beside a
design, so two arms are judged against each other, brief by brief.

- **A run** is realset's machinery on the fixed briefs: the same designer
  (`--via port`, the bench's session on the app's port; `--via relay`, as
  the owner designs, Claude through the connector relay to the app as a
  throwaway account's tab), the same `--jobs` workers, BENCH_PORTS and
  XDG_DATA_HOME. Each design's app holds the brief's id out of design
  memory; there is no set to hold out. Each design is drawn from realset's
  cameras and read by tools/style.py. No build check: the head to head is
  the measure.
- **The compare** is pairwise.py's method as realset asks it: the two arms'
  views of one brief, both orders, a forced choice on likeness to the
  brief, realism as a LEGO® set, creativity, technique and overall, each
  with a reason. A brief counts the share of its verdicts the first arm
  won, with a 95% interval over briefs (realset.win_rate). realset's
  compare prints the first arm's share under a header that does not say
  whose, which misled a reader once: here every column names its arm, and
  the second arm's share stands beside the first's. A brief one arm made
  no model for is lost by that arm on every dimension; one neither made is
  left out and named, as is a brief whose words changed since a design.
- **The noise floor** is main against main: two arms of one snapshot. Their
  head to head is luck alone, and a lever must clear its interval.

Everything lands in the main checkout's bench/results/: ideas-<date>-<arm>/<id>/
for an arm's designs (worker-<id>.log, each design's session.jsonl with
--via relay), ideas-<date>-<a>-vs-<b>/ for two arms judged (report.md).
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import statistics
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from bench import pairwise, realset, suite  # noqa: E402
from bench import run as bench  # noqa: E402
from bench.ideas_briefs import IDEAS, Idea  # noqa: E402

RESULTS = bench.RESULTS
VIEWS = bench.VIEWS
DIMS = ("likeness", "realism", "creativity", "technique", "overall")
RUBRIC = {
    "likeness": "Likeness to the brief: which builds what the person asked for, every element "
                "they named, in the setting and at the size they gave, and reads as it at a "
                "glance from every view?",
    "realism": "Realism as a LEGO® set: which could pass for a real set on a shop shelf, with a "
               "set's proportions, part choices and colours and a finished, sturdy build, "
               "rather than bricks stacked into roughly the right shape?",
    "creativity": pairwise.RUBRIC["creativity"],
    "technique": pairwise.RUBRIC["technique"],
    "overall": "Overall: which of the two would a LEGO® set designer rather hand the person who "
               "asked for this, everything considered?",
}
QUESTION = realset.Question(DIMS, RUBRIC, 1)
CANNED_PAIR = bench.CANNED / "ideas_pair_reply.json"


def arm_dir(date: str, arm: str) -> Path:
    return RESULTS / f"ideas-{date}-{arm}"


def subject_of(idea: Idea) -> suite.Subject:
    """The designer's subject: its id, held out of design memory, is the brief's."""
    return suite.Subject(idea.id, idea.title, idea.brief, "", "other")


def wanted(subjects: str = "", first: int = 0) -> list[Idea]:
    chosen = list(IDEAS[:first] if first else IDEAS)
    if not subjects:
        return chosen
    by = {i.id: i for i in IDEAS}
    named = [s.strip() for s in subjects.split(",") if s.strip()]
    missing = [n for n in named if n not in by]
    if missing:
        raise SystemExit(f"no such idea: {', '.join(missing)}")
    return [by[n] for n in named]


# -- an arm's run ---------------------------------------------------------------


def one(idea: Idea, args: argparse.Namespace, parts: style.Parts) -> dict:
    """A brief designed, drawn and read on one arm, each stage skipped when its output is
    there. A machine's failure (no tab, a 529) is not recorded, so the command tries again."""
    out = arm_dir(args.date, args.arm) / idea.id
    out.mkdir(parents=True, exist_ok=True)
    path = out / "record.json"
    if path.exists():
        return json.loads(path.read_text())
    subject = subject_of(idea)
    bench._write_json(out / "brief.json", {"id": idea.id, "kind": idea.kind,
                                           "brief": idea.brief})
    canned = bench.CANNED / "design.ldr" if args.dry_run else None
    try:
        made = (realset.design_via_relay(subject, out, args.timeout, args.checkout,
                                         args.instructions, not args.no_claude_code)
                if args.via == "relay" and canned is None else
                bench.design(subject, out, args.timeout, canned, app=args.checkout))
    except SystemExit as failed:
        bench.say(f"{idea.id}: {failed}")
        return {}
    record = {"id": idea.id, "kind": idea.kind, "brief": idea.brief, "arm": args.arm,
              "date": args.date, "key": f"ideas:{args.arm}:{args.date}:{idea.id}",
              "design": made}
    if made.get("model"):
        design = out / "design.ldr"
        views = bench.render(design, out / "views", out / "views_render.log", args.software)
        if len(views) < len(VIEWS):
            bench.say(f"{idea.id}: missing pictures; see {out}/views_render.log")
            return {}
        record["measures"] = realset.measures(design.read_text(errors="replace"), parts)
    else:
        record["note"] = "no model was produced: every verdict goes to the other arm"
    bench._write_json(path, record)
    bench.say(f"{idea.id}: recorded, {record.get('measures', {}).get('parts', 'no')} parts")
    return record


def run(args: argparse.Namespace) -> int:
    if not args.dry_run and not os.environ.get("XDG_DATA_HOME"):
        raise SystemExit("set XDG_DATA_HOME to a folder of this run's: a design must never "
                         "write into the owner's app folder")
    chosen = wanted(args.subjects, args.first)
    out = arm_dir(args.date, args.arm)
    out.mkdir(parents=True, exist_ok=True)
    if args.what == "one":
        parts = style.Parts()
        for idea in chosen:
            bench.say(f"{idea.id}: starting")
            try:
                one(idea, args, parts)
            except Exception as failed:  # noqa: BLE001 - one brief's fault stops only it
                bench.say(f"{idea.id}: failed: {failed!r}")
        return 0
    if not args.dry_run:
        # The arm's app designs and this checkout draws: both read their class lists.
        for checkout in dict.fromkeys((args.checkout, ROOT)):
            realset._imported(checkout)
    bench._write_json(out / "arm.json", {"arm": args.arm, "checkout": str(args.checkout),
                                         "commit": bench.commit(args.checkout),
                                         "date": args.date, "via": args.via,
                                         "instructions": args.instructions,
                                         "claude_code": not args.no_claude_code})
    jobs = max(1, min(args.jobs, len(chosen)))
    bench.say(f"ideas: {len(chosen)} briefs on {args.arm} ({bench.commit(args.checkout)}) "
              f"via {args.via}, {jobs} at a time, into {out}")
    with ThreadPoolExecutor(max_workers=jobs) as workers:
        list(workers.map(lambda share: _in_a_slot(share, args),
                         [chosen[k::jobs] for k in range(jobs)]))
    text = report_arm(args.date, args.arm)
    (out / "report.md").write_text(text)
    print(text)
    return 0


def _in_a_slot(share: list[Idea], args: argparse.Namespace) -> int:
    """A worker's briefs one after another, as realset's workers run (realset._in_a_slot):
    bare on the GPU, each design and drawing taking the lease for itself; in software one
    `heavy` job."""
    out = arm_dir(args.date, args.arm)
    command = [*([bench.HEAVY] if args.software else []), sys.executable,
               str(Path(__file__).resolve()), "one", "--arm", args.arm, "--date", args.date,
               "--subjects", ",".join(i.id for i in share), "--checkout", str(args.checkout),
               "--timeout", str(args.timeout), "--via", args.via,
               "--instructions", args.instructions,
               *(["--no-claude-code"] if args.no_claude_code else []),
               *(["--software"] if args.software else []),
               *(["--dry-run"] if args.dry_run else [])]
    log_path = out / f"worker-{share[0].id}.log"
    with log_path.open("a") as log:
        status = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
    left = [i.id for i in share if not (out / i.id / "record.json").exists()]
    bench.say(f"{', '.join(i.id for i in share)}: ended {status}"
              + (f"; not recorded: {', '.join(left)} (see {log_path})" if left else ""))
    return status


def records(date: str, arm: str) -> list[dict]:
    found = []
    for idea in IDEAS:
        path = arm_dir(date, arm) / idea.id / "record.json"
        if path.exists():
            found.append(json.loads(path.read_text()))
    return found


def minutes(record: dict) -> float:
    """A session's own minutes (Claude Code's clock), else the design's wall clock."""
    made = record.get("design", {})
    return (made.get("design_seconds") or made.get("seconds") or 0) / 60.0


def times_said(found: list[dict]) -> str:
    took = [minutes(r) for r in found]
    if not took:
        return "no sessions"
    late = sum(1 for r in found if r.get("design", {}).get("timed_out"))
    return (f"median {statistics.median(took):.0f} min, {min(took):.0f}-{max(took):.0f}, "
            f"{sum(took) / 60:.1f} h in all; {late} timed out")


def report_arm(date: str, arm: str) -> str:
    found = records(date, arm)
    meta = arm_dir(date, arm) / "arm.json"
    said = json.loads(meta.read_text()) if meta.exists() else {}
    made = [r for r in found if r.get("design", {}).get("model")]
    out = [f"# Ideas: {arm} ({said.get('commit', '?')}), {date}, via {said.get('via', '?')}", "",
           f"{len(found)} of {len(IDEAS)} briefs recorded, {len(made)} with a model. "
           f"Sessions: {times_said(found)}.", "",
           "| idea | kind | parts | minutes | pictures given up |", "|---|---|---|---|---|"]
    for r in found:
        parts = r.get("measures", {}).get("parts", "no model")
        out.append(f"| {r['id']} | {r['kind']} | {parts} | {minutes(r):.0f} | "
                   f"{r.get('design', {}).get('pictures_given_up', '')} |")
    return "\n".join(out) + "\n"


# -- two arms -------------------------------------------------------------------


def _made(record: dict) -> bool:
    return bool(record.get("design", {}).get("model"))


def share_won(x: dict, y: dict, verdicts: list[pairwise.Verdict], dim: str) -> float | None:
    """The share of one brief's verdicts on `dim` that preferred x's design to y's: all of
    them when only x made a model, none when only y did, None when nothing was judged."""
    if _made(x) != _made(y):
        return 1.0 if _made(x) else 0.0
    if not verdicts:
        return None
    return sum(v.winners[dim] == x["key"] for v in verdicts) / len(verdicts)


def compare(args: argparse.Namespace) -> int:
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    if len(arms) != 2:
        raise SystemExit("--arms takes two arms: a,b")
    dates = [d.strip() for d in args.dates.split(",")] if args.dates else [args.date] * 2
    if (arms[0], dates[0]) == (arms[1], dates[1]):
        raise SystemExit("an arm judged against itself is the same designs twice")
    a_dir, b_dir = arm_dir(dates[0], arms[0]), arm_dir(dates[1], arms[1])
    out = RESULTS / f"ideas-{dates[1]}-{arms[0]}-vs-{arms[1]}"
    tasks, left_out = [], []
    for idea in wanted(args.subjects, args.first):
        ra, rb = a_dir / idea.id / "record.json", b_dir / idea.id / "record.json"
        if not (ra.exists() and rb.exists()):
            left_out.append((idea.id, "not recorded on both arms"))
            continue
        x, y = json.loads(ra.read_text()), json.loads(rb.read_text())
        if x["brief"] != idea.brief or y["brief"] != idea.brief:
            left_out.append((idea.id, "its brief changed since a design"))
        elif not (_made(x) or _made(y)):
            left_out.append((idea.id, "neither arm made a model"))
        else:
            tasks.append((idea, x, y))

    def judged(task: tuple) -> tuple:
        idea, x, y = task
        if not (_made(x) and _made(y)):
            return (idea, x, y, [])
        shown = [(r["key"], realset.shown(r["key"], [where / idea.id / f"views_{v}.png"
                                                      for v in VIEWS], idea.id))
                 for r, where in ((x, a_dir), (y, b_dir))]
        return (idea, x, y, realset.both_orders(idea.brief, idea.id, shown[0], shown[1],
                                                out / idea.id, args.judge_model,
                                                CANNED_PAIR if args.dry_run else None, QUESTION))

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        results = list(workers.map(judged, tasks))
    text = compare_report(arms, dates, results, left_out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "report.md").write_text(text)
    print(text)
    return 0


def compare_report(arms: list[str], dates: list[str], results: list[tuple],
                   left_out: list[tuple[str, str]]) -> str:
    """`results` is (idea, x, y, verdicts) per brief, x the first arm's record."""
    a, b = arms
    counted = [(idea, x, y, said) for idea, x, y, said in results
               if share_won(x, y, said, DIMS[0]) is not None]
    unjudged = [(idea.id, "the judge gave no readable verdict") for idea, x, y, said in results
                if share_won(x, y, said, DIMS[0]) is None]
    one_sided = sum(1 for _i, x, y, _s in counted if _made(x) != _made(y))
    out = [f"# Ideas head to head: {a} ({dates[0]}) against {b} ({dates[1]})", "",
           f"{len(counted)} briefs judged"
           + (f", {one_sided} of them made by one arm only and lost by the other on every "
              "dimension" if one_sided else "") + ".",
           *(["Left out: " + "; ".join(f"{i} ({why})" for i, why in left_out + unjudged) + "."]
             if left_out or unjudged else []), "",
           f"**Each share is the share of verdicts that preferred {a}'s design to {b}'s**, both "
           f"orders, a brief counting the share of its verdicts {a} won; {b}'s share is the "
           "rest. 50% is a draw.", "",
           f"| dimension | {a} preferred | 95% interval of {a}'s share | {b} preferred |",
           "|---|---|---|---|"]
    for dim in DIMS:
        rate, low, high = realset.win_rate([share_won(x, y, said, dim)
                                            for _i, x, y, said in counted])
        out.append(f"| {dim} | {100 * rate:.0f}% | {100 * low:.0f}-{100 * high:.0f}% | "
                   f"{100 * (1 - rate):.0f}% |")
    both = [said for _i, _x, _y, said in counted if len(said) == 2]
    same = sum(s[0].winners[d] == s[1].winners[d] for s in both for d in DIMS)
    every = [v for _i, _x, _y, said in counted for v in said]
    first = sum(v.picked_first(d) for v in every for d in DIMS)
    out += ["", f"The two orders named the same design on {pairwise.share(same, len(both) * len(DIMS))}"
            f" of dimensions; the design shown first won {pairwise.share(first, len(every) * len(DIMS))}.",
            "", f"Sessions: {a}'s {times_said([x for _i, x, _y, _s in results])}; "
            f"{b}'s {times_said([y for _i, _x, y, _s in results])}.", "",
            f"Each brief: the parts and minutes of each arm's design, and the verdicts {a}'s "
            "won of those asked (all or none when one arm made no model).", "",
            f"| idea | kind | {a} parts | {b} parts | {a} min | {b} min | "
            + " | ".join(f"{d} to {a}" for d in DIMS) + " |", "|" + "---|" * (6 + len(DIMS))]
    for idea, x, y, said in counted:
        def cell(dim: str) -> str:
            if not said:
                return "all" if _made(x) else "none"
            return f"{sum(v.winners[dim] == x['key'] for v in said)}/{len(said)}"
        out.append(f"| {idea.id} | {idea.kind} | {x.get('measures', {}).get('parts', '-')} | "
                   f"{y.get('measures', {}).get('parts', '-')} | {minutes(x):.0f} | "
                   f"{minutes(y):.0f} | " + " | ".join(cell(d) for d in DIMS) + " |")
    return "\n".join(out) + "\n"


# -- the command line -----------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    sub.add_parser("list", help="the briefs, one a line")
    for name in ("run", "one", "report", "compare"):
        p = sub.add_parser(name)
        p.add_argument("--date", default=f"{datetime.date.today():%Y-%m-%d}")
        p.add_argument("--jobs", type=int, default=2)
        p.add_argument("--subjects", default="", help="idea ids, comma-separated")
        p.add_argument("--first", type=int, default=0, help="only the first N briefs")
        p.add_argument("--dry-run", action="store_true",
                       help="a canned design and canned replies: nothing designed or asked")
        if name in ("run", "one", "report"):
            p.add_argument("--arm", required=True, help="this arm's name: main315a, a branch's")
        if name in ("run", "one"):
            p.add_argument("--checkout", type=Path, default=ROOT,
                           help="the checkout whose app designs (this one)")
            p.add_argument("--timeout", type=int, default=2700)
            p.add_argument("--software", action="store_true",
                           help="draw on lavapipe under heavy, not on the GPU")
            p.add_argument("--via", choices=("port", "relay"), default="port",
                           help="relay: as the owner designs, Claude through the connector "
                           "relay to the app as a throwaway account's tab")
            p.add_argument("--instructions", choices=("all", "none"), default="all",
                           help="none: the server's instructions withheld (with --via relay)")
            p.add_argument("--no-claude-code", action="store_true",
                           help="each tab as a browser is, with no Claude Code (with --via relay)")
        if name == "compare":
            p.add_argument("--arms", required=True)
            p.add_argument("--dates", default="", help="each arm's date, when they differ")
            p.add_argument("--judge-model", default="opus")
    args = parser.parse_args(argv)
    if args.what == "list":
        for idea in IDEAS:
            print(f"{idea.id:20} {idea.kind:27} {idea.brief}")
        return 0
    if args.what in ("run", "one"):
        args.checkout = args.checkout.resolve()
        if args.instructions == "none" and args.via != "relay":
            raise SystemExit("--instructions none withholds what the relay serves: with --via relay")
        if args.no_claude_code and args.via != "relay":
            raise SystemExit("--no-claude-code starts a relay tab as a browser is: with --via relay")
        return run(args)
    if args.what == "report":
        text = report_arm(args.date, args.arm)
        (arm_dir(args.date, args.arm) / "report.md").write_text(text)
        print(text)
        return 0
    return compare(args)


if __name__ == "__main__":
    raise SystemExit(main())
