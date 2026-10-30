"""The weekly AI showcase's gates (tools/showcase.py, gallery362).

A run on a busy box, or with the owner's Claude limits spent, must skip with
a line in the log and never wait or retry; the briefs go in turn; and the
timer ships switched off. These hold the gates to what heavy and Claude Code
really print.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import showcase  # noqa: E402

QUIET = """heavy: 24 slots (8 per project), 3 threads want a CPU (gate 30), load 4/5/6 of 24 cores, 94466 MB free
  held  slot.0   soniq             1069 s   python scripts/ci_local.py
"""
QUEUED = QUIET + "  wait  soniq            1793322229693543312-4070599-249951931  (priority)\n"
LOADED = """heavy: 24 slots (8 per project), 31 threads want a CPU (gate 30), load 32/34/29 of 24 cores, 94466 MB free
"""


def test_a_quiet_box_lets_a_run_in_and_a_busy_one_skips_it() -> None:
    assert showcase.heavy_busy(QUIET) == ""
    assert "wait in heavy's queue" in showcase.heavy_busy(QUEUED)
    assert "over heavy's gate of 30" in showcase.heavy_busy(LOADED)
    # Words heavy never printed are not a free box.
    assert showcase.heavy_busy("") and showcase.heavy_busy("something else")


def test_claude_s_limits_stop_a_run_and_an_answer_does_not() -> None:
    for said in ("Claude AI usage limit reached|1793330000", "You've hit your 5-hour limit · resets 3am",
                 '{"type":"result","is_error":true,"result":"OAuth session expired. Please run /login"}',
                 "OAuth token has expired"):
        assert showcase.claude_says(said), said
    assert showcase.claude_says('{"type":"result","is_error":false,"result":"ready"}') == ""


def test_the_briefs_go_in_turn_and_are_not_the_bench_s() -> None:
    every = showcase.briefs()
    assert len(every) >= 6 and all(re.fullmatch(r"[a-z0-9-]+", one["id"]) for one in every)
    assert showcase.next_brief(every, {})["id"] == every[0]["id"]
    made = {one["id"]: "2026-11-01" for one in every[:3]}
    assert showcase.next_brief(every, made)["id"] == every[3]["id"]
    # All made: the one made longest ago comes again.
    made = {one["id"]: f"2026-11-{n + 10:02d}" for n, one in enumerate(every)}
    made[every[5]["id"]] = "2026-10-01"
    assert showcase.next_brief(every, made)["id"] == every[5]["id"]
    from bench.ideas_briefs import IDEAS
    bench_words = {idea.brief for idea in IDEAS} | {idea.id for idea in IDEAS}
    assert not any(one["brief"] in bench_words or one["id"] in bench_words for one in every)
    assert not any(re.search(r"\bLEGO\b(?!®)", one["brief"] + one["title"]) for one in every)


def test_the_timer_ships_off_and_runs_the_script_under_its_own_gates() -> None:
    service = (ROOT / "tools/systemd/brickworks-showcase.service").read_text()
    timer = (ROOT / "tools/systemd/brickworks-showcase.timer").read_text()
    installer = (ROOT / "tools/install_showcase_timer.sh").read_text()
    assert "ExecStart=/usr/bin/python3 @ROOT@/tools/showcase.py run" in service
    assert "OnCalendar=" in timer and "WantedBy=timers.target" in timer
    commands = [line for line in installer.splitlines() if not line.lstrip().startswith("#")]
    assert not any("enable" in line and "is-enabled" not in line and "echo" not in line for line in commands)
    # The design itself in a heavy slot; the API key never reaches Claude.
    source = (ROOT / "tools/showcase.py").read_text()
    assert "os.execv(HEAVY, [HEAVY," in source and "ANTHROPIC_API_KEY" in source
    assert json.loads((ROOT / "tools/showcase_briefs.json").read_text())["briefs"]
