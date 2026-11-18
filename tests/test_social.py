"""The owner's social desk (socialdesk, 2026-11-18; docs/SOCIAL_DESK.md, /admin › Social).

tests/fixtures/social/api_check.mjs drives the real handlers (api/admin.js's
social ops, api/plans.js's cron and visit) with supabase/social.sql's tables
held in memory and the checks' pool talking to the mock Reddit
(api/_social_mock.js): every op closed to anybody but the owner, connect,
the inbox's three kinds, rules, drafts, the press, send, schedule, results,
visits by UTM, disconnect and the by-hand route; every write the mock is
sent counted after each act, and every answer and log line searched for a
token. tests/fixtures/social/db_check.mjs applies social.sql twice in a
Postgres of its own (pg.mjs; skipped without one, as test_console.py's).
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
SQL = (ROOT / "supabase/social.sql").read_text()
SOCIAL = (ROOT / "api/_social.js").read_text()
REDDIT = (ROOT / "api/_social_reddit.js").read_text()


@functools.cache
def _api() -> dict:
    done = subprocess.run(["node", "tests/fixtures/social/api_check.mjs"], cwd=ROOT, capture_output=True, text=True, timeout=180)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


@functools.cache
def _db() -> dict | None:
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    done = subprocess.run(["node", "tests/fixtures/social/db_check.mjs"], cwd=ROOT, capture_output=True, text=True, timeout=240,
                          env={**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin})
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


# --- Only the owner ------------------------------------------------------------


def test_every_op_is_the_owners_alone() -> None:
    got = _api()
    # Signed out 401; any other account 404, the console's answer to anybody
    # else (a 403 would tell them the console exists); nothing written.
    assert len(got["gate"]) == 13
    assert all(one.endswith(":401:404") for one in got["gate"]), got["gate"]
    assert got["gate_wrote"] == 0


# --- Nothing leaves without the owner's press ---------------------------------


def test_nothing_is_sent_but_by_the_owners_press_on_those_words() -> None:
    got = _api()
    # Drafts, the inbox's look, marks, rules: nothing sent. A press with a
    # hash not of the words held, or of words since changed, is refused.
    assert got["press"] == {"wrong_hash": 409, "old_words": 409, "writes": 0,
                            "said": "These are not the words you pressed Send on: they changed since. Look again and press Send."}
    # The press: one post, its address kept, the presser kept; again, refused.
    assert got["send"]["status"] == 200 and got["send"]["outcome"] == "sent" and got["send"]["writes"] == 1
    assert got["send"]["row"] == "sent" and got["send"]["pressed_by"] == "owner@example.com"
    assert re.match(r"^https://www\.reddit\.com/r/lego/comments/m[0-9a-z]+/a_free_lego_cad_in_the_browser/$", got["send"]["url"])
    assert got["send_twice"] == {"status": 409, "writes": 1}


def test_a_scheduled_send_goes_at_its_time_only_as_pressed() -> None:
    got = _api()["schedule"]
    assert got["too_soon"] == 400 and got["status"] == 200 and got["outcome"] == "scheduled"
    # The cron's own key, and nothing before its time.
    assert got["not_cron"] == 401 and got["early"] == "nothing due" and got["writes_before_due"] == 1
    assert got["due"] == "1 sent, 0 failed" and got["writes"] == 2 and got["row"] == "sent"
    after = _api()["edit_after_press"]
    # Edited after its press it is a draft again; words changed behind the
    # press are never sent, and say why.
    assert after["status"] == "draft" and after["outcome"] == "unscheduled"
    assert after["cron"] == "0 sent, 1 failed" and after["writes"] == 0
    assert after["tampered"] == "failed" and after["said"] == "Its words are not those pressed: not sent."
    assert _api()["unschedule_draft"] == 409


def test_the_database_refuses_a_send_past_a_draft_without_a_press() -> None:
    assert _api()["unpressed_row"] == {"status": 400, "said": 'violates check constraint "social_sends_pressed"'}
    got = _db()
    if got is None:
        return
    assert got["sent_unpressed"] == got["scheduled_unpressed"] == got["draft_to_sent"] == "social_sends_pressed"
    assert got["draft"] == got["scheduled_pressed"] == "kept"


def test_only_one_place_sends_and_only_after_the_press() -> None:
    # provider.send is called in deliver() alone; deliver() only from the
    # press (social_send) and the due sends, each after its hash is checked.
    assert len(re.findall(r"provider\.send\(", SOCIAL)) == 1
    deliver = SOCIAL[SOCIAL.index("async function deliver("):SOCIAL.index("/// Where a send is handed")]
    assert "provider.send(" in deliver
    assert len(re.findall(r"await deliver\(", SOCIAL)) == 2
    press = SOCIAL[SOCIAL.index("export async function socialSend("):SOCIAL.index("/// POST op=social_unschedule")]
    assert press.index("hashOf(row)") < press.index("await deliver(")
    due = SOCIAL[SOCIAL.index("export async function socialDue("):SOCIAL.index("/// GET /api/plans?op=social_due")]
    assert due.index("row.pressed_hash !== hashOf(row)") < due.index("await deliver(")
    # Nothing in the adapter votes, marks read or messages anybody at Reddit.
    for path in ("/api/vote", "/api/read_message", "/api/compose", "/api/del", "/api/editusertext"):
        assert path not in REDDIT, path
    assert set(re.findall(r'ask\(session, "(/api/[a-z_/]+)", \{ method: "POST"', REDDIT)) == {"/api/submit", "/api/comment"}


# --- Connect, the inbox, rules, drafts ----------------------------------------


def test_connect_with_no_reddit_app_says_what_is_missing() -> None:
    got = _api()
    assert got["real_reddit"] == {"api": False, "missing": ["REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET"], "route": "by_hand",
                                  "later": ["x", "facebook", "instagram"]}
    # Connecting later, as the console shows it in place: the names to set,
    # the one address to register, what Reddit's page will ask for.
    assert got["real_later"] == {"env": ["REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET"],
                                 "redirect": "https://brickworks.diy/admin?connected=reddit",
                                 "scopes": ["identity", "history", "privatemessages", "read", "submit"]}
    assert got["real_connect"]["status"] == 409
    assert "REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET" in got["real_connect"]["said"]


def test_connect_takes_a_signed_state_and_keeps_the_tokens_here() -> None:
    got = _api()
    assert got["authorize"]["status"] == 200
    assert got["authorize"]["redirect"] == "https://brickworks.diy/admin?tests=1&connected=reddit"
    assert "duration" in got["authorize"]["page"] and "state" in got["authorize"]["page"]
    assert got["connect"] == {"forged": 400, "status": 200, "handle": "brickworks_checks", "accounts": 1, "tokens": 1}


def test_a_connect_is_finished_once_and_comes_back_to_one_address() -> None:
    got = _api()
    once = got["state_once"]
    # Its state again: refused before any code is taken.
    assert once["replay"] == 409 and once["said"].startswith("That connect is finished already")
    # Two finishes of one connect at once, both past the first read: one
    # account, one set of keys, the loser's handed back at Reddit.
    assert once["both_exchanged"] is True
    assert once["twins"] == [200, 409] and once["after"] == 409
    assert once["accounts"] == 1 and once["tokens"] == 1 and once["handed_back"] == 1
    # Reddit's own app: the one address registered with it, from www too.
    assert got["redirects"] == {"brickworks.diy": "https://brickworks.diy/admin?connected=reddit",
                                "www.brickworks.diy": "https://brickworks.diy/admin?connected=reddit"}


def test_two_keeps_of_one_new_draft_at_once_are_one_draft() -> None:
    got = _api()["twin_keeps"]
    assert got["statuses"] == [200, 200] and got["made"] == 1 and got["same"] is True
    # The draft kept tags the site's links with its own id, whichever answered.
    assert got["tagged"] == [True, True]
    # Other words are another draft. The same words kept again at once (an
    # answer lost) are the same draft; twenty seconds on, a second.
    assert got["other_words"] is True and got["retried"] is True and got["later"] is True


def test_every_schedule_is_listed_however_old_and_the_rest_are_counted() -> None:
    got = _api()["listed"]
    assert got["old_scheduled"] == "scheduled"
    assert got["listed"] >= 301 and got["unlisted"] == got["total"] - got["listed"] > 0


def test_the_inbox_holds_replies_mentions_and_messages_once() -> None:
    got = _api()["sync"]
    assert got["first"] == "5 new" and got["second"] == "0 new"
    assert got["kinds"] == ["mention:search", "mention:username_mention", "message:message", "reply:comment_reply", "reply:post_reply"]
    assert got["unread"] == 5 and got["links"] is True
    assert _api()["mark"] == {"status": 200, "read": ["t4_mk4001"]}


def test_rules_and_drafts() -> None:
    got = _api()
    assert got["rules"] == {"status": 200, "from": "network", "count": 3, "missing": "missing"}
    draft = got["draft"]
    # The site's links tagged with the send's campaign; anybody else's left.
    campaign = draft["campaign"]
    assert re.match(r"^bw-[a-z0-9]{10}$", campaign) and draft["hash"] is True
    assert draft["body"] == (f"Have a look: https://brickworks.diy/gallery?utm_source=reddit&utm_medium=social&utm_campaign={campaign}, "
                             "and https://example.com/x.")
    assert got["reply_draft"] == {"status": "draft", "orphan": 400}


# --- What it brought ------------------------------------------------------------


def test_results_and_visits_by_utm() -> None:
    got = _api()["results"]
    assert got["points"] >= 1 and got["score"] >= 1
    # Two visitors, as the server sees them (address and browser): the first
    # told three times with two numbers of its own is still one. An unknown
    # campaign and a draft's are let go.
    assert got["visit_status"] == 204 and got["visits"] == 2 and got["by_day"] == [2] and got["draft_visits"] == 0
    assert "nonce: visitorOf(request, id)" in SOCIAL and "VISITS_AN_HOUR" in SOCIAL


def test_disconnect_forgets_the_tokens_and_a_post_then_goes_by_hand() -> None:
    got = _api()
    assert got["disconnect"] == {"status": 200, "revoked": True, "tokens": 0, "accounts": 0, "kept_sends": 9}
    hand = got["by_hand"]
    assert hand["outcome"] == "handed" and hand["hand_off"] == "https://www.reddit.com/r/lego/submit" and hand["writes"] == 0
    assert hand["hand_text"].startswith("Posted by the owner: https://brickworks.diy/?utm_source=reddit")
    assert hand["wrong_url"] == 400 and hand["posted"] == "sent" and hand["external_id"] == "t3_abc123"


# --- The review's findings (sdreview, 2026-11-18) -------------------------------


def test_a_post_with_a_link_and_words_is_refused_not_sent_without_its_link() -> None:
    got = _api()["link_and_words"]
    assert got["status"] == 400 and got["said"].startswith("A Reddit post is a link or words, not both")
    # The adapter never chooses one for the owner: words go as text, a link as a link.
    assert '...(words.link ? { kind: "link", url: words.link } : { kind: "self", text: words.body })' in REDDIT


def test_a_lost_answer_is_unsure_and_never_sent_again_on_that_press() -> None:
    got = _api()
    lost = got["answer_lost"]
    assert lost["status"] == 502 and "may be up" in lost["said"]
    assert lost["row"] == "sending" and lost["unsure"] is True
    # Send, an edit and a drop each refused: one post at Reddit, not two.
    assert lost["resend"] == lost["edit"] == lost["drop"] == 409 and lost["posts"] == 1
    assert lost["found"] == "sent"
    # Not up: back to the drafts, and only a fresh press sends it, once.
    assert got["not_up"] == {"back": "back to drafts", "status_after_back": "draft", "fresh": "sent", "posts": 1}
    # Reddit's own no is "did not go", not unsure.
    assert got["reddit_refused"] == {"status": 409, "row": "failed", "unsure": False}
    # Cut off mid-send: left alone while it may be in flight, unsure after five minutes.
    assert got["cut_off"] == {"in_flight": {"unsure": False, "back": 409}, "unsure": True, "back": "back to drafts"}


def test_a_long_post_by_hand_opens_reddit_with_the_title_alone() -> None:
    got = _api()["long_by_hand"]
    # 15,000 characters would make a 414 at Reddit: the words are copied instead, and the sheet says so before the press.
    assert got["filled_before"] is False and got["filled"] is False and got["text_in_address"] is False
    assert got["length"] < 6000 and got["short_filled"] is True
    assert "export const ADDRESS_MOST = 6000;" in REDDIT


def test_a_handed_send_can_be_taken_back_or_dropped_and_marked_by_the_right_address() -> None:
    got = _api()
    assert got["handed_back"] == {"back": "back to drafts", "row": "draft", "pressed": None, "drop": 200, "gone": True}
    paste = got["paste"]
    assert paste["comment_for_post"] == paste["share_link"] == 400 and paste["post"] == 200
    assert "Share links" in paste["said"]
    # A reply to a private message is marked sent with its conversation's address.
    assert got["message_reply"] == {"handed": "handed", "posted": "sent", "url": "https://www.reddit.com/message/messages/mk4001"}


def test_a_reply_by_hand_answers_any_post_or_comment_by_its_address() -> None:
    # No inbox without Reddit's API (and Reddit ended RSS on 2026-11-13), so a
    # reply by hand names what it answers by the address the owner pastes.
    got = _api()["reply_by_address"]
    assert got["comment"] == {"status": 200, "parent": "t1_def888",
                              "link": "https://www.reddit.com/r/lego/comments/abc777/a_castle/def888/", "community": None}
    assert got["post"] == {"status": 200, "parent": "t3_abc999", "link": "https://www.reddit.com/r/legomoc/comments/abc999/",
                           "tagged": True}
    assert got["refused"] == {"share": 400, "redd_it": 400, "subreddit": 400, "other": 400, "script": 400, "none": 400}
    assert "A Share link (…/s/…) or a redd.it link names nothing" in got["said"]
    # Handed: Reddit's own page of that comment, where the owner presses Reply.
    there = "https://www.reddit.com/r/lego/comments/abc777/a_castle/def888/"
    assert got["handed"] == {"outcome": "handed", "hand_off": there, "filled": False, "listed": there}
    # An edit keeps what it answers, whatever address comes with it.
    assert got["edited"] == {"outcome": "redrafted", "parent": "t1_def888", "link": there}
    assert got["again"] == there
    assert got["posted"] == {"status": "sent", "external_id": "t1_ghi999",
                             "url": "https://www.reddit.com/r/lego/comments/abc777/a_castle/ghi999/"}


def test_words_of_the_wrong_type_are_refused_and_a_title_counts_characters() -> None:
    assert _api()["types"] == {"body_object": 400, "title_list": 400, "community_list": 400, "hash_list": 400,
                               "emoji_title": 200, "emoji_over": 400}


def test_the_page_claims_no_more_than_is_true() -> None:
    page = (ROOT / "web/admin-social.js").read_text()
    # By hand there is no score: only visits, until Reddit is connected.
    assert "Its score and comments are read only once Reddit is connected." in page
    assert "Its score is read only once Reddit is connected." in page
    # Reddit's page may fill the words; Copy the words comes first.
    assert "Reddit's page may fill in the title and words" in page
    assert page.index('make("div", "row", copy,') > 0
    # An empty inbox with no Reddit app does not point at a Connect that is off.
    assert "Nothing comes in here until Reddit grants the desk API access" in page
    # What Reddit ended is said where it matters, and a score by hand is never a zero (redditway).
    assert "Reddit ended its RSS feeds on 13 November 2026" in page
    assert "what is left of its public access ends in March 2027" in page
    assert 'make("h3", "", "Its score")' in page and '$("social-new-reply").addEventListener("click", startReply);' in page
    # No Reddit app: no Connect at all, never one shown off (connectfix,
    # owner 11-18: "clicking Connect Reddit doesn't do anything"). The state,
    # an act that works, and connecting later in the console, not the repo.
    assert ".disabled = !one.api" not in page and "docs/SOCIAL_DESK.md says" not in page
    assert '"Posting by hand: Reddit takes no new API apps (since 31 Oct 2026)."' in page
    assert ".networks details.later ol li { display: list-item; }" in (ROOT / "web/admin.html").read_text()
    assert 'link("#social/write", "Write a post", "cta")' in page
    assert 'make("summary", "cta ghost", "How to connect later")' in page
    for step in ("code(one.redirect)", "...names,", "Redeploy: Deployments", "Back here, Connect Reddit takes the place"):
        assert step in page
    # A sheet that becomes the next gives its name the focus; an act that
    # closes it lands focus on what is there (sdreview L6).
    assert "else if (!sheet.contains(document.activeElement)) {\n    heading.tabIndex = -1;\n    heading.focus();" in page
    assert page.count("landed(send.id,") == 3
    html = (ROOT / "web/admin.html").read_text()
    # The rules' line is a status; each table has a name; links by finger are tall (L7).
    assert '<p class="note" id="social-rules-said" role="status">' in html
    for name in ("What came in", "Drafts", "Sent and scheduled"):
        assert f'<caption class="visually-hidden">{name}</caption>' in html
    assert 'make("caption", "visually-hidden", "Its score over time")' in page
    assert "table.cards td.text a, #social-sheet dd a { display: inline-flex; align-items: center; min-height: var(--control-h); }" in html
    # Meta's App Review is not promised away.
    assert "no App Review for the owner's own Page" not in SOCIAL and "likely needs App Review" in SOCIAL


def test_tokens_reach_no_answer_and_no_log() -> None:
    got = _api()
    assert got["tokens_in_answers"] == 0
    assert got["tokens_in_logs"] == 0
    assert got["calls_with_token_in_path"] == 0
    # Read only by session(), and never selected for an answer.
    assert len(re.findall(r"social_tokens\?[^`]*select=access_token", SOCIAL)) == 1
    assert "console." not in REDDIT


# --- The SQL ---------------------------------------------------------------------


def test_the_sql_only_adds_and_keeps_every_table_the_servers() -> None:
    lowered = SQL.lower()
    outside = re.sub(r"--[^\n]*", "", lowered)
    for word in ("drop ", "truncate", "alter column", "add column", "delete from", "update public", "rename", "insert into"):
        assert word not in outside, word
    made = set(re.findall(r"create table if not exists public\.([a-z_]+)", lowered))
    assert made == {"social_accounts", "social_tokens", "social_items", "social_sends", "social_results", "social_visits",
                    "social_rules"}
    for table in made:
        assert f"alter table public.{table} enable row level security" in lowered, table
        assert f"revoke all on public.{table} from public, anon, authenticated;" in lowered, table
        assert f"grant select, insert, update, delete on public.{table} to service_role;" in lowered, table
    # Nothing names an account of the site, so no export reaches it.
    assert "auth.users" not in outside
    got = _db()
    if got is None:
        return
    assert got["policies"] == 0 and got["fk_to_users"] == 0
    assert all(one.endswith(":true") for one in got["tables"]) and len(got["tables"]) == 7
    assert all(reach == ["denied", "denied", "ok"] for reach in got["reach"].values()), got["reach"]
    assert got["token_without_account"] == "social_tokens_account" and got["tokens_after_disconnect"] == 0
    assert got["visit"] == "kept" and got["visit_unknown_send"] == "social_visits_send_fkey"
    assert got["visit_bad_nonce"] == "social_visits_nonce" and got["bad_community"] == "social_sends_community"


def test_the_cron_runs_every_quarter_hour_at_its_own_address() -> None:
    deploy = (ROOT / "tools/deploy.sh").read_text()
    assert '{ "path": "/api/plans/social-due", "schedule": "*/15 * * * *" }' in deploy
    assert '{ "src": "/api/plans/social-due", "dest": "/api/plans?op=social_due" }' in deploy
    site = (ROOT / "api/_console_site.js").read_text()
    assert 'job: "social_due"' in site
