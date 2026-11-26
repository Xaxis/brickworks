"""Your own work in your own feed (feedself, 2026-11-26), held to what it promises.

supabase/feed_self.sql adds own_rows and own_page; api/_follows.js puts own_page's page beside
follow_page's in time order (withOwn), says each of your own rows "You ..." (feedSaid), and never
marks one New (isNew). tools/feed_self_try.sql runs the functions on made-up accounts in a
rolled-back dry run; tools/web/feed_flow.mjs drives the page. Here: that the file only adds and
reads only the viewer's own, and that the server's pure parts say and order what they should.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/feed_self.sql").read_text()


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def node(script: str) -> object:
    said = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                          capture_output=True, text=True, timeout=60)
    return json.loads(said.stdout.strip().splitlines()[-1])


def test_the_file_only_adds_two_functions_for_the_server() -> None:
    body = code(SQL).lower()
    for word in (r"\bdrop\b", r"\brename\b", r"\btruncate\b", r"\bdelete from\b", r"\balter\b", r"\binsert\b",
                 r"\bupdate\b"):
        assert not re.search(word, body), word
    made = re.findall(r"create or replace function public\.(\w+)\(", body)
    assert made == ["own_rows", "own_page"]
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", body)
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", body)


def test_every_row_is_the_viewers_own_and_in_the_gallery() -> None:
    body = code(SQL)
    rows = body[body.index("function public.own_rows("):body.index("function public.own_page(")]
    parts = rows.split("union all")
    assert len(parts) == 5
    for part in parts:
        # Whose: the viewer's own, by the column that says whose it is.
        assert re.search(r"\b(m\.owner|b\.account|e\.owner) = viewer\b", part), part
        # Up: published and not taken out; a model in the gallery, but a photo of one's own model.
        assert "m.published" in part and "not m.barred" in part, part
        assert "m.listed" in part, part
        assert "'mine', true" in part, part
    photo = next(part for part in parts if "build_photos" in part)
    assert "b.removed_at is null" in photo and "b.hidden_at is null" in photo


def test_the_server_says_your_own_rows_as_yours_and_never_new() -> None:
    if shutil.which("node") is None:
        return
    said = node(
        "const f = await import('./api/_follows.js');"
        "const by = { handle: 'nia-builds', name: 'Nia' };"
        "const rows = [{ kind: 'model', model: 'Mine000001', name: 'Castle', credited: true, mine: true, by },"
        "  { kind: 'model', model: 'Mine000002', name: 'Boat', credited: false, mine: true, by },"
        "  { kind: 'version', model: 'Mine000001', name: 'Castle', version: 2, note: 'Taller', mine: true, by },"
        "  { kind: 'photo', photo: 'Photo00001', model: 'Robin00001', name: 'Mill', words: 'Mine', yours: false, mine: true, by },"
        "  { kind: 'challenge', model: 'Mine000001', name: 'Castle', title: 'Castles', way: 'hand', mine: true, by },"
        "  { kind: 'model', model: 'Robin00001', name: 'Mill', by: { handle: 'robin', name: 'Robin' } }];"
        "const at = '2026-11-26T10:00:00.000001+00:00';"
        "console.log(JSON.stringify({ said: rows.map((r) => f.feedSaid(r, 'https://brickworks.diy')),"
        "  isNew: rows.map((r) => f.isNew({ ...r, at }, null, null)) }));")
    lines = [one["line"] for one in said["said"]]
    assert lines == ["You shared a new model {name}",
                     "You listed {name} without your name: it is not on your profile or in your followers’ feeds",
                     "You shared version 2 of {name}", "You posted a photo of your build of {name}",
                     "You entered {name} in the challenge {title}, built by hand",
                     "{who} shared a new model {name}"]
    assert [one.get("mine") for one in said["said"]] == [True] * 5 + [None]
    assert said["said"][2]["said"] == "Taller" and said["said"][2]["link"].endswith("/m/Mine000001/v/2")
    # Never New, whenever the feed was last opened; somebody else's row, never opened, is.
    assert said["isNew"] == [False] * 5 + [True]


def test_the_two_pages_go_together_in_time_order() -> None:
    if shutil.which("node") is None:
        return
    said = node(
        "const f = await import('./api/_follows.js');"
        "const row = (name, at, mine) => ({ name, at, ...(mine ? { mine: true } : {}) });"
        "const theirs = { rows: [row('t1', '2026-11-26T10:00:00.000300+00:00'), row('t2', '2026-11-26T08:00:00+00:00'),"
        "  row('t3', '2026-11-25T08:00:00+00:00')], more: true };"
        "const own = { rows: [row('o1', '2026-11-26T10:00:00.000301+00:00', 1), row('o2', '2026-11-26T09:00:00+00:00', 1)], more: false };"
        "const page = f.withOwn(theirs, own, 3);"
        "const alone = f.withOwn({ rows: [row('t1', '2026-11-26T10:00:00+00:00')], more: false }, null, 3);"
        "const last = f.withOwn({ rows: [], more: false }, own, 3);"
        "console.log(JSON.stringify({ page: page.rows.map((r) => r.name), more: page.more,"
        "  alone: [alone.rows.map((r) => r.name), alone.more], last: [last.rows.map((r) => r.name), last.more] }));")
    # A microsecond apart is apart: o1 is the newer.
    assert said["page"] == ["o1", "t1", "o2"] and said["more"] is True
    assert said["alone"] == [["t1"], False]
    assert said["last"] == [["o1", "o2"], False]


def test_the_studio_says_where_a_nameless_listing_is_not() -> None:
    panel = (ROOT / "src/ui/share_panel.gd").read_text()
    words = "Listed without your name, it will not be on your profile or in your followers' feeds."
    assert words in panel
    assert "_unnamed.visible = _list.button_pressed and not _list.disabled and not _credit.button_pressed" in panel
    for code_ in ("de", "fr", "es"):
        po = (ROOT / f"locale/{code_}.po").read_text()
        assert f'msgid "{words}"\nmsgstr "' in po and f'msgid "{words}"\nmsgstr ""' not in po, code_
