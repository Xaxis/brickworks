"""Joining the beta is a step of signing up (betajoin, 2026-11-09).

supabase/beta_join.sql runs after beta.sql and feedback.sql in a Postgres of
its own (tests/fixtures/beta/pg.mjs), and the API (api/_beta.js through
api/plans.js, api/account.js and api/admin.js) runs against it with the
stand-in Admission (tests/fixtures/beta/join_check.mjs): a new account is
welcomed, joins in one call and is a tester at once; Not now is never asked
again; an existing account joins and leaves; telling us about you needs no
boxes ticked again; the month of Pro is as it was; the owner's list; the
switch off; and everything as it was before the file is applied.

Needs node's pg and Postgres (as tests/test_beta.py); without them the
database's tests return. The SQL's shape and the pages' words run everywhere.
"""

from __future__ import annotations

import functools
import glob
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/beta_join.sql").read_text()


def _postgres() -> dict | None:
    """node's pg and Postgres's own binaries, as tests/test_beta.py finds them."""
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    return {**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin}


@functools.cache
def _run() -> dict | None:
    env = _postgres()
    if env is None:
        return None
    done = subprocess.run(["node", "tests/fixtures/beta/join_check.mjs"], cwd=ROOT, env=env, capture_output=True,
                          text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


def test_off_no_welcome_and_joining_refused():
    got = _run()
    if got is None:
        return
    assert got["off_get"] == {"status": 200, "json": {"beta": "off"}}
    assert got["off_join"]["status"] == 403 and got["off_join"]["json"]["beta"] == "off"
    # Refused before the database is asked anything.
    assert got["off_join_calls"] == []
    # The account says nothing of the beta's welcome while it is off.
    assert got["off_account"] == {"tester": False, "early": []}
    assert got["off_rejoin"] == 403
    # Anybody may leave, whatever the switch.
    assert got["off_leave"]["status"] == 200 and got["off_leave"]["json"] == {"beta": "off", "tester": False, "state": "left"}


def test_signed_out_and_wrong_method():
    got = _run()
    if got is None:
        return
    assert got["signed_out"] == {"status": 200, "beta": "open", "spots": {"cap": 100, "left": 100}, "signed_in": False,
                                 "tester": None}
    assert got["join_signed_out"] == 401
    assert got["join_get"] == 405


def test_a_new_account_is_welcomed_and_joins_in_one_call():
    got = _run()
    if got is None:
        return
    assert got["new_account"] == {"tester": False, "early": [], "open": True, "welcome": True}
    assert got["new_status"]["welcome"] is True and got["new_status"]["tester"] is False
    assert got["new_status"]["month"] == ["application", "early", "pool", "test"]
    assert got["joined"]["status"] == 200 and got["joined"]["tester"] is True and got["joined"]["state"] == "tester"
    assert got["joined"]["joined"] is True and got["joined"]["welcome"] is False
    assert got["joined"]["spots"] == {"cap": 100, "left": 100}
    # GET says so after, and so does everything that reads beta_tester.
    assert got["joined_get"]["tester"] is True and got["joined_get"]["welcome"] is False
    assert got["joined_account"] == {"tester": True, "early": ["beta_hub"], "open": True, "welcome": False}
    assert got["joined_hub"] == 200
    assert got["joined_tester_fn"] is True
    # Under today's terms; joining again changes nothing.
    assert got["join_terms"] == "2026-10-29"
    assert got["join_again_same"] is True


def test_not_now_is_never_asked_again():
    got = _run()
    if got is None:
        return
    assert got["not_now"]["status"] == 200 and got["not_now"]["tester"] is False
    assert got["not_now"]["state"] == "not_now" and got["not_now"]["welcome"] is False
    assert got["not_now_account"]["welcome"] is False and got["not_now_account"]["tester"] is False
    assert got["not_now_hub"] == 403


def test_an_existing_account_joins_and_leaves():
    got = _run()
    if got is None:
        return
    # Made a month ago: no welcome.
    assert got["old_account"]["welcome"] is False
    assert got["old_join"]["tester"] is True
    assert got["old_left"]["status"] == 200 and got["old_left"]["tester"] is False and got["old_left"]["state"] == "left"
    assert got["old_left_hub"] == 403
    # And joins again, from somewhere the server does not know: kept as the site.
    assert got["old_rejoin"]["tester"] is True and got["old_rejoin_via"] == "site"


def test_telling_us_about_you():
    got = _run()
    if got is None:
        return
    # A tester agreed to the terms and the emails when it joined.
    assert got["told"] == {"status": 200, "status_of": "new", "error": None}
    # Somebody who has not joined ticks them, and joins with it.
    assert got["untold_no_boxes"] == 422
    assert got["untold_applied"] == 200
    assert got["untold_now"]["tester"] is True and got["untold_now"]["application"]["status"] == "new"
    assert got["untold_via"] == "beta"


def test_the_month_is_as_it_was():
    got = _run()
    if got is None:
        return
    # Approved from the queue: the checks' pool's first spot, given in
    # Admission's test mode, once. Joining asked Admission nothing.
    assert got["month_approved"] == {"status": 200, "spot": 1, "comp": "granted"}
    assert got["comps_asked"] == 1
    # Leaving changes nothing about money.
    assert got["month_after_leaving"] == {"tester": False, "status": "approved", "comp": "granted", "spot": 1}
    # An approval from before the file, with no row, is a tester; and may leave.
    assert got["legacy"]["tester"] is True and got["legacy"]["state"] == "tester" and got["legacy"]["joined"] is True
    assert got["legacy_left"]["tester"] is False and got["legacy_left"]["state"] == "left"
    assert got["legacy_left"]["application"]["status"] == "approved"


def test_the_owners_list():
    got = _run()
    if got is None:
        return
    assert got["list_stranger"] == 404
    assert got["list"]["status"] == 200
    assert got["list"]["counts"] == {"testers": 2, "left": 2, "not_now": 1, "welcome": 0, "application": 1}
    # Testers first, newest first; then who left; then Not now.
    assert [row[1] for row in got["list"]["rows"]] == ["tester", "tester", "left", "left", "not_now"]
    assert ["pia", "tester", "beta", "new"] in got["list"]["rows"] and ["ida", "tester", "site", None] in got["list"]["rows"]
    assert ["nell", "left", "welcome", "approved"] in got["list"]["rows"]
    # The checks' accounts are never in the 100's list.
    assert got["list_real"] == 0


def test_before_the_file_is_applied_everything_is_as_it_was():
    got = _run()
    if got is None:
        return
    assert got["without_account"] == {"tester": False, "early": [], "open": True, "welcome": False}
    assert got["without_get"]["tester"] is False and got["without_get"]["welcome"] is False
    assert got["without_join"] == 503
    # The form still works, as it did.
    assert got["without_apply"] == 200
    assert got["without_list"] == 503


def test_the_database_keeps_it_to_itself():
    got = _run()
    if got is None:
        return
    assert got["exposure"] == [{"anon": False, "signed_in": False, "anon_join": False, "signed_in_member": False,
                                "server_join": True, "row_security": True}]
    assert got["deleted_row"] == 0
    # An application made before the file joins at its next applying; then nothing changes.
    assert got["backfilled"] == {"state": "tester", "via": "application"}
    assert got["again_same"] is True


def test_the_file_only_adds():
    body = re.sub(r"--[^\n]*", "", SQL)
    assert not re.search(r"\b(drop|truncate|alter\s+function|delete\s+from|update\s+public)\b", body, re.I)
    for table in re.findall(r"alter table (\S+)", body):
        assert table == "public.beta_testers"
    assert re.findall(r"create table if not exists (\S+)", body) == ["public.beta_testers"]
    functions = set(re.findall(r"create or replace function (public\.beta_\w+)\(", body))
    assert functions == {"public.beta_tester", "public.beta_member", "public.beta_join", "public.beta_leave",
                         "public.beta_testers_list"}
    granted = set(re.findall(r"grant execute on function (public\.beta_\w+)\([^)]*\) to service_role;", body))
    assert granted == functions
    for one in functions:
        assert re.search(rf"revoke all on function {re.escape(one)}\([^)]*\) from public, anon, authenticated;", body)
    # beta_tester is feedback.sql's, replaced: the later file guards it.
    later = (ROOT / "supabase/later.tsv").read_text()
    assert "feedback.sql\tbeta_tester\tbeta_join.sql\t" in later
    # Every function security definer with an empty search path.
    assert body.count("security definer") == len(functions)
    assert body.count("set search_path = ''") == len(functions)
