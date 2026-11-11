#!/usr/bin/env python3
"""timing_judge.py: is a timing check's failure on a release's preview the
change, or the load? Its runs on the preview and on brickworks.diy, taken by
turns (live_ab.sh), judged by the measures the check prints.

  timing_judge.py [--battery LOG] --run SIDE EXIT LOG [--run SIDE EXIT LOG]...

SIDE is P (the preview) or L (brickworks.diy); EXIT the run's exit and LOG
what it printed. --battery is the preview's run that failed in the release's
battery: its failures are judged too, but its numbers are only shown, as it
was picked for failing.

A measure is a line the check says ok or FAIL on with a figure in ms: the
app's own work where the line names it ("own 53 ms", "own work 15.4 ms"),
else its first figure in ms that is not a bar ("under 36 ms"). Its bar is
what the line holds it to ("under 3000", "of 200", "budget 300"). A FAIL
line with no figure (a step that did not happen, a run that ended with no
FAIL line) is counted instead.

Judged: every line the preview failed, in the battery or here. Each holds
the release only when the preview is worse than brickworks.diy by more than
the noise: its mean past live's by more than the wider of the two sides'
spreads (their runs' max - min), and by at least 2% of the bar (of live's
mean, with no bar), so that two sides failing alike by a hair are alike; a
counted line, failed in more of the preview's runs than live's; a measure
live never printed, always. One run a side is luck:
rel-m287's play held twice on the phone's 3000 ms bar, 3324 and 3685 against
live's 1267 and 1953, and played P L L P P L the preview was no slower (2511
vs 2809 ms mean); live failed the same bar in 1 run of 3 (2026-11-11).

Prints the verdict ("ships past: ..." or "holds: ..."), then a line a
measure judged; exits 0 to ship past, 1 to hold, 2 when it cannot read.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

NUM = r"\d+(?:\.\d+)?"
SAID = re.compile(r"^\s*(ok|FAIL)\b\s*(.*?)\s*$")
# The time a step took, or why a progress row failed: never part of a key.
TAIL = re.compile(r"\s*\[[^\]]*\]\s*$")
OWN = re.compile(r"\bown(?: work)?\s+(%s) ms\b" % NUM)
BAR_FIGURE = re.compile(r"\bunder\s+(%s)(?: ms)?" % NUM)
FIGURE = re.compile(r"(%s)\s*ms\b" % NUM)
BARS = (re.compile(r"\bunder (%s)\b" % NUM), re.compile(r"\d ms of (%s)\b" % NUM), re.compile(r"\bbudget (%s)\b" % NUM))
# In a key, every figure, a dash and "never" alike, "ms" with them: a step's
# number after "#" (Next #3) stays, as it says which line it is.
VARIES = re.compile(r"(?<![#\d.])~?(?:%s|—|never)(?: ms\b)?" % NUM)
SIDES = {"P": "the preview", "L": "brickworks.diy"}
# The run did not happen: the live database stayed busy, the probes had
# failed, or the check has no such name (preview_checks.sh).
NOT_RUN = {75, 125, 127}


@dataclass
class Line:
    key: str
    failed: bool
    value: float | None
    bar: float | None


def _key(text: str) -> str:
    return re.sub(r"\s+", " ", VARIES.sub("#", text)).strip()


def read_line(body: str, failed: bool) -> Line:
    body = TAIL.sub("", body)
    bar = next((float(m.group(1)) for m in (b.search(body) for b in BARS) if m), None)
    own = OWN.search(body)
    if own:
        at = own
    else:
        bars = {m.start(1) for m in BAR_FIGURE.finditer(body)}
        at = next((m for m in FIGURE.finditer(body) if m.start(1) not in bars), None)
    if at is None:
        return Line(_key(body)[:160], failed, None, bar)
    key = _key(body[:at.start(1)]).rstrip(" (") + " # ms"
    if bar is not None:
        key += " (bar %g)" % bar
    return Line(key, failed, float(at.group(1)), bar)


def read_log(text: str, code: int) -> list[Line]:
    lines, seen = [], {}
    for raw in text.splitlines():
        m = SAID.match(raw)
        if not m or not m.group(2):
            continue
        line = read_line(m.group(2), m.group(1) == "FAIL")
        # The same words twice in a run (a measure each size makes alike):
        # each its own, in order.
        seen[line.key] = seen.get(line.key, 0) + 1
        if seen[line.key] > 1:
            line.key += " #%d" % seen[line.key]
        lines.append(line)
    if code != 0 and not any(line.failed for line in lines):
        lines.append(Line("the run ended exit %d with no FAIL line" % code, True, None, None))
    return lines


@dataclass
class Side:
    runs: int = 0
    values: dict[str, list[float]] = field(default_factory=dict)
    fails: dict[str, int] = field(default_factory=dict)
    said: set[str] = field(default_factory=set)


def _fig(v: float) -> str:
    return "%g" % round(v, 1)


def judge(battery: list[Line], runs: list[tuple[str, int, list[Line]]]) -> tuple[bool, list[str]]:
    sides = {"P": Side(), "L": Side()}
    bars: dict[str, float] = {}
    order: list[str] = []
    for line in battery:
        if line.failed and line.key not in order:
            order.append(line.key)
    for side, code, lines in runs:
        if code in NOT_RUN and not lines:
            continue
        s = sides[side]
        s.runs += 1
        for line in lines:
            s.said.add(line.key)
            if line.value is not None:
                s.values.setdefault(line.key, []).append(line.value)
            if line.bar is not None:
                bars[line.key] = line.bar
            if line.failed:
                s.fails[line.key] = s.fails.get(line.key, 0) + 1
                if side == "P" and line.key not in order:
                    order.append(line.key)
    p, l = sides["P"], sides["L"]
    for side in ("P", "L"):
        if not sides[side].runs:
            return False, ["holds: no run on %s finished, so there is nothing to compare" % SIDES[side]]
    first = {line.key: line.value for line in battery if line.value is not None}
    out, worse = [], []
    for key in order:
        pv, lv = p.values.get(key, []), l.values.get(key, [])
        counts = "failed %d of %d, %d of %d" % (p.fails.get(key, 0), p.runs, l.fails.get(key, 0), l.runs)
        shown = " (in the battery %s)" % _fig(first[key]) if key in first else ""
        if pv and key not in l.said:
            worse.append(key)
            out.append("%s: here %s, %s never printed it%s; %s: worse" % (
                key, " ".join(map(_fig, pv)), SIDES["L"], shown, counts))
        elif pv and lv:
            mp, ml = sum(pv) / len(pv), sum(lv) / len(lv)
            bar = bars.get(key)
            noise = max(max(pv) - min(pv), max(lv) - min(lv), 0.02 * (bar if bar is not None else ml))
            bad = mp > ml + noise
            if bad:
                worse.append(key)
            out.append("%s: here %s (mean %s), there %s (mean %s)%s; noise %s; %s: %s" % (
                key, " ".join(map(_fig, pv)), _fig(mp), " ".join(map(_fig, lv)), _fig(ml), shown, _fig(noise),
                counts, "worse" if bad else "no worse"))
        else:
            bad = p.fails.get(key, 0) > l.fails.get(key, 0)
            if bad:
                worse.append(key)
            out.append("%s%s: %s: %s" % (key, shown, counts, "worse" if bad else "no worse"))
    each = "%d run%s on the preview, %d on brickworks.diy" % (p.runs, "" if p.runs == 1 else "s", l.runs)
    if worse:
        return False, ["holds: the preview is worse than brickworks.diy beyond the noise (%s): %s"
                       % (each, "; ".join(worse))] + out
    return True, ["ships past: the preview no worse than brickworks.diy beyond the noise (%s)" % each] + out


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--battery", type=Path)
    ap.add_argument("--run", nargs=3, action="append", default=[], metavar=("SIDE", "EXIT", "LOG"))
    args = ap.parse_args(argv)
    try:
        battery = read_log(args.battery.read_text(errors="replace"), 1) if args.battery else []
    except OSError:
        battery = []
    runs = []
    for side, code, log in args.run:
        if side not in SIDES or not re.fullmatch(r"\d+", code):
            print("timing_judge: a run is P|L, its exit and its log, not %s %s %s" % (side, code, log))
            return 2
        try:
            text = Path(log).read_text(errors="replace")
        except OSError:
            text = ""
        runs.append((side, int(code), read_log(text, int(code))))
    ships, lines = judge(battery, runs)
    print("\n".join(lines))
    return 0 if ships else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
