"""Feedback from anywhere, and the beta's testers marked (beta374, 2026-10-30).

supabase/feedback.sql runs after beta.sql in a Postgres of its own
(tests/fixtures/beta/pg.mjs): what only a database can show is shown by one
(db_check.mjs). The API (api/_feedback.js through api/plans.js, api/admin.js
and api/account.js) runs against those same files (api_check.mjs): a report
sent signed in and signed out, its files stored and fetched, the refusals,
the rate, the owner's inbox, triage and answers, a tester's mark, the early
features and the hub, an account's deletion and the daily sweep.

Both need node's pg (PG_MODULE, or /tmp/pg) and Postgres's initdb and
postgres (PG_BIN, or Admission's embedded copy); without them those tests
return, as test_beta.py's do. What needs neither (the SQL's shape, the pages,
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
SQL = (ROOT / "supabase/feedback.sql").read_text()


def _postgres() -> dict | None:
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
    done = subprocess.run(["node", f"tests/fixtures/feedback/{script}"], cwd=ROOT, env=env, capture_output=True,
                          text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def db() -> dict | None:
    return _run("db_check.mjs")


def api() -> dict | None:
    return _run("api_check.mjs")


# --- The database itself --------------------------------------------------


def test_a_report_keeps_the_account_never_its_address() -> None:
    got = db()
    if got is None:
        return
    assert got["from_account"] == {"id": 1, "beta": False, "test": False}
    assert got["kept_row"] == [{"has_account": True, "email": None, "kind": "bug",
                                "words": "The hinge turns the wrong way", "source": "site", "page": "/gallery",
                                "beta": False, "test": False, "status": "new"}]
    assert got["signed_out_row"] == [{"account": None, "email": "visitor@example.com"}]
    for refused in ("both", "neither"):
        assert "feedback_who" in got[refused]
    assert "feedback_kind" in got["bad_kind"] and "feedback_picture" in got["bad_picture"]
    assert got["nobody"] == {"refused": "nobody"}
    assert got["bucket"] == [{"id": "feedback", "public": False, "cap": 1572864,
                              "types": ["image/png", "image/jpeg", "text/plain"]}]


def test_a_testers_report_is_marked_beta_and_the_checks_apart() -> None:
    got = db()
    if got is None:
        return
    assert got["before_approval"] is False and got["tester"] is True and got["tester_nobody"] is False
    assert got["from_tester"]["beta"] is True and got["from_check"]["test"] is True
    assert got["inbox_tests"]["counts"]["all"] == 1
    assert [r["id"] for r in got["inbox_tests"]["reports"]] == [got["from_check"]["id"]]
    assert got["from_check"]["id"] not in [r["id"] for r in got["inbox_all"]["reports"]]


def test_the_owner_triages_notes_and_answers() -> None:
    got = db()
    if got is None:
        return
    assert got["triage"]["status"] == "planned" and got["triage"]["note"] == "Next week"
    assert got["triage_keeps_note"]["note"] == "Next week" and got["triage_keeps_note"]["status"] == "planned"
    assert got["triage_clears_note"]["note"] is None
    assert got["triage_none"] == got["reply_none"] == {"refused": "none"}
    # An answer marks a new report seen, and is kept with it.
    assert got["reply"]["status"] == "seen"
    assert [r["words"] for r in got["reply"]["replies"]] == ["Thank you: fixed in the next release."]
    assert got["files"] is True and got["files_none"] is False


def test_a_sender_sees_their_own_without_the_note() -> None:
    got = db()
    if got is None:
        return
    mine = got["mine_tester"]
    assert mine["beta"] is True
    [report] = mine["reports"]
    assert report["status"] == "planned" and report["picture"] is True and report["model"] is True
    assert not {"note", "email", "log", "details", "account"} & set(report)
    [ada] = got["mine_ada"]["reports"]
    assert [r["words"] for r in ada["replies"]] == ["Thank you: fixed in the next release."]
    assert set(ada["replies"][0]) == {"words", "at"}


def test_the_inbox_filters_and_counts() -> None:
    got = db()
    if got is None:
        return
    assert got["inbox_all"]["counts"] == {"all": 3, "new": 1, "seen": 1, "planned": 1, "fixed": 0, "wont_fix": 0,
                                          "beta": 1}
    assert [r["kind"] for r in got["inbox_ideas"]["reports"]] == ["idea"]
    assert all(r["beta"] for r in got["inbox_beta"]["reports"]) and len(got["inbox_beta"]["reports"]) == 1
    assert [r["status"] for r in got["inbox_new"]["reports"]] == ["new"]
    assert {r["status"] for r in got["inbox_open"]["reports"]} == {"new", "seen", "planned"}
    assert got["one"]["email"] == "ada@example.com" and got["one"]["signed_in"] is True


def test_the_rate_is_counted_by_account_place_and_inbox() -> None:
    got = db()
    if got is None:
        return
    assert got["account_rate"] == ["id,beta,test"] * 10 + ["refused"]
    assert got["place_rate"] == ["id,beta,test"] * 5 + ["refused"]
    # dee@googlemail.com and d.ee+x@gmail.com are one inbox.
    assert got["inbox_rate"] == ["id,beta,test"] * 3 + ["refused"]
    assert got["tries_left"] == 1


def test_an_account_and_the_sweep_take_reports_and_name_their_files() -> None:
    got = db()
    if got is None:
        return
    assert got["files_of"] == [f"{6}/picture.jpg", f"{6}/model.mpd"]
    assert got["deleted"] == 0
    assert got["sweep"] == {"erased": 3, "files": ["1/picture.png"]}
    assert got["after_sweep"] == 0


def test_only_the_server_and_only_through_the_functions() -> None:
    got = db()
    if got is None:
        return
    for role in ("anon", "authenticated"):
        assert all(said.startswith("refused: permission denied") for said in got["grants"][role].values()), role
    server = got["grants"]["service_role"]
    assert server["read_feedback"].startswith("refused") and server["read_replies"].startswith("refused")
    assert server["inbox"] == server["send"] == server["tester"] == "allowed"
    assert got["row_security"] == [{"relname": name, "on": True, "policies": 0}
                                   for name in ("feedback", "feedback_replies", "feedback_tries")]


def test_the_sql_only_adds() -> None:
    body = re.sub(r"--[^\n]*", "", SQL)
    assert not re.search(r"\b(drop|truncate|alter\s+table\s+(?!public\.feedback)|alter\s+function)\b", body, re.I)
    for table in re.findall(r"create table if not exists (public\.\w+)", body):
        assert table.startswith("public.feedback")
        assert f"alter table {table} enable row level security" in body
        assert f"revoke all on {table} from public, anon, authenticated, service_role" in body
    functions = set(re.findall(r"create or replace function (public\.\w+)\(", body))
    assert functions == {"public.beta_tester", "public.feedback_own_view", "public.feedback_owner_view",
                         "public.feedback_send", "public.feedback_files", "public.feedback_mine",
                         "public.feedback_inbox", "public.feedback_one", "public.feedback_triage",
                         "public.feedback_reply", "public.feedback_files_of", "public.feedback_sweep"}
    for name in functions:
        assert re.search(rf"revoke all on function {re.escape(name)}\(", body), name
    granted = set(re.findall(r"grant execute on function (public\.\w+)\([^)]*\) to service_role;", body))
    assert granted == functions - {"public.feedback_own_view", "public.feedback_owner_view"}
    assert "to anon" not in body and "to authenticated" not in body
    assert body.count("set search_path = ''") == len(functions)
    # The bucket private, and added only when it is not there.
    assert "'feedback', 'feedback', false, 1572864" in body and "on conflict (id) do nothing" in body
    # No IP address kept: a place is a key the server made.
    assert not re.search(r"\b(ip|inet)\b", body)


# --- The API, against the SQL ----------------------------------------------


def test_a_report_signed_in_with_its_picture_and_model() -> None:
    got = api()
    if got is None:
        return
    assert got["sent"]["status"] == 200
    assert got["sent"]["json"]["attached"] == {"picture": True, "model": True}
    assert "settings page" in got["sent"]["json"]["said"]
    assert got["bucket"] == [{"name": "1/picture.png", "type": "image/png", "size": 72},
                             {"name": "1/model.mpd", "type": "text/plain", "size": 62}]
    [mine] = got["mine"]["json"]["reports"]
    # The words as typed, their runs of empty lines one.
    assert mine["words"] == "The hinge\n\nturns the wrong way." and mine["source"] == "app"
    assert got["mine_signed_out"]["status"] == 401
    # The details kept small: a name that is not one dropped, a long value cut.
    details = got["triaged"]["json"]["report"]["details"]
    assert "Bad Key" not in details and len(details["long"]) == 200 and details["model_name"] == "Crane"
    assert got["triaged"]["json"]["report"]["log"] == "line one\nline two"


def test_signed_out_an_address_is_asked_and_the_place_is_limited() -> None:
    got = api()
    if got is None:
        return
    assert got["signed_out_no_email"] == {"status": 422, "json": {"error": "Give an email address, so we can answer you."}}
    assert got["signed_out"]["status"] == 200 and "by email" in got["signed_out"]["json"]["said"]
    assert got["signed_out_bad_email"] == {"error": "That email address does not look right."}
    assert got["place_rate"] == [200] * 5 + [429]
    assert got["ended_token"]["status"] == 401


def test_what_is_refused_is_said() -> None:
    got = api()
    if got is None:
        return
    refused = got["refused"]
    assert all(status == 422 and words for status, words in refused.values()), refused
    assert refused["picture_big"][1].startswith("The picture is at most 1.5 MB")
    assert refused["model_text"][1] == "The model is an LDraw file's text."
    assert refused["model_big"][1].startswith("The model is at most 1.5 MB")
    # A picture that did not go: the report kept, and the person told.
    assert got["storage_down"]["json"]["attached"] == {"picture": False}
    assert got["storage_down"]["json"]["said"].endswith("The picture did not go with it.")


def test_a_tester_is_marked_and_sees_the_early_features_and_the_hub() -> None:
    got = api()
    if got is None:
        return
    assert got["account_before"] == {"tester": False, "early": []}
    assert got["hub_before"]["status"] == 403
    assert got["account_tester"] == {"tester": True, "early": ["beta_hub"]}
    hub = got["hub"]["json"]
    assert got["hub"]["status"] == 200 and hub["tester"] is True
    assert [one["key"] for one in hub["early"]] == ["beta_hub"] and hub["new"] and hub["known"]
    assert got["hub_signed_out"] == 401
    assert got["from_tester"]["json"]["beta"] is True


def test_the_inbox_is_the_owners_alone() -> None:
    got = api()
    if got is None:
        return
    assert got["inbox_stranger"]["status"] == 404
    inbox = got["inbox"]["json"]
    assert got["inbox"]["status"] == 200 and inbox["counts"]["all"] == 8
    assert all(not r["test"] for r in inbox["reports"])
    assert [r["beta"] for r in got["inbox_tests"]["json"]["reports"]] == [True]
    assert {r["kind"] for r in got["inbox_ideas"]["json"]["reports"]} == {"idea"}
    assert got["inbox_not_beta"]["json"]["reports"] == []
    assert got["inbox_bad"] == [400, 400]
    assert got["file_picture"] == {"status": 200, "type": "image/png", "same": True}
    assert got["file_model"]["disposition"] == 'attachment; filename="report-1-Crane.mpd"'
    assert got["file_model"]["text"].startswith("0 FILE crane.ldr")
    assert got["file_stranger"] == 404 and got["file_none"] == 404


def test_triage_and_answers() -> None:
    got = api()
    if got is None:
        return
    report = got["triaged"]["json"]["report"]
    assert report["status"] == "planned" and report["note"] == "For 0.11"
    assert got["triage_bad"] == 422 and got["triage_none"] == 404 and got["triage_stranger"] == 404
    [mail] = got["reply_mail"][:1]
    assert mail["to"] == ["ada@example.com"] and mail["reply_to"] == "beta@brickworks.diy"
    assert mail["subject"] == "About your Brickworks report" and mail["has_html"]
    assert mail["text"].startswith("Thank you, Ada.\nIt is planned for 0.11.\n\nYou wrote, on ")
    assert "See your reports: https://brickworks.diy/settings#feedback" in mail["text"]
    assert got["replied"]["json"]["mail"] == "sent"
    assert "Open Brickworks: https://brickworks.diy/app" in got["reply_signed_out_text"]
    # A test inbox where there is no mail key: dry, and kept all the same.
    assert got["replied_tester"]["json"]["mail"] == "dry"
    assert got["replied_tester"]["json"]["report"]["replies"][0]["mail"] == "dry"
    assert got["reply_empty"] == 422
    answered = [r for r in got["mine_after"]["reports"] if r["id"] == 1][0]
    assert answered["status"] == "planned" and [r["words"] for r in answered["replies"]] == [
        "Thank you, Ada.\nIt is planned for 0.11."]


def test_deleting_the_account_and_the_daily_run_take_the_files() -> None:
    got = api()
    if got is None:
        return
    assert got["deleted"]["json"]["feedback"] == 2
    # Ada's picture and model went; the visitor's picture stays.
    assert got["files_after_delete"] == [3, 1, ["2/picture.jpg"]]
    assert got["daily"]["status"] == 200 and got["daily"]["json"]["feedback"] == {"erased": 1, "files": 0}


def test_before_the_sql_words_never_a_crash() -> None:
    got = api()
    if got is None:
        return
    assert got["no_sql_send"] == {"status": 503, "json": {"error": "Feedback is not open here yet. Try again soon."}}
    assert got["no_sql_inbox"]["status"] == 503
    assert got["no_sql_account"] == {"tester": False, "early": []}
    assert got["no_sql_hub"]["status"] == 503
