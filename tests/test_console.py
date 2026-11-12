"""The owner's console (console1, 2026-11-12; docs/ADMIN.md).

supabase/console.sql runs in a Postgres of its own (tests/fixtures/beta/pg.mjs)
after beta.sql, feedback.sql and beta_join.sql (db_check.mjs): the switches
kept a scope apart, the audit kept and listed, the waitlist by hand, the mail
counted, and nothing reachable but by the server. The API (api/admin.js,
api/_console.js, api/_beta.js's switch) runs against that same file
(api_check.mjs): every new op closed to anybody but the owner, the beta's
switch flipped on a preview and only that preview following, every act kept
in the audit whatever came of it, and the reads.

Both need node's pg (PG_MODULE, or /tmp/pg) and Postgres's initdb and
postgres (PG_BIN, or Admission's embedded copy); without them those tests
return, as test_beta.py's do. What needs neither (the SQL's shape, the page,
the words) runs everywhere.
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
SQL = (ROOT / "supabase/console.sql").read_text()
PAGE = (ROOT / "web/admin.html").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()


def _postgres() -> dict | None:
    """node's pg and Postgres's own binaries, as test_beta.py finds them; None without."""
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    return {**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin}


@functools.cache
def _run(script: str) -> dict | None:
    env = _postgres()
    if env is None:
        return None
    done = subprocess.run(["node", f"tests/fixtures/console/{script}"], cwd=ROOT, env=env, capture_output=True,
                          text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


# --- The SQL's shape ----------------------------------------------------------


def test_the_sql_only_adds() -> None:
    lowered = SQL.lower()
    for word in ("drop ", "alter table public.beta", "truncate", "delete from", "update public.site", "alter column"):
        assert word not in lowered, word
    assert "create table if not exists public.site_settings" in lowered
    assert "create table if not exists public.admin_audit" in lowered
    # Every function granted to the server alone.
    made = set(re.findall(r"create or replace function public\.([a-z_]+)\(", SQL))
    assert made == {"site_setting", "site_setting_set", "admin_audit_note", "admin_audit_list", "beta_waitlist",
                    "admin_mail_counts"}
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\(", SQL), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\)\s+to service_role;", SQL), name


def test_every_act_is_audited_and_every_op_is_behind_the_owner_check() -> None:
    # The acts go through audited(); the owner check comes before any op.
    assert "return audited(op, acts[op], request, response, claims" in ADMIN
    assert ADMIN.index("if (!isMaster(claims))") < ADMIN.index("const op = String(request.query?.op")
    for op in ("beta_waitlist: betaWaitlist", "beta_switch: betaSwitchRoute"):
        assert op in ADMIN


# --- The database -------------------------------------------------------------


def test_a_switch_is_kept_for_its_scope_alone() -> None:
    got = _run("db_check.mjs")
    if got is None:
        return
    assert got["unset"] is None
    assert got["set"]["value"] == "off" and got["set"]["was"] is None
    assert got["again"]["value"] == "open" and got["again"]["was"] == "off"
    assert got["read"]["value"] == "open" and got["read"]["set_by"] == "owner@example.com"
    assert got["other_scope"] is None
    assert "site_settings_scope" in got["bad_scope"]


def test_the_audit_keeps_and_lists_each_act() -> None:
    got = _run("db_check.mjs")
    if got is None:
        return
    assert [row["op"] for row in got["all"]["rows"]] == ["dismiss", "beta_decide", "unlist"]
    assert got["all"]["more"] is False
    assert [row["op"] for row in got["page1"]["rows"]] == ["dismiss", "beta_decide"] and got["page1"]["more"] is True
    assert [row["op"] for row in got["page2"]["rows"]] == ["unlist"] and got["page2"]["more"] is False
    assert [row["op"] for row in got["by_op"]["rows"]] == ["beta_decide"]
    # On an account: its address with it.
    assert got["on_ada"]["rows"][0]["email"] == "ada@example.com"
    assert [row["op"] for row in got["query"]["rows"]] == ["unlist"]
    # A refusal is kept with its status and why.
    assert got["all"]["rows"][0]["status"] == 404 and got["all"]["rows"][0]["said"] == "no such report"
    # A test's apart, with where it was done.
    assert [(row["op"], row["test"], row["scope"]) for row in got["tests"]["rows"]] == [
        ("beta_switch", True, "preview-abc.vercel.app")]
    assert "admin_audit_op" in got["bad_op"]


def test_the_waitlist_by_hand_is_from_new_only_and_gives_no_spot() -> None:
    got = _run("db_check.mjs")
    if got is None:
        return
    assert got["waitlist"]["application"]["status"] == "waitlist" and got["waitlist"]["application"]["spot"] is None
    assert got["waitlist_again"] == {"refused": "status", "status": "waitlist"}
    assert got["waitlist_none"] == {"refused": "none"}
    assert got["row"] == {"status": "waitlist", "note": "after the first wave", "spot": None,
                          "decided_by": "owner@example.com"}
    # Approved from the waitlist, as from New: the next spot.
    assert got["approved"]["application"]["status"] == "approved" and got["approved"]["application"]["spot"] == 1


def test_mail_is_counted_by_how_it_went_tests_apart() -> None:
    got = _run("db_check.mjs")
    if got is None:
        return
    assert got["mail"]["beta"] == {"sent": 1, "dry": 0, "failed": 1}
    assert got["mail_tests"]["beta"] == {"sent": 0, "dry": 1, "failed": 0}


def test_nobody_but_the_server_reaches_it_and_applying_again_changes_nothing() -> None:
    got = _run("db_check.mjs")
    if got is None:
        return
    assert not any(row["can"] for row in got["grants"])
    for row in got["functions"]:
        assert row["can"] == (row["rolname"] == "service_role"), row
    assert got["after_again"] == {"settings": 1, "audit": 4}


# --- The API ------------------------------------------------------------------


def test_every_new_op_is_401_signed_out_and_404_to_anybody_else() -> None:
    got = _run("api_check.mjs")
    if got is None:
        return
    assert got["gate"] == {op: [401, 404] for op in ("overview", "people", "person", "audit", "switches", "beta_switch",
                                                     "beta_waitlist")}
    # Nothing kept of a refusal at the gate: it never reached an act.
    assert got["audit_after_refusals"] == 0


def test_the_beta_switch_flips_where_the_console_is_and_nowhere_else() -> None:
    got = _run("api_check.mjs")
    if got is None:
        return
    assert got["switch_before"]["mode"] == "open" and got["switch_before"]["source"] == "project"
    assert got["switch_before"]["ready"] is True
    assert got["flip_off"]["status"] == 200 and got["flip_off"]["json"]["beta"]["mode"] == "off"
    assert got["flip_off"]["json"]["was"] is None and got["flip_off"]["json"]["audit"] == 1
    # The preview follows; the site does not.
    assert got["spots_preview_off"] == {"beta": "off"}
    assert got["beta_preview_off"] == {"beta": "off"}
    assert got["join_preview_off"] == 403
    assert got["spots_live"]["beta"] == "open"
    assert got["flip_bad"]["status"] == 422
    assert got["flip_on"]["json"]["was"] == "off" and got["spots_preview_on"]["beta"] == "open"
    assert got["switch_after"]["source"] == "console" and got["switch_after"]["set_by"] == "owner@example.com"


def test_every_act_is_kept_in_the_audit_whatever_came_of_it() -> None:
    got = _run("api_check.mjs")
    if got is None:
        return
    rows = got["audit"]["rows"]
    assert [(row["op"], row["status"]) for row in rows] == [("beta_waitlist", 400), ("beta_switch", 200),
                                                             ("beta_switch", 422), ("beta_switch", 200)]
    assert rows[0]["said"] == "name an application: ?account=<id>"
    assert rows[1]["detail"]["said"]["was"] == "off" and rows[1]["detail"]["asked"]["mode"] == "open"
    assert all(row["actor"] == "owner@example.com" for row in rows)
    assert all(row["scope"] == "brickworks-abc123-xaxis-projects.vercel.app" for row in rows)
    # The waitlist's, on a test's application, kept as a test's, on its account.
    tests = got["audit_tests"]["rows"]
    assert [(row["op"], row["status"], row["email"]) for row in tests] == [("beta_waitlist", 409, "bob@resend.dev"),
                                                                            ("beta_waitlist", 200, "bob@resend.dev")]
    assert tests[1]["detail"]["asked"]["note"] == "after the first wave"
    assert [row["op"] for row in got["audit_switch"]["rows"]] == ["beta_switch"] * 3
    assert got["audit_bad"] == 400
    assert got["waitlist"]["json"]["application"]["status"] == "waitlist"
    assert got["waitlist_again"]["status"] == 409


def test_the_reads_say_how_things_stand() -> None:
    got = _run("api_check.mjs")
    if got is None:
        return
    assert got["overview"]["status"] == 200
    view = got["overview"]["json"]
    # The checks' own accounts are counted apart.
    assert view["accounts"]["all"] == 2 and got["overview_tests"]["accounts"]["all"] == 1
    assert view["beta"]["pool"]["cap"] == 100 and view["switches"]["beta"]["mode"] == "open"
    assert view["mail"]["beta"] == {"sent": 0, "dry": 0, "failed": 0}
    assert [row["op"] for row in view["audit"]] == ["beta_waitlist", "beta_switch", "beta_switch", "beta_switch"]
    emails = [one["email"] for one in got["people"]["people"]]
    assert sorted(emails) == ["ada@example.com", "owner@example.com"]
    assert [one["owner"] for one in got["people"]["people"] if one["email"] == "owner@example.com"] == [True]
    assert [one["email"] for one in got["people_tests"]["people"]] == ["bob@resend.dev"]
    person = got["person"]
    assert person["email"] == "bob@resend.dev" and person["test"] is True
    assert person["beta"]["application"]["status"] == "waitlist"
    assert [row["op"] for row in person["audit"]] == ["beta_waitlist", "beta_waitlist"]
    assert got["person_none"] == 404


# --- The page -----------------------------------------------------------------


def test_the_page_puts_what_people_typed_on_it_as_text() -> None:
    # Never markup from data: no innerHTML, insertAdjacentHTML or outerHTML.
    for script in ("web/admin.js", "web/admin-kit.js", "web/admin-gallery.js", "web/admin-beta.js", "web/admin-feedback.js"):
        text = (ROOT / script).read_text()
        for word in ("innerHTML", "insertAdjacentHTML", "outerHTML", "document.write"):
            assert word not in text, (script, word)
    assert 'name="robots" content="noindex, nofollow"' in PAGE
