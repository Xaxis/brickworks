"""The admin's list of challenges puts the ones not yet ended first.

challenge_list ordered every challenge newest first, at most 24. Once the
owner planned a year of themes (2026-10-25, ids 107-119) and each browser run
left an ended test challenge in a coming month, those filled the 24 rows: the
open challenge, the next to open and a test challenge a run had left open
were in no row, so /admin could not end it and challenges_flow could not see
the one it had just set. supabase/challenge_list_order.sql replaces it with
the same rows in another order: open, then upcoming by their first day, then
the ended ones, the one that ended last first. tools/challenge_list_order_try.sql proves it on
the live project in a rolled-back dry run; this holds the file to that.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/challenge_list_order.sql").read_text()
EARLIER = (ROOT / "supabase/challenge_year.sql").read_text()
STAND_IN = (ROOT / "tools/web/challenges_stand_in.mjs").read_text()
ORDER = re.compile(r"\n\s*order by .*?(?=\n\s*limit 24$)", re.S)


def later() -> list[list[str]]:
    return [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
            if line.strip() and not line.startswith("#")]


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_the_file_replaces_challenge_list_and_nothing_else() -> None:
    plain = code(SQL).lower()
    assert re.findall(r"create or replace function public\.([a-z_]+)\(", plain) == ["challenge_list"]
    for word in ("drop ", "truncate", "rename ", "alter ", "delete from", "update public.", "insert into", "create table"):
        assert word not in plain, f"challenge_list_order.sql says {word.strip()}"
    assert "revoke all on function public.challenge_list(boolean) from public, anon, authenticated;" in plain
    assert "grant execute on function public.challenge_list(boolean) to service_role;" in plain


def test_the_same_rows_in_another_order() -> None:
    new, old = body("challenge_list", SQL), body("challenge_list", EARLIER)
    found = ORDER.search(new)
    assert found and ORDER.search(old)
    # Everything but the order is challenge_year.sql's, to the letter: the
    # same columns, the same where, at most 24.
    assert ORDER.sub("", new) == ORDER.sub("", old)
    order = " ".join(found.group(0).split())
    assert order == ("order by case public.challenge_state(c) when 'open' then 0 when 'upcoming' then 1 else 2 end, "
                     "case when public.challenge_state(c) = 'upcoming' then c.starts_on end asc, "
                     "least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)) desc, c.id desc")
    # The ended ones as challenge_past orders what ran: by the day each ended.
    assert "least(c.ends_on, coalesce((c.ended_at at time zone 'utc')::date, c.ends_on)) desc, c.id desc" \
        in body("challenge_past", EARLIER)


def test_applying_challenge_year_again_alone_is_refused() -> None:
    guard = [row for row in later() if row[:3] == ["challenge_year.sql", "challenge_list", "challenge_list_order.sql"]]
    assert len(guard) == 1, "supabase/later.tsv does not guard challenge_year.sql's challenge_list"
    mark = guard[0][3]
    assert mark in body("challenge_list", SQL) and mark not in body("challenge_list", EARLIER)
    before = EARLIER[:EARLIER.index("create or replace function public.challenge_list(")]
    assert any(line.startswith("-- REPLACED LATER: challenge_list_order.sql")
               for line in before.rstrip().splitlines()[-8:])


def test_the_stand_in_lists_them_in_the_same_order() -> None:
    held = STAND_IN[STAND_IN.index("async challenge_list("):]
    held = held[:held.index("\n  },")]
    assert "listOrder" in held and "function listOrder(" in STAND_IN
