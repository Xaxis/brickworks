"""Finding and stopping a run must not take the shells watching it.

``pgrep -f <pattern>`` matches the command line of the shell that asked,
so it answers "running" about a process that has exited — four times in
one sitting, before tools/running.py existed.  Stopping has the same
fault one step on: a wait loop polling for the run holds the pattern in
its own command line, and killing everything that matches ended two
background waiters along with the run.

The second of these was claimed in a docstring before it was true.  The
test is what said so.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import running  # noqa: E402


MARK = "brickworks_test_marker_run"


def _spawn(command: list[str]) -> subprocess.Popen:
    """Its own session, so nothing here can be reached by a group kill."""
    return subprocess.Popen(command, start_new_session=True,
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL)


def _ended(process: subprocess.Popen) -> bool:
    """Whether it really stopped, reaping it so a zombie is not mistaken
    for a survivor.

    ``os.kill(pid, 0)`` succeeds on a child that has died and not been
    waited for, so the first version of this test said the run had
    survived while holding its exit status of -SIGTERM in its hand.
    """
    try:
        return process.wait(timeout=5) is not None
    except subprocess.TimeoutExpired:
        return False


def test_a_wait_loop_is_not_the_work() -> None:
    assert running.waiting(
        "bash -c until ! pgrep -f %s; do sleep 2; done" % MARK)
    assert running.waiting("python3 tools/running.py %s" % MARK)
    # A run wrapped in a timeout is still the run.
    assert not running.waiting("timeout 3400 python3 tools/design.py a castle")
    assert not running.waiting("godot --path . --script src/dev/x.gd")


def test_stop_ends_the_run_and_spares_the_waiter() -> None:
    work = _spawn(["bash", "-c", "exec -a %s sleep 120" % MARK])
    waiter = _spawn(["bash", "-c",
                     "until ! pgrep -f %s >/dev/null; do sleep 1; done" % MARK])
    try:
        time.sleep(1.5)
        found = {pid for pid, _args in running.matches(MARK)}
        assert work.pid in found, "the run itself was not found"
        assert waiter.pid in found, "the waiter holds the pattern too"

        ended, spared = running.stop(MARK)
        assert work.pid in {pid for pid, _a in ended}
        assert waiter.pid in {pid for pid, _a in spared}

        assert _ended(work), "the run should have been ended"
        assert work.returncode == -signal.SIGTERM, \
            "ended by something other than our own signal: %s" % work.returncode
        time.sleep(1.5)
        assert waiter.poll() is None, \
            "the waiting shell should have been spared"
    finally:
        for process in (work, waiter):
            try:
                os.kill(process.pid, signal.SIGKILL)
            except OSError:
                pass
            process.wait(timeout=5)


def test_nothing_matching_is_not_an_error() -> None:
    ended, spared = running.stop("brickworks_nothing_like_this")
    assert ended == [] and spared == []
