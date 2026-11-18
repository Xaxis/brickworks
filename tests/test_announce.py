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

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/announce.sql").read_text()
API = (ROOT / "api/_announce.js").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()
CONSOLE = (ROOT / "web/admin-announce.js").read_text()
TABLES = {"announcements", "announcement_reads", "announcement_mails", "news_mail", "site_notice_hides"}
OPS = ["announce", "announce_preview", "announce_keep", "announce_send", "announce_unschedule", "announce_edit", "announce_withdraw",
       "announce_drop", "announce_limit"]


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
    assert '<input type="checkbox" id="mail-news">' in html and 'id="news-choice" hidden' in html
    assert '$("news-choice").hidden = !(news && news.ready);' in js
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
    for op in ("announce_keep", "announce_send", "announce_unschedule", "announce_edit", "announce_withdraw", "announce_drop", "announce_limit"):
        assert got["audit"].get(op, 0) > 0, op
    assert set(got["audit_targets"]) == {"announcement", "setting"}
