"""The gallery's Top builds, held to one set of numbers and one list.

supabase/discovery.sql's gallery_score is what the gallery sorts by and the
week's pick is worked out with; api/_directory.js SCORE is what the page
says it weighs; tools/web/discovery_stand_in.mjs answers for the SQL on a
local relay until the file is applied. If any of the three weighed a build,
a remix or the Tested mark differently, the gallery would sort one way and
say another. These read the three files and hold them together.

And directory_models is defined in several files, the last applied winning:
discovery.sql's must carry every filter and sort of builds.sql's, the one it
supersedes, or applying it would quietly drop one. That, too, is read here
from the two files. What the SQL does with them is proven by
tools/discovery_try.sql in a rolled-back dry run.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/discovery.sql").read_text()
BUILDS = (ROOT / "supabase/builds.sql").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
STAND_IN = (ROOT / "tools/web/discovery_stand_in.mjs").read_text()


def function(text: str, name: str) -> str:
    """The body of public.[name] as [text] defines it, last definition first."""
    found = re.findall(
        rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S
    )
    assert found, f"no public.{name} in the file"
    return found[-1]


def score_in_sql() -> dict[str, int]:
    body = function(SQL, "gallery_score")
    found = re.search(
        r"select\s+(\d+)\s*\*\s*coalesce\(builds, 0\)\s*\+\s*(\d+)\s*\*\s*coalesce\(remixes, 0\)"
        r"\s*\+\s*case when tested then (\d+) else 0 end",
        body,
    )
    assert found, f"gallery_score is not the sum this test reads: {body.strip()}"
    return {"builds": int(found[1]), "remixes": int(found[2]), "tested": int(found[3])}


def score_in_js() -> dict[str, int]:
    found = re.search(r"export const SCORE = \{ builds: (\d+), remixes: (\d+), tested: (\d+) \};", DIRECTORY)
    assert found, "api/_directory.js has no SCORE"
    return {"builds": int(found[1]), "remixes": int(found[2]), "tested": int(found[3])}


def test_the_page_says_what_the_sql_weighs() -> None:
    assert score_in_sql() == score_in_js()


def test_a_build_counts_most_and_views_not_at_all() -> None:
    weights = score_in_sql()
    assert weights["builds"] > weights["remixes"] > 0
    assert weights["tested"] > weights["builds"]
    assert "views" not in function(SQL, "gallery_score")


def test_the_stand_in_weighs_with_the_page_s_numbers() -> None:
    # Read from api/_directory.js, never written out again.
    assert 'import { SCORE } from "../../api/_directory.js";' in STAND_IN
    assert re.search(r"SCORE\.builds \* builds \+ SCORE\.remixes \* remixes", STAND_IN)
    assert "SCORE.tested" in STAND_IN


def test_top_builds_is_a_sort_the_list_knows() -> None:
    assert re.search(r'^\s*top: "Top builds",$', DIRECTORY, flags=re.M)
    assert "case when a.sort = 'top'" in function(SQL, "directory_models")


def test_directory_models_keeps_every_filter_and_sort_of_builds_sql() -> None:
    before = function(BUILDS, "directory_models")
    after = function(SQL, "directory_models")
    squash = lambda text: re.sub(r"\s+", " ", text)  # noqa: E731
    # Every question it reads.
    asked = re.findall(r"(?:nullif\()?\(?query->>'([a-z_]+)'", before)
    assert len(set(asked)) >= 15
    for key in set(asked):
        assert f"query->>'{key}'" in after, f"discovery.sql's directory_models does not read {key}"
    # Every filter, as written.
    for line in re.findall(r"^\s*(?:where|and) (.+)$", before, flags=re.M):
        assert squash(line) in squash(after), f"discovery.sql's directory_models has lost: {line.strip()}"
    # Every sort, and its tie-break.
    for sort in re.findall(r"case when a\.sort = '([a-z]+)'", before):
        assert f"case when a.sort = '{sort}'" in after, f"discovery.sql's directory_models has lost the sort {sort}"
    assert "listed_at desc nulls last" in after and "id desc" in after


def test_the_small_shelf_is_the_size_filter_s_small() -> None:
    small = re.search(r"small: \{ most: (\d+),", DIRECTORY)
    assert small and int(small[1]) == 199
    share = (ROOT / "api/share.js").read_text()
    assert "most: SIZES.small.most, sort: \"top\"" in share


def test_parts_i_own_is_offered_only_with_a_collection() -> None:
    # Not among the sorts every visitor is offered and the CDN keeps.
    assert re.search(r'export const MINE_SORTS = \{ owned: "Parts I own" \};', DIRECTORY)
    sorts = re.search(r"export const SORTS = \{(.*?)\};", DIRECTORY, flags=re.S)
    assert sorts and "owned" not in sorts[1]
    body = function(SQL, "directory_models")
    assert "case when a.sort = 'owned'" in body
    assert "(not a.buildable or (k.pieces > 0 and coalesce(o.have, 0) >= k.pieces))" in body


def test_a_pool_is_read_only_for_the_one_asking() -> None:
    share = (ROOT / "api/share.js").read_text()
    # The pool asked is the verified session's own, never one a query names.
    assert "if (mine?.pool) asked.pool = mine.account;" in share
    # With the request since a9e5016f (2026-10-23): its method says whether
    # an orangecheck account's session is asked after for a read or a write.
    assert "claims = await verify(bearer(request), request);" in share
    assert not re.search(r"asked\.pool = [^m]", share)
    # And an answer with anybody's own shares in it is never kept by the CDN.
    assert 'said.tests || mine ? TESTS_CACHE : SHARED_CACHE' in share
    assert 'tests || mine ? TESTS_CACHE : SHARED_CACHE' in share


def test_nobody_reads_the_new_tables_directly() -> None:
    for table in ["gallery_picks", "model_needs", "model_needs_kept", "collection_pools", "collection_pools_kept"]:
        assert f"alter table public.{table} enable row level security;" in SQL
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role;" in SQL
    for granted in re.findall(r"grant (\w+) on (?:function )?public\.(\w+)", SQL):
        assert granted[0] == "execute", f"discovery.sql grants {granted[0]} on {granted[1]}"
