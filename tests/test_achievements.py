"""Achievements with levels (docs/SOCIAL.md section 7), held to what they promise.

supabase/achievements.sql goes into the live project, so it may only add: one
table only its functions reach, deleted with its account, an index, and
functions the service role alone runs; replies.sql's notification_rows
replaced with every row it gave and the levels reached, guarded so applying
replies.sql again alone is refused. tools/achievements_try.sql proves the rest
in a rolled-back dry run. The words for a level are made in web/card.js, the
one file the server and the browser share, so a pill, a notice and your own
tab say a level the same way.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/achievements.sql").read_text()
REPLIES = (ROOT / "supabase/replies.sql").read_text()
LATER = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
         if line.strip() and not line.startswith("#")]
TRACKS = ("designer", "built", "builder", "remixed", "tested", "challenger")


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
        assert word not in plain, f"achievements.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["achievement_marks"]
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [
        ("achievement_marks", "enable row level security")]
    assert "references auth.users (id) on delete cascade" in plain
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"achievement_marks"}
    assert set(re.findall(r"update public\.([a-z_]+)", plain)) == {"achievement_marks"}


def test_the_table_and_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    assert "revoke all on public.achievement_marks from public, anon, authenticated, service_role;" in plain
    assert not re.search(r"grant [^;]* on public\.achievement_marks", plain)
    for name in set(defined(SQL)):
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name


def test_it_replaces_only_notification_rows_and_keeps_every_row_it_gave() -> None:
    others = {name for path in (ROOT / "supabase").glob("*.sql") if path.name != "achievements.sql"
              for name in defined(path.read_text())}
    assert set(defined(SQL)) & others == {"notification_rows"}
    before, after = body("notification_rows", REPLIES), body("notification_rows", SQL)
    # replies.sql's whole, then the levels reached: nothing of it changed.
    assert after.startswith(before)
    assert "'achievement'::text" in after[len(before):] and "achievement_marks" in after[len(before):]
    for earlier in ("replies.sql", "notifications.sql"):
        guard = [row for row in LATER if row[:3] == [earlier, "notification_rows", "achievements.sql"]]
        assert guard and guard[0][3] in after and guard[0][3] not in body("notification_rows", (ROOT / f"supabase/{earlier}").read_text())
    told = REPLIES[:REPLIES.index("create or replace function public.notification_rows(")]
    assert "REPLACED LATER: achievements.sql" in "\n".join(told.rstrip().splitlines()[-4:])


def test_numbers_are_read_as_a_designers_page_reads_them() -> None:
    numbers = body("achievement_numbers", SQL)
    assert "public.shown_publicly(achievement_numbers.account)" in numbers
    assert "m.published and m.listed and not m.barred and m.author is not null" in numbers
    assert numbers.count("not m.test or coalesce(achievement_numbers.tests, false)") == 2
    assert "ph.removed_at is null and ph.hidden_at is null" in numbers
    assert "not c.test or coalesce(achievement_numbers.tests, false)" in numbers
    # A test account counts its own test models, as its own page does.
    assert "public.trust_is_test_account(viewer)" in body("achievement_mark", SQL)
    assert "on conflict on constraint achievement_marks_pkey do nothing" in body("achievement_mark", SQL)


def test_the_ladders_and_the_words_name_the_same_tracks() -> None:
    ladders = re.findall(r"\('([a-z]+)', (\d), array\[([\d, ]+)\]\)", body("achievement_ladders", SQL))
    assert [one[0] for one in ladders] == list(TRACKS)
    assert [int(one[1]) for one in ladders] == list(range(1, 7))
    for _, _, steps in ladders:
        numbers = [int(n) for n in steps.split(",")]
        assert numbers[0] == 1 and numbers == sorted(set(numbers))
    check = re.search(r"track in \(([^)]+)\)", SQL).group(1)
    assert re.findall(r"'([a-z]+)'", check) == list(TRACKS)
    stand_in = (ROOT / "tools/web/design_stand_in.mjs").read_text()
    held = re.findall(r'\["([a-z]+)", \[([\d, ]+)\]\]', stand_in[stand_in.index("const LADDERS"):])
    assert [(track, steps) for track, steps in held] == [(one[0], one[2]) for one in ladders]


def test_a_level_is_said_the_same_everywhere() -> None:
    script = """
      import { TRACKS, levelName, levelAwards } from "./web/card.js";
      import { noticeSaid, noticeGroups } from "./api/_notifications.js";
      const levels = [
        { track: "designer", n: 1, level: 1, of: 6, reached: 1, next: 3 },
        { track: "built", n: 12, level: 2, of: 6, reached: 10, next: 50 },
        { track: "builder", n: 0, level: 0, of: 5, reached: null, next: 1 },
        { track: "tested", n: 1, level: 1, of: 4, reached: 1, next: 5 },
      ];
      const rows = [
        { kind: "achievement", at: "2026-10-30T08:00:00Z", on: null, track: "designer", level: 3, of: 6, reached: 10, read: false },
        { kind: "achievement", at: "2026-10-29T08:00:00Z", on: null, track: "tested", level: 1, of: 4, reached: 1, read: true },
        { kind: "likes", at: "2026-10-29T07:00:00Z", on: "SamModel01", model: "SamModel01", likes: 2, day: "2026-10-29" },
      ];
      console.log(JSON.stringify({
        tracks: Object.keys(TRACKS),
        names: [levelName("designer", 1), levelName("designer", 10), levelName("built", 1), levelName("remixed", 25),
          levelName("challenger", 3), levelName("nope", 3)],
        awards: levelAwards(levels),
        said: noticeSaid(rows[0], "https://x"),
        groups: noticeGroups({ rows, models: { SamModel01: { name: "Tram" } }, seen_at: "2026-10-29T12:00:00Z",
          read_at: null, reads: {} }, "https://x"),
      }));
    """
    out = json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                    capture_output=True, text=True).stdout)
    assert out["tracks"] == list(TRACKS)
    assert out["names"] == ["Designer · first model", "Designer · 10 models", "Built · once", "Remixed · 25 times",
                            "Challenger · 3 challenges", ""]
    # The highest first, the tracks' order between equals; none at level 0.
    assert [(one["id"], one["level"], one["name"]) for one in out["awards"]] == [
        ("built", 2, "Built · 10 times"), ("designer", 1, "Designer · first model"), ("tested", 1, "Tested · first model")]
    assert out["awards"][0]["said"] == "Level 2 of 6: 12 builds finished to the last step"
    assert out["said"]["who"] == "You" and out["said"]["did"] == "reached Designer · 10 models, level 3 of 6"
    assert out["said"]["link"] == "https://x/profile?tab=achievements"
    first, second = out["groups"]["groups"]
    assert first["achievements"] is True and first["model"] == "" and first["name"] == "Your achievements"
    assert first["picture"] is None and first["link"] == "https://x/profile?tab=achievements"
    # Unread until its group is opened (each row's read), whatever else was.
    assert [row["unread"] for row in first["rows"]] == [True, False] and first["unread"] is True
    assert second["model"] == "SamModel01" and out["groups"]["unread"] == 2


def test_the_pages_ask_for_levels_and_tell_them() -> None:
    people = (ROOT / "api/people.js").read_text()
    assert people.count("levelsOf(person.account, tests)") == 2
    assert people.count("achievementsOf({ about, earned, built, wins, levels })") == 2
    notices = (ROOT / "api/_notifications.js").read_text()
    # Written down before it is counted or listed, so it is told at once.
    assert 'marked(asker).then(() => call("notification_counts"' in notices
    assert notices.index("await marked(asker);") < notices.index('call("notification_list"')
    assert 'call("achievement_read"' in notices
    page = (ROOT / "web/notifications.js").read_text()
    assert '"achievements" in group.dataset ? { achievements: true }' in page
    profile = (ROOT / "web/profile.js").read_text()
    assert '"achievements"' in profile.split("const TABS = ", 1)[1].split("\n", 1)[0]
    assert 'data-tab="achievements"' in (ROOT / "web/profile.html").read_text()
