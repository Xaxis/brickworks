"""The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md).

supabase/console3.sql runs in a Postgres of its own (tests/fixtures/beta/pg.mjs)
after the files it reads (db3_check.mjs): the site's notice set, replaced and
cleared by scope, the deployment's variables kept by name only, what the
project uses, an account signed out everywhere, exported with no secret
column and within what a browser holds, and found by Find; nothing reachable
but by the server. The API (api/admin.js's new ops; api/plans.js's public
notice) runs against that same file (api3_check.mjs): every new op closed to
anybody but the owner, its reads never audited and its writes always, a
cron run only at the site's own address, and an account deleted only with
its address typed again.

Both need node's pg (PG_MODULE, or /tmp/pg) and Postgres's initdb and
postgres (PG_BIN, or Admission's embedded copy); without them those tests
return, as test_console.py's do. What needs neither runs everywhere.
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
SQL = (ROOT / "supabase/console3.sql").read_text()
# admin_export again after the review (c3fix): what the live database has.
SQL_B = (ROOT / "supabase/console3b.sql").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()

FUNCTIONS = {"site_notice", "site_notice_set", "site_notice_clear", "site_notices_list", "site_settings_list", "site_env_note",
             "site_env_list", "admin_usage", "admin_sign_out", "admin_export", "admin_person_more",
             "challenge_admin_entries", "admin_find"}


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
                          text=True, timeout=240)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


def _node(code: str) -> str:
    done = subprocess.run(["node", "--input-type=module", "-e", code], cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return done.stdout.strip()


# --- The SQL's shape ----------------------------------------------------------


def test_the_sql_only_adds() -> None:
    lowered = SQL.lower()
    # What it runs as it is applied: nothing dropped, changed or removed.
    outside = re.sub(r"\$\$.*?\$\$", "", re.sub(r"--[^\n]*", "", lowered), flags=re.S)
    for word in ("drop ", "truncate", "alter column", "add column", "delete ", "update ", "rename"):
        assert word not in outside, word
    # What its functions remove, each the act it is for: a variable gone
    # from Vercel, and one account's sessions and Claudes signed out.
    assert re.findall(r"delete from (\w+\.\w+)", lowered) == ["public.site_env", "auth.sessions", "public.oauth_grants"]
    assert set(re.findall(r"update (\w+\.\w+)", lowered)) == {"public.site_notices"}
    made_tables = set(re.findall(r"create table if not exists public\.([a-z_]+)", lowered))
    assert made_tables == {"site_notices", "site_env"}
    for table in made_tables:
        assert f"alter table public.{table} enable row level security" in lowered, table
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role" in lowered, table


def test_every_function_is_the_servers_alone() -> None:
    made = set(re.findall(r"create or replace function public\.([a-z_]+)\(", SQL))
    assert made == FUNCTIONS
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", SQL), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", SQL), name
    # Each runs as its owner with no search path to be steered by.
    assert len(re.findall(r"^security definer$", SQL, re.M)) == len(FUNCTIONS)
    assert len(re.findall(r"^set search_path = ''$", SQL, re.M)) == len(FUNCTIONS)


def test_the_export_holds_back_secrets_and_stays_a_download() -> None:
    body = SQL_B[SQL_B.index("create or replace function public.admin_export"):SQL_B.index("revoke all on function")]
    # orangecheck's handle beside rh, and the connector tab's tool list (hello, list), never read.
    assert ("array['hash', 'rh', 'oc_rh', 'code_challenge', 'channel', 'secret', 'token', 'hello', 'list']" in body
            and "a.attname <> all (hidden)" in body)
    # Sign-in codes, orangecheck's sessions and the audit are not the person's to take.
    assert "not in ('oauth_codes', 'oc_sessions', 'admin_audit')" in body
    assert body.count("limit 1000") == 2 and body.count("> 8192") == 2 and "'not_exported'" in body
    assert "'more', more" in body
    # A value is measured, never written out as text to be measured (the busy export's 6 to 10 s).
    assert "pg_column_size" in body and "octet_length" not in body and "::text)" not in body


def test_console3b_only_replaces_the_export_and_keeps_it_the_servers() -> None:
    assert re.findall(r"create or replace function public\.([a-z_]+)\(", SQL_B) == ["admin_export"]
    outside = re.sub(r"\$\$.*?\$\$", "", re.sub(r"--[^\n]*", "", SQL_B.lower()), flags=re.S)
    for word in ("drop ", "truncate", "alter ", "delete ", "update ", "rename", "create table", "insert "):
        assert word not in outside, word
    assert "revoke all on function public.admin_export(uuid) from public, anon, authenticated;" in SQL_B
    assert "grant execute on function public.admin_export(uuid) to service_role;" in SQL_B
    assert SQL_B.count("\nsecurity definer\n") == 1 and SQL_B.count("\nset search_path = ''\n") == 1
    # Applying console3.sql again alone would put the slow export back: apply_sql.mjs refuses it.
    later = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
             if line.strip() and not line.startswith("#")]
    row = ["console3.sql", "admin_export", "console3b.sql", "'oc_rh'"]
    assert row in later and row[3] in SQL_B and row[3] not in SQL


def test_the_new_ops_are_ops_of_admin_and_behind_its_owner_check() -> None:
    # No new function: Vercel's twelve stay twelve.
    functions = [p.name for p in (ROOT / "api").glob("*.js") if not p.name.startswith("_")]
    assert len(functions) == 12, functions
    for op in ("unbar_model: unbarModel", "notice_set: noticeSet", "notice_clear: noticeClear", "run_cron: runCron",
               "export: exportAccount", "delete_account: deleteAccount", "sign_out: signOut"):
        assert op in ADMIN, op
    for read in ("switches: async () => switchesRead(", "find: () => findRead(", "challenge_view: () =>", "data: "):
        assert read in ADMIN, read
    assert ADMIN.index("if (!isMaster(claims))") < ADMIN.index("const op = String(request.query?.op")
    # One deletion, the person's own and the owner's: the same code.
    erase = (ROOT / "api/_erase.js").read_text()
    assert "export async function erase(" in erase
    assert 'from "./_erase.js"' in (ROOT / "api/account.js").read_text()
    assert "erase(" in (ROOT / "api/_console_people.js").read_text()


# --- Run now's address --------------------------------------------------------


def test_run_now_sends_the_crons_key_only_to_the_sites_own_address() -> None:
    got = json.loads(_node("""
const { ownOrigin } = await import("./api/_console_data.js");
process.env.VERCEL_URL = "brickworks-q1w2e3-xaxis-projects.vercel.app";
const of = (host, forwarded) => ownOrigin({ headers: { host, ...(forwarded ? { "x-forwarded-host": forwarded } : {}) } });
console.log(JSON.stringify([
  of("brickworks.diy"), of("www.brickworks.diy"), of("brickworks-q1w2e3-xaxis-projects.vercel.app"),
  of("brickworks-git-console3-xaxis-projects.vercel.app"), of("127.0.0.1:9981"), of("localhost:9981"),
  of("evil.example.com"), of("brickworks-x-xaxis-projects.vercel.app.evil.com"), of("brickworks.diy.evil.com"),
  of("brickworks.diy", "evil.example.com"), of(""), ownOrigin(undefined),
]));
"""))
    assert got == ["https://brickworks.diy", "https://www.brickworks.diy", "https://brickworks-q1w2e3-xaxis-projects.vercel.app",
                   "https://brickworks-git-console3-xaxis-projects.vercel.app", "http://127.0.0.1:9981", "http://localhost:9981",
                   None, None, None, None, None, None]


# --- The notice on every page -------------------------------------------------


def test_every_page_asks_for_the_notice_and_shows_it_as_text() -> None:
    theme = (ROOT / "web/theme.js").read_text()
    notice = (ROOT / "web/notice.js").read_text()
    assert 'import("/notice.js")' in theme
    # Not on an embed's card or the connector's consent page.
    hook = theme[theme.index("// The site's notice"):]
    assert 'hasAttribute("data-embed")' in hook and "oauth" in hook
    assert "text.textContent = words" in notice and "innerHTML = words" not in notice
    assert 'fetch("/api/plans?op=notice"' in notice
    # Its one word of its own is translated; the owner's are never machine-made.
    assert '"web/notice.js": ()' in (ROOT / "tools/site_lang.py").read_text()
    for lang in ("de", "fr", "es"):
        words = json.loads((ROOT / f"web/_lang/{lang}.json").read_text())
        assert words["scripts"].get("Site notice"), lang
    css = (ROOT / "web/site.css").read_text()
    assert ".site-notice" in css and "position: fixed" in css[css.index(".site-notice"):]


# --- The release train --------------------------------------------------------


def test_the_train_writes_down_variable_names_and_never_a_value(tmp_path: Path) -> None:
    ship = (ROOT / "tools/release/ship.sh").read_text()
    assert ship.index('"$HERE/env_names.sh"') > ship.index('"$HERE/release_live.sh" "$TAG" "$LIVE"')
    # Vercel's listing with its values, and what reached the database: names
    # and environments only, nothing printed of a value.
    secret = "sk-this-is-a-value-never-to-be-seen"
    listing = {"envs": [
        {"key": "CRON_SECRET", "value": secret, "target": ["production", "preview"], "type": "encrypted"},
        {"key": "MASTER_EMAIL", "value": "owner@example.com", "target": "production"},
        {"key": "lower_case", "value": secret, "target": ["production"]},
        {"key": "ODD_TARGET", "value": secret, "target": ["staging", "development"]},
    ]}
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "npx").write_text(f"#!/bin/bash\ncat <<'EOF'\n{json.dumps(listing)}\nEOF\n")
    sent = tmp_path / "sent"
    (bin_dir / "curl").write_text(f'#!/bin/bash\nprintf "%s\\n" "$@" > {sent}\nprintf "4 200"\n')
    for tool in ("npx", "curl"):
        (bin_dir / tool).chmod(0o755)
    env = {"PATH": f"{bin_dir}:/usr/bin:/bin", "HOME": str(tmp_path), "SUPABASE_URL": "https://db.test",
           "SUPABASE_SECRET_KEY": "server-key", "VERCEL_TOKEN": "vercel-token"}
    done = subprocess.run(["bash", "tools/release/env_names.sh"], cwd=ROOT, env=env, capture_output=True, text=True,
                          timeout=60, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr
    assert done.stdout.strip() == "env_names: 4 variables written down", done.stdout
    assert secret not in done.stdout + done.stderr and "owner@example.com" not in done.stdout + done.stderr
    posted = sent.read_text().splitlines()
    body = json.loads(posted[posted.index("-d") + 1])
    assert body == {"p_vars": [{"name": "CRON_SECRET", "environments": ["preview", "production"]},
                               {"name": "MASTER_EMAIL", "environments": ["production"]},
                               {"name": "ODD_TARGET", "environments": ["development"]}]}
    assert secret not in sent.read_text() and "owner@example.com" not in sent.read_text()
    # Vercel not answering: said, and the ship goes on.
    (bin_dir / "npx").write_text("#!/bin/bash\nexit 1\n")
    done = subprocess.run(["bash", "tools/release/env_names.sh"], cwd=ROOT, env=env, capture_output=True, text=True,
                          timeout=60, stdin=subprocess.DEVNULL)
    assert done.returncode == 0 and "did not list" in done.stdout


# --- The database -------------------------------------------------------------


def test_the_database_keeps_and_reads_as_the_console_needs() -> None:
    got = _run("db3_check.mjs")
    if got is None:
        return
    assert got["again"] == "ok"
    # One notice a scope: set in place of the one before, cleared, kept as history.
    assert got["none"] is None and got["first"]["was"] is None and got["second"]["was"] == 1
    assert got["showing"]["words"] == {"en": "Back up.", "de": "Wieder da."} and got["preview_none"] is None
    for why, said in got["bad_words"].items():
        assert "violates check constraint" in said, why
    assert got["preview_after_bad"] is None
    assert got["cleared"] == {"cleared": 2} and got["cleared_again"] == {"cleared": None} and got["after_clear"] is None
    assert [one["id"] for one in got["history"]] == [2, 1] and all(one["cleared_at"] for one in got["history"])
    # The variables by name: a name gone from Vercel let go, a duplicate once.
    assert got["env_kept"] == 3 and got["env_again"] == 2
    assert got["env"]["vars"] == [{"name": "CRON_SECRET", "environments": ["production"]},
                                  {"name": "MASTER_EMAIL", "environments": ["preview", "production"]}]
    assert "site_env_name" in got["env_bad"] and "site_env_environments" in got["env_bad_where"]
    # Usage: the database's size, its tables, storage by bucket (a size that is no number, nothing).
    assert got["usage"]["database"] > 0 and got["usage"]["tables"]
    assert got["usage"]["buckets"] == [{"bytes": 3000, "files": 2, "bucket": "parts"},
                                       {"bytes": 500, "files": 2, "bucket": "shared-models"}]
    # Signed out everywhere: ada's sessions, their refresh tokens and her Claude; bob's kept.
    assert got["signed_out"] == {"claudes": 1, "sessions": 2}
    assert got["left"] == {"ada_sessions": 0, "bob_sessions": 1, "refresh_tokens": 1, "ada_claudes": 0}
    assert got["signed_out_again"] == {"claudes": 0, "sessions": 0}


def test_an_export_is_every_table_of_the_account_with_no_secret() -> None:
    got = _run("db3_check.mjs")
    if got is None:
        return
    export = got["export"]
    assert sorted(export["tables"]) == ["model_collection_items", "model_collections", "oauth_grants", "people", "relay_tabs",
                                        "reports", "shared_models"]
    # A thousand rows a table, the rest counted; the tool lists never read.
    tabs = export["tables"]["relay_tabs"]
    assert len(tabs) == 1000 and export["more"] == {"relay_tabs": 1002}
    assert not any("hello" in row for row in tabs)
    # A working value over 8 KB is named by its size: as JSON where it stores small (20 KB of one
    # letter), as stored where it does not (12.8 KB of hex), and never read then.
    sizes = {json.dumps(row["model"]) for row in tabs}
    assert len(sizes) == 2, sizes
    for row in tabs:
        assert set(row["model"]) == {"not_exported"} and row["model"]["not_exported"] > 8192
    text = json.dumps(export)
    assert "channel" not in text and "c" * 64 not in text and "d" * 64 not in text
    assert "oc_rh" not in text and "h" * 43 not in text and "x" * 100 not in text and "m" * 100 not in text
    assert export["tables"]["model_collection_items"] == [{"model": "BobModel01", "added_at": export["tables"][
        "model_collection_items"][0]["added_at"], "collection": "AdaList001"}]


def test_find_reaches_people_lists_and_reports_and_no_wildcard() -> None:
    got = _run("db3_check.mjs")
    if got is None:
        return
    assert [one["handle"] for one in got["find_handle"]["people"]] == ["ada-builds"]
    assert [one["id"] for one in got["find_list"]["lists"]] == ["AdaList001"]
    assert [one["id"] for one in got["find_report"]["reports"]] == [1]
    empty = {"lists": [], "models": [], "people": [], "reports": []}
    assert got["find_wild"] == empty and got["find_short"] == empty


def test_nothing_is_reachable_but_by_the_server() -> None:
    got = _run("db3_check.mjs")
    if got is None:
        return
    for row in got["grants"]:
        assert row["rls"] is True and row["anon"] is False and row["signed_in"] is False and row["server"] is False, row
    assert len(got["functions"]) == 10
    for row in got["functions"]:
        assert row["definer"] and not row["anon"] and not row["signed_in"] and row["server"], row


# --- The API ------------------------------------------------------------------


NEW_OPS = ("data", "find", "challenge_view", "switches", "unbar_model", "notice_set", "notice_clear", "run_cron", "export",
           "delete_account", "sign_out")


def test_every_new_op_is_401_signed_out_and_404_to_anybody_else() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["gate"] == {op: [401, 404] for op in NEW_OPS}
    # Nothing done for them: nothing kept, nobody deleted.
    assert got["audit_after_gate"] == 0 and got["ada_after_gate"] == 1


def test_reads_are_never_audited_and_every_write_is() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["audit_after_reads"] == 0
    assert got["audit"] == [
        "notice_set:setting:notice:400", "notice_set:setting:notice:200", "notice_set:setting:notice:200",
        "notice_set:setting:notice:200",
        "notice_clear:setting:notice:200", "notice_clear:setting:notice:404",
        "run_cron:cron:beta_daily:409", "run_cron:cron:nope:400",
        # A name Object's prototype lends is no cron: refused as one, kept as what was asked.
        "run_cron:cron:constructor:400", "run_cron:cron:__proto__:400", "run_cron:cron:hasOwnProperty:400",
        "run_cron:cron:toString:400",
        "run_cron:cron:gallery_feature:200",
        # Twice at once: the one refused answers first; then one more, once the first has ended.
        "run_cron:cron:share_sweep:409", "run_cron:cron:share_sweep:200", "run_cron:cron:share_sweep:200",
        "run_cron:cron:canary:400", "run_cron:cron:canary:503",
        "sign_out:account:00000000-0000-4000-8000-000000000003:200", "sign_out:account:00000000-0000-4000-8000-00000000abcd:404",
        "export:account:00000000-0000-4000-8000-000000000002:200",
        "export:account:00000000-0000-4000-8000-000000000003:200",
        "export:account:00000000-0000-4000-8000-000000000004:200",
        "delete_account:account:00000000-0000-4000-8000-000000000001:403",
        "delete_account:account:00000000-0000-4000-8000-000000000002:422",
        "delete_account:account:00000000-0000-4000-8000-000000000002:422",
        "delete_account:account:00000000-0000-4000-8000-000000000002:200",
        "delete_account:account:00000000-0000-4000-8000-000000000002:404",
        "unbar_model:model:short:400"]
    detail = got["audit_detail"]
    # A deleted account kept by its address; an export by its count, never its rows; never a key.
    assert detail["delete_account"]["said"]["email"] == "ada@example.com"
    assert detail["delete_account"]["asked"] == {"reason": "Asked by email"}
    assert got["audit_exports"] == [{"rows": "4", "email": "ada@example.com"}, {"rows": "1", "email": "bob@resend.dev"},
                                    {"rows": "0", "email": "cleo@resend.dev"}]
    assert detail["run_cron"]["said"]["outcome"] == "done" and got["audit_leaks"] is False


def test_the_switches_name_every_variable_and_never_a_value() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    switches = got["switches"]
    assert switches["status"] == 200 and switches["leaks"] == [] and switches["cron_here"] is True
    for name in ("MASTER_EMAIL", "CRON_SECRET", "SUPABASE_SECRET_KEY", "RESEND_API_KEY", "OC_SIGNING_SECRET"):
        assert name in switches["names"], name
    # Nothing written down yet: each variable's environments are not known.
    assert switches["master_before"] is None
    noted = got["switches_noted"]
    assert noted["cron"] == ["preview", "production"] and noted["master"] == []
    # Set at Vercel and read by nothing in the code: named so it can be taken out.
    assert noted["unread"] == ["ANTHROPIC_API_KEY:production"]


def test_the_notice_is_set_shown_on_its_own_site_and_cleared() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["notice_no_english"]["status"] == 400
    assert got["notice_set"]["status"] == 200 and got["notice_set"]["json"]["languages"] == ["en", "de"]
    # A language the site does not have is dropped, not kept.
    assert got["notice_shown"] == {"status": 200, "json": {"notice": {"id": 1, "words": {
        "de": "Wartung um 02:00 UTC.", "en": "Down for upkeep at 02:00 UTC."}, "tone": "warn"}}}
    # A preview's notice is the preview's alone.
    assert got["notice_live"] == {"notice": None}
    assert got["notice_again"]["was"] == 1 and got["notice_overview"]["words"] == {"en": "Back up."}
    # Words that are markup are words: kept and given back exactly as typed, and every page puts
    # them on itself as text (test_every_page_asks_for_the_notice_and_shows_it_as_text).
    assert got["notice_markup_set"] == 200 and got["notice_markup"] == {"en": True, "fr": True}
    assert got["notice_cleared"] == 200 and got["notice_cleared_again"] == 404 and got["notice_after"] == {"notice": None}


def test_the_numbers_a_phone_is_warned_by_are_the_owners_and_their_sites() -> None:
    """phonetruth (api/_phone.js, docs/PHONE.md): set in Switches, read by anybody at /api/plans?op=phone."""
    got = _run("api3_check.mjs")
    if got is None:
        return
    measured = {"phone_parts": 2500, "phone_start_s": 25}
    assert got["phone_before"] == measured
    # Nobody but the owner, and nothing kept of the attempts.
    assert got["phone_gate"] == [401, 404] and got["phone_audit_gate"] == 0
    # Refused with words, and then none kept: a number named for neither, out of range, not whole, not a number,
    # even with the other one good (all or none).
    assert got["phone_none"]["status"] == 400 and "phone_parts or phone_start_s" in got["phone_none"]["json"]["error"]
    assert got["phone_low"]["status"] == 400 and "from 50 to 100,000 parts" in got["phone_low"]["json"]["error"]
    assert got["phone_half"]["status"] == 400 and "from 1 to 600 seconds" in got["phone_half"]["json"]["error"]
    assert got["phone_words"]["status"] == 400
    assert got["phone_after_refused"] == measured
    # A zero-width space typed into the number is not part of it.
    assert got["phone_set"]["status"] == 200 and got["phone_set"]["json"]["phone_parts"] == 1200
    assert got["phone_shown"]["status"] == 200 and got["phone_shown"]["json"] == {"phone_parts": 1200, "phone_start_s": 40}
    # A preview's numbers are the preview's alone.
    assert got["phone_live"] == measured
    # One named alone leaves the other as it was.
    assert got["phone_one"]["phone_start_s"] == 30 and "phone_parts" not in got["phone_one"]
    rules = {one["name"]: one for one in got["phone_switches"]}
    assert rules["phone_parts"]["value"] == 1200 and rules["phone_parts"]["set"] and rules["phone_parts"]["fallback"] == 2500
    assert rules["phone_parts"]["set_by"] == "owner@example.com" and rules["phone_start_s"]["value"] == 30
    # Every act kept, refused ones too, each on the setting, with what was asked.
    assert [one["status"] for one in got["phone_audit"]] == [400, 400, 400, 400, 200, 200]
    assert {one["target"] for one in got["phone_audit"]} == {"setting:phone"}
    assert got["phone_audit"][4]["asked"] == {"phone_parts": "1​200", "phone_start_s": "40"}


def test_the_phone_numbers_read_by_the_pages_are_the_apis_measured_ones() -> None:
    """The fallbacks the pages hold until the site answers are api/_phone.js's own."""
    phone = (ROOT / "api/_phone.js").read_text()
    parts = re.search(r"phone_parts: \{[^}]*fallback: (\d+)", phone).group(1)
    start = re.search(r"phone_start_s: \{[^}]*fallback: (\d+)", phone).group(1)
    assert f"export const PHONE_PARTS = {parts};" in (ROOT / "web/phone-warn.js").read_text()
    assert f"start_s: {start}," in (ROOT / "src/boot/shell.html").read_text()


def test_run_now_runs_only_a_safe_cron_at_the_sites_own_address() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["run_beta"]["status"] == 409 and "testers" in got["run_beta"]["json"]["error"]
    assert got["run_unknown"] == 400
    # constructor, __proto__, hasOwnProperty, toString: no cron (400), no op (404 by GET and POST), nothing audited.
    assert got["run_proto"] == [400, 400, 400, 400]
    assert got["op_proto"] == [[404, 404]] * 4 and got["audit_after_proto"] == 0
    assert got["wrong_method"] == [405, 405]
    assert got["run"]["status"] == 200 and got["run"]["ran"] is True and got["run"]["outcome"] == "done"
    assert got["run"]["calls"] == [{"url": "https://brickworks-abc123-xaxis-projects.vercel.app/api/share/feature",
                                    "key": "Bearer cron-key-for-this-test-only"}]
    # Asked under another address: refused, and the key sent nowhere.
    # Twice at once (two tabs, two presses): one runs, the other is refused and never reaches the
    # cron; the hold goes when the first ends, so the next is run.
    assert [one[:2] for one in got["run_twice"]] == [[200, True], [409, False]]
    assert "running already" in got["run_twice"][1][2] and got["run_twice_calls"] == 1
    assert got["run_after_twice"] == 200
    assert got["run_holds"] == ["run_now_gallery_feature:console:done", "run_now_share_sweep:console:done",
                                "run_now_share_sweep:console:locked", "run_now_share_sweep:console:done"]
    assert got["run_elsewhere"] == 400 and got["calls_after_elsewhere"] == 3
    assert got["run_no_secret"] == 503


def test_an_account_is_exported_signed_out_and_deleted_only_as_typed() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    export = got["export"]
    assert export["status"] == 200 and export["email"] == "ada@example.com"
    assert export["tables"] == ["collection_sets", "model_collections", "people", "relay_tabs"] and export["rows"] == 4
    # The sets in its lists (lists1), keyed to a list and not to the account, come with it.
    assert export["sets"] == ["AdaList001:10305-1"]
    # Bob follows ada: counted in hers, never named, in no table nor count (c3review X); his own keeps it.
    assert export["followers"] == 1 and export["follower_named"] is False and export["more"] == {}
    assert "follows.followed" not in export["tables"] and "follows.followed" not in export["counts"]
    assert got["export_follower"] == {"status": 200, "follows": [True], "followers": 0}
    # An account with nothing anywhere: an export of nothing, not a failure.
    assert got["export_empty"] == {"status": 200, "email": "cleo@resend.dev", "tables": {}, "rows": 0, "more": {}}
    assert export["channel"] is False
    assert export["sign_in"] == ["confirmed_at", "created_at", "email", "last_sign_in_at", "providers"]
    assert got["sign_out"]["sessions"] == 2 and got["sessions_left"] == {"bob": 0, "ada": 1}
    assert got["sign_out_nobody"] == 404
    # Never the owner's; never without the address typed, exactly but for case and spaces.
    assert got["delete_owner"]["status"] == 403
    assert got["delete_untyped"]["status"] == 422 and got["delete_mistyped"]["status"] == 422
    assert got["ada_after_refusals"] == 1
    assert got["delete"]["status"] == 200 and got["delete"]["json"]["deleted"] is True
    assert got["delete"]["deleted"] == ["00000000-0000-4000-8000-000000000002"]
    assert got["ada_after"] == 0 and got["ada_rows_after"] == {"people": 0, "lists": 0}
    assert got["delete_again"] == 404


def test_find_and_the_challenge_and_data_reads() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["find"] == {"status": 200, "accounts": ["ada@example.com"], "people": ["ada-builds"], "ready": True}
    # The checks' own accounts only when the console shows the checks'.
    assert got["find_tests"] == ["bob@resend.dev"]
    assert all(value == [] for key, value in got["find_short"].items() if key != "query")
    assert got["challenge_bad"] == 400 and got["challenge_before_sql"] == {"ready": False}
    data = got["data"]
    assert data["status"] == 200 and data["database"] is True and data["buckets"] == []
    # Supabase's egress: no read-only way to it, said so.
    assert data["egress_read"] is False and data["egress_why"] is True


def test_moderation_sorts_every_kind_of_report() -> None:
    got = _run("api3_check.mjs")
    if got is None:
        return
    assert got["kinds"] == ["model", "comment", "photo", "profile", "list", "takedown", "counter_notice", "model"]
    # Each kind the server says has a row the queue draws; an unknown one is drawn plainly.
    moderation = (ROOT / "web/admin-moderation.js").read_text()
    for kind in set(got["kinds"]):
        assert re.search(rf"^\s+{kind}: \{{", moderation, re.M), kind
    assert "KINDS[report.kind] || PLAIN" in moderation
