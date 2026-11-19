"""The owner's notifications (ownernotify, 2026-11-18; docs/OWNER_NOTIFY.md, /admin › Notifications).

tests/fixtures/owner_notify/api_check.mjs raises each event where it happens
(a sign-up through api/otp.js, a first model through api/share.js, a report
through api/_feedback.js, Admission's signed word through api/plans.js, 5xx
answers through api/_noted.js, the cron's looks at Supabase's size and the
social desk's tables) with supabase/owner_notify.sql's tables held in memory
and Resend stood in for, and reads every mail it was handed: one a kind, a
burst as one, ten minutes at most, quiet hours held and sent as one, the
digest at its time once a day, the hour's cap folded and then held, pause,
off, the one-click links, a test, another address by its code, a failing
Resend tried three times, an erased account's mails emptied, the cron by
hand on a preview touching nothing of the site's, the database refusing
told without it, and only Resend's test inboxes mailed.
tests/fixtures/owner_notify/db_check.mjs applies owner_notify.sql twice in a
Postgres of its own (pg.mjs; skipped without one, as test_social.py's), then
owner_notify2.sql twice over its rows (onfix: the prune's day).
"""

from __future__ import annotations

import functools
import glob
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/owner_notify.sql").read_text()
SQL2 = (ROOT / "supabase/owner_notify2.sql").read_text()


@functools.cache
def _api() -> dict:
    done = subprocess.run(["node", "tests/fixtures/owner_notify/api_check.mjs"], cwd=ROOT, capture_output=True, text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "threw" not in got, got.get("threw")
    return got


def _checks(prefix: str) -> list[dict]:
    found = [one for one in _api()["checks"] if one["name"].startswith(prefix)]
    assert found, f"no check named {prefix}…"
    return found


@functools.cache
def _db() -> dict | None:
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    done = subprocess.run(["node", "tests/fixtures/owner_notify/db_check.mjs"], cwd=ROOT, capture_output=True, text=True, timeout=240,
                          env={**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin})
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


# Each part of the bar, by the checks' own names (api_check.mjs).
PARTS = ["not applied", "gate", "open", "settings", "burst", "batching", "first model", "feedback", "plans", "errors", "each",
         "digest", "quiet", "cap", "pause", "off", "off link", "test", "address", "failing", "sent", "check now", "erase", "cron",
         "alarm", "no real address", "after", "prune"]


@pytest.mark.parametrize("part", PARTS)
def test_each_part_does_what_it_says(part: str) -> None:
    bad = [one for one in _checks(f"{part}:") if not one["ok"]]
    assert not bad, json.dumps(bad, ensure_ascii=False)[:3000]


def test_every_check_ran_and_passed() -> None:
    got = _api()
    # Every check is one of the parts above, and the run reached its end.
    assert len(got["checks"]) >= 80
    assert all(any(one["name"].startswith(f"{part}:") for part in PARTS) for one in got["checks"] if one["name"] != "the zone is mid-morning")
    assert all(one["ok"] for one in got["checks"]), [one for one in got["checks"] if not one["ok"]]
    assert got["sent"] > 20


def test_the_sql_is_only_additions() -> None:
    body = "\n".join(line for line in SQL.splitlines() if not line.lstrip().startswith("--")).lower()
    for word in ["drop ", "truncate", "delete from", "alter table public.owner_notify_settings add", "update "]:
        assert word not in body, word
    assert body.count("create table if not exists") == 4
    assert "create policy" not in body


def test_the_second_sql_only_adds_its_column() -> None:
    body = " ".join(line for line in SQL2.splitlines() if not line.lstrip().startswith("--")).lower()
    for word in ["drop ", "truncate", "delete ", "update ", "create policy", "grant ", "revoke ", "not null", "default "]:
        assert word not in body, word
    statements = [one.split() for one in body.split(";") if one.strip()]
    assert statements == [["alter", "table", "public.owner_notify_settings", "add", "column", "if", "not", "exists", "pruned_on", "date"],
                          ["notify", "pgrst,", "'reload", "schema'"]]


def test_the_second_sql_keeps_every_row() -> None:
    got = _db()
    if got is None:
        pytest.skip("no Postgres here (PG_MODULE, PG_BIN)")
    assert got["second"] == {"column": ["date:YES"], "rows": True, "nulls": 0, "written": "kept"}


def test_the_database_keeps_it_for_the_server_alone() -> None:
    got = _db()
    if got is None:
        pytest.skip("no Postgres here (PG_MODULE, PG_BIN)")
    assert got["tables"] == ["owner_notify_errors:true", "owner_notify_events:true", "owner_notify_mails:true", "owner_notify_settings:true"]
    assert got["policies"] == 0
    assert all(reach == ["denied", "denied", "ok"] for reach in got["reach"].values()), got["reach"]
    assert got["server_writes"] == ["ok", "ok", "ok", "ok", "ok", "denied"]
    assert got["fk_to_users"] == 0


def test_the_database_refuses_what_is_not_so() -> None:
    got = _db()
    if got is None:
        pytest.skip("no Postgres here (PG_MODULE, PG_BIN)")
    assert got["settings_made"] == {"key": True, "version": 0, "tries": 0, "settings": "{}"}
    assert got["two_keys_differ"] is True
    assert got["settings_refused"] == ["owner_notify_settings_scope", "owner_notify_settings_address", "owner_notify_settings_pending",
                                       "owner_notify_settings_settings", "owner_notify_settings_version",
                                       "owner_notify_settings_pending_tries"]
    # Kept once by its key, every state the code moves an event through allowed.
    assert got["once"] == 1
    assert got["event_states"] == ["kept"] * 9
    assert got["events_refused"] == ["owner_notify_events_event", "owner_notify_events_state", "owner_notify_events_key",
                                     "owner_notify_events_detail", "owner_notify_events_detail", "owner_notify_events_mail_fkey"]
    assert got["after_mail_deleted"] == {"state": "mailed", "mail": None}
    assert got["mails_refused"] == ["owner_notify_mails_id", "owner_notify_mails_kind", "owner_notify_mails_state", "owner_notify_mails_body"]
    assert got["errors"] == ["kept", "owner_notify_errors_status", "owner_notify_errors_fn"]
