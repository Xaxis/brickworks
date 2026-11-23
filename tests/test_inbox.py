"""What you hear of, and where (inbox, 2026-11-23; supabase/notification_prefs.sql,
api/_notifications.js, web/settings.*, web/notifications.*, web/follow.js).

Run under node behind tests/fixtures/inbox_world.mjs: the API's handler as
Vercel calls it, Supabase in memory with notification_prefs.sql's functions
stood in for as its dry run proved them (bench/results/inbox-2026-11-23:
sql_dry.log, and sql_matrix.log for push, email and the count, each of the
eleven kinds on and off on each channel against the database itself):

- every kind the page has is one of the eleven a person chooses, and a group's
  key is the one notification_group makes;
- each kind turned off here leaves the list, and only it; a muted model's
  every row goes; Done moves a group to the Done view, and what comes after
  is back; an older Done never moves a mark back; Undo puts it back;
- the account menu's newest five are the list's first five, a row each, and
  asking for them marks nothing seen; the Done view marks nothing seen;
- the day's email says each notification of the kinds chosen by email, with
  its link, in its subject's count;
- before the file, everything is in the list as before, and the choices say so;
- Settings has a row a kind and a box a place, each named by its row and its
  column, and Notifications a Done and a Mute.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
ADA = {"sub": "7d6c1a2e-0000-4000-8000-00000000ada0", "email": "ada@example.com",
       "session_id": "5e55e55e-0000-4000-8000-00000000ada0"}
KINDS = ["comment", "reply", "mention", "photo", "remix", "likes", "talk", "challenge", "result", "achievement", "news"]


def run(body: str, *, sql: bool = True) -> object:
    """[body], an async function's body returning JSON, run in a fresh node."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "import { inboxWorld, everyKind, groupOf } from './tests/fixtures/inbox_world.mjs';"
        "import * as n from './api/_notifications.js';"
        "import * as c from './api/_comments.js';"
        f"const w = await inboxWorld({{ sqlApplied: {json.dumps(sql)} }});"
        f"const ada = await w.signIn({json.dumps(ADA)});"
        f"const ADA = {json.dumps(ADA)};"
        "const list = async (query = {}) => (await w.people('GET', { op: 'notifications', ...query }, undefined, ada)).json;"
        "const kinds = (answer) => answer.groups.flatMap((g) => g.rows.map((r) => r.kind));"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_every_kind_is_one_of_the_eleven_and_its_group_is_the_sqls() -> None:
    out = run("return { kinds: n.KINDS, rows: everyKind().map((r) => [r.kind, n.kindOf(r.kind), n.groupKey(r), groupOf(r)]) };")
    assert out["kinds"] == KINDS
    assert {row[1] for row in out["rows"]} == set(KINDS)
    for raw, kind, key, sql_key in out["rows"]:
        assert kind in KINDS, raw
        assert key == sql_key, raw


@pytest.mark.parametrize("off", KINDS)
def test_a_kind_off_here_leaves_the_list_and_only_it(off: str) -> None:
    out = run(
        "const before = kinds(await list());"
        f"const set = await w.people('POST', {{ op: 'notification_prefs' }}, {{ kind: {json.dumps(off)}, channel: 'here', on: false }}, ada);"
        "const after = kinds(await list());"
        "const count = (await w.people('GET', { op: 'feed_count' }, undefined, ada)).json;"
        "return { before, after, set: set.json, count: count.notifications,"
        "  as: after.map((k) => n.kindOf(k)), was: before.map((k) => n.kindOf(k)) };")
    assert out["set"]["on"] is False and off not in out["set"]["here"]
    assert len(out["before"]) == 14
    assert off not in out["as"]
    assert sorted(k for k in out["was"] if k != off) == sorted(out["as"])
    # The avatar's count is the list's.
    assert out["count"] == len(out["after"])


def test_a_change_sent_back_is_a_remixs_notice_for_somebody_who_chose() -> None:
    # suggestedit's rows (supabase/suggestions.sql suggestion_notices) are
    # listed for an account with chosen kinds too, and go with remixes.
    out = run(
        "const at = new Date(Date.now() - 60000).toISOString();"
        "const rows = [{ kind: 'suggestion', at, on: 'SuggestM01' }, { kind: 'suggestion_taken', at, on: 'SuggestM02' }];"
        "const all = { ...n.DEFAULTS, here: n.KINDS };"
        "const noRemix = { ...all, here: n.KINDS.filter((k) => k !== 'remix') };"
        "const muted = { ...all, muted: ['SuggestM01'] };"
        "return { all: n.keptRows(rows, all).map((r) => r.kind), off: n.keptRows(rows, noRemix).length,"
        "  muted: n.keptRows(rows, muted).map((r) => r.on) };")
    assert out["all"] == ["suggestion", "suggestion_taken"]
    assert out["off"] == 0
    assert out["muted"] == ["SuggestM02"]


def test_a_muted_models_every_row_goes_and_comes_back_unmuted() -> None:
    out = run(
        "w.rows.push({ ...w.rows[0], comment: 99, at: new Date(Date.now() - 30 * 60000).toISOString() });"
        "const muted = (await w.people('POST', { op: 'notification_mute' }, { model: 'CommentM01', on: true }, ada)).json;"
        "const during = await list();"
        "const count = (await w.people('GET', { op: 'feed_count' }, undefined, ada)).json.notifications;"
        "const back = (await w.people('POST', { op: 'notification_mute' }, { model: 'CommentM01', on: false }, ada)).json;"
        "const after = await list();"
        "const bad = (await w.people('POST', { op: 'notification_mute' }, { model: 'no', on: true }, ada));"
        "return { muted, during: during.groups.map((g) => g.key), count, back, after: after.groups.map((g) => g.key),"
        "  bad: bad.status };")
    assert out["muted"] == {"model": "CommentM01", "muted": True, "count": 1}
    assert "CommentM01" not in out["during"] and len(out["during"]) == 13
    assert out["count"] == 13
    assert out["back"]["muted"] is False and "CommentM01" in out["after"]
    assert out["bad"] == 400


def test_done_moves_a_group_to_done_and_what_comes_after_is_back() -> None:
    out = run(
        "const first = await list();"
        "const tower = first.groups.find((g) => g.key === 'CommentM01');"
        "const done = (await w.people('POST', { op: 'notifications_done' }, { group: tower.key, at: tower.at }, ada)).json;"
        "const inbox = await list();"
        "const doneView = await list({ view: 'done' });"
        "const count = (await w.people('GET', { op: 'feed_count' }, undefined, ada)).json.notifications;"
        # A second tab that read the list an hour earlier marks it done: the mark stays.
        "const older = (await w.people('POST', { op: 'notifications_done' }, { group: tower.key,"
        "  at: new Date(Date.parse(tower.at) - 3600e3).toISOString() }, ada)).json;"
        # Something new about it: back in the inbox, the old row still done.
        "w.rows.unshift({ ...w.rows[0], comment: 50, at: new Date().toISOString() });"
        "const again = await list();"
        "const undo = (await w.people('POST', { op: 'notifications_done' }, { group: tower.key, at: done.before, undo: true }, ada)).json;"
        "const undone = await list();"
        "const all = (await w.people('POST', { op: 'notifications_done' }, { all: true, at: new Date().toISOString() }, ada)).json;"
        "const none = await list();"
        "const allDone = await list({ view: 'done' });"
        "const refused = await w.people('POST', { op: 'notifications_done' }, { group: 'drop table', at: tower.at }, ada);"
        "const noAt = await w.people('POST', { op: 'notifications_done' }, { group: tower.key }, ada);"
        "return { done, inbox: inbox.groups.map((g) => g.key), doneView: doneView.groups.map((g) => g.key), count,"
        "  older: older.at === done.at, again: again.groups.find((g) => g.key === 'CommentM01')?.rows.length,"
        "  undo, undone: undone.groups.find((g) => g.key === 'CommentM01')?.rows.length,"
        "  none: none.groups.length, allDone: allDone.groups.length, marks: w.listMarks,"
        "  refused: refused.status, noAt: noAt.status };")
    assert out["done"]["group"] == "CommentM01" and out["done"]["before"] is None
    # Fourteen rows, fourteen groups (each its own), the tower's gone to Done.
    assert "CommentM01" not in out["inbox"] and len(out["inbox"]) == 13
    assert out["doneView"] == ["CommentM01"]
    assert out["count"] == 13
    assert out["older"] is True
    assert out["again"] == 1
    assert out["undo"]["at"] is None and out["undone"] == 2
    assert out["none"] == 0 and out["allDone"] == 14
    # Only the inbox's own opening marks what was counted seen; the Done view never.
    # (the lists asked, in order: inbox, inbox, Done, inbox, inbox, inbox, Done)
    assert out["marks"] == [True, True, False, True, True, True, False]
    assert out["refused"] == 400 and out["noAt"] == 400


def test_the_menus_five_are_the_lists_first_five_and_mark_nothing_seen() -> None:
    out = run(
        "const page = await list();"
        "const marks = w.listMarks.length;"
        "const five = await list({ most: '5' });"
        "const bad = await w.people('GET', { op: 'notifications', most: '50' }, undefined, ada);"
        "return { page: page.groups.slice(0, 5).map((g) => [g.key, g.name, g.rows[0].line, g.rows[0].link]),"
        "  five: five.groups.map((g) => [g.key, g.name, g.rows[0].line, g.rows[0].link]), rows: five.groups.map((g) => g.rows.length),"
        "  mark: w.listMarks[marks], bad: bad.status };")
    assert out["five"] == out["page"] and len(out["five"]) == 5
    assert out["rows"] == [1, 1, 1, 1, 1]
    assert out["mark"] is False
    assert out["bad"] == 400


def test_the_days_email_says_each_kind_chosen_with_its_link() -> None:
    mailed = ["reply", "mention", "likes", "talk", "challenge", "result", "achievement"]
    out = run(
        f"const mailed = {json.dumps(mailed)};"
        "const notices = everyKind().filter((r) => mailed.includes(n.kindOf(r.kind)));"
        "const email = c.renderCommentDigest({ comments: [], feed: [], notices, notices_more: 3 }, 'https://brickworks.diy');"
        "const said = notices.map((r) => { const s = n.noticeSaid(r, 'https://brickworks.diy'); return [r.kind, s.link]; });"
        "return { subject: email.subject, text: email.text, html: email.html, said, n: notices.length };")
    assert out["subject"] == f"Brickworks: {out['n']} new things for you"
    for kind, link in out["said"]:
        assert link in out["text"], kind
        assert f'data-kind="{kind}"' in out["html"], kind
    assert "3 more are in your notifications" in out["text"]
    assert "/settings#email-part" in out["text"]


def test_before_the_file_everything_is_listed_and_the_choices_say_so() -> None:
    out = run(
        "const page = await list();"
        "const prefs = (await w.people('GET', { op: 'notification_prefs' }, undefined, ada)).json;"
        "const choose = await w.people('POST', { op: 'notification_prefs' }, { kind: 'likes', channel: 'here', on: false }, ada);"
        "const done = await w.people('POST', { op: 'notifications_done' }, { all: true, at: new Date().toISOString() }, ada);"
        "return { n: kinds(page).length, chosen: page.chosen, ready: prefs.ready, here: prefs.here, push: prefs.push,"
        "  choose: choose.status, done: done.status };", sql=False)
    assert out["n"] == 14 and out["chosen"] is False
    assert out["ready"] is False and out["here"] == KINDS and out["push"] == ["reply", "mention"]
    assert out["choose"] == 503 and out["done"] == 503


@pytest.mark.parametrize("body", [{"kind": "follows", "channel": "here", "on": True}, {"kind": "likes", "channel": "sms", "on": True},
                                  {"kind": "likes", "channel": "here", "on": "yes"}, {"kind": "comment", "channel": "email", "on": True},
                                  {"kind": "news", "channel": "email", "on": True}])
def test_a_choice_that_is_not_one_is_refused(body: dict) -> None:
    out = run(f"const r = await w.people('POST', {{ op: 'notification_prefs' }}, {json.dumps(body)}, ada); return {{ status: r.status, prefs: w.prefs.size }};")
    assert out == {"status": 400, "prefs": 0}


def test_settings_has_a_box_a_kind_a_place_each_named_by_its_row_and_column() -> None:
    html = (ROOT / "web/settings.html").read_text()
    rows = re.findall(r'<tr data-notice="([a-z]+)"><th scope="row" id="kind-\1">', html)
    assert rows == KINDS
    boxes = re.findall(r'<input type="checkbox" data-channel="(here|push|email)"[^>]*aria-labelledby="kind-([a-z]+) col-\1"', html)
    assert len(boxes) == 33 and {(k, c) for c, k in boxes} == {(k, c) for k in KINDS for c in ("here", "push", "email")}
    for col in ("here", "push", "email"):
        assert f'id="col-{col}"' in html
    # The email of comments, photos, remixes and news keeps its own box, as the flows know it.
    for mail in ('id="mail-comments"', 'id="mail-photos" data-kind="photos"', 'id="mail-remixes" data-kind="remixes"', 'id="mail-news"'):
        assert mail in html
    assert ".kinds .cell { display: flex; align-items: center; justify-content: center; min-width: 44px; min-height: 44px;" in html


def test_notifications_has_done_mute_and_the_done_view() -> None:
    html = (ROOT / "web/notifications.html").read_text()
    js = (ROOT / "web/notifications.js").read_text()
    assert 'id="all-done"' in html and 'data-view="done"' in html and 'id="empty-done"' in html
    assert 'op=notifications_done' in js and 'op=notification_mute' in js and 'label: say("Undo")' in js
    page = (ROOT / "web/model-page.js").read_text()
    assert 'say("Mute notifications")' in page and 'op=notification_mute' in page
    menu = (ROOT / "web/follow.js").read_text()
    assert "op=notifications&most=5" in menu
