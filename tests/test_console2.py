"""The owner's console, part B (console2, 2026-11-13; docs/ADMIN.md).

supabase/console2.sql runs in a Postgres of its own (tests/fixtures/beta/pg.mjs)
after the files it reads (db2_check.mjs): Resend's events kept once, the mail
read back by kind and day beside what Brickworks kept as sent, a year's
mail kept, releases written down, each conversation's tool calls counted by
account and day, a cron's run noted, Admission's snapshots listed, and
nothing reachable but by the server. The API (api/admin.js's plans, mail,
connector and site; api/otp.js's mail_event) runs against that same file
(api2_check.mjs): every new op closed to anybody but the owner and none of
them audited, Resend's events taken only signed and only Brickworks' own,
and each section's read.

Both need node's pg (PG_MODULE, or /tmp/pg) and Postgres's initdb and
postgres (PG_BIN, or Admission's embedded copy); without them those tests
return, as test_console.py's do. What needs neither runs everywhere.
"""

from __future__ import annotations

import base64
import functools
import glob
import hashlib
import hmac
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/console2.sql").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()
OTP = (ROOT / "api/otp.js").read_text()


def _postgres() -> dict | None:
    """node's pg and Postgres's own binaries, as test_console.py finds them; None without."""
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
    for word in ("drop ", "truncate", "alter column", "update public.relay_tabs", "delete from public.relay"):
        assert word not in lowered, word
    # The one change to a table that was there: a column added, with a default.
    assert re.findall(r"alter table public\.(\w+) add column", lowered) == ["relay_picks"]
    assert "add column if not exists calls integer not null default 0" in lowered
    made_tables = set(re.findall(r"create table if not exists public\.([a-z_]+)", lowered))
    assert made_tables == {"mail_events", "site_releases", "relay_call_days"}
    for table in made_tables:
        assert f"alter table public.{table} enable row level security" in lowered, table
        assert re.search(rf"revoke all on public\.{table} from public, anon, authenticated", lowered), table


def test_every_function_is_the_servers_alone() -> None:
    made = set(re.findall(r"create or replace function public\.([a-z_]+)\(", SQL))
    assert made == {"mail_event_keep", "admin_mail", "site_release_live", "site_releases_list", "relay_call_note",
                    "cron_noted", "admission_customers"}
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\)\s+from public, anon, authenticated;", SQL), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\)\s+to service_role;", SQL), name


def test_the_new_reads_are_ops_of_admin_and_resends_word_an_op_of_otp() -> None:
    # No new function: Vercel's twelve stay twelve.
    functions = [p.name for p in (ROOT / "api").glob("*.js") if not p.name.startswith("_")]
    assert len(functions) == 12, functions
    for op in ("plans: () => plansRead()", "mail: () => mailRead(request, tests)", "site: () => siteRead()"):
        assert op in ADMIN, op
    assert "connector: () => connectorRead(tests" in ADMIN
    # Behind the owner check, like part A's.
    assert ADMIN.index("if (!isMaster(claims))") < ADMIN.index("const op = String(request.query?.op")
    assert 'request.query?.op === "mail_event"' in OTP and "mailEventRoute(request, response)" in OTP
    # Before the sign-in code's own handling: a webhook is not a person asking for a code.
    assert OTP.index('op === "mail_event"') < OTP.index("That is not an email address.")


def test_every_mail_says_its_kind() -> None:
    sends = {
        "api/otp.js": "sign_in_code", "api/_beta.js": "beta", "api/_feedback.js": "feedback_answer",
        "api/_comments.js": "digest", "api/_trust.js": "report_digest", "api/_canary.js": "canary_alarm",
        "api/orangecheck.js": "sign_in_notice",
    }
    for path, kind in sends.items():
        text = (ROOT / path).read_text()
        assert f'"{kind}"' in text, (path, kind)
        assert "api.resend.com/emails" in text or "resend(" in text, path
    assert '{ name: "kind", value: kind }' in (ROOT / "api/_beta.js").read_text()


# --- Resend's signature, as Svix makes it ------------------------------------


def _node(code: str) -> str:
    done = subprocess.run(["node", "--input-type=module", "-e", code], cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return done.stdout.strip()


def test_a_signature_made_as_svix_makes_one_is_taken_and_nothing_else() -> None:
    secret = "whsec_" + base64.b64encode(b"thirty-two bytes of a test secret").decode()
    raw = json.dumps({"type": "email.delivered", "data": {"email_id": "e1"}})
    msg_id, stamp = "msg_2pQ", "1763000000"
    signature = base64.b64encode(hmac.new(base64.b64decode(secret[6:]), f"{msg_id}.{stamp}.{raw}".encode(),
                                          hashlib.sha256).digest()).decode()
    asked = json.dumps({"secret": secret, "raw": raw, "id": msg_id, "t": stamp, "sig": signature})
    got = json.loads(_node(f"""
const a = {asked};
const {{ signedBy, kindOf }} = await import("./api/_console_mail.js");
const now = Number(a.t) * 1000;
const s = (header, raw = a.raw, at = now, id = a.id, t = a.t) => signedBy(a.secret, {{ id, timestamp: t, header }}, raw, at);
console.log(JSON.stringify({{
  good: s(`v1,${{a.sig}}`),
  among: s(`v1,bm90IGl0 v1,${{a.sig}}`),
  other_version: s(`v2,${{a.sig}}`),
  tampered: s(`v1,${{a.sig}}`, a.raw.replace("delivered", "bounced")),
  other_id: s(`v1,${{a.sig}}`, a.raw, now, "msg_other"),
  late: s(`v1,${{a.sig}}`, a.raw, now + 301000),
  early: s(`v1,${{a.sig}}`, a.raw, now - 301000),
  none: s(""),
  kinds: [kindOf({{ tags: [{{ name: "kind", value: "beta" }}] }}), kindOf({{ tags: {{ kind: "digest" }} }}),
    kindOf({{ tags: [{{ name: "kind", value: "made_up" }}], subject: "123456 is your Brickworks sign-in code" }}),
    kindOf({{ subject: "About your Brickworks report" }}), kindOf({{ subject: "Hello" }})],
}}));
"""))
    assert got["good"] is True and got["among"] is True
    for key in ("other_version", "tampered", "other_id", "late", "early", "none"):
        assert got[key] is False, key
    assert got["kinds"] == ["beta", "digest", "sign_in_code", "feedback_answer", "other"]


def test_revenue_by_month_is_paid_less_refunded() -> None:
    got = json.loads(_node("""
const { byMonth } = await import("./api/_console_plans.js");
console.log(JSON.stringify(byMonth([
  { at: "2026-10-03T10:00:00Z", type: "payment.succeeded", amount: 800, currency: "usd" },
  { at: "2026-10-20T10:00:00Z", type: "payment.succeeded", amount: 8000, currency: "usd" },
  { at: "2026-11-02T10:00:00Z", type: "refund", amount: 300, currency: "usd" },
  { at: "2026-11-02T11:00:00Z", type: "subscription.started", currency: "usd" },
])));
"""))
    assert [(m["month"], m["paid"], m["refunded"], m["net"], m["payments"], m["refunds"]) for m in got] == [
        ("2026-11", 0, 300, -300, 0, 1), ("2026-10", 8800, 0, 8800, 2, 0)]


# --- The database -------------------------------------------------------------


def test_the_database_keeps_and_reads_as_the_console_needs() -> None:
    got = _run("db2_check.mjs")
    if got is None:
        return
    assert got["again"] == "ok"
    # An event kept once however often Resend sends it; a type it does not know refused.
    assert got["kept"] == [True, False, True]
    assert "mail_events_type" in got["bad_type"]
    # A year's mail kept: the older let go as the next event comes.
    assert "msg_1" not in got["after_a_year"] and "msg_8" in got["after_a_year"]
    # Read back with what Brickworks kept as sent, the checks' own apart.
    assert {one["kind"] for one in got["mail"]["kept"]} >= {"beta", "feedback_answer"}
    assert all(one["address"].endswith("@resend.dev") for one in got["mail_tests"]["kept"])
    # A release written down again keeps its first time unless told one.
    assert got["release_again"]["units"] == ["treedrag", "heldsteps", "f5"]
    assert [one["tag"] for one in got["releases"]] == ["rel-m290", "rel-m289"]
    assert "site_releases_sha" in got["bad_release"]
    # Each call counted on its conversation and its account's day; a pick that is gone, nothing.
    assert got["calls"] == [1, 2, 1, None]
    assert got["pick"] == {"calls": 2, "did": "place_part", "called": True}
    assert got["cron"]["outcome"] == "done" and got["cron_run"] is True
    assert got["customers_bad"] == [] and len(got["customers_test"]) == 1
    # Nobody but the server.
    for row in got["grants"]:
        assert row["rls"] is True and row["anon"] is False and row["signed_in"] is False, row
    assert len(got["functions"]) == 7
    for row in got["functions"]:
        assert row["definer"] and not row["anon"] and not row["signed_in"] and row["server"], row


# --- The API ------------------------------------------------------------------


def test_every_new_op_is_401_signed_out_and_404_to_anybody_else_and_never_audited() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    assert got["gate"] == {op: [401, 404] for op in ("plans", "mail", "connector", "site")}
    assert got["audit_after_reads"] == 0 and got["audit_after_all"] == 0


def test_resends_word_is_taken_signed_and_only_of_brickworks_mail() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    assert got["event_no_secret"] == 404
    assert got["event_sent"] == {"status": 200, "json": {"kept": True, "again": False, "type": "sent"}}
    assert got["event_again"]["again"] is True
    for key in ("event_badly_signed", "event_stale", "event_tampered"):
        assert got[key] == 401, key
    assert got["event_foreign"] == {"kept": False, "why": "not Brickworks' mail"}
    assert got["event_not_mail"]["kept"] is False
    assert got["events_kept"] == ["em_1:sent:sign_in_code:false", "em_1:delivered:sign_in_code:false",
                                  "em_2:bounced:beta:false", "em_3:delivered:sign_in_code:true"]
    # A unit's preview, with the checks' own secret: only test inboxes' mail.
    assert got["stand_in_real"]["kept"] is False and got["stand_in_test"]["kept"] is True


def test_mail_reads_each_mail_once_with_what_became_of_it() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    mail = got["mail"]
    assert mail["status"] == 200 and mail["ready"] is True and mail["webhook"] is True
    assert mail["mails"] == ["em_2:beta:nobody@example.com:bounced:Permanent: General: No such mailbox",
                             "em_1:sign_in_code:ada@example.com:delivered+sent:"]
    assert mail["totals"]["sent"] == 1 and mail["totals"]["delivered"] == 1 and mail["totals"]["bounced"] == 1
    # The checks' own apart.
    assert got["mail_tests"] == ["em_6:bounced@resend.dev", "em_3:delivered+console@resend.dev"]
    assert got["overview_site"]["delivery"]["bounced"] == 1


def test_connector_says_each_accounts_state_and_its_calls() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    assert got["calls_noted"] == [1, 2]
    assert got["connector"]["emails"] == ["ada@example.com"] and got["connector"]["ada_state"] == "tab"
    tests = got["connector_tests"]
    assert tests["emails"] == ["bob@resend.dev"] and tests["claudes"] == 1 and tests["live_tabs"] == 1
    assert tests["calls"] == {"today": 2, "week": 2, "month": 2} and tests["last_tool"] == "get_model"
    assert len(tests["sessions"]) == 1 and tests["sessions"][0].endswith(":2:true:get_model")
    assert got["connector_one"] == ["bob@resend.dev"]
    assert got["connector_bad"] == 404 and got["connector_none"] == []


def test_site_says_the_releases_the_crons_and_the_backend() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    site = got["site"]
    assert site["releases"] == ["rel-m2:0123456789ab:three", "rel-m1:abcdef123456:one+two"]
    assert site["share_sweep"] == "failed" and site["share_said"] == {"error": "storage 500"}
    assert site["canary"] == "failed" and site["canary_said"]["failed"] == ["(code) no code came"]
    assert site["beta_daily"] == "never"
    assert site["health_ok"] is True and site["health_parts"] == ["auth", "rest", "storage"]
    over = got["overview_site"]
    assert over["live"] == "rel-m2" and over["failed"] == ["canary:failed", "share_sweep:failed"]
    # Supabase refusing the project: said, with where the owner lifts it.
    down = got["health_402"]
    assert down["ok"] is False and down["restricted"] is True
    assert "Billing" in down["fix"] and "402" in down["fix"]
    assert down["parts"] == {"auth": "402:True", "rest": "402:True", "storage": "402:True"} or \
        down["parts"] == {"auth": "402:true", "rest": "402:true", "storage": "402:true"}
    assert got["health_back"] is True


def test_plans_ask_nothing_while_billing_is_off_and_read_admission_when_on() -> None:
    got = _run("api2_check.mjs")
    if got is None:
        return
    assert got["plans_off"] == {"billing": "off", "plans": None, "customers": None, "asked": 0}
    on = got["plans_on"]
    assert on["billing"] == "test" and on["read"] is True and on["plans"] == ["free", "pro"]
    # This mode's customers only, from Admission's own answers kept.
    assert on["customers"] == ["ada@example.com:pro:override", "bob@resend.dev:pro:subscription"]
    assert on["comps"] == ["ada@example.com"] and on["mrr"] == 800
    assert on["months"] == ["2026-11:0:300:-300", "2026-10:800:0:800"]
    assert on["events"] == ["refund", "payment.succeeded", "subscription.started"] and on["said"] == {}


# --- The release train --------------------------------------------------------


def test_the_train_writes_down_each_release_live_and_never_fails_a_ship() -> None:
    ship = (ROOT / "tools/release/ship.sh").read_text()
    live = (ROOT / "tools/release/release_live.sh").read_text()
    # After the domain serves the release, and never with a Vercel token.
    assert ship.index('"$HERE/release_live.sh" "$TAG" "$LIVE"') > ship.index("serves || { sleep 120; serves; }")
    assert "VERCEL_TOKEN" not in live and "rpc/site_release_live" in live
    assert re.search(r"^exit 0$", live, re.M)
    # A database that does not answer: it says so and exits 0.
    done = subprocess.run(["bash", "tools/release/release_live.sh", "rel-m1", "abcdef1"], cwd=ROOT, capture_output=True,
                          text=True, timeout=60, env={"PATH": "/usr/bin:/bin", "SUPABASE_URL": "http://127.0.0.1:9",
                                                      "SUPABASE_SECRET_KEY": "x"})
    assert done.returncode == 0, done.stderr
    assert "release_live: rel-m1 not written down" in done.stdout
