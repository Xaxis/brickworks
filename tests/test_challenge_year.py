"""Challenges between months and achievements, held to what they promise.

supabase/challenge_year.sql goes into the live project, so it may only add:
one column, empty on every row, new functions the service role alone runs,
and three of challenges.sql's replaced with the same answers for every
challenge there is (tools/challenge_year_try.sql proves that in a rolled-back
dry run), each guarded so applying challenges.sql again alone is refused.
Achievements (docs/SOCIAL.md U13) are only for a profile shown in public.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def _guards() -> str:
    """The guard list, supabase/later.tsv, written as apply_sql.mjs once held
    it inline (one ["earlier", "function", "later", "mark"], a line)."""
    import json
    rows = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
            if line.strip() and not line.startswith("#")]
    return "\n".join("[" + ", ".join(json.dumps(v) for v in row) + "]," for row in rows)

SQL = (ROOT / "supabase/challenge_year.sql").read_text()
EARLIER = (ROOT / "supabase/challenges.sql").read_text()
APPLY = _guards()
PEOPLE = (ROOT / "api/people.js").read_text()
STAND_IN = (ROOT / "tools/web/challenges_stand_in.mjs").read_text()
REPLACED = ("challenge_shown", "challenge_page", "challenge_list")


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "delete from", "update public."):
        assert word not in plain, f"challenge_year.sql says {word.strip()}"
    assert "create table" not in plain
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [
        ("challenges", "add column if not exists announced_at timestamptz")]
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"challenges"}


def test_it_replaces_only_three_of_challenges_and_each_is_guarded() -> None:
    others = {name for path in (ROOT / "supabase").glob("*.sql") if path.name != "challenge_year.sql"
              for name in defined(path.read_text())}
    assert set(defined(SQL)) & others == set(REPLACED)
    for name in REPLACED:
        guard = re.search(rf'\["challenges\.sql", "{name}", "challenge_year\.sql", "([^"]+)"\]', APPLY)
        assert guard, f"apply_sql.mjs does not guard challenges.sql's {name}"
        assert guard.group(1) in body(name, SQL) and guard.group(1) not in body(name, EARLIER), name
        before = EARLIER[:EARLIER.index(f"create or replace function public.{name}(")]
        assert before.rstrip().splitlines()[-4].startswith("-- REPLACED LATER: challenge_year.sql"), name


def test_the_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    for name in set(defined(SQL)):
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name


def test_a_theme_is_told_only_when_its_time_comes() -> None:
    for name in ("challenge_shown", "challenge_next", "challenge_page_at"):
        assert "challenge_announced" in body(name, SQL), name
    assert "challenge_opened" in body("challenge_past", SQL) and "challenge_opened" in body("challenge_page_at", SQL)
    # A winner only while its model is in the gallery and its designer shown.
    past = body("challenge_past", SQL)
    assert "gallery_shows(m, challenge_past.tests)" in past and "shown_publicly(w.owner)" in past


def test_the_stand_in_holds_the_new_functions() -> None:
    held = set(re.findall(r'"(challenge_[a-z_]+)"', STAND_IN.split("];", 1)[0]))
    assert {"challenge_next", "challenge_past", "challenge_page_at", "challenge_plan"} <= held


def test_achievements_are_only_for_a_public_profile() -> None:
    # Kept since supabase/achievements.sql (tests/test_achievements.py), never here.
    assert "achievement" not in code(SQL).lower()
    page = PEOPLE[PEOPLE.index("async function profilePage("):]
    # Only once personOf has said the profile may be shown (none under 13).
    assert page.index("const person = await personOf(handle);") < page.index("achievementsOf(")
    answer = PEOPLE[PEOPLE.index("async function profile(request"):PEOPLE.index("async function likedShown(")]
    assert answer.index("const person = await personOf(handle);") < answer.index("achievementsOf(")
    assert "shownPublicly(rows[0].account)" in PEOPLE[PEOPLE.index("async function personOf("):]
