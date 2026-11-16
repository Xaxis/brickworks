"""Build together's poll, a line at a time, and its pointers told at once
(presence, 2026-10-30).

A browser's poll is answered a line at a time: who is in it and where each
is working goes out the moment it changes, and the poll waits on, so a
pointer moved is never left waiting for the next poll to be asked
(api/together.js poll, src/net/together.gd _ask_page). The desktop's,
asked plainly, is answered whole as before. A pointer sent is told to every
poll waiting in the session on the session's own channel of the database's
Realtime (api/together.js channelOf), so it goes out without waiting for a
read of who is in it. tests/fixtures/together/poll_check.mjs runs the real
handler against a session it keeps, the database, its Realtime and the
sign-in's keys stood in for.
"""

from __future__ import annotations

import functools
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
# api/together.js's: a step of a poll's wait, and how often in it who is in
# it and the session are read again.
POLL_MS, PEOPLE_MS, SESSION_MS = 100, 250, 1000


@functools.cache
def _run() -> dict:
    done = subprocess.run(["node", "tests/fixtures/together/poll_check.mjs"], cwd=ROOT, capture_output=True,
                          text=True, timeout=300)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def _times(log: list, what: str) -> list[int]:
    return [at for kind, at in log if kind == what]


def _no_more_often(log: list, where) -> None:
    """Who is in it read no sooner after the last read of them than
    PEOPLE_MS, the changes POLL_MS, the session SESSION_MS: barred by how
    often, not by how many reads fit in a second, which a busy box makes
    fewer, never more (rel-m305's gate, 4 reads of the changes in one second
    against 10 in the next, failed on that, pollreads 2026-11-16). 2 ms for
    a timer's and a clock's rounding."""
    for what, every in (("GET together_people", PEOPLE_MS), ("GET together_ops", POLL_MS),
                        ("GET together_sessions", SESSION_MS)):
        times = _times(log, what)
        assert all(b - a >= every - 2 for a, b in zip(times, times[1:])), (where, what, times)


pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


def test_a_pointer_moved_while_the_poll_waits_goes_out_as_a_line():
    lines = _run()["lines"]
    assert lines["type"] == "application/x-ndjson" and lines["status"] == 200
    # Who is in it at once, then the other's pointer, each a line of its own.
    assert lines["more"] == [True, True]
    assert lines["at"] == [None, [1, 2, 3]]
    # Less what the box did not let the fixture run for (poll_check.mjs).
    assert lines["moved_ms"] is not None and lines["moved_ms"] - lines["stalled"] < 600, lines
    # The poll waited on, and ended with the change, as before.
    assert [op["seq"] for op in lines["last"]["ops"]] == [1]
    assert lines["last"]["seen"] == lines["seen_last"]


def test_a_poll_asked_plainly_is_answered_whole_as_before():
    whole = _run()["whole"]
    assert whole["type"] == "application/json" and whole["writes"] == 0
    assert whole["last"]["ops"] == [] and len(whole["last"]["people"]) == 2
    assert whole["ms"] - whole["stalled"] < 1000, whole


def test_a_refusal_after_the_first_line_is_said_in_the_last():
    refused = _run()["refused"]
    assert refused["writes"] >= 1
    assert refused["last"]["refused"] == 403
    assert "taken you out" in refused["last"]["error"]


def test_waiting_with_nobody_pointing_reads_no_more():
    # Asked a line at a time, asked plainly, and a line at a time with its
    # channel joining slower than a read: each waits, and reads no more often
    # than its steps allow. (Each against the other in turn, one second each,
    # it failed under load before pointfix as after: bugbar's gate, 11-13.)
    for asked, reads in _run()["reads"].items():
        assert reads["writes"] == 0, (asked, reads)
        assert reads["ops"] >= 1 and reads["people"] >= 1, (asked, reads)
        _no_more_often(reads["log"], asked)


def test_a_poll_reads_who_is_in_it_once_as_it_begins_however_slow_its_channel():
    # pollreads (2026-11-16): who is in it read once as a poll begins, once
    # its channel listens; not read, then read again the moment it joined
    # (pointfix's first way), which on Vercel was every poll that waited:
    # Realtime's join takes longer than a read. Its channel joining in 5 ms;
    # in 120, slower than a read of 20 ms, on purpose; and in 400, slower
    # than PEOPLE_MS, so not waited for.
    for case in _run()["begins"]:
        where = (case["joinMs"], case["readMs"], case["joined"])
        log = case["log"]
        assert case["writes"] == 0 and len(_times(log, "PATCH together_people")) == 1, (where, log)
        people = _times(log, "GET together_people")
        # The session and who is in it read together, first: one beside the other.
        kinds = [what for what, _ in log if what.startswith("GET together_") and what != "GET together_ops"]
        assert people and kinds[:2] == ["GET together_sessions", "GET together_people"], (where, log)
        _no_more_often(log, where)
        if case["joinMs"] < PEOPLE_MS:
            assert case["joined"] is not None and people[0] >= case["joined"], (where, log)
        else:
            assert case["joined"] is None or people[0] <= case["joined"], (where, log)


def test_a_change_made_as_a_poll_begins_waits_for_no_channel():
    changed = _run()["changed"]
    # Made 30 ms into a poll whose channel joins at 240: given at the poll's
    # next read of the changes (each POLL_MS while it joins, as before
    # pollreads waited them for the join: 516 ms browser to browser at p50
    # on the preview, against 432), not once it has joined; reading them,
    # and who is in it, no more often than ever.
    assert changed["ops"] == [1], changed
    assert changed["ms"] - changed["stalled"] < POLL_MS + 50, changed
    _no_more_often(changed["log"], "changed")


def test_a_pointer_sent_goes_out_at_once_without_a_read():
    for asked in ("lines", "whole"):
        told = _run()["told"][asked]
        # Its reads of who is in it showed them as before it was sent, so the
        # line with it went out without one (a read beside it counted none,
        # since a busy box's pause lets one fall due between: pollreads).
        assert told["heard"] and [4, 5, 6] in told["shown"], (asked, told)
        # From the server telling the channel to the line, less what the box
        # did not let the fixture run for; the send's own way in (its sign-in
        # check waits on the thread pool a busy box keeps: 81 ms in 1 of 20
        # under heavy with 2 ms stalled, pollreads) is not the relay's.
        assert told["relay_ms"] - told["relay_stalled"] < 50, (asked, told)


def test_nobody_outside_the_session_is_shown_by_the_channel():
    for asked in ("lines", "whole"):
        told = _run()["told"][asked]
        # A stranger's point is refused, and their pointer said on the
        # channel all the same changes nothing a poll gives.
        assert told["stranger_status"] == 403 and told["quiet"] == 0 and not told["strangers_shown"]
    taken_out = _run()["told"]["taken_out"]
    assert taken_out["point_status"] == 403 and not taken_out["shown"]


def test_somebody_pointing_reads_no_more_than_nobody():
    run = _run()
    listening, unheard = run["pointing"]["listening"], run["pointing"]["not"]
    # Listening on the channel, a poll reads who is in it no more often than
    # when nobody points.
    assert listening["people"] >= 1, listening
    _no_more_often(listening["log"], "listening")
    # Not listening, it reads them at every step as before (each read takes
    # 20 ms, so every step is over POLL_MS from the last): a step's reads go
    # out together, so each read of the changes is followed by one of them.
    # By order, not by time: a busy box has paused the fixture between two.
    # From its first read of them: as it begins, the changes are read before
    # it (a change waits for no channel, pollreads).
    log = unheard["log"]
    first = next(n for n, (what, _) in enumerate(log) if what == "GET together_people")
    steps = [n for n, (what, _) in enumerate(log) if what == "GET together_ops" and n > first]
    assert len(steps) >= 2, unheard
    assert all(n + 1 < len(log) and log[n + 1][0] == "GET together_people" for n in steps), log


# -- pointat (APP_UX8 #17): a part pointed out, with the pointer ------------------


def test_a_part_pointed_out_goes_out_at_once_with_its_age():
    looked = _run()["looked"]
    assert looked["sent"] == 200 and looked["ms"] is not None, looked
    # As a pointer is: reads showing them as before, so the line went out
    # without one; timed from the server telling the channel to the line.
    assert looked["relay_ms"] - looked["relay_stalled"] < 50, looked
    first = next(look for look in looked["looks"] if look and look["n"] == 1763000000000)
    assert first["sel"] == ["ab12.3"] and first["at"] == [1, 2, 3] and first["claude"] is False
    assert 40 <= first["age"] < 400 + looked["stalled"], looked


def test_a_part_pointed_out_ages_out_at_5_s_and_is_taken_back_without_it():
    looks = [look["n"] if look else None for look in _run()["looked"]["looks"]]
    old = _run()["looked"]["looks"][looks.index(1763000000001)]
    # Said with the age it had on its side, and Claude's; then nothing, at
    # 5 s, before the next was pointed out.
    assert old["age"] >= 4800 and old["claude"] is True and old["sel"] == ["ab12.3", "ab12.4"]
    after = looks[looks.index(1763000000001):]
    assert after.index(None) < after.index(1763000000002)
    # The third, then a point without it: nothing, to the end.
    assert looks[-1] is None and 1763000000002 in looks


def test_a_look_not_of_its_shape_is_refused_and_none_keeps_the_signature():
    looked = _run()["looked"]
    assert looked["refused"] == [400] * 7
    assert looked["always"] is True


# -- pointfix (2026-11-15): a point's way, and two sends at once ------------------


def test_a_line_with_a_point_says_when_the_server_and_the_poll_had_it():
    looked = _run()["looked"]
    server, poll, via = looked["pointed"]
    # Had by the server once sent, by this poll on the channel after, and
    # said on its line after both: a check times the relay's legs by them.
    assert via == "told", looked["pointed"]
    assert looked["sentAt"] - 5 <= server <= poll <= looked["lineAt"], looked


def test_a_part_pointed_out_while_the_poll_joins_its_channel_is_read_once_joined():
    joining = _run()["joining"]
    # Told 30 ms into a poll whose channel joins 70 ms after (after the
    # server told it, not by the clock: a busy box's sign-in check can take
    # longer than that, pollreads): not heard, so read the moment it has
    # joined, not at the next read of who is in it (PEOPLE_MS, ~270 ms on).
    assert joining["joinedMs"] is not None and joining["joinedMs"] >= joining["toldMs"], joining
    assert joining["via"] == "read", joining
    assert joining["ms"] is not None and joining["ms"] - joining["stalled"] < 150, joining


def test_a_part_pointed_out_beside_a_pointer_on_its_way_is_kept():
    ordered = _run()["ordered"]
    # The pointer's send reached the database after the point sent beside
    # it: the point is kept, and a poll that reads it is told it.
    assert ordered["codes"] == [200, 200], ordered
    assert ordered["kept"]["look"]["n"] == 1763000000009 and ordered["kept"]["at"] == [1, 2, 3], ordered
    assert ordered["read"] == 1763000000009, ordered

