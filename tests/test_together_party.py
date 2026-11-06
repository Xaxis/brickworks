"""A build party (APP_UX5 buildparty): several phones build one shared model,
with no account (api/together.js, its build party block).

tests/fixtures/together/party_check.mjs runs the real handler with no
sign-in against a database kept in the fixture: a shared model, the
parties' sessions and their numbered words, together_append as
supabase/together.sql makes it. Each test reads one line of what it found.
"""

from __future__ import annotations

import functools
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


@functools.cache
def _run() -> dict:
    done = subprocess.run(["node", "tests/fixtures/together/party_check.mjs"], cwd=ROOT, capture_output=True,
                          text=True, timeout=120)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_a_party_starts_with_no_sign_in_under_the_links_owner():
    start = _run()["start"]
    assert start["status"] == 200 and start["seat"] == 1 and start["ops"] == 1
    assert len(start["code"]) == 4 and all(c in "BCDFGHJKLMNPQRSTVWXZ23456789" for c in start["code"])
    assert start["owner"] == "11111111-1111-4111-8111-111111111111"
    assert start["title"] == "party:Car0000001"


def test_a_code_works_only_on_its_own_link():
    out = _run()
    assert out["no_model"] == 404 and out["wrong_code"] == 404 and out["other_link"] == 404


def test_a_name_a_stranger_may_not_be_shown_is_refused_in_words():
    rude = _run()["rude"]
    assert rude["status"] == 422 and "say it another way" in rude["error"]


def test_a_second_phone_joins_by_the_code_as_typed_and_never_sees_a_phone_id():
    join = _run()["join"]
    assert join["status"] == 200 and join["seat"] == 2 and join["ops"] == 2
    assert join["names"] == ["Ana", "Leo"]
    assert join["phones_shown"] is False


def test_only_the_first_phone_deals_and_only_once():
    out = _run()
    assert out["deal_by_two"] == 403 and out["deal"] == 200 and out["deal_again"] == 409


def test_no_new_phone_once_dealt_or_past_four_and_none_a_day_on():
    out = _run()
    assert out["late"] == 409 and out["fifth"] == 409 and out["old"] == 410


def test_progress_is_said_by_phones_in_it_in_its_one_shape():
    out = _run()
    assert out["at"] == 200 and out["bad_word"] == 400 and out["not_in"] == 403


def test_a_phone_that_left_has_its_seat_back():
    out = _run()
    assert out["left"] == 200 and out["back"] == {"status": 200, "seat": 2}


def test_a_poll_gives_every_word_in_order_and_waits_for_the_next():
    out = _run()
    assert out["poll"]["kinds"] == ["join", "join", "deal", "at", "left", "join"]
    wait = out["poll_wait"]
    assert wait["status"] == 200 and wait["ops"] == 1 and 350 <= wait["ms"] < 2000
