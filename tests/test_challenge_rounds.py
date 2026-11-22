"""Judges, a fan vote and honours, held to what they promise.

supabase/challenge_rounds.sql goes into the live project, so it may only add:
six columns, empty on every row, one table, and new functions the service
role alone runs; it replaces none. A challenge with no rounds runs as it ran:
its entries, its blind vote and its rules are challenges.sql's, asked by the
round functions themselves, and its count is challenge_settle's word for word
with the shortlist rule alone added. tools/challenge_rounds_try.sql proves the
rest in a rolled-back dry run, and tools/web/challenges_flow.mjs part 7 in a
browser once the file is applied.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/challenge_rounds.sql").read_text()
EARLIER = (ROOT / "supabase/challenges.sql").read_text()
API = (ROOT / "api/_challenges.js").read_text()
CONSOLE = (ROOT / "api/_console_challenges.js").read_text()


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column"):
        assert word not in plain, f"challenge_rounds.sql says {word.strip()}"
    added = re.findall(r"alter table public\.challenges add column if not exists ([a-z_]+) ", plain)
    assert added == ["entries_until", "votes_from", "judge_name", "judge_account", "cover_model", "shortlisted_at"]
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["challenge_shortlist"]
    # Its constraints only where none of that name is yet, and each holds
    # for a challenge with no rounds (every row there is).
    assert plain.count("add constraint") == 3 and plain.count("if not exists (select 1 from pg_constraint") == 3
    # Rows are written only by its functions, as the owner asks: a delete
    # only of the shortlist it replaces.
    assert set(re.findall(r"delete from public\.([a-z_]+)", plain)) == {"challenge_shortlist"}
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"challenge_shortlist", "challenge_winners", "gallery_picks"}


def test_it_replaces_nothing() -> None:
    others = {name for path in (ROOT / "supabase").glob("*.sql") if path.name != "challenge_rounds.sql"
              for name in defined(path.read_text())}
    assert not set(defined(SQL)) & others, set(defined(SQL)) & others
    assert "challenge_rounds.sql" not in (ROOT / "supabase/later.tsv").read_text()


def test_the_functions_and_the_table_are_the_servers_alone() -> None:
    plain = code(SQL)
    for name in set(defined(SQL)):
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name
        assert "set search_path = public" in body(name, SQL), name
        # challenge_round, a pure helper over a row it is handed, runs as its caller.
        assert ("security definer" in body(name, SQL)) == (name != "challenge_round"), name
    assert "alter table public.challenge_shortlist enable row level security;" in plain
    assert "revoke all on public.challenge_shortlist from public, anon, authenticated, service_role;" in plain


def test_the_blind_vote_and_the_rules_are_challenges_own() -> None:
    # The round functions refuse only what a round adds, and then ask the
    # functions they stand before, with the same arguments.
    assert "return public.challenge_vote(challenge_vote_round.account, challenge_vote_round.challenge_id," in body("challenge_vote_round", SQL)
    assert "return public.challenge_enter(challenge_enter_round.account, challenge_enter_round.model_id, challenge_enter_round.way);" \
        in body("challenge_enter_round", SQL)
    # A challenge with no rounds (entries_until null) is never refused here.
    assert "c.entries_until is not null and public.challenge_state(c) = 'open'" in body("challenge_vote_round", SQL)
    assert "c.entries_until is not null and public.challenge_today() > c.entries_until" in body("challenge_enter_round", SQL)


def test_its_count_is_challenge_settles_with_the_shortlist_alone_added() -> None:
    def count(text: str) -> list[str]:
        part = text[text.index("insert into public.challenge_winners"):text.index("update public.challenges x set settled_at")]
        return [" ".join(line.split()) for line in part.splitlines() if line.strip()]
    before = count(body("challenge_settle", EARLIER))
    after = count(body("challenge_settle_rounds", SQL))
    added = [line for line in after if line not in before]
    assert added == ["and (c.entries_until is null",
                     "or exists (select 1 from public.challenge_shortlist s where s.challenge = c.id and s.model = e.model))"], added
    assert [line for line in after if line not in added] == before


def test_winners_are_the_pick_the_week_after_a_week_each() -> None:
    settle = body("challenge_settle_rounds", SQL)
    assert "order by x.votes desc, x.way desc" in settle
    assert "week_from := ended + make_interval(days => 7 * week);" in settle
    assert "values (w.model, greatest(now(), week_from), week_from + interval '7 days');" in settle
    # A pick may last 31 days at most (discovery.sql's gallery_picks).
    assert "until <= chosen_at + interval '31 days'" in (ROOT / "supabase/discovery.sql").read_text()
    # Counted without the page: the home page's and the gallery's line asks it.
    line = API[API.index("export async function challengeLine("):]
    assert 'db("rpc/challenge_settle_due"' in line[:600]


def test_a_shortlist_is_at_most_five_in_each_group() -> None:
    shortlist = body("challenge_shortlist_set", SQL)
    assert "> 5" in shortlist and "'too_many'" in shortlist
    # The owner's panel holds a group to five before it asks.
    assert 'querySelectorAll("input:checked").length > 5' in (ROOT / "web/admin-challenges.js").read_text()


def test_the_api_asks_the_new_and_falls_back_before_the_file() -> None:
    for name in ("challenge_enter_round", "challenge_vote_round", "challenge_settle_rounds", "challenge_rounds_of"):
        assert f'"rpc/{name}"' in API, name
    for name in ("challenge_rounds_set", "challenge_shortlist_set", "challenge_rounds_of"):
        assert f'"rpc/{name}"' in CONSOLE, name
    assert API.count("missing(trouble)") >= 3
