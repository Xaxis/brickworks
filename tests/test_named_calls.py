"""A call to the project that fails says which call it was (sharetime,
2026-11-02).

Seven publishes were refused that day with a 502, and each left one line
in Vercel's log: "share: The operation was aborted due to timeout". It
took timing every call by hand to learn that it was the picture's upload,
while Supabase's storage took up to 40 s to write. api/_db.js reach() is
how the database's, storage's and sign-in's calls are asked now. When one
is given up, its answer's reading included, it says "<call>: no answer in
<n> s", and when it never reaches the project, "<call>: not reached". So
the 502's line names the call (tests/fixtures/named_calls/check.mjs, by
api/share.js's own handler).
"""

from __future__ import annotations

import functools
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


@functools.cache
def checked() -> dict | None:
    if shutil.which("node") is None:
        return None
    done = subprocess.run(["node", "tests/fixtures/named_calls/check.mjs"], cwd=ROOT, capture_output=True,
                          text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_a_call_given_up_says_which_and_how_long_it_waited() -> None:
    got = checked()
    if got is None:
        return
    assert got["stalled"] == "storage POST png: no answer in 0.3 s"
    # Its body's reading is within the same limit, and named the same.
    assert got["stalled_body"] == "storage GET mpd: no answer in 0.3 s"


def test_a_call_that_never_reached_the_project_says_which() -> None:
    got = checked()
    if got is None:
        return
    assert got["unreached"] == "storage POST png: not reached (ECONNREFUSED)"
    assert got["db_unreached"] == "database POST rpc/may_publish: not reached (ECONNREFUSED)"


def test_a_call_answered_in_time_is_not_given_up_later() -> None:
    got = checked()
    if got is None:
        return
    assert got["answered"] == {"status": 200, "text": "ok"}


def test_a_publish_refused_by_storage_names_the_upload_in_its_log_line() -> None:
    got = checked()
    if got is None:
        return
    publish = got["publish"]
    assert publish["status"] == 502
    assert publish["error"] == "Brickworks could not reach its storage just now. Try again in a minute."
    assert publish["logged"] == ["share: storage POST png: not reached (UND_ERR_SOCKET)"]
    # The model went, the picture did not, and the new link's files went
    # with the failed publish (share.js dropNew).
    assert publish["asked"] == [
        "GET /auth/v1/.well-known/jwks.json",
        "POST /rest/v1/rpc/may_publish",
        "POST /storage/v1/object/shared-models/<id>.mpd",
        "POST /storage/v1/object/shared-models/<id>.png",
        "DELETE /storage/v1/object/shared-models",
        "DELETE /storage/v1/object/shared-thumbs",
    ]
