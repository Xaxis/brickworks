"""The beta: 100 testers, each given a month of Pro (beta361, 2026-10-29).

supabase/beta.sql runs in a Postgres of its own (tests/fixtures/beta/pg.mjs),
so what only a database can show is shown by one: two approvals at once at
99 spots given make spot 100 and one refusal, and 120 from ten connections
make spots 1 to 100, each once (db_check.mjs). The API (api/_beta.js through
api/plans.js and api/admin.js) runs against that same file with the stand-in
Admission (api_check.mjs): the switch, the form's refusals, the owner's gate,
the month given in Admission's test mode or left to start when Pro launches,
Admission's refusals said, the emails, and the daily run.

Both need node's pg (PG_MODULE, or /tmp/pg) and Postgres's initdb and
postgres (PG_BIN, or Admission's embedded copy); without them those tests
return, as test_billing.py's do without node. What needs neither (the SQL's
shape, the pages, the words) runs everywhere.
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
SQL = (ROOT / "supabase/beta.sql").read_text()
PAGE = (ROOT / "web/beta.html").read_text()
SCRIPT = (ROOT / "web/beta.js").read_text()


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
    done = subprocess.run(["node", f"tests/fixtures/beta/{script}"], cwd=ROOT, env=env, capture_output=True,
                          text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def db() -> dict | None:
    return _run("db_check.mjs")


def api() -> dict | None:
    return _run("api_check.mjs")


# --- The database itself --------------------------------------------------


def test_two_approvals_at_once_at_99_give_one_spot_100_and_one_refusal() -> None:
    got = db()
    if got is None:
        return
    first, second = got["race_at_99"]
    # The second waited on the pool's lock while the first held it.
    assert got["second_waits"] == 1
    assert first["application"]["spot"] == 100 and first["application"]["status"] == "approved"
    assert second == {"refused": "full", "pool": {"pool": "beta", "cap": 100, "given": 100, "left": 0}}
    assert got["race_spots"] == [{"spot": 100, "status": "approved"}]
    # The last spot gone, what waits goes to the waitlist, and so does what comes after.
    assert got["late_status"] == "waitlist"
    assert got["after_full"]["application"]["status"] == "waitlist"


def test_many_approvals_at_once_give_each_spot_once_and_never_past_100() -> None:
    got = db()
    if got is None:
        return
    many = got["many"]
    assert many["approved"] == 100 and many["refused"] == 20 and many["distinct"] == 100
    assert (many["lowest"], many["highest"], many["rows"]) == (1, 100, 100)
    assert many["pool"] == {"pool": "beta", "cap": 100, "given": 100, "left": 0}
    # Nothing past the cap or a spot twice, even written by hand.
    assert "beta_pools_given" in got["past_cap"]
    assert "beta_applications_spot_once" in got["spot_twice"]


def test_one_application_an_account_and_again_only_30_days_after_a_decline() -> None:
    got = db()
    if got is None:
        return
    assert got["apply_first"]["application"]["status"] == "new"
    assert got["apply_again"] == {"refused": "applied", "status": "new"}
    assert got["decline"]["application"]["status"] == "declined"
    assert got["decline"]["application"]["may_apply_again_at"]
    assert got["decline_again"]["again"] is True
    assert got["apply_too_soon"]["refused"] == "too_soon"
    assert got["apply_after_30"]["application"]["status"] == "new"
    # The owner may change their mind about a decline; an approval stands.
    assert got["approve_declined"]["application"]["spot"] == 1
    assert got["decline_approved"]["refused"] == "approved"
    assert got["approve_twice"]["again"] is True and got["approve_twice"]["application"]["spot"] == 1
    assert got["decisions_of_eve"] == [{"decision": "declined", "by_email": "owner@example.com"},
                                       {"decision": "approved", "by_email": "owner@example.com"}]


def test_an_account_from_before_29_october_takes_no_spot() -> None:
    got = db()
    if got is None:
        return
    assert got["early_apply"]["early"] is True and got["early_apply"]["application"]["status"] == "new"
    # Approved with every spot given: it needs none.
    approved = got["early_approve"]["application"]
    assert approved["status"] == "approved" and approved["spot"] is None and approved["comp"] == "none"
    assert got["early_approve"]["pool"]["given"] == 100
    assert got["early_edges"] == [{"before": True, "at": False}]


def test_the_month_and_its_reminder() -> None:
    got = db()
    if got is None:
        return
    assert got["comp_pending"]["comp"] == "pending"
    assert got["comp_granted"]["comp"] == "granted" and got["comp_granted"]["month_ends_at"]
    # Granted is never made pending again.
    assert got["comp_not_undone"] == got["comp_granted"]
    assert got["comps_due"] == []
    assert got["remind_too_early"] == []
    assert [one["email"] for one in got["remind"]] == ["eve@example.com"]
    assert got["remind_again"] == []


def test_the_owners_queue_reads_each_account() -> None:
    got = db()
    if got is None:
        return
    facts = got["queue_facts"]
    # One inbox, two accounts: Gmail's dots, a +tag and googlemail.com.
    assert facts["a.da.l+beta@gmail.com"]["same_inbox"] == 1 and facts["a.da.l+beta@gmail.com"]["same_inbox_applied"] == 1
    assert facts["a.da.l+beta@gmail.com"]["models_kept"] == 2 and facts["a.da.l+beta@gmail.com"]["models_shared"] == 1
    assert facts["dee@example.com"]["same_inbox"] == 0
    assert facts["never@example.com"]["confirmed"] is False and facts["dee@example.com"]["confirmed"] is True
    assert got["inbox"] == [{"g": "adal@gmail.com", "e": "ada@example.com", "plain": "ada@example.com"}]
    # New first, oldest first; then approved.
    assert got["queue_order"][0] == "dee@example.com"
    assert got["queue_all"][-1] == ["approved", "eve@example.com"]
    # The checks' pool is their own.
    assert got["test_apply"]["application"]["pool"] == "test"
    assert got["test_approve"]["application"]["spot"] == 99
    assert got["beta_pool_untouched"]["given"] == 1
    assert got["test_queue"] == ["delivered+bw-beta-1@resend.dev"]


def test_deleting_the_account_erases_its_application() -> None:
    got = db()
    if got is None:
        return
    assert got["deleted"] == [{"applications": 0, "decisions": 0, "mail": 0}]
    assert got["deleted_status"]["application"] is None
    # Its spot is spent, not given back.
    assert got["spot_spent"]["given"] == 99
    assert got["sweep"] == 1 and got["swept"] == [{"applications": 0, "decisions": 0}]


def test_only_the_server_and_only_through_the_functions() -> None:
    got = db()
    if got is None:
        return
    for role in ("anon", "authenticated"):
        assert all(said.startswith("refused: permission denied") for said in got["grants"][role].values()), role
    server = got["grants"]["service_role"]
    assert server["read_applications"].startswith("refused") and server["read_pools"].startswith("refused")
    assert server["status"] == server["decide"] == server["test_pool"] == "allowed"
    assert got["row_security"] == [{"relname": name, "on": True, "policies": 0}
                                   for name in ("beta_applications", "beta_decisions", "beta_mail", "beta_pools")]
    assert got["pools"] == [{"pool": "beta", "cap": 100, "given": 0}, {"pool": "test", "cap": 100, "given": 0}]


def test_the_sql_only_adds() -> None:
    body = re.sub(r"--[^\n]*", "", SQL)
    assert not re.search(r"\b(drop|truncate|alter\s+table\s+(?!public\.beta_)|alter\s+function)\b", body, re.I)
    for table in re.findall(r"create table if not exists (public\.\w+)", body):
        assert table.startswith("public.beta_")
        assert f"alter table {table} enable row level security" in body
        assert f"revoke all on {table} from public, anon, authenticated, service_role" in body
    functions = set(re.findall(r"create or replace function (public\.beta_\w+)\(", body))
    assert len(functions) == 15
    for name in functions:
        assert re.search(rf"revoke all on function {re.escape(name)}\(", body), name
    # Only the ones the server calls are granted, and only to it.
    granted = set(re.findall(r"grant execute on function (public\.beta_\w+)\([^)]*\) to service_role;", body))
    assert granted == functions - {"public.beta_inbox", "public.beta_early", "public.beta_pool_view", "public.beta_own_view"}
    assert "to anon" not in body and "to authenticated" not in body
    assert body.count("set search_path = ''") == len(functions)
    # No address and no IP kept: the address is read from the account.
    assert not re.search(r"\b(ip|address|email)\s+(text|inet)", body)


# --- The API, against the SQL ----------------------------------------------


def test_off_the_page_says_coming_and_the_api_takes_nothing() -> None:
    got = api()
    if got is None:
        return
    assert got["off_get"] == {"status": 200, "json": {"beta": "off"}}
    assert got["off_post"]["status"] == 403 and got["off_post"]["json"]["beta"] == "off"
    assert got["off_calls"] == []


def test_signed_out_is_asked_to_sign_in() -> None:
    got = api()
    if got is None:
        return
    assert got["open_signed_out"]["json"]["signed_in"] is False and got["open_signed_out"]["json"]["application"] is None
    assert got["open_signed_out"]["json"]["pool"]["left"] == 100
    assert got["post_signed_out"] == {"status": 401, "json": {"error": "Sign in to apply."}}


def test_the_form_is_checked_at_the_edge() -> None:
    got = api()
    if got is None:
        return
    for name, (status, said) in got["refused"].items():
        assert status == 422 and said, name
    assert "at least 20" in got["refused"]["short"][1]
    assert "at most 800" in got["refused"]["long"][1] and "801" in got["refused"]["long"][1]
    assert "at most 160" in got["refused"]["line"][1]
    assert "https://" in got["refused"]["link"][1] and "https://" in got["refused"]["http_link"][1]
    assert "terms" in got["refused"]["terms"][1] and "email" in got["refused"]["emails"][1]
    # A bare host is made a link.
    assert got["queue"]["first"]["link"] == "https://rebrickable.com/users/ada/mocs/"


def test_applying_once_is_kept_and_mailed() -> None:
    got = api()
    if got is None:
        return
    assert got["applied"]["status"] == 200 and got["applied"]["json"]["application"]["status"] == "new"
    # No mail key here and a test inbox: kept as it would have gone.
    assert got["applied"]["json"]["mail"] == "dry"
    assert got["applied_again"]["status"] == 409
    assert got["tester_mail"][0]["kind"] == "received" and got["tester_mail"][0]["state"] == "dry"
    # With the key: sent, plain and HTML, and Resend's id kept.
    assert got["ada_mail"][0]["state"] == "sent" and got["ada_mail"][0]["sent_id"] == "re-1"
    assert got["sent"] == [{"to": ["ada@example.com"], "subject": "We have your Brickworks beta application",
                            "from": "Brickworks <noreply@brickworks.diy>", "has_text": True, "has_html": True}]
    assert "/privacy#beta" in got["received_text"]
    # Resend down: the application stands, the email kept as failed.
    assert got["resend_down"]["status"] == 200 and got["resend_down"]["json"]["mail"] == "failed"


def test_the_queue_is_the_owners_alone_with_the_signals() -> None:
    got = api()
    if got is None:
        return
    assert got["queue_stranger"] == {"status": 404, "json": {"error": "not found"}}
    first = got["queue"]["first"]
    assert got["queue"]["status"] == 200 and first["email"] == "delivered+beta-a@resend.dev"
    assert set(first["facts"]) == {"confirmed", "made_at", "age_days", "models_kept", "models_shared", "same_inbox",
                                   "same_inbox_applied"}
    assert first["signals"]["domain"] == "resend.dev" and first["signals"]["disposable"] is False
    assert first["signals"]["quality"]["issues"] == []
    assert got["queue"]["months"] == {"billing": "test", "live": "when Pro launches", "test": "at approval"}
    assert got["queue_real"] == ["ada@example.com"]
    assert got["queue_bad_status"] == 400


def test_a_tester_is_given_the_month_in_admissions_test_mode_once() -> None:
    got = api()
    if got is None:
        return
    approved = got["approved"]["json"]
    assert approved["application"]["spot"] == 1 and approved["month"]["comp"] == "granted"
    assert approved["pool"]["left"] == 99
    asked = got["comps_asked"][0]
    assert asked["reason"] == "beta" and asked["made"] is True
    subject = got["approved_mail"][0]["subject"]
    assert subject == "You're in: spot 1 of 100 in the Brickworks beta"
    assert "Your month runs from" in got["approved_mail"][0]["text"]
    # Approving again asks Admission nothing and mails nobody.
    assert got["approved_again"]["json"]["again"] is True
    assert got["comps_asked_again"] == 1
    assert got["tester_after"]["application"]["comp"] == "granted"
    assert got["tester_after"]["pool"]["left"] == 99


def test_a_real_month_waits_for_pro_while_billing_is_not_live() -> None:
    got = api()
    if got is None:
        return
    assert got["ada_approved"]["json"]["month"] == {"comp": "pending", "said": "Starts when Pro launches."}
    assert got["ada_comps_asked"] == 0
    assert got["ada_after"]["application"]["comp"] == "pending" and got["ada_after"]["application"]["spot"] == 1
    assert "starts the day Pro launches" in got["ada_approved_text"]


def test_admissions_refusals_are_said_and_granted_later_once() -> None:
    got = api()
    if got is None:
        return
    assert "API comps limit (100)" in got["comps_off"]["json"]["month"]["said"]
    assert "limit is reached" in got["comps_full"]["json"]["month"]["said"]
    assert got["comps_off"]["json"]["application"]["comp"] == "pending"
    assert got["grant"]["json"] == {"mode": "test", "granted": 2, "pending": 0, "said": []}
    assert got["grant_mail"] == ["Your month of Brickworks Pro has started"] * 2
    assert got["grant_again"]["json"]["granted"] == 0
    assert got["queue_pending"]["pending"] == 0


def test_decline_is_kind_and_says_when_to_apply_again() -> None:
    got = api()
    if got is None:
        return
    assert got["declined"]["json"]["application"]["status"] == "declined"
    mail = got["declined_mail"][0]
    assert mail["subject"] == "About your Brickworks beta application"
    assert "apply again from" in mail["text"] and len(mail["text"]) < 400
    assert got["dee_again"]["status"] == 409 and "apply again from" in got["dee_again"]["json"]["error"]
    assert got["decline_approved"]["status"] == 409
    assert got["decide_nobody"]["status"] == 404


def test_the_last_spot_goes_to_one_of_two_at_once() -> None:
    got = api()
    if got is None:
        return
    assert sorted(got["last_two"], key=lambda one: one[0]) == [[200, 100, None], [409, None, "full"]]
    assert got["full_status"] == {"pool": "test", "cap": 100, "given": 100, "left": 0}
    assert got["early_applied"]["early"] is True
    assert got["early_approved"]["application"]["spot"] is None and "month" not in got["early_approved"]
    assert got["early_mail"] == ["You're in the Brickworks beta"]


def test_the_daily_run_is_the_crons_and_reminds_once() -> None:
    got = api()
    if got is None:
        return
    assert got["daily_stranger"] == 401
    assert got["daily"]["json"]["reminded"] == 1
    assert got["daily_mail"] == [{"to": ["delivered+beta-a@resend.dev"],
                                  "subject": "Three days left of your Brickworks beta month"}]
    assert got["daily_again"]["reminded"] == 0


# --- Words, pages and links -----------------------------------------------


def _mails() -> dict | None:
    if shutil.which("node") is None:
        return None
    script = (
        "const b = await import('./api/_beta.js');"
        "const data = { spot: 7, cap: 100, starts: '2026-11-02T00:00:00Z', ends: '2026-12-02T00:00:00Z',"
        "  again_at: '2026-12-01T00:00:00Z' };"
        "const out = {};"
        "for (const kind of ['received', 'approved', 'declined', 'started', 'reminder'])"
        "  out[kind] = b.renderMail(kind, data, 'https://brickworks.diy');"
        "out.early = b.renderMail('approved', { early: true }, 'https://brickworks.diy');"
        "out.pending = b.renderMail('approved', { spot: 7, cap: 100 }, 'https://brickworks.diy');"
        "out.replied = b.renderMail('received', {}, 'https://brickworks.diy', 'beta@example.com');"
        "out.escaped = b.renderMail('received', {}, 'https://x.test/<b>');"
        "out.quality = [b.qualityOf({ build: 'asdf asdf asdf asdf asdf asdf' }), b.qualityOf({ build: 'A Technic crane "
        "with a working slewing ring, two winches and outriggers' })];"
        "out.disposable = [b.disposable('a@mailinator.com'), b.disposable('a@eu.mailinator.com'), b.disposable('a@gmail.com')];"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_every_email_is_plain_and_html_and_says_what_it_must() -> None:
    got = _mails()
    if got is None:
        return
    for kind in ("received", "approved", "declined", "started", "reminder", "early", "pending"):
        mail = got[kind]
        assert mail["subject"] and mail["text"] and mail["html"].startswith("<!doctype html>"), kind
        assert not re.search(r"AI builds?", mail["text"] + mail["html"], re.I), kind
    approved = got["approved"]["text"]
    assert "spot 7 of 100" in approved and "2 November 2026 to 2 December 2026" in approved
    assert "Nothing is charged, no card is asked for, and nothing is deleted" in approved
    assert "more than 25 models" in approved and "desktop app" in approved
    assert "starts the day Pro launches" in got["pending"]["text"]
    assert "spot" not in got["early"]["subject"] and "no end date" in got["early"]["text"]
    assert "apply again from 1 December 2026" in got["declined"]["text"]
    assert "ends on 2 December 2026" in got["reminder"]["text"]
    assert "Reply to this email" in got["replied"]["text"] and "Reply to this email" not in got["received"]["text"]
    assert "&lt;b&gt;" in got["escaped"]["html"] and "<b>" not in got["escaped"]["html"].split("Brickworks</p>")[0]
    assert "keyboard mashing" in got["quality"][0]["issues"] and got["quality"][1]["issues"] == []
    assert got["disposable"] == [True, True, False]


def test_the_page_says_what_the_brief_asks() -> None:
    words = re.sub(r"<[^>]+>", " ", PAGE)
    words = re.sub(r"\s+", " ", words)
    assert not re.search(r"AI builds?", PAGE + SCRIPT, re.I)
    for said in ("30 days of Pro", "honest", "Nothing is charged", "no card", "nothing is deleted", "25 models",
                 "Coming soon", "before 29 October 2026"):
        assert said.lower() in words.lower(), said
    for field in ('name="build"', 'name="ai"', 'name="background"', 'name="background_line"', 'name="link"',
                  'name="terms"', 'name="emails"'):
        assert field in PAGE, field
    assert 'maxlength="800"' in PAGE and 'maxlength="160"' in PAGE and 'maxlength="300"' in PAGE
    # LEGO® only as an adjective, marked, in the page's own words (the footer's notices are the shell's).
    main = PAGE[PAGE.index("<main"):PAGE.index("</main>")]
    assert "LEGO® " in main and not re.search(r"LEGO(?!®)", main)


def test_terms_privacy_sitemap_and_docs_know_the_beta() -> None:
    terms = (ROOT / "web/terms.html").read_text()
    privacy = (ROOT / "web/privacy.html").read_text()
    assert 'id="beta"' in terms and 'id="beta"' in privacy
    assert "not a subscription" in terms
    for said in ("only the site’s owner", "deleted with your account", "90 days", "IP address"):
        assert said.lower() in privacy.lower(), said
    assert "https://brickworks.diy/beta</loc>" in (ROOT / "web/sitemap.xml").read_text()
    assert (ROOT / "docs-site/beta.md").exists()
    assert "beta" in json.loads((ROOT / "docs-site/_nav.json").read_text()).__repr__()
