"""The gallery's tabs held to one set of words and to what came before.

supabase/gallery_tabs.sql makes gallery_models, play.sql's directory_models
with three words more (days, following, made), and replaces directory_card,
motions.sql's with the comments. Each is defined again in full, so a filter,
a sort or a key left out in the copy would be lost the day the file is
applied, with nothing failing. These read the files and hold them together:
what the copy keeps, that the page, the API and the SQL name the same
assistant tags, windows and ways a model was made, and that the new list is
the server's alone. What the SQL does with them is proven by
tools/gallery_tabs_try.sql in a rolled-back dry run, and that the gallery
answers as before by tools/sql_compare.mjs.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/gallery_tabs.sql").read_text()
PLAY = (ROOT / "supabase/play.sql").read_text()
MOTIONS = (ROOT / "supabase/motions.sql").read_text()
CARD = (ROOT / "web/card.js").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
SHARE = (ROOT / "api/share.js").read_text()
STAND_IN = (ROOT / "tools/web/design_stand_in.mjs").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()


def function(text: str, name: str) -> str:
    """The body of public.[name] as [text] defines it, its last definition."""
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name} in the file"
    return found[-1]


def squash(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def test_gallery_models_keeps_every_filter_and_sort_of_directory_models() -> None:
    before = function(PLAY, "directory_models")
    after = function(SQL, "gallery_models")
    asked = set(re.findall(r"\(?query->>'([a-z_]+)'", before))
    assert len(asked) >= 17
    for key in asked:
        assert f"query->>'{key}'" in after, f"gallery_models does not read {key}"
    for line in re.findall(r"^\s*(?:where|and) (.+)$", before, flags=re.M):
        assert squash(line) in squash(after), f"gallery_models has lost: {line.strip()}"
    for sort in re.findall(r"case when a\.sort = '([a-z]+)'", before):
        assert f"case when a.sort = '{sort}'" in after, f"gallery_models has lost the sort {sort}"
    # Its order, every key and tie-break, as directory_models orders.
    orders = re.findall(r"order by (.+?)(?=\n\s*(?:limit\b|$))", before, flags=re.S)
    assert len(orders) == 2
    for order in orders:
        assert squash(order) in squash(after), f"gallery_models orders otherwise: {squash(order)[:80]}"


def test_gallery_models_reads_its_three_new_words() -> None:
    body = function(SQL, "gallery_models")
    for key in ("days", "following", "made"):
        assert f"query->>'{key}'" in body
    # Top over a time counts what happened in it, as the week's pick does.
    assert "b.at > now() - make_interval(days => a.days)" in body
    assert "r.listed_at > now() - make_interval(days => a.days) and public.gallery_shows(r, a.tests)" in body
    # Following: only people who may be followed, and only credited models.
    assert "public.follow_may_be_followed(f.followed)" in body
    assert "m.author is not null and m.owner in (select w.account from followed w)" in body


def test_directory_card_keeps_every_key_of_motions_sql_and_adds_comments() -> None:
    before = function(MOTIONS, "directory_card")
    after = function(SQL, "directory_card")
    keys = re.findall(r"'([a-z_]+)', ", before)
    assert len(keys) >= 20
    for key in keys:
        assert f"'{key}', " in after, f"directory_card has lost {key}"
    assert "'comments', (select count(*) from public.model_comments k" in after
    # What a visitor may read on its page, comments_on's rule.
    for rule in ("k.removed_at is null", "k.hidden_at is null", "public.shown_publicly(k.author)",
                 "select min(v.at) from public.share_versions v where v.model = m.id"):
        assert rule in after


def test_the_card_the_api_and_the_sql_name_the_same_assistant_tags() -> None:
    tags = re.search(r"export const ASSISTANT_TAGS = \[(.*?)\];", CARD)
    assert tags
    in_js = sorted(re.findall(r'"([a-z-]+)"', tags[1]))
    assert in_js == ["ai-designed", "brickify"]
    in_sql = re.findall(r"array\[([^\]]*)\]::text\[\]", function(SQL, "gallery_models"))
    made = [sorted(re.findall(r"'([a-z-]+)'", one)) for one in in_sql if "ai-designed" in one]
    assert made and all(one == in_js for one in made)
    # The API reads the card's own list, never a copy.
    assert 'import { ASSISTANT_TAGS, MADE_WITH } from "./_card.js";' in DIRECTORY


def test_made_and_windows_are_the_same_words_in_the_api_the_sql_and_the_stand_in() -> None:
    mades = re.search(r"export const MADES = \{ hand: \"Hand-built\", assistant: \"With the assistant\" \};", DIRECTORY)
    assert mades
    body = function(SQL, "gallery_models")
    assert "a.made = 'assistant'" in body and "a.made = 'hand'" in body
    windows = re.search(r"export const WINDOWS = \{ week: \{ days: (\d+),.*?month: \{ days: (\d+),", DIRECTORY)
    assert windows and (int(windows[1]), int(windows[2])) == (7, 30)
    # The SQL takes any span up to a year.
    assert "least(greatest((query->>'days')::integer, 1), 366)" in body
    assert 'const WINDOWS = { week: { days: 7, label: "This week" }, month: { days: 30, label: "This month" } };' in STAND_IN


def test_following_is_the_asker_s_own() -> None:
    # Whom somebody follows is read only for their own list, asked with
    # their verified sign-in, and the answer is never kept by the CDN.
    assert "if (asked.following) asked.following = mine.account;" in SHARE
    assert not re.search(r"asked\.following = [^m]", SHARE)
    assert 'signedIn: Boolean(mine)' in SHARE
    assert "said.tests || mine ? TESTS_CACHE : SHARED_CACHE" in SHARE


def test_before_the_file_the_list_answers_as_before() -> None:
    # A database without gallery_models: directory_models, and the new words
    # refused in words (400), never a 500.
    assert 'db("rpc/gallery_models"' in SHARE
    assert "if (!/: 404$/.test(String(trouble?.message || \"\"))) throw trouble;" in SHARE
    assert 'rows = await db("rpc/directory_models", { method: "POST", body: { query: asked } });' in SHARE


def test_the_new_functions_are_the_server_s_alone() -> None:
    for name, args in (("gallery_models", "jsonb"), ("directory_card", "public.shared_models")):
        assert f"revoke all on function public.{name}({args}) from public, anon, authenticated;" in SQL
        assert f"grant execute on function public.{name}({args}) to service_role;" in SQL
    assert not re.search(r"\b(drop|alter table|create table)\b", re.sub(r"--.*", "", SQL), flags=re.I)


def test_the_gallery_flow_runs_before_a_release() -> None:
    assert re.search(r'\[gallery\]="tools/web/gallery_flow\.mjs --url=\$P ', CHECKS)
    order = re.search(r'^ORDER="(.*)"$', CHECKS, flags=re.M)
    assert order and "gallery" in order[1].split()
