"""tools/release/timing_judge.py: a timing check's runs on a release's preview
and on brickworks.diy, by turns, judged by the numbers it prints. One run on
brickworks.diy was luck: rel-m287 held twice on play's phone bar while live
passed it, and the lead's A/B by hand found the preview no slower
(2026-11-11). The lines here are the checks' own, from release logs.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "release"))

import timing_judge as tj  # noqa: E402

PLAY_OPENS = ('  {} it opens playing "Open the gates", {} ms after the model is shown (under 3000; parts 9327, '
              'registered 9401, read 10510, pressed 10522, moving 12556; shapes here [27,27]; frames {{"moving":[49,1]}})  [64s]')
PLAY_DRAG = "  ok    the app's own work in a drag frame, on a CPU 4 times slower, stays under 36 ms on average ({} ms)  [62s]"


def _log(*lines: str) -> str:
    return "\n".join(["heavy: brickworks in slot.2 at load 36", *lines, "1 FAILED"])


def _opens(ms: float) -> str:
    return PLAY_OPENS.format("FAIL" if ms > 3000 else "ok  ", ms)


def test_each_timing_checks_measure_is_read_with_its_bar():
    cases = [
        (PLAY_DRAG.format(27.8), 27.8, 36),
        (_opens(3229), 3229, 3000),
        ("  FAIL  75969-1.mpd: Next #1, its worst frame's own work 216.1 ms of 200 (the page's wait 286.8 ms)", 216.1, 200),
        ("  ok    75969-1.mpd: an orbit's drawn frames, the app's own work at the 95th percentile 38.8 ms of 200 "
         "(median 27.5, worst 42.9; 41 drawn)", 38.8, 200),
        ("  ok    the app's own work in a drag frame stays under 33 ms: worst 6.94 ms  [41s]", 6.94, 33),
        ("  ok    the app's own work in a swing frame stays under 33 ms: mean 7.36, worst 10.01 ms over 19 frames  [73s]",
         10.01, 33),
        ("FAIL  bin        said       —  heard     never  own    385 ms (383 wall)  frame    389 ms  page held    392 ms  "
         "total     —  gone    [never finished]", 385, None),
        ("ok    booklet    said   15 ms  heard     56 ms  own     60 ms (204 wall)  frame    382 ms  page held    373 ms  "
         "total    3738 ms  gone  Planning the booklet…", 60, None),
    ]
    for text, value, bar in cases:
        (line,) = tj.read_log(text, 0)
        assert (line.value, line.bar) == (value, bar), (text, line)
        assert line.failed == ("FAIL" in text.split()[0]), text
    # Its key is the same whatever the run's figures, and says which line it is.
    assert tj.read_log(_opens(3229), 1)[0].key == tj.read_log(_opens(1670), 0)[0].key \
        == 'it opens playing "Open the gates", # ms (bar 3000)'
    steps = [tj.read_log("  ok    75969-1.mpd: Next #%d, its worst frame's own work 15.4 ms of 200" % n, 0)[0].key
             for n in (1, 2)]
    assert steps[0] != steps[1]
    rows = [tj.read_log("ok    bin        said       —  heard     never  own     53 ms (96 wall)", 0)[0].key,
            tj.read_log("ok    bin        said    3 ms  heard   ~40 ms  own     61 ms (96 wall)", 0)[0].key]
    assert rows[0] == rows[1] == "bin said # heard # own # ms", rows
    # The same words twice (a measure each size makes alike): each its own.
    twice = tj.read_log("\n".join(["  ok    the app's own work in a drag frame stays under 33 ms (2.28 ms worst)"] * 2), 0)
    assert twice[0].key != twice[1].key and twice[1].key.endswith(" #2")
    # A run that failed with no FAIL line is a failure of its own, counted.
    assert [(line.key, line.failed) for line in tj.read_log("Node.js v24.21.0", 1)] \
        == [("the run ended exit 1 with no FAIL line", True)]


def _run(side: str, *ms: float) -> tuple[str, int, list]:
    return (side, int(any(m > 3000 for m in ms)), tj.read_log(_log(PLAY_DRAG.format(30), *map(_opens, ms)), 0))


def test_rel_m287s_play_was_the_load_and_ships_past():
    # P L L P of the lead's A/B: rel-m287_pv's play had failed at 3324 ms.
    battery = tj.read_log(_log(_opens(3324)), 1)
    ships, lines = tj.judge(battery, [_run("P", 3229), _run("L", 2617), _run("L", 3054), _run("P", 2635)])
    assert ships, lines
    assert lines[0] == ("ships past: the preview no worse than brickworks.diy beyond the noise "
                        "(2 runs on the preview, 2 on brickworks.diy)")
    assert lines[1:] == ['it opens playing "Open the gates", # ms (bar 3000): here 3229 2635 (mean 2932), '
                         'there 2617 3054 (mean 2835.5) (in the battery 3324); noise 594; failed 1 of 2, 1 of 2: no worse']


def test_a_preview_clearly_worse_holds_and_one_over_the_bar_alike_ships():
    battery = tj.read_log(_log(_opens(3685)), 1)
    held, lines = tj.judge(battery, [_run("P", 3600), _run("L", 1900), _run("L", 2100), _run("P", 3800)])
    assert not held and lines[0].startswith("holds: the preview is worse than brickworks.diy beyond the noise"), lines
    assert lines[1].endswith("noise 200; failed 2 of 2, 0 of 2: worse"), lines
    # Within live's own spread it is not worse, nor failing alike within 2% of
    # the bar; past both, by a hair, it is.
    for p, l, worse in (((3300, 2500), (2400, 3100), False), ((3110, 3120), (3100, 3105), False),
                        ((3110, 3120), (2990, 3000), True)):
        ships, lines = tj.judge(battery, [_run("P", p[0]), _run("L", l[0]), _run("L", l[1]), _run("P", p[1])])
        assert ships != worse, lines
    # Over the bar on both sides alike: shipped past, and the lines say both fail.
    ships, lines = tj.judge(battery, [_run("P", 3400), _run("L", 3500), _run("L", 3300), _run("P", 3350)])
    assert ships and lines[1].endswith("failed 2 of 2, 2 of 2: no worse"), lines


def test_what_cannot_be_compared_holds():
    battery = tj.read_log(_log(_opens(3324)), 1)
    # brickworks.diy never printed the measure (its build lacks what the check does).
    bare = ("L", 1, tj.read_log(_log("  FAIL  the link went on to the viewer with its motion: /m/x?motion=y"), 1))
    held, lines = tj.judge(battery, [_run("P", 2000), bare, bare, _run("P", 2100)])
    assert not held and "brickworks.diy never printed it" in lines[1], lines
    # A step that failed on the preview only, counted.
    step = ("P", 1, tj.read_log(_log(_opens(2000), "  FAIL  its button lit, and the pill says how to stop it: \"undefined\""), 1))
    held, lines = tj.judge(battery, [step, _run("L", 2000), _run("L", 2100), _run("P", 2000)])
    assert not held and any(line.endswith("failed 1 of 2, 0 of 2: worse") for line in lines), lines
    # No run on one side finished: the live database stayed busy each time (exit 75).
    busy = ("L", 75, [])
    held, lines = tj.judge(battery, [_run("P", 2000), busy, busy, _run("P", 2100)])
    assert not held and lines == ["holds: no run on brickworks.diy finished, so there is nothing to compare"]


def test_its_command_line_exits_by_the_verdict(tmp_path):
    logs = {}
    for name, ms in (("pv", 3324), ("P1", 3229), ("L2", 2617), ("L3", 3054), ("P4", 2635)):
        logs[name] = tmp_path / ("%s.log" % name)
        logs[name].write_text(_log(_opens(ms)))
    judge = [sys.executable, str(ROOT / "tools/release/timing_judge.py"), "--battery", str(logs["pv"])]
    runs = ["--run", "P", "1", str(logs["P1"]), "--run", "L", "0", str(logs["L2"]),
            "--run", "L", "1", str(logs["L3"]), "--run", "P", "0", str(logs["P4"])]
    done = subprocess.run(judge + runs, capture_output=True, text=True)
    assert done.returncode == 0 and done.stdout.startswith("ships past: "), done.stdout + done.stderr
    logs["P4"].write_text(_log(_opens(4200)))
    logs["P1"].write_text(_log(_opens(4400)))
    done = subprocess.run(judge + runs, capture_output=True, text=True)
    assert done.returncode == 1 and done.stdout.startswith("holds: "), done.stdout + done.stderr
    done = subprocess.run(judge + ["--run", "X", "0", str(logs["P1"])], capture_output=True, text=True)
    assert done.returncode == 2, done.stdout
