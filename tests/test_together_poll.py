"""Build together's poll, a line at a time (presence, 2026-10-30).

A browser's poll is answered a line at a time: who is in it and where each
is working goes out the moment it changes, and the poll waits on, so a
pointer moved is never left waiting for the next poll to be asked
(api/together.js poll, src/net/together.gd _ask_page). The desktop's,
asked plainly, is answered whole as before. tests/fixtures/together/
poll_check.mjs runs the real handler against a session it keeps, the
database and the sign-in's keys stood in for by fetch.
"""

from __future__ import annotations

import functools
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


@functools.cache
def _run() -> dict:
    done = subprocess.run(["node", "tests/fixtures/together/poll_check.mjs"], cwd=ROOT, capture_output=True,
                          text=True, timeout=120)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


def test_a_pointer_moved_while_the_poll_waits_goes_out_as_a_line():
    lines = _run()["lines"]
    assert lines["type"] == "application/x-ndjson" and lines["status"] == 200
    # Who is in it at once, then the other's pointer, each a line of its own.
    assert lines["more"] == [True, True]
    assert lines["at"] == [None, [1, 2, 3]]
    assert lines["moved_ms"] is not None and lines["moved_ms"] < 600
    # The poll waited on, and ended with the change, as before.
    assert [op["seq"] for op in lines["last"]["ops"]] == [1]
    assert lines["last"]["seen"] == lines["seen_last"]


def test_a_poll_asked_plainly_is_answered_whole_as_before():
    whole = _run()["whole"]
    assert whole["type"] == "application/json" and whole["writes"] == 0
    assert whole["last"]["ops"] == [] and len(whole["last"]["people"]) == 2
    assert whole["ms"] < 1000


def test_a_refusal_after_the_first_line_is_said_in_the_last():
    refused = _run()["refused"]
    assert refused["writes"] >= 1
    assert refused["last"]["refused"] == 403
    assert "taken you out" in refused["last"]["error"]


def test_waiting_with_nobody_pointing_reads_no_more():
    reads = _run()["reads"]
    assert reads["lines"]["writes"] == 0
    for kind in ("ops", "people", "sessions"):
        assert abs(reads["lines"][kind] - reads["whole"][kind]) <= 1, reads
