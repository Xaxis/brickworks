"""Who laid a model's parts, said by the app as it publishes, held to one
set of words and to what came before (docs/SOCIAL.md D7, U16).

supabase/made_with.sql adds shared_models.made_with and defines again in
full replies.sql's directory_card and gallery_tabs.sql's gallery_models, so
a key or a filter left out of the copy would be lost the day the file is
applied, with nothing failing. These read the files and hold them together:
the copies keep everything, the ways a model is made are the same words in
the app, the card, the server and the SQL, and the column is the server's
alone. What the SQL does is proven by tools/made_with_try.sql in a
rolled-back dry run, and that the gallery answers as before by
tools/sql_compare.mjs.
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

SQL = (ROOT / "supabase/made_with.sql").read_text()
REPLIES = (ROOT / "supabase/replies.sql").read_text()
TABS = (ROOT / "supabase/gallery_tabs.sql").read_text()
CARD = (ROOT / "web/card.js").read_text()
SHARE = (ROOT / "api/share.js").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
STORE = (ROOT / "src/parts/model_store.gd").read_text()
PANEL = (ROOT / "src/ui/share_panel.gd").read_text()
APPLY = _guards()


def function(text: str, name: str) -> str:
    """The body of public.[name] as [text] defines it, its last definition."""
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name} in the file"
    return found[-1]


def squash(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"--[^\n]*", "", text)).strip()


def test_directory_card_keeps_every_key_of_replies_sql_and_adds_made_with() -> None:
    before = function(REPLIES, "directory_card")
    after = function(SQL, "directory_card")
    keys = re.findall(r"'([a-z_]+)', ", before)
    assert len(keys) >= 20
    for key in keys:
        assert f"'{key}', " in after, f"directory_card has lost {key}"
    assert "'made_with', m.made_with," in after
    # Nothing else differs.
    assert squash(after).replace("'made_with', m.made_with, ", "") == squash(before)


def test_gallery_models_is_gallery_tabs_sql_s_but_for_the_made_filter() -> None:
    before = squash(function(TABS, "gallery_models"))
    after = squash(function(SQL, "gallery_models"))
    made = r"and \(a\.made is null or .*?\)\)\)? order by"
    assert re.search(made, before) and re.search(made, after)
    assert re.sub(made, "", before) == re.sub(made, "", after, count=1)
    # The app first; the tags only where it said nothing.
    assert "(a.made = 'assistant' and (m.made_with in ('assistant', 'brickify') or (m.made_with is null and " \
        "m.tags && array['ai-designed', 'brickify']::text[])))" in after
    assert "(a.made = 'hand' and (m.made_with = 'hand' or (m.made_with is null and " \
        "not (m.tags && array['ai-designed', 'brickify']::text[]))))" in after


def test_the_ways_are_the_same_words_in_the_app_the_card_the_server_and_the_sql() -> None:
    sql = re.search(r"check \(made_with in \(([^)]*)\)\)", SQL)
    assert sql
    in_sql = sorted(re.findall(r"'([a-z]+)'", sql[1]))
    card = re.search(r"export const MADE_WITH = \[(.*?)\];", CARD)
    assert card and sorted(re.findall(r'"([a-z]+)"', card[1])) == in_sql
    app = re.search(r"const MADE_WAYS: Array\[String\] = \[(.*?)\]", STORE)
    assert app and sorted(re.findall(r'"([a-z]+)"', app[1])) == in_sql
    # The server checks what it is sent against the card's list, and cards
    # are given it from the same list.
    assert 'import { MADE_WITH, cardHtml } from "./_card.js";' in SHARE
    assert "if (!MADE_WITH.includes(given))" in SHARE
    assert "made_with: MADE_WITH.includes(row.made_with) ? row.made_with : null," in DIRECTORY
    # The app sends it only when it knows.
    assert 'if store.made_with in ModelStore.MADE_WAYS:\n\t\tbody["made_with"] = store.made_with' in PANEL


def test_the_column_is_the_server_s_alone() -> None:
    # No grant on the table or the column; the functions the service role's.
    for grant in re.findall(r"^grant [^;]*;", SQL, flags=re.M):
        assert grant.startswith("grant execute on function public.") and grant.endswith("to service_role;"), grant
    assert re.search(r"revoke select \(made_with\), insert \(made_with\), update \(made_with\), "
                     r"references \(made_with\)\s+on public\.shared_models from public, anon, authenticated;", SQL)
    for name in ("directory_card(public.shared_models)", "gallery_models(jsonb)"):
        assert f"revoke all on function public.{name} from public, anon, authenticated;" in SQL
    # Additive: nothing dropped, no row changed.
    assert not re.search(r"\b(drop|delete from|truncate)\b", SQL, flags=re.I)
    assert not re.search(r"^\s*update\s", SQL, flags=re.M | re.I)


def test_a_database_without_the_column_publishes_as_before() -> None:
    # Kept by a PATCH of its own that never stops the publish, and never
    # read where a select names columns: before the file there is no column.
    keep = re.search(r"async function keepMadeWith\(id, owner, madeWith\) \{(.*?)\n\}", SHARE, flags=re.S)
    assert keep and "try {" in keep[1] and "} catch {\n    return null;" in keep[1]
    assert "made_with" not in re.search(r'const PUBLIC = "([^;]*);', SHARE)[1]
    for select in re.findall(r"select=([a-z_,]+)", SHARE):
        assert "made_with" not in select


def test_applying_an_earlier_file_alone_is_refused() -> None:
    assert '["replies.sql", "directory_card", "made_with.sql", "\'made_with\', m.made_with"],' in APPLY
    assert '["gallery_tabs.sql", "gallery_models", "made_with.sql", "m.made_with in (\'assistant\', \'brickify\')"],' in APPLY
    assert "'made_with', m.made_with" in function(SQL, "directory_card")
    assert "m.made_with in ('assistant', 'brickify')" in function(SQL, "gallery_models")
    for earlier in (REPLIES, TABS):
        assert "REPLACED LATER: made_with.sql replaces this function" in earlier
