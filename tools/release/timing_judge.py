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
counted line, failed in more of the preview's runs than live's, where a
failed run that never got to the line (it stopped before it: printed
nothing from there on but the lines every run ends on) failed it, as the
verdict says ("L2 never got to it"; rel-m343, 2026-11-26); a measure
live never printed, always; and the whole check, when no measure was timed
on both sides (runs that could not start fail alike, and are no load),
unless every run on the preview passed: then it ships past, "passed N of N
by turns" (rel-m301's placing, which times nothing, held so). One
run a side is luck: rel-m287's play held twice on the phone's 3000 ms bar,
3324 and 3685 against live's 1267 and 1953, and played P L L P P L the
preview was no slower (2511 vs 2809 ms mean); live failed the same bar in 1
run of 3 (2026-11-11).

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
# A line's words up to their detail: what an ok and a FAIL of one step share.
STEM = re.compile(r": | \(")
# The run did not happen: the live database stayed busy, the probes had
# failed, or the check has no such name (preview_checks.sh).
NOT_RUN = {75, 125, 127}


@dataclass
class Line:
    key: str
    failed: bool
    value: float | None
    bar: float | None
    # Where it stands in its run, however it went: its words up to their
    # detail ("the flywheel is there to take hold of", whether "(none)" or
    # its handles follow), and which time in the run they came. "" for a
    # line no step printed (the run's own end, read_log).
    stem: str = ""
    nth: int = 0


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
    lines, seen, stems = [], {}, {}
    for raw in text.splitlines():
        m = SAID.match(raw)
        if not m or not m.group(2):
            continue
        line = read_line(m.group(2), m.group(1) == "FAIL")
        line.stem = STEM.split(line.key, 1)[0].strip()
        stems[line.stem] = line.nth = stems.get(line.stem, 0) + 1
        # The same words twice in a run (a measure each size makes alike):
        # each its own, in order.
        seen[line.key] = seen.get(line.key, 0) + 1
        if seen[line.key] > 1:
            line.key += " #%d" % seen[line.key]
        lines.append(line)
    if code != 0 and not any(line.failed for line in lines):
        lines.append(Line("the run ended exit %d with no FAIL line" % code, True, None, None))
    return lines


def _got_to(lines: list[Line], mark: tuple[str, int], refs: list[list[Line]]) -> bool:
    """Whether a run that failed, and never printed the line [mark] stands
    for, got as far as where it stands in [refs], the runs that did print
    it: it printed a line that comes after it there, or the line before it
    and then a line of its own said ok (its own way on: a step the other
    side stopped at, it went through). The lines both runs end on, however
    they ended ("no script errors"), are no sign of how far either got."""
    places = [(line.stem, line.nth) for line in lines]
    for ref in refs:
        there = [(line.stem, line.nth) for line in ref]
        at = there.index(mark)
        ends = 0
        while ends < min(len(places), len(there) - at - 1) and places[-1 - ends] == there[-1 - ends]:
            ends += 1
        body, mine = lines[:len(lines) - ends], places[:len(places) - ends]
        if set(mine) & set(there[at + 1:len(there) - ends]):
            return True
        if at == 0:
            on = body
        elif there[at - 1] in mine:
            on = body[len(mine) - mine[::-1].index(there[at - 1]):]
        else:
            continue
        if any(not line.failed for line in on):
            return True
    return False


@dataclass
class Side:
    runs: int = 0
    # Runs that exited 0 with no FAIL line.
    passed: int = 0
    values: dict[str, list[float]] = field(default_factory=dict)
    fails: dict[str, int] = field(default_factory=dict)
    said: set[str] = field(default_factory=set)


def _fig(v: float) -> str:
    return "%g" % round(v, 1)


def judge(battery: list[Line], runs: list[tuple]) -> tuple[bool, list[str]]:
    """Each run is (SIDE, EXIT, its lines) or (SIDE, EXIT, its lines, its
    name: live_ab's L2); unnamed, it is its side and its place, 1 on."""
    sides = {"P": Side(), "L": Side()}
    bars: dict[str, float] = {}
    order: list[str] = []
    # Where each line judged stands: the first that failed it, in the battery or a run.
    marks: dict[str, tuple[str, int]] = {}
    for line in battery:
        if line.failed and line.key not in order:
            order.append(line.key)
            marks[line.key] = (line.stem, line.nth)
    judged: list[tuple[str, str, bool, list[Line]]] = []
    for n, run in enumerate(runs):
        side, code, lines = run[:3]
        if code in NOT_RUN and not lines:
            continue
        s = sides[side]
        s.runs += 1
        passed = code == 0 and not any(line.failed for line in lines)
        if passed:
            s.passed += 1
        judged.append((side, run[3] if len(run) > 3 else "%s%d" % (side, n + 1), passed, lines))
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
                    marks[line.key] = (line.stem, line.nth)
    p, l = sides["P"], sides["L"]
    for side in ("P", "L"):
        if not sides[side].runs:
            return False, ["holds: no run on %s finished, so there is nothing to compare" % SIDES[side]]
    # A line judged that a run never got to was not run there, and that run
    # failed it on its side: one that passed went to its end. rel-m343's
    # A/B counted the lines brickworks.diy's L2 never reached, stopped early
    # ("reading 'handles'") by the very race the preview failed them on, as
    # passes, said live failed them 0 of 2, and held a release a day on what
    # live failed too (2026-11-26).
    places = [[(line.stem, line.nth) for line in lines] for _, _, _, lines in judged]
    battery_places = [(line.stem, line.nth) for line in battery]
    not_run: dict[str, dict[str, list[str]]] = {key: {"P": [], "L": []} for key in order}
    for k, (side, name, passed, lines) in enumerate(judged):
        keys = {line.key for line in lines}
        for key in order:
            mark = marks[key]
            if passed or key in keys or not mark[0] or mark in places[k]:
                continue
            refs = [judged[j][3] for j in range(len(judged)) if mark in places[j]]
            if mark in battery_places:
                refs.append(battery)
            if not _got_to(lines, mark, refs):
                not_run[key][side].append(name)

    def failed(key: str, side: str) -> int:
        return sides[side].fails.get(key, 0) + len(not_run[key][side])

    def counts(key: str) -> str:
        names = not_run[key]["P"] + not_run[key]["L"]
        return "failed %d of %d, %d of %d%s" % (failed(key, "P"), p.runs, failed(key, "L"), l.runs,
                                               " (%s never got to it)" % ", ".join(names) if names else "")

    stopped: dict[tuple[str, str], int] = {}
    for key in order:
        for side in ("P", "L"):
            for name in not_run[key][side]:
                stopped[(side, name)] = stopped.get((side, name), 0) + 1
    said_so = "".join("; %s on %s never got to %d of the lines judged, each counted failed there"
                      % (name, SIDES[side], many) for (side, name), many in stopped.items())
    # Runs that timed nothing on one side or the other measured nothing: a
    # flow that could not start (a worktree with no node_modules) fails on
    # both alike, and is no load. Unless the preview passed every run: a
    # check that times nothing and passes each time by turns is the load's
    # (rel-m301's placing held, its four runs all passed).
    if not any(l.values.get(key) for key in p.values):
        if p.passed == p.runs:
            return True, ["ships past: passed %d of %d by turns on the preview (%d of %d on brickworks.diy), "
                          "with no measure timed on both sides to compare%s"
                          % (p.passed, p.runs, l.passed, l.runs, said_so)] \
                + ["%s: %s" % (key, counts(key)) for key in order]
        return False, ["holds: no measure was timed on both sides, so there is nothing to compare (%d runs on "
                       "the preview, %d on brickworks.diy)" % (p.runs, l.runs)]
    first = {line.key: line.value for line in battery if line.value is not None}
    out, worse = [], []
    for key in order:
        pv, lv = p.values.get(key, []), l.values.get(key, [])
        shown = " (in the battery %s)" % _fig(first[key]) if key in first else ""
        if pv and key not in l.said:
            worse.append(key)
            out.append("%s: here %s, %s never printed it%s; %s: worse" % (
                key, " ".join(map(_fig, pv)), SIDES["L"], shown, counts(key)))
        elif pv and lv:
            mp, ml = sum(pv) / len(pv), sum(lv) / len(lv)
            bar = bars.get(key)
            noise = max(max(pv) - min(pv), max(lv) - min(lv), 0.02 * (bar if bar is not None else ml))
            bad = mp > ml + noise
            if bad:
                worse.append(key)
            out.append("%s: here %s (mean %s), there %s (mean %s)%s; noise %s; %s: %s" % (
                key, " ".join(map(_fig, pv)), _fig(mp), " ".join(map(_fig, lv)), _fig(ml), shown, _fig(noise),
                counts(key), "worse" if bad else "no worse"))
        else:
            bad = failed(key, "P") > failed(key, "L")
            if bad:
                worse.append(key)
            out.append("%s%s: %s: %s" % (key, shown, counts(key), "worse" if bad else "no worse"))
    each = "%d run%s on the preview, %d on brickworks.diy%s" % (p.runs, "" if p.runs == 1 else "s", l.runs, said_so)
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
        # Named as live_ab names it (TAG_ab_NAME_L2_NAME.log, a kept round's r1L2), else by its place.
        named = re.findall(r"_((?:r\d+)?[PL]\d+)_", Path(log).name)
        runs.append((side, int(code), read_log(text, int(code)), named[-1] if named else "%s%d" % (side, len(runs) + 1)))
    ships, lines = judge(battery, runs)
    print("\n".join(lines))
    return 0 if ships else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
