"""Challenges people hear of (docs/SOCIAL.md section 7, item 3), held to what they promise.

supabase/challenge_notices.sql goes into the live project, so it may only add: one
table only its functions reach, deleted with its account or its challenge, and
functions the service role alone runs; achievements.sql's notification_rows
replaced with every row it gave and the challenges', guarded so applying any
earlier file of it again alone is refused. tools/challenge_notices_try.sql proves
who hears what in a rolled-back dry run; here, that the rules it proves are the
ones written, and that a notice says a challenge the same way to every page.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/challenge_notices.sql").read_text()
ACHIEVEMENTS = (ROOT / "supabase/achievements.sql").read_text()
LATER = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
         if line.strip() and not line.startswith("#")]


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "delete from"):
        assert word not in plain, f"challenge_notices.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["challenge_reads"]
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [("challenge_reads", "enable row level security")]
    assert "account    uuid not null references auth.users (id) on delete cascade" in plain
    assert "challenge  bigint not null references public.challenges (id) on delete cascade" in plain
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"challenge_reads"}
    assert not re.findall(r"update public\.([a-z_]+)", plain)


def test_the_table_and_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    assert "revoke all on public.challenge_reads from public, anon, authenticated, service_role;" in plain
    assert not re.search(r"grant [^;]* on public\.challenge_reads", plain)
    assert sorted(set(defined(SQL))) == ["challenge_read", "notification_rows"]
    for name in set(defined(SQL)):
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name


def test_it_keeps_every_row_achievements_gave_and_is_guarded() -> None:
    before, after = body("notification_rows", ACHIEVEMENTS), body("notification_rows", SQL)
    # achievements.sql's whole, then the challenges: nothing of it changed.
    assert after.startswith(before)
    added = after[len(before):]
    for kind in ("'challenge_open'::text", "'challenge_closing'::text", "'challenge_won'::text"):
        assert kind in added
    for earlier in ("notifications.sql", "replies.sql", "achievements.sql"):
        guard = [row for row in LATER if row[:3] == [earlier, "notification_rows", "challenge_notices.sql"]]
        assert guard, earlier
        assert guard[0][3] in after and guard[0][3] not in body("notification_rows", (ROOT / f"supabase/{earlier}").read_text())
    told = ACHIEVEMENTS[:ACHIEVEMENTS.index("create or replace function public.notification_rows(")]
    assert "REPLACED LATER: challenge_notices.sql" in "\n".join(told.rstrip().splitlines()[-4:])


def test_who_hears_is_who_may_enter_and_who_voted() -> None:
    added = body("notification_rows", SQL)[len(body("notification_rows", ACHIEVEMENTS)):]
    opened, won = added.split("'challenge_won'::text", 1)
    # Whoever may enter: 13 or over and asked, not taken out, a test account
    # only of the test challenges; made before it was told, and only once it
    # has come, never after it was ended.
    for rule in ("c.test = public.trust_is_test_account(viewer)", "public.trust_may_go_public(viewer)",
                 "not public.is_barred(viewer)", "k.at <= now()", "(c.ended_at is null or c.ended_at > k.at)",
                 "k.at > (select u.created_at from auth.users u where u.id = viewer)",
                 "coalesce(c.announced_at, '-infinity')"):
        assert rule in opened, rule
    # The last two days: not for an entrant, nor a challenge too short to have them.
    assert "d.closing > d.opened" in opened
    assert "not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)" in opened
    # Who won: for a voter who did not enter (an entrant hears it as 'result').
    assert "exists (select 1 from public.challenge_votes v where v.challenge = c.id and v.voter = viewer)" in won
    assert "not exists (select 1 from public.challenge_entries e where e.challenge = c.id and e.owner = viewer)" in won
    assert "c.settled_at is not null" in won
    read = body("challenge_read", SQL)
    assert "'refused', 'sign_in'" in read and "'refused', 'nobody'" in read
    assert "on conflict on constraint challenge_reads_pkey do update set at = excluded.at" in read


def test_a_challenge_is_said_and_grouped_the_same_everywhere() -> None:
    script = """
      import { noticeSaid, noticeGroups } from "./api/_notifications.js";
      const rows = [
        { kind: "challenge_closing", at: "2026-10-30T00:00:00Z", on: null, challenge: 7, title: "Harbour", ends_on: "2026-10-31",
          test: false, read: false },
        { kind: "likes", at: "2026-10-29T07:00:00Z", on: "SamModel01", model: "SamModel01", likes: 2, day: "2026-10-29" },
        { kind: "challenge_won", at: "2026-10-02T09:00:00Z", on: null, challenge: 6, title: "Castle", ends_on: "2026-09-30",
          test: true, picked: true, read: true },
        { kind: "challenge_open", at: "2026-10-01T00:00:00Z", on: null, challenge: 7, title: "Harbour", ends_on: "2026-10-31",
          test: false, read: false },
      ];
      const said = (row) => noticeSaid(row, "https://x").did;
      console.log(JSON.stringify({
        said: rows.filter((row) => row.challenge).map(said),
        lost: said({ kind: "challenge_won", challenge: 6, title: "Castle", picked: false }),
        link: noticeSaid(rows[2], "https://x").link,
        groups: noticeGroups({ rows, models: { SamModel01: { name: "Tram" } }, seen_at: "2026-10-29T12:00:00Z",
          read_at: "2026-10-03T00:00:00Z", reads: {} }, "https://x"),
      }));
    """
    out = json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                    capture_output=True, text=True).stdout)
    assert out["said"] == ["The last two days to enter “Harbour”: it closes at the end of 31 October",
                           "“Castle” has ended, and a model you voted for won",
                           "“Harbour” is open: enter by the end of 31 October"]
    assert out["lost"] == "“Castle” has ended: see who won"
    # A test challenge's own page, as a test asks for it.
    assert out["link"] == "https://x/challenge?id=6&tests=1"
    harbour, tram, castle = out["groups"]["groups"]
    assert harbour["challenge"] == 7 and harbour["model"] == "" and harbour["name"] == "Challenge: Harbour"
    assert harbour["picture"] is None and harbour["link"] == "https://x/challenge?id=7"
    assert [row["kind"] for row in harbour["rows"]] == ["challenge_closing", "challenge_open"]
    # Unread until its group was opened, or everything marked read after it
    # (read_at, 3 October, after its opening and before its last days).
    assert [row["unread"] for row in harbour["rows"]] == [True, False] and harbour["unread"] is True
    assert castle["challenge"] == 6 and castle["unread"] is False and tram["model"] == "SamModel01"


def test_the_page_reads_a_challenges_group_by_its_number() -> None:
    notices = (ROOT / "api/_notifications.js").read_text()
    assert 'call("challenge_read", { viewer: asker, challenge: body.challenge }' in notices
    assert "Number.isSafeInteger(body.challenge)" in notices
    page = (ROOT / "web/notifications.js").read_text()
    assert "group.dataset.challenge ? { challenge: Number(group.dataset.challenge) }" in page
    assert 'one.challenge ? "pic challenge"' in page
    css = (ROOT / "web/directory.css").read_text()
    assert ".notice .pic.challenge .icon" in css


def test_a_challenges_link_shows_that_challenge() -> None:
    script = """
      import { readFileSync } from "node:fs";
      import { challengeHead } from "./api/_challenges.js";
      const html = readFileSync("web/challenge.html", "utf8");
      const page = { id: 7, title: "Harbour <night>", brief: "Build a harbour   with a crane.", starts_on: "2026-10-01",
        ends_on: "2026-10-31", state: "ended", test: false,
        winners: [{ way: "hand", model: "SamModel01", votes: 3 }, { way: "assistant", model: "PriyaSpc01", votes: 1 }],
        entries: [{ model: "PriyaSpc01", way: "assistant", card: { id: "PriyaSpc01", has_image: true } },
                  { model: "SamModel01", way: "hand", card: { id: "SamModel01", has_image: false } }] };
      const tags = (made) => Object.fromEntries([...made.matchAll(/<(title)>([^<]*)<\\/title>|<meta (?:name|property)="([a-z:]+)" content="([^"]*)">|<link rel="(canonical)" href="([^"]*)">/g)]
        .map((m) => [m[1] || m[3] || m[5], m[2] ?? m[4] ?? m[6]]));
      console.log(JSON.stringify({
        ended: tags(challengeHead(html, "https://x", page)),
        open: tags(challengeHead(html, "https://x", { ...page, state: "open", winners: [], test: true }, true)),
        same: challengeHead(html, "https://x", null) === html,
        body: challengeHead(html, "https://x", page).split("</head>")[1] === html.split("</head>")[1],
      }));
    """
    out = json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                    capture_output=True, text=True).stdout)
    ended, opened = out["ended"], out["open"]
    title = "Harbour &lt;night&gt; · Brickworks challenge"
    about = "Build a harbour with a crane. Ran 1 to 31 October 2026: see who won."
    assert [ended[key] for key in ("title", "og:title", "twitter:title")] == [title] * 3
    assert [ended[key] for key in ("description", "og:description", "twitter:description")] == [about] * 3
    assert ended["canonical"] == ended["og:url"] == "https://x/challenge?id=7"
    # The first winner with a picture: the hand's has none, the assistant's has.
    assert ended["og:image"] == ended["twitter:image"] == "https://x/m/PriyaSpc01.png"
    assert "robots" not in ended
    # A test challenge, asked as a test: its own address, never found, and the site's picture.
    assert opened["og:url"] == "https://x/challenge?id=7&amp;tests=1" and opened["robots"] == "noindex"
    assert opened["og:description"].endswith("Open 1 to 31 October 2026.") and opened["og:image"] == "https://x/share.png"
    assert out["same"] is True and out["body"] is True


def test_the_route_and_the_page_go_together() -> None:
    deploy = (ROOT / "tools/deploy.sh").read_text()
    route = deploy.index('"dest": "/api/people?op=challenge_page"')
    # After the site's own headers (its security policy), before the files.
    assert deploy.index('"Content-Security-Policy": "$csp"') < route < deploy.index('{ "handle": "filesystem" }')
    assert 'cp web/challenge.html "$fn/_challenge.html"' in deploy
    assert 'if (op === "challenge_page") return await challengePage(request, response);' in (ROOT / "api/people.js").read_text()
