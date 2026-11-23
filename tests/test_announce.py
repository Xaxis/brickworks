"""/admin › Announcements (announce, 2026-11-18; docs/ANNOUNCE.md, docs/ADMIN.md).

The owner tells the site's people something in their own Notifications, and
by email only those who chose news. supabase/announce.sql runs in a Postgres
of its own after the console's files (tests/fixtures/announce/world.mjs),
and the API runs against it (api_check.mjs): each audience counts and
reaches exactly its people, two presses make one send, a change after
scheduling makes it a draft, a withdrawal takes it out of every list, the
banner's dismissal holds per person, only those who chose news are mailed
(by a stand-in Resend), and the unsubscribe link stops them. Every op is
closed to anybody but the owner.

The Postgres checks need node's pg (PG_MODULE, or /tmp/pg) and Postgres's
initdb and postgres (PG_BIN, or Admission's embedded copy); without them
those tests return, as test_console3.py's do. What needs neither runs
everywhere.
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
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from loadbound import within  # noqa: E402
SQL = (ROOT / "supabase/announce.sql").read_text()
API = (ROOT / "api/_announce.js").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()
CONSOLE = (ROOT / "web/admin-announce.js").read_text()
TABLES = {"announcements", "announcement_reads", "announcement_mails", "news_mail", "site_notice_hides"}
OPS = ["announce", "announce_preview", "announce_keep", "announce_send", "announce_unschedule", "announce_edit", "announce_withdraw",
       "announce_drop", "announce_limit", "announce_mail_most", "announce_mail_address"]


def _postgres() -> dict | None:
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    return {**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin}


@functools.cache
def _checked() -> dict | None:
    env = _postgres()
    if env is None:
        return None
    done = subprocess.run(["node", "tests/fixtures/announce/api_check.mjs"], cwd=ROOT, env=env, capture_output=True, text=True,
                          timeout=300, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


# --- The SQL's shape ----------------------------------------------------------


def test_the_sql_only_adds() -> None:
    lowered = SQL.lower()
    outside = re.sub(r"\$\$.*?\$\$", "", re.sub(r"--[^\n]*", "", lowered), flags=re.S).replace("on delete cascade", "")
    for word in ("drop ", "truncate", "alter column", "delete ", "update ", "rename"):
        assert word not in outside, word
    # The one column added to a table that was there: the notice's end.
    assert re.findall(r"add column if not exists (\w+)", outside) == ["ends_at"]
    assert set(re.findall(r"create table if not exists public\.([a-z_]+)", lowered)) == TABLES
    for table in TABLES:
        assert f"alter table public.{table} enable row level security" in lowered, table
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role" in lowered, table
    # What its functions remove: a draft thrown away, and a mail taken again after Resend was busy.
    assert re.findall(r"delete from (\w+\.\w+)", lowered) == ["public.announcements", "public.announcement_mails"]


def test_every_function_is_the_servers_alone() -> None:
    made = set(re.findall(r"create or replace function public\.([a-z_]+)\(", SQL))
    assert {"announce_audience", "announce_press", "announcement_rows", "notification_rows", "news_choice", "site_notice_hide"} <= made
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", SQL), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", SQL), name
    assert "to anon" not in SQL and "to authenticated" not in SQL


def test_one_row_each_never_a_copy_per_person() -> None:
    # Who it reaches is kept on the one row as it goes; each person's read is a row of theirs.
    assert "recipients     uuid[]" in SQL or re.search(r"recipients\s+uuid\[\]", SQL)
    assert "a.recipients @> array[viewer]" in SQL
    # The notifications' own rows take it in: the page, the menu's count and Mark all read read it the usual way.
    rows = SQL[SQL.index("create or replace function public.notification_rows"):]
    assert "union all" in rows and "public.announcement_rows(viewer, since, until)" in rows
    later = (ROOT / "supabase/later.tsv").read_text()
    for earlier in ("notifications.sql", "replies.sql", "achievements.sql", "challenge_notices.sql", "comment_mentions.sql"):
        assert f"{earlier}\tnotification_rows\tannounce.sql\t" in later, earlier


def test_the_press_is_on_the_words_and_the_version_seen() -> None:
    press = SQL[SQL.index("create or replace function public.announce_press"):]
    press = press[:press.index("$$;")]
    assert "pg_advisory_xact_lock" in press
    for refused in ("'nobody'", "'gone'", "'changed'", "'pressed'", "'limit'"):
        assert refused in press, refused
    # A change after scheduling makes it a draft again.
    keep = SQL[SQL.index("create or replace function public.announce_keep"):]
    keep = keep[:keep.index("$$;")]
    assert "status = 'draft'" in keep and "send_at = null" in keep and "pressed_hash = null" in keep


def test_mail_only_to_those_who_chose_it_before_it_went() -> None:
    take = SQL[SQL.index("create or replace function public.announce_mail_take"):]
    take = take[:take.index("$$;")]
    assert "n.news and n.at <= a.sent_at" in take and "not a.test" in take and "skip locked" in take
    assert "@(oc\\.brickworks\\.diy|resend\\.dev)$" in take
    news = SQL[SQL.index("create table if not exists public.news_mail"):]
    assert "news     boolean     not null default false" in news[:400]


# --- The API ---------------------------------------------------------------------


def test_every_op_is_the_owners_and_in_the_audit() -> None:
    for op in OPS:
        assert f'{op}:' in ADMIN or f'"{op}"' in ADMIN, op
    targets = (ROOT / "api/_console.js").read_text()
    for op in OPS[2:]:
        assert op in targets, op


def test_the_cron_is_the_sites_own() -> None:
    deploy = (ROOT / "tools/deploy.sh").read_text()
    assert '"/api/plans/announce-due"' in deploy and "/api/plans?op=announce_due" in deploy
    assert "isCron(request)" in API


# --- What the person sees -----------------------------------------------------------


def test_the_console_preview_is_drawn_by_the_page_s_own_code() -> None:
    view = (ROOT / "web/notice-view.js").read_text()
    page = (ROOT / "web/notifications.js").read_text()
    assert 'import { group } from "/notice-view.js";' in page
    assert 'import { group as noticeGroup } from "/notice-view.js";' in CONSOLE
    assert "export function group(" in view and 'told ? "pic announce"' in view
    # Its words are text, never markup; another site's link only an announcement's.
    assert "innerHTML" not in view.replace("made.innerHTML = html", "")
    assert 'one.kind === "announcement" ? outside(one.link) : here(one.link)' in view
    # Opened on the first screen, the console asks none of it.
    admin = (ROOT / "web/admin.js").read_text()
    assert 'import("/admin-announce.js")' in admin and 'from "/admin-announce.js"' not in admin


def test_the_console_never_cuts_and_never_sends_twice() -> None:
    # No maxlength cuts a paste short: the count says it is over, and the server refuses it in words.
    assert "maxlength" not in CONSOLE.lower()
    assert "over" in CONSOLE and "MOST_TITLE" in CONSOLE
    # Keep is once at a time; Send is held once pressed.
    assert "if (keeping) return keeping;" in CONSOLE
    assert 'act("Send now"' in CONSOLE
    # Typed words are kept before New, Open or Change takes the form, or stay with why.
    assert CONSOLE.count("await keptFirst()") == 3
    assert CONSOLE.count("held = JSON.stringify(typed());") == 3


def test_settings_offers_news_off_by_default() -> None:
    html = (ROOT / "web/settings.html").read_text()
    js = (ROOT / "web/settings.js").read_text()
    # In Settings › Notifications' grid, the news row's email box (inbox,
    # 2026-11-23): off and not to be ticked until the account says it is open.
    assert re.search(r'<input type="checkbox" data-channel="email" id="mail-news" [^>]*disabled>', html)
    assert '$("mail-news").disabled = ocOnly || !(news && news.ready);' in js
    assert 'call("/api/people?op=news"' in js and "op=news_unsubscribe" in js


# --- Against the SQL itself ---------------------------------------------------------


def test_gate() -> None:
    got = _checked()
    if got is None:
        return
    assert got["gate"] == {op: [401, 404] for op in OPS}
    assert got["gate_kept"] == {"audit": 0, "announcements": 0}
    assert got["people_gate"] == {"news": 401, "notice_hide": 401, "notice_hidden": 401, "cron": 401}


def test_each_audience_counts_and_reaches_exactly_its_people() -> None:
    got = _checked()
    if got is None:
        return
    for name, one in got["audiences"].items():
        assert one["count"] == one["want"] == one["reach"], (name, one)
        assert one["exactly"] and one["listed_exactly"], (name, one)
        assert one["outcome"] == "sent", (name, one)
    assert got["live_everyone"] == {"count": 3, "test": False}
    assert got["nobody"] == 0 and got["send_to_nobody"]["status"] == 409
    assert all(isinstance(said, str) and said for said in got["bad_audience"])


def test_two_presses_make_one_send_and_stale_words_are_refused() -> None:
    got = _checked()
    if got is None:
        return
    assert got["double"]["statuses"] == [200, 409] and got["double"]["later"] == 409
    assert got["double"]["reach"] == 3 and got["double"]["sends_audited"] == 1
    assert got["stale"]["hash"] == 409 and got["stale"]["version"] == 409 and got["stale"]["still"] == "draft"


def test_an_edit_after_scheduling_unschedules_it() -> None:
    got = _checked()
    if got is None:
        return
    s = got["schedule"]
    assert s["scheduled"] == "scheduled" and s["edited"] == "unscheduled"
    assert s["after_edit"] == {"status": "draft", "send_at": None, "pressed": None}
    assert s["rescheduled"] == "scheduled" and s["cron_sent"] == 1 and s["audited"] == 1
    assert s["done"] == {"status": "sent", "reach": 1, "title": "Later, changed"}
    assert got["held"]["status"] == "draft" and got["held"]["reach"] is None and got["held"]["audited"] == 1
    assert got["unschedule"] == {"outcome": "unscheduled", "status": "draft"}


def test_reads_clicks_edits_and_a_withdrawal() -> None:
    got = _checked()
    if got is None:
        return
    r = got["reads"]
    assert r["statuses"] == [200, 200, 200, 200] and r["stranger"][0] == 404 and r["wrong"] == 400
    # clicked: false is no click; two clicks by one person are one.
    assert r["after_t1"] == {"read": 1, "clicked": 0} and r["after_all"] == {"read": 2, "clicked": 1, "reach": 3}
    assert got["group"]["who"] == "Brickworks" and got["group"]["line"] == "From {who}" and got["group"]["unread"] is True
    e = got["edit"]
    assert e["looked"] == "looked" and e["looked_edited"] is True and e["changed"] == "edited" and e["wrong_hash"] == 409
    assert e["title"] == "Read me (new time)" and e["edited"] is True and e["still_read"] is True
    assert got["withdraw"] == {"outcome": "withdrawn", "again": 409, "left": 0, "read_after": 404, "listed": "withdrawn"}


def test_the_days_most_and_the_words() -> None:
    got = _checked()
    if got is None:
        return
    assert got["limit"]["first"] == 200 and got["limit"]["second"] == 409 and got["limit"]["still_draft"] == "draft"
    assert got["limit"]["said"].startswith("Today's most is ")
    # Each preview's checks count against their own most and list their own:
    # a day of many previews never fills one pool.
    s = got["scopes"]
    assert s["before"] == {"sent": 0, "scheduled": 0} and s["listed_before"] == 0 and s["went"] == 200
    assert s["after"] == {"sent": 1, "scheduled": 0} and s["listed_after"] == ["Another preview's"]
    assert s["here_lists_theirs"] is False and s["here_today"] >= 1
    w = got["words"]
    assert w["long"] == [400, "The title is 121 characters: at most 120."]
    assert w["long_body"] == [400, "The words are 1001 characters: at most 1000."]
    assert w["title"] == "Hello world" and w["body"] == "One\nTwo\n\nThree"
    assert w["email_false"] is False and w["same_hash"] is True and w["kept_none_long"] == 0
    assert got["pool_email"] is False


def test_only_those_who_chose_news_are_mailed_and_unsubscribe_works() -> None:
    got = _checked()
    if got is None:
        return
    m = got["mail"]
    assert m["dee_default"] is False and m["not_bool"] == 400 and m["absent"] == 400
    assert m["count"] == 3 and m["mail_count"] == 1 and m["to"] == ["ada@example.com"]
    assert m["batch_path"] == "/emails/batch" and m["idempotent"] and m["header_ok"] and m["page_link"]
    assert m["one_click"] == "List-Unsubscribe=One-Click" and m["round_mailed"] == 0 and m["states"] == {"sent": 1}
    u = got["unsubscribe"]
    # Opening the link only goes to Settings; the one click (a POST) unsubscribes.
    assert u["opened"][0] == 303 and u["opened"][1].startswith("/settings?unsubscribe=") and u["news_after_open"] is True
    assert u["bad"] == 400 and u["cut"] == 400 and u["bad_get"] == "/settings#email-part"
    assert u["clicked"] == {"news": False, "unsubscribed": True} and u["settings"] == 200 and u["news"] is False
    assert u["next_batches"] == 0
    assert got["chose_later"] == {"mailed": 0, "to_dee": 0}
    b = got["busy"]
    assert b["tries"] == [429, 200] and b["retry_mailed"] == 1 and b["final"] == [{"state": "sent", "n": 1}]


def test_the_banner_ends_and_its_dismissal_holds() -> None:
    got = _checked()
    if got is None:
        return
    b = got["banner"]
    assert b["set"] == [200, True] and b["shown_ends"] is True
    assert b["hide"] == [200, 200] and b["no_such"] == 404 and b["wrong_id"] == 400
    assert b["t1"] is True and b["t2"] is False
    assert b["refused"][0::2] == [400, 400, 400] and b["unchanged"] is True
    assert b["new_notice_hidden"] is False and b["old_still_hidden"] is True
    assert b["gone_at_end"] is None and b["history_ends"] is True


def test_every_act_is_audited() -> None:
    got = _checked()
    if got is None:
        return
    for op in ("announce_keep", "announce_send", "announce_unschedule", "announce_edit", "announce_withdraw", "announce_drop", "announce_limit",
               "announce_mail_most", "announce_mail_address"):
        assert got["audit"].get(op, 0) > 0, op
    assert set(got["audit_targets"]) == {"announcement", "setting"}


# --- The review's fixes (anfix, 2026-11-18; bench/results/anreview-2026-11-18) ---------

SQL2 = (ROOT / "supabase/announce2.sql").read_text()
TABLES2 = {"announcement_to", "announcement_counts"}
REPLACED = ["announce_audience", "announce_count", "announce_press", "announce_list", "announcement_rows", "announcement_read",
            "announce_mail_take", "announce_mail_done", "announce_mail_due"]


def _body(sql: str, name: str) -> str:
    at = sql.index(f"create or replace function public.{name}(")
    return sql[at:sql.index("$$;", at)]


def test_the_second_file_only_adds_and_leaves_notification_rows() -> None:
    lowered = SQL2.lower()
    outside = re.sub(r"\$\$.*?\$\$", "", re.sub(r"--[^\n]*", "", lowered), flags=re.S).replace("on delete cascade", "")
    for word in ("drop ", "truncate", "alter column", "delete ", "update ", "rename", "add column"):
        assert word not in outside, word
    assert set(re.findall(r"create table if not exists public\.([a-z_]+)", lowered)) == TABLES2
    for table in TABLES2:
        assert f"alter table public.{table} enable row level security" in lowered, table
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role" in lowered, table
    assert "create or replace function public.notification_rows" not in lowered
    # Each replaced function keeps its arguments, and a later.tsv row guards it.
    later = (ROOT / "supabase/later.tsv").read_text().splitlines()
    for name in REPLACED:
        old = re.search(rf"create or replace function public\.{name}\(([^)]*)\)", SQL).group(1)
        new = re.search(rf"create or replace function public\.{name}\(([^)]*)\)", SQL2).group(1)
        assert re.sub(r"\s+", " ", old) == re.sub(r"\s+", " ", new), name
        row = next(line.split("\t") for line in later if line.startswith(f"announce.sql\t{name}\tannounce2.sql\t"))
        assert row[3] in _body(SQL2, name) and row[3] not in _body(SQL, name), name
    made = set(re.findall(r"create or replace function public\.([a-z_]+)\(", SQL2))
    for name in made - {"announce_tally"}:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", SQL2), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", SQL2), name
    assert "revoke all on function public.announce_tally(bigint, integer, integer, jsonb) from public, anon, authenticated, service_role;" in SQL2
    assert "to anon" not in SQL2 and "to authenticated" not in SQL2


def test_who_it_reached_is_rows_written_with_the_send() -> None:
    press = _body(SQL2, "announce_press")
    # One statement: the rows, and the reach as their count; recipients no longer written.
    assert "put as (\n        insert into public.announcement_to" in press and "reach = (select count(*) from put)" in press
    assert "recipients = '{}'::uuid[]" in press
    assert "from public.announcement_to t" in _body(SQL2, "announcement_rows") and "t.account = viewer" in _body(SQL2, "announcement_rows")
    for name in ("announce_mail_take", "announce_mail_due"):
        assert "join public.announcement_to t on t.announcement = a.id" in _body(SQL2, name) or \
            "from public.announcement_to t" in _body(SQL2, name), name
        assert "recipients" not in _body(SQL2, name), name
    listing = _body(SQL2, "announce_list")
    for per_person in ("announcement_reads", "announcement_mails", "announcement_to", "notification_marks", "unnest"):
        assert per_person not in listing, per_person
    assert "create index if not exists announcement_to_announcement on public.announcement_to (announcement, account);" in SQL2


def test_news_mail_has_a_most_a_stop_and_waits_for_sign_in_codes() -> None:
    take = _body(SQL2, "announce_mail_take")
    assert "pg_advisory_xact_lock(hashtext('announce_mail_take'))" in take and "public.news_mail_stopped() is not null" in take
    assert "public.news_mail_most('live') - public.news_mail_today()" in take
    assert "interval '1.1 seconds'" in take and "public.otp_requests" in take and "interval '1.5 seconds'" in take
    assert "for update of n skip locked" in take and "barred_accounts" in take
    assert "'news_mail_most' and s.scope = p_scope and s.value ~ '^[0-9]{1,5}$'), 200)" in SQL2
    assert 'const QUOTA = /^(daily|monthly)_quota_exceeded$/;' in API and 'rpc/announce_mail_stop' in API
    assert "pause(PACE_MS)" not in API


def test_the_notice_asks_the_avatars_count_before_it_draws() -> None:
    notice = (ROOT / "web/notice.js").read_text()
    follow = (ROOT / "web/follow.js").read_text()
    account = (ROOT / "web/account.js").read_text()
    # Never an answer kept forever (anreview M1): asked on every page.
    assert "ASKED" not in notice and "brickworks.notice.asked" not in notice
    assert "kept.feedCountHeard(COUNT_WAIT_MS)" in notice and "heard.notice_hidden" in notice
    assert "show(read(KEPT));" in notice and "\ndraw(read(KEPT));" not in notice
    assert "export function tellFeedCount(" in account and "export function feedCountHeard(" in account
    assert "tellFeedCount(answer?.status === 200" in follow
    notes = (ROOT / "api/_notifications.js").read_text()
    assert '"site_notice_hidden_ids", { p_account: asker, p_scope: scopeOf(request) }' in notes


def test_settings_unsubscribes_only_when_pressed() -> None:
    js = (ROOT / "web/settings.js").read_text()
    part = js[js.index("async function unsubscribed()"):]
    part = part[:part.index("\n}\n")]
    # The POST is in the button's press, never on opening (anreview L4).
    assert part.index('go.addEventListener("click"') < part.index('fetch("/api/people?op=news_unsubscribe"')
    for code in ("de", "fr", "es"):
        words = json.loads((ROOT / f"web/_lang/{code}.json").read_text())["scripts"]
        for english in ("Unsubscribe", "Stop Brickworks news by email to this address?",
                        "That did not work just now. Press Unsubscribe again in a minute."):
            assert words.get(english), (code, english)


def test_the_console_shows_the_news_mails_most_and_its_stop() -> None:
    assert "announce-news-form" in CONSOLE and 'op: "announce_mail_most"' in CONSOLE and 'op: "announce_mail_address"' in CONSOLE
    assert "one.seen" not in CONSOLE and ">Seen<" not in CONSOLE
    assert "Resend said the team's" in CONSOLE
    for op in ("announce_mail_most", "announce_mail_address"):
        assert f"{op}:" in ADMIN, op
        assert op in (ROOT / "api/_console.js").read_text(), op


def test_fix_feed_count_carries_the_hidden_notices() -> None:
    got = _checked()
    if got is None:
        return
    m = got["fix"]["m1"]
    assert m["before"] == [] and m["after"] == [m["id"]] and m["other"] == [] and m["elsewhere"] == [] and m["cleared"] == []
    assert "notice_hidden" not in m["signed_out"]


def test_fix_reach_is_rows_and_the_list_reads_counts() -> None:
    got = _checked()
    if got is None:
        return
    m = got["fix"]["m2"]
    assert m["reach"] == m["to_rows"] == m["row_reach"] == 3 and m["recipients"] == []
    assert m["listed"] == {"read": 1, "clicked": 1, "seen": None, "recipients": None}
    assert m["truth"] == m["counted"] == {"reads": 1, "clicks": 1}
    assert m["list_reads"] == ["announcement_counts"] and m["reach_is_rows"] is True and m["sent_every"] > 10


def test_fix_news_mails_most_quota_stop_and_pace() -> None:
    got = _checked()
    if got is None:
        return
    m = got["fix"]["m3"]
    assert m["default_most"] == 200 and m["refused"] == [400, 400, 400] and m["set"] == 200
    # At the day's most: one of three mailed, none by the next round, the count at the most.
    assert m["first_mailed"] == 1 and m["first_to"] == 1 and m["cron_mailed"] == 0 and m["today_at_most"] is True
    # Resend's daily quota: stopped until the next UTC day, said, nothing tried while stopped, nothing lost.
    assert m["quota_batches"] == 1 and "news mail stopped until" in m["quota_outcome"]
    assert m["stopped_until_midnight"] is True and m["stopped_why"] == "daily_quota_exceeded"
    assert m["batches_while_stopped"] == 0 and m["still"] == 0 and m["states"] == [{"state": "sent", "n": 1}]
    assert m["resumed"] == 3
    p = got["fix"]["pace"]
    assert p["round_batches"] == 2 and all(gap >= 1090 for gap in p["round_gaps_ms"])
    assert len(p["after_code_ms"]) == 1 and p["after_code_ms"][0] >= 1450 and p["empty_take_ms"] < within(500)
    assert got["no_secret"]["mail"] is False and got["no_secret"]["missing"] == ["NEWS_UNSUB_SECRET"]
    assert got["fix"]["key_after_edit"] == {"statuses": [429, 200], "keys_differ": True, "subjects": ["Mail one", "Mail one, corrected"]}


def test_fix_overlapping_crons_previews_barred_secret_and_address() -> None:
    got = _checked()
    if got is None:
        return
    f = got["fix"]
    assert f["l1"]["sent"] == [0, 1] and f["l1"]["runs"] == [0, 0] and f["l1"]["held_audits"] == 0 and f["l1"]["failed_runs"] == 0
    assert f["l1"]["late"] == {"held": 0, "sent": 0} and f["l1"]["late_audits"] == 0 and f["l1"]["still"] == "sent"
    # Off the site: only the checks' own sent, nobody mailed; the site's own wait for the site.
    assert f["l2"]["off"] == {"sent": 1, "mailed": 0, "held": 0} and f["l2"]["off_batches"] == 0 and f["l2"]["local"] == 0
    assert f["l2"]["statuses"] == {"site": "scheduled", "checks": "sent"} and f["l2"]["site_after_on"] == "sent" and f["l2"]["on"]["mailed"] >= 1
    assert f["l3"]["everyone"] == [4, 3] and f["l3"]["mail"] == [2, 1] and f["l3"]["person"] == [1, 0]
    assert f["l3"]["reach"] == 1 and f["l3"]["rows"] == 1 and f["l3"]["mailed_gil"] is False
    assert f["l5"] == {"own_secret": True, "not_old": True, "other": 400, "old": 200, "now": 200, "news": False}
    assert f["l6"]["long"] == 400 and f["l6"]["five"] == 400 and f["l6"]["set"] == 200 and f["l6"]["html"] and f["l6"]["text"]
    assert f["l6"]["bare"] and f["l6"]["sent_has"] and f["l6"]["cleared"] == [200, ""]
