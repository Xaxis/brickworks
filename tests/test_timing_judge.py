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
        # Judged by the app's own work since webfaults, the clock said beside it.
        ('  ok    it opens playing "Open the gates", the app\'s own work 1404 ms after the model is shown, under 2000 '
         '(page 710 ms in 7 frames, the joints read 414 ms, the gates worked out 280.9 ms; by the clock 3956 ms: '
         'parts 6669, registered 8858, read 10098, pressed 10272, moving 10625; shapes here [27,27]; '
         'frames {"moving":[41,13]})  [64s]', 1404, 2000),
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
    bare = ("L", 1, tj.read_log(_log(PLAY_DRAG.format(31), "  FAIL  the link went on to the viewer with its motion: "
                                      "/m/x?motion=y"), 1))
    held, lines = tj.judge(battery, [_run("P", 2000), bare, bare, _run("P", 2100)])
    assert not held and "brickworks.diy never printed it" in lines[1], lines
    # A step that failed on the preview only, counted.
    step = ("P", 1, tj.read_log(_log(_opens(2000), "  FAIL  its button lit, and the pill says how to stop it: \"undefined\""), 1))
    held, lines = tj.judge(battery, [step, _run("L", 2000), _run("L", 2100), _run("P", 2000)])
    assert not held and any(line.endswith("failed 1 of 2, 0 of 2: worse") for line in lines), lines
    # Runs that timed nothing anywhere, failing alike: a flow that could not
    # start (no node_modules in a worktree) is no load.
    crash = tj.read_log("Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'playwright'\nNode.js v24.21.0", 1)
    held, lines = tj.judge(battery, [("P", 1, crash), ("L", 1, crash), ("L", 1, crash), ("P", 1, crash)])
    assert not held and lines[0].startswith("holds: no measure was timed on both sides"), lines
    # No run on one side finished: the live database stayed busy each time (exit 75).
    busy = ("L", 75, [])
    held, lines = tj.judge(battery, [_run("P", 2000), busy, busy, _run("P", 2100)])
    assert not held and lines == ["holds: no run on brickworks.diy finished, so there is nothing to compare"]


PLACED = ("parts: 9 of 11 put where their ghosts stood; 2 of 4 as the file has them\n"
          "  (storage mirror: 170 cache (5.0 MB); the bucket asked 0 time(s))")


# grab_flow's lines as rel-m343's A/B printed them (2026-11-26), shortened.
GRAB_START = [
    "  ok    the app came up  [13s]",
    "  ok    the crane opened: 29 parts  [50s]",
    "  ok    the arm and the turret are there to take hold of: 3937 on its turntable, 3795 on its hinge  [54s]",
    "  ok    while the button is down the arm turns on its hinge: 37.8° (the Plate 2 x 6, 2 parts on its hinge)  [65s]",
    "  ok    the app's own work in a drag frame stays under 33 ms: worst 5.79 ms  [65s]",
    "  ok    a crank of the four-bar is there to take hold of (3937 on its turntable, 3673 on its pin)  [79s]",
]
GRAB_WENT = [
    "  ok    the loop carried what the crank does not hold: 32316, 32524 moved  [86s]",
    "  ok    the pendulum's beam is there to take hold of  [94s]",
    "  ok    the beam turns out on its free pin: 66.8°  [94s]",
    "  ok    the flywheel is there to take hold of (3937 on its turntable, 3673 on its pin)  [115s]",
    "  ok    the flywheel turns on its axle while the button is down: 106.6° (the Technic Gear 40 Tooth)  [119s]",
]
GRAB_STUCK = [
    "  FAIL  the loop carried what the crank does not hold: nothing moved  [107s]",
    "  FAIL  the pendulum's beam is there to take hold of  [128s]",
    "  FAIL  the flywheel is there to take hold of (none)  [148s]",
]
GRAB_END = ["  ok    the tube and its arm opened: 58 parts  [124s]", "  ok    no script errors ()  [137s]"]
# Stopped by the same race a step earlier: the rest of the flow never ran.
GRAB_STOPPED = GRAB_START[:5] + ["  FAIL  stopped: Cannot read properties of null (reading 'handles')  [85s]",
                                 "        picture: /tmp/brickworks-release/rel-m343_ab_grab_L2_grab_web/stopped.png",
                                 "  ok    no script errors ()  [85s]"]


def _grab(*parts: list[str]) -> tuple[int, list]:
    lines = [one for part in parts for one in part]
    return int(any(" FAIL " in one for one in lines)), tj.read_log("\n".join(lines), 0)


def test_a_line_a_run_never_got_to_is_not_run_and_failed_on_its_side():
    # rel-m343's grab: P1 passed, live's L2 stopped early on the race, L3
    # passed, P4 failed the three steps. Counted as passes, L2's unrun lines
    # made live 0 of 2 against the preview's 1 of 2, and the A/B held.
    went, stuck, stopped = _grab(GRAB_START, GRAB_WENT, GRAB_END), _grab(GRAB_START, GRAB_STUCK, GRAB_END), \
        _grab(GRAB_STOPPED)
    runs = [("P", *went, "P1"), ("L", *stopped, "L2"), ("L", *went, "L3"), ("P", *stuck, "P4")]
    ships, lines = tj.judge([], runs)
    assert ships, lines
    assert lines[0] == ("ships past: the preview no worse than brickworks.diy beyond the noise (2 runs on the "
                        "preview, 2 on brickworks.diy; L2 on brickworks.diy never got to 3 of the lines judged, "
                        "each counted failed there)"), lines
    assert lines[1:] == [
        "the loop carried what the crank does not hold: nothing moved: failed 1 of 2, 1 of 2 (L2 never got to it): "
        "no worse",
        "the pendulum's beam is there to take hold of: failed 1 of 2, 1 of 2 (L2 never got to it): no worse",
        "the flywheel is there to take hold of (none): failed 1 of 2, 1 of 2 (L2 never got to it): no worse"], lines
    # The same runs without the names: each by its side and place.
    ships, lines = tj.judge([], [run[:3] for run in runs])
    assert ships and "L2 on brickworks.diy never got to 3" in lines[0], lines
    # Live through to its end in both runs: the preview's three are its own.
    held, lines = tj.judge([], [("P", *went, "P1"), ("L", *went, "L2"), ("L", *went, "L3"), ("P", *stuck, "P4")])
    assert not held and all(line.endswith("failed 1 of 2, 0 of 2: worse") for line in lines[1:]), lines
    assert "never got to" not in lines[0], lines


def test_the_preview_stopping_early_holds_and_a_run_that_went_on_is_never_not_run():
    went, stuck, stopped = _grab(GRAB_START, GRAB_WENT, GRAB_END), _grab(GRAB_START, GRAB_STUCK, GRAB_END), \
        _grab(GRAB_STOPPED)
    # The preview's P1 stopped where live went through: its stop is the
    # preview's own, and the steps after it failed on the preview's side.
    # Live's L3 failed a line of its own and went on: it got past the stop.
    slow = _grab([line.replace("ok    the app's own work in a drag frame stays under 33 ms: worst 5.79",
                               "FAIL  the app's own work in a drag frame stays under 33 ms: worst 41.2")
                  for line in GRAB_START], GRAB_WENT, GRAB_END)
    held, lines = tj.judge([], [("P", *stopped, "P1"), ("L", *went, "L2"), ("L", *slow, "L3"), ("P", *stuck, "P4")])
    assert not held, lines
    assert lines[0].startswith("holds: ") and "P1 on the preview never got to 3 of the lines judged" in lines[0], lines
    assert "L2 on" not in lines[0] and "L3 on" not in lines[0], lines
    said = {line.split(": failed")[0]: line for line in lines[1:]}
    assert said["stopped: Cannot read properties of null (reading 'handles')"].endswith(
        "failed 1 of 2, 0 of 2: worse"), said
    assert said["the pendulum's beam is there to take hold of"].endswith(
        "failed 2 of 2, 0 of 2 (P1 never got to it): worse"), said
    # A run that passed went to its end, whatever it printed: never not run
    # (here live's run takes no flywheel at all).
    bare = _grab(GRAB_START, GRAB_WENT[:3], GRAB_END)
    held, lines = tj.judge([], [("P", *went, "P1"), ("L", *bare, "L2"), ("L", *bare, "L3"), ("P", *stuck, "P4")])
    assert not held and "never got to" not in "\n".join(lines), lines


def test_the_command_line_names_each_run_as_live_ab_does(tmp_path):
    logs = {}
    for name, parts in (("P1", (GRAB_START, GRAB_WENT, GRAB_END)), ("L2", (GRAB_STOPPED,)),
                        ("L3", (GRAB_START, GRAB_WENT, GRAB_END)), ("r1P4", (GRAB_START, GRAB_STUCK, GRAB_END))):
        logs[name] = tmp_path / ("rel-m343_ab_grab_%s_grab.log" % name)
        logs[name].write_text("\n".join(line for part in parts for line in part))
    done = subprocess.run([sys.executable, str(ROOT / "tools/release/timing_judge.py"),
                           "--run", "P", "0", str(logs["P1"]), "--run", "L", "1", str(logs["L2"]),
                           "--run", "L", "0", str(logs["L3"]), "--run", "P", "1", str(logs["r1P4"])],
                          capture_output=True, text=True)
    assert done.returncode == 0, done.stdout + done.stderr
    assert "L2 on brickworks.diy never got to 3 of the lines judged" in done.stdout, done.stdout


def test_a_check_with_no_measure_that_passes_every_run_by_turns_ships():
    # rel-m301's placing: the battery's run ended exit 1 with no FAIL line,
    # and P L L P each exited 0 printing no ok or FAIL line at all. It held,
    # "no measure was timed on both sides".
    battery = tj.read_log("Node.js v24.21.0", 1)
    passed = tj.read_log(PLACED, 0)
    ships, lines = tj.judge(battery, [("P", 0, passed), ("L", 0, passed), ("L", 0, passed), ("P", 0, passed)])
    assert ships, lines
    assert lines == ["ships past: passed 2 of 2 by turns on the preview (2 of 2 on brickworks.diy), "
                     "with no measure timed on both sides to compare",
                     "the run ended exit 1 with no FAIL line: failed 0 of 2, 0 of 2"]
    # One of the preview's runs failing, crashing or saying FAIL, holds.
    crash = tj.read_log("Node.js v24.21.0", 1)
    said = tj.read_log("  FAIL  4081b clip plate: the search would not put it in hand", 0)
    for bad in (("P", 1, crash), ("P", 0, said)):
        held, lines = tj.judge(battery, [("P", 0, passed), ("L", 0, passed), ("L", 0, passed), bad])
        assert not held and lines[0].startswith("holds: no measure was timed on both sides"), lines


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
