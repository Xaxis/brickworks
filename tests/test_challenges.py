"""The monthly challenge, held to what it promises.

supabase/challenges.sql goes into the live project, so it may only add: new
tables, their indexes and new functions, and nothing another file defines
replaced (the gallery's directory_card and directory_models above all) but
follows.sql's feed_rows, word for word with one kind more. What the SQL
answers is proven by tools/challenges_try.sql in a rolled-back dry run, and
what it keeps by tools/sql_compare.mjs; these read the files and hold the
promises around it:

- the tables are the server's alone, read and written only through the
  functions, which only the service role may run;
- what changes rows changes only the file's own tables;
- nobody's account comes from the request: entering, voting and taking back
  are the sign-in's own, and a test account's kind is its sign-in's too;
- a signed-in answer is never kept by a cache;
- the local stand-in answers every function the API asks, and the browser
  flow asks a deployment only through its API.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/challenges.sql").read_text()
API = (ROOT / "api/_challenges.js").read_text()
ADMIN = (ROOT / "api/admin.js").read_text()
STAND_IN = (ROOT / "tools/web/challenges_stand_in.mjs").read_text()
FLOW = (ROOT / "tools/web/challenges_flow.mjs").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()
TABLES = {"challenges", "challenge_set_parts", "challenge_entries", "challenge_votes", "challenge_winners"}


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column"):
        assert word not in plain, f"challenges.sql says {word.strip()}"
    assert set(re.findall(r"create table if not exists public\.([a-z_]+)", plain)) == TABLES
    for altered in re.findall(r"alter table public\.([a-z_]+)", plain):
        assert altered in TABLES, f"alters {altered}"
    # Every write is to one of its own tables.
    for verb, table in re.findall(r"\b(insert into|update|delete from)\s+public\.([a-z_]+)", plain):
        assert table in TABLES, f"{verb} {table}"


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_it_replaces_only_the_feed_which_keeps_every_row_it_had() -> None:
    # challenge_year.sql replaces three of these later, guarded as follows.sql's
    # feed is (tests/test_challenge_year.py).
    others = {
        name
        for path in (ROOT / "supabase").glob("*.sql")
        if path.name not in ("challenges.sql", "challenge_year.sql")
        for name in defined(path.read_text())
    }
    mine = defined(SQL)
    assert mine and all(name.startswith("challenge_") for name in mine if name != "feed_rows"), mine
    assert set(mine) & others == {"feed_rows"}, set(mine) & others
    # follows.sql's, the live one, word for word, and one branch more after it.
    theirs = body("feed_rows", (ROOT / "supabase/follows.sql").read_text())
    ours = body("feed_rows", SQL)
    assert ours.startswith(theirs + "\n    union all\n"), "feed_rows is not follows.sql's with one branch added"
    added = code(ours[len(theirs):])
    assert added.count("select ") == 1 and "'challenge'::text" in added
    for rule in ("join followed w on w.account = e.owner", "m.listed", "not m.barred", "m.author is not null",
                 "(not m.test or t.ok)", "(not c.test or t.ok)", "e.at > since and e.at <= until"):
        assert rule in added, f"the entry's row does not ask {rule}"


def test_applying_follows_again_alone_is_refused() -> None:
    """tools/apply_sql.mjs guards the function this file replaces: follows.sql
    applied again alone would take the entries out of every feed."""
    apply = (ROOT / "tools/apply_sql.mjs").read_text()
    guard = re.search(r'\["follows\.sql", "feed_rows", "challenges\.sql", "([^"]+)"\]', apply)
    assert guard, "apply_sql.mjs does not guard follows.sql's feed_rows"
    mark = guard.group(1)
    assert mark in body("feed_rows", SQL)
    assert mark not in body("feed_rows", (ROOT / "supabase/follows.sql").read_text())
    assert "REPLACED LATER: challenges.sql" in (ROOT / "supabase/follows.sql").read_text()


def test_the_tables_and_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    for table in TABLES:
        assert f"alter table public.{table} enable row level security;" in plain
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role;" in plain
    for name in set(defined(SQL)):
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name
    assert "grant execute" not in re.sub(r"grant execute on function public\.(challenge_[a-z_]+|feed_rows)\([^)]*\) to service_role;",
                                         "", plain)


def test_the_rules_are_checked_in_the_database() -> None:
    plain = code(SQL)
    enter = plain[plain.index("function public.challenge_enter("):plain.index("function public.challenge_withdraw(")]
    for rule in ("trust_kept_private", "trust_may_go_public", "is_barred", "gallery_shows", "challenge_check", ">= 3"):
        assert rule in enter, f"challenge_enter does not ask {rule}"
    vote = plain[plain.index("function public.challenge_vote("):plain.index("function public.challenge_settle(")]
    for rule in ("trust_kept_private", "trust_may_go_public", "is_barred", "e.owner = challenge_vote.account",
                 "challenge_check", "on conflict (challenge, way, voter) do nothing"):
        assert rule in vote, f"challenge_vote does not ask {rule}"
    check = plain[plain.index("function public.challenge_check("):plain.index("function public.challenge_keeps(")]
    for read in ("public.model_needs", "public.challenge_set_parts", "public.model_tested", "m.parts <= c.most_parts"):
        assert read in check, f"challenge_check does not read {read}"


def test_nobody_is_named_by_the_request() -> None:
    for name in ("enter", "withdraw", "vote", "challengeEntry"):
        start = API.index(f"export async function {name}(")
        part = API[start:API.index("\n}\n", start)]
        assert "await caller(request)" in part, name
        assert "account: who.account" in part or "who.account" in part, name
        assert "body.account" not in part and "query?.account" not in part, name
    vote = API[API.index("export async function vote("):]
    assert "tests: who.test" in vote, "a vote's kind is the sign-in's own"
    assert "isTestAccount(claims)" in API


def test_a_signed_in_answer_is_never_kept() -> None:
    page = API[API.index("export async function challenge("):API.index("export async function challengeEntry(")]
    assert 'response.setHeader("Cache-Control", who || tests ? TESTS_CACHE : PAGE_CACHE);' in page
    entry = API[API.index("export async function challengeEntry("):API.index("export async function enter(")]
    assert 'response.setHeader("Cache-Control", "private, no-store");' in entry


def test_the_admin_sets_a_test_one_only_when_asked() -> None:
    part = ADMIN[ADMIN.index("async function setChallenge("):ADMIN.index("async function endChallenge(")]
    assert 'const tests = String(request.query?.tests || "") === "1";' in part
    assert "test: tests" in part
    assert "keyed([...(record.p || []), ...(record.s || [])])" in part


def test_the_stand_in_answers_what_the_api_asks() -> None:
    asked = set(re.findall(r'"rpc/(challenge_[a-z_]+)"', API + ADMIN))
    held = set(re.findall(r'"(challenge_[a-z_]+)"', STAND_IN.split("];", 1)[0]))
    assert asked <= held, asked - held
    both = set(defined(SQL)) | set(defined((ROOT / "supabase/challenge_year.sql").read_text()))
    assert asked <= both, asked - both


def test_the_flow_asks_a_deployment_only_through_its_api() -> None:
    assert "/__held/" not in FLOW
    assert "x-vercel-protection-bypass" in FLOW
    assert '[challenges]="tools/web/challenges_flow.mjs --url=$P --out=$S/${TAG}_challenges"' in CHECKS
