"""What moves in a model, held to one list of words and one gallery.

The app names what moves as a model is published (src/assembly/playable.gd
Playable.KINDS), api/share.js takes those words and no others (api/_directory.js
MOVES), and supabase/play.sql keeps them under a check of its own and reads all
but doors as a mechanism for the gallery's "Technic or mechanism" filter. If
any of them named a thing differently, a card would say one thing and the
filter find another, or a publish would be refused.

And directory_models and directory_card are defined in several files, the last
applied winning: play.sql's must carry every filter, sort and key of the ones
it supersedes (discovery.sql's list, builds.sql's card), or applying it would
quietly drop one. What the SQL does with them is proven by tools/play_try.sql
in a rolled-back dry run.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/play.sql").read_text()
DISCOVERY = (ROOT / "supabase/discovery.sql").read_text()
BUILDS = (ROOT / "supabase/builds.sql").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
PLAYABLE = (ROOT / "src/assembly/playable.gd").read_text()


def function(text: str, name: str) -> str:
    """The body of public.[name] as [text] defines it, last definition first."""
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name} in the file"
    return found[-1]


def words(text: str) -> list[str]:
    return re.findall(r"['\"]([a-z]+)['\"]", text)


def gd_list(name: str) -> list[str]:
    found = re.search(rf"const {name}: Array\[String\] = \[(.*?)\]", PLAYABLE, flags=re.S)
    assert found, f"playable.gd has no {name}"
    return words(found[1])


def test_the_app_the_api_and_the_database_say_the_same_words() -> None:
    found = re.search(r"export const MOVES = \[(.*?)\];", DIRECTORY, flags=re.S)
    assert found, "api/_directory.js has no MOVES"
    kinds = gd_list("KINDS")
    assert words(found[1]) == kinds
    check = re.search(r"constraint shared_models_moves_words.*?array\[(.*?)\]::text\[\]", SQL, flags=re.S)
    assert check, "play.sql has no check on the words"
    assert sorted(words(check[1])) == sorted(kinds)


def test_a_mechanism_is_every_word_but_doors() -> None:
    mechanisms = gd_list("MECHANISMS")
    assert mechanisms == [kind for kind in gd_list("KINDS") if kind != "doors"]
    body = function(SQL, "moves_mechanism")
    assert sorted(words(re.search(r"array\[(.*?)\]", body, flags=re.S)[1])) == sorted(mechanisms)


def test_directory_models_keeps_every_filter_and_sort_of_discovery_sql() -> None:
    before = function(DISCOVERY, "directory_models")
    after = function(SQL, "directory_models")
    squash = lambda text: re.sub(r"\s+", " ", text)  # noqa: E731
    asked = set(re.findall(r"\(?query->>'([a-z_]+)'", before))
    assert len(asked) >= 17
    for key in asked:
        assert f"query->>'{key}'" in after, f"play.sql's directory_models does not read {key}"
    technic = "and (not a.technic or m.technic)"
    for line in re.findall(r"^\s*((?:where|and) .+)$", before, flags=re.M):
        if squash(line) == technic:
            continue
        assert squash(line) in squash(after), f"play.sql's directory_models has lost: {line.strip()}"
    for sort in re.findall(r"case when a\.sort = '([a-z]+)'", before):
        assert f"case when a.sort = '{sort}'" in after, f"play.sql's directory_models has lost the sort {sort}"
    # The one line it changes: Technic or a mechanism by its moves.
    assert technic not in squash(after)
    assert "and (not a.technic or m.technic or public.moves_mechanism(m.moves))" in squash(after)
    # And the rest of it as discovery.sql wrote it, word for word.
    assert squash(after).replace(" or public.moves_mechanism(m.moves)", "") == squash(before)


def test_directory_card_keeps_every_key_of_builds_sql_and_says_what_moves() -> None:
    before = function(BUILDS, "directory_card")
    after = function(SQL, "directory_card")
    for key in re.findall(r"'([a-z_]+)', ", before):
        assert f"'{key}', " in after, f"play.sql's directory_card has lost {key}"
    assert "'moves', to_jsonb(m.moves)" in after


def test_the_card_a_client_is_given_says_what_moves() -> None:
    assert re.search(r"^\s*moves: movesOf\(row\.moves\),$", DIRECTORY, flags=re.M)
    # Every page's card is web/cards.js's (the gallery's own moved there):
    # its motions' names when it has them (supabase/motions.sql), else these.
    cards = (ROOT / "web/cards.js").read_text()
    assert "line.textContent = `Moves: ${motions.length ? motionWords(motions, 3) : moves.join(\", \")}`;" in cards


def test_only_additions() -> None:
    plain = re.sub(r"--[^\n]*", "", SQL).lower()
    for word in ["drop ", "rename ", "delete ", "update ", "truncate "]:
        assert word not in plain, f"play.sql has a {word.strip()}"
    assert "add column if not exists moves text[] not null default '{}'" in plain
    for granted in re.findall(r"grant (\w+) on (?:function )?public\.(\w+)", SQL):
        assert granted[0] == "execute", f"play.sql grants {granted[0]} on {granted[1]}"
    for name in ["moves_mechanism", "directory_card", "directory_models"]:
        assert re.search(rf"revoke all on function public\.{name}\(.*?\) from public, anon, authenticated;", SQL)
        assert re.search(rf"grant execute on function public\.{name}\(.*?\) to service_role;", SQL)
