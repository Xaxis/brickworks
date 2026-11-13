"""live_ab.sh: a reship of the same preview judges its runs with the earlier rounds'; a new preview starts over.

rel-m290's play held twice on two runs a side, its verdict flipping between sizes while brickworks.diy alone swung
1956 ms; pooled, four a side, it was no worse (2026-11-12).
"""
import os
import pathlib
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]

# The check as preview_checks.sh runs it: its .out line and a log with one measure, the next number of
# STUB_HERE's (the preview) or STUB_THERE's (the live site), failing over the bar of 100.
STUB = """#!/bin/bash
P=$1 OUT=$3 c=$4
S=$RELEASE_OUT
side=${OUT##*_}; side=${side:0:1}
nums=$STUB_HERE; [ "$side" = L ] && nums=$STUB_THERE
k=$(cat "$S/count.$side" 2>/dev/null || echo 0); echo $((k + 1)) > "$S/count.$side"
read -r -a each <<< "$nums"; ms=${each[$k]:-50}
if [ "$ms" -gt 100 ]; then said=FAIL; echo "$c exit=1 fails=1 1s :: FAIL" > "$S/$OUT.out"
else said=ok; echo "$c exit=0 fails=0 1s :: passed" > "$S/$OUT.out"; fi
echo "  $said  the stand-in's own work stays under 100 ms on average ($ms ms)  [1s]" > "$S/${OUT}_$c.log"
"""


def _here(tmp: pathlib.Path) -> pathlib.Path:
    here = tmp / "here"
    here.mkdir()
    (here / "preview_checks.sh").write_text(STUB)
    (here / "preview_checks.sh").chmod(0o755)
    shutil.copy(ROOT / "tools/release/timing_judge.py", here / "timing_judge.py")
    return here


def _round(tmp: pathlib.Path, here: pathlib.Path, preview: str, mine: str, theirs: str) -> tuple[int, str]:
    out = tmp / "out"
    out.mkdir(exist_ok=True)
    for side in "PL":
        (out / f"count.{side}").unlink(missing_ok=True)
    (out / "t-m9_pv_play.log").write_text("  FAIL  the stand-in's own work stays under 100 ms on average (150 ms)  [1s]\n")
    env = dict(os.environ, RELEASE_HERE=str(here), RELEASE_OUT=str(out), STUB_HERE=mine, STUB_THERE=theirs)
    run = subprocess.run(["bash", str(ROOT / "tools/release/live_ab.sh"), str(tmp), "t-m9", "play", preview],
                         env=env, capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=120)
    return run.returncode, (out / "t-m9_ab_play.judge").read_text()


def test_a_second_round_on_the_same_preview_is_judged_with_the_first(tmp_path):
    here = _here(tmp_path)
    # Alone, the first round holds: the preview 120, 125 against 60, 62.
    code, judge = _round(tmp_path, here, "https://p1", "120 125", "60 62")
    assert code == 1, judge
    assert "here 120 125" in judge and "there 60 62" in judge, judge
    # Alone, the second round would hold too (95, 99 against 60, 61), but with the first the live site's own
    # numbers swing as far: 60 62 60 61 against the preview's 120 125 95 99 is still worse, so it holds...
    code, judge = _round(tmp_path, here, "https://p1", "95 99", "60 61")
    assert "2 runs on the preview" not in judge and "4 runs on the preview, 4 on brickworks.diy" in judge, judge
    assert "here 120 125 95 99" in judge or "here 95 99 120 125" in judge, judge
    assert code == 1, judge
    # ...and a third round where they cross shows the swing: pooled, no worse.
    code, judge = _round(tmp_path, here, "https://p1", "40 45", "130 140")
    assert "6 runs on the preview, 6 on brickworks.diy" in judge, judge
    assert code == 0, judge
    kept = (tmp_path / "out" / "t-m9_ab_play.kept").read_text().splitlines()
    assert len(kept) == 8 and all(pathlib.Path(line.split()[2]).exists() for line in kept), kept


def test_a_new_preview_starts_over(tmp_path):
    here = _here(tmp_path)
    _round(tmp_path, here, "https://p1", "40 45", "130 140")
    code, judge = _round(tmp_path, here, "https://p2", "120 125", "60 62")
    assert "2 runs on the preview, 2 on brickworks.diy" in judge, judge
    assert code == 1, judge
    assert not (tmp_path / "out" / "t-m9_ab_play.kept").exists()
