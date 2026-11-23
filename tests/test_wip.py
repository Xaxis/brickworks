"""Work in progress shared by version (docs/MASTERPLAN.md row 10, unit buildlog), held to what it promises.

supabase/wip.sql goes into the live project, so it may only add: columns, and functions that
replace the gallery's own with one rule more each. tools/wip_try.sql runs every query that ranks
or chooses with a WIP model in it, in a rolled-back dry run; src/dev/wip_probe.gd presses the
studio's Share progress; tools/web/wip_flow.mjs drives it end to end. Here, that the replaced
functions are their files' word for word but for the rule, and that what is said of a work in
progress (its posts in Talk, its feed rows, its cards in Talk) is what the versions say.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/wip.sql").read_text()


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def function(text: str, name: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def node(script: str) -> object:
    said = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                          capture_output=True, text=True, timeout=60)
    return json.loads(said.stdout.strip().splitlines()[-1])


def test_the_file_only_adds() -> None:
    body = code(SQL).lower()
    for word in (r"\bdrop\b", r"\brename\b", r"\btruncate\b", r"\bdelete from\b", r"alter column"):
        assert not re.search(word, body), word
    # Columns only added, each nullable or with a default.
    added = re.findall(r"alter table public\.(\w+) add column if not exists (\w+) ([^;]+);", SQL)
    assert sorted((table, column) for table, column, _ in added) == sorted([
        ("shared_models", "wip_at"), ("share_versions", "wip"), ("share_versions", "finished_at"),
        ("share_versions", "talk_post"), ("share_versions", "finished_post"), ("share_versions", "has_thumb")])
    for _, column, kind in added:
        assert "not null" not in kind or "default" in kind, column
    # Every function the server's alone.
    for name in re.findall(r"create or replace function public\.(\w+)\(", SQL):
        assert f"revoke all on function public.{name}(" in SQL, name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", SQL), name
        assert "security definer" in function(SQL, name), name


def test_each_replaced_function_is_its_files_but_for_the_one_rule() -> None:
    sources = {"gallery_shows": "discovery.sql", "directory_card": "modelled_by.sql",
               "gallery_models": "made_with.sql", "follow_rows": "collection_follows.sql"}
    later = (ROOT / "supabase/later.tsv").read_text().splitlines()
    for name, source in sources.items():
        mine = function(SQL, name)
        theirs = function((ROOT / "supabase" / source).read_text(), name)
        # The rows apply_sql.mjs guards with: the earlier file is not applied over this one.
        assert any(row.split("\t")[:3] == [source, name, "wip.sql"] for row in later), name
        mark = next(row.split("\t")[3] for row in later if row.split("\t")[:3] == [source, name, "wip.sql"])
        assert mark in mine and mark not in theirs, (name, mark)
        if name == "follow_rows":
            continue
        # Word for word, the one rule it adds taken out (a clause on a line
        # of theirs, or lines of its own).
        # Comments set aside: the rule's own say why it is there.
        plain = code(mine.replace(" and m.wip_at is null", ""))
        kept = [line for line in plain.splitlines() if "wip" not in line.lower()]
        assert [line for line in code(theirs).splitlines() if line.strip()] == [line for line in kept if line.strip()], name
        assert "wip" in mine.lower()


def test_a_wip_model_is_only_where_the_list_is_in_time_order() -> None:
    models = function(SQL, "gallery_models")
    assert "and (m.wip_at is null or (a.sort in ('newest', 'added') and not a.buildable))" in models
    assert "m.wip_at is null" in function(SQL, "gallery_shows")
    # The shelves and a page's More by and Like this ask the list that has the rule.
    share = (ROOT / "api/share.js").read_text()
    shelves = share[share.index("async function shelves("):share.index("async function seen(")]
    assert "directory_models" not in shelves and shelves.count("rankedRows(") == 2
    nexts = share[share.index("async function nextOf("):share.index("async function nextOf(") + 600]
    assert "rankedRows(" in nexts and "directory_models" not in nexts


def test_what_a_wip_post_says() -> None:
    if shutil.which("node") is None:
        return
    said = node(
        "const w = await import('./api/_wip.js');"
        "const v = await import('./api/_versions.js');"
        "const changes = { added: [{ part: '3001', colour: 4, count: 60 }], removed: [], added_count: 60, removed_count: 0,"
        "  added_in: [4, 5, 6], removed_from: [], steps_added: [], steps_removed: [], steps_changed: [4, 5, 6], first: 4,"
        "  compared: true, parts: 120, steps: 6 };"
        "const line = v.saidOf(2, changes);"
        "const base = { id: 'WipModel01', name: 'Harbour crane', origin: 'https://brickworks.diy' };"
        "console.log(JSON.stringify({ line,"
        "  first: w.postWords({ ...base, n: 1, kind: 'wip', first: true }),"
        "  later: w.postWords({ ...base, n: 2, note: 'The jib is on', said: line, kind: 'wip' }),"
        "  done: w.postWords({ ...base, n: 3, note: 'The hook', said: 'Version 3: 4 parts added.', kind: 'finished' }),"
        "  marked: w.postWords({ ...base, n: 3, kind: 'marked', said: 'not said' }),"
        "  short: w.threadTitle('AT'), long: w.threadTitle('x'.repeat(200)).length,"
        "  wip: [w.isWip([{ wip: true }]), w.isWip([{ wip: true, finished_at: '2026-11-23' }]), w.isWip([{ wip: false }]), w.isWip([])],"
        "  why: [w.refusedSaid('limit'), w.refusedSaid('no_profile')] }));")
    assert said["line"] == "Version 2: 60 parts added in steps 4–6."
    assert said["first"]["title"] == "Harbour crane"
    assert said["first"]["body"].splitlines() == [
        "Work in progress, version 1.", "Each new version will be posted in this thread as it is shared.",
        "https://brickworks.diy/m/WipModel01/v/1"]
    # The change line is the versions' own, word for word; the card is the version's.
    assert said["later"]["body"].splitlines() == [
        "Work in progress, version 2. The jib is on", said["line"], "https://brickworks.diy/m/WipModel01/v/2"]
    assert said["done"]["body"].splitlines() == [
        "Finished: version 3 is the finished model. The hook", "Version 3: 4 parts added.",
        "https://brickworks.diy/m/WipModel01/v/3"]
    assert said["marked"]["body"].splitlines() == [
        "Finished: version 3 is the finished model.", "https://brickworks.diy/m/WipModel01/v/3"]
    assert said["short"] == "The model AT" and said["long"] == 120
    assert said["wip"] == [True, False, False, False]
    assert "try again in an hour" in said["why"][0] and "profile" in said["why"][1]


def test_talk_draws_a_versions_link_as_that_versions_card() -> None:
    if shutil.which("node") is None:
        return
    said = node(
        "const t = await import('./api/_talk.js');"
        "const hosts = new Set(['brickworks.diy']);"
        "const embeds = t.embedsIn('Version 2 https://brickworks.diy/m/WipModel01/v/2 and the model https://brickworks.diy/m/WipModel01', hosts);"
        "const models = new Map([['WipModel01', { id: 'WipModel01', name: 'Harbour crane', author: 'Ada', has_thumb: true, updated_at: '2026-11-23T10:00:00Z' }]]);"
        "console.log(JSON.stringify({ embeds, html: t.embedsHtml(embeds, { models }) }));")
    assert [one.get("version") for one in said["embeds"]] == [2, None]
    assert 'src="/m/WipModel01/v/2.webp"' in said["html"] and 'href="/m/WipModel01/v/2"' in said["html"]
    assert "Version 2: open it" in said["html"] and 'href="/m/WipModel01"' in said["html"]


def test_the_feed_says_work_in_progress_and_the_finish() -> None:
    if shutil.which("node") is None:
        return
    said = node(
        "const f = await import('./api/_follows.js');"
        "const by = { handle: 'ada-builds', name: 'Ada' };"
        "const rows = [{ kind: 'model', model: 'WipModel01', name: 'Harbour crane', wip: true, by },"
        "  { kind: 'version', model: 'WipModel01', name: 'Harbour crane', version: 2, note: 'The jib', wip: true, by },"
        "  { kind: 'version', model: 'WipModel01', name: 'Harbour crane', version: 3, note: 'The hook', wip: false, finished: true, by },"
        "  { kind: 'version', model: 'WipModel01', name: 'Harbour crane', version: 3, note: 'The hook', wip: true, finished: true, later: true, by },"
        "  { kind: 'version', model: 'Other00001', name: 'Barn', version: 2, note: null, by }];"
        "console.log(JSON.stringify(rows.map((r) => f.feedSaid(r, 'https://brickworks.diy'))));")
    lines = [one["line"] for one in said]
    assert lines == ["{who} shared work in progress: {name}", "{who} shared progress on {name}: version 2",
                     "{who} finished {name}: version 3 is the finished one", "{who} finished {name}: version 3 is the finished one",
                     "{who} shared version 2 of {name}"]
    assert said[1]["said"] == "The jib" and said[1]["link"].endswith("/m/WipModel01/v/2")
    assert said[2]["said"] == "The hook" and said[3]["said"] == ""


def test_the_studio_shares_progress_in_one_press_from_the_panel() -> None:
    panel = (ROOT / "src/ui/share_panel.gd").read_text()
    assert '_progress.text = "Share progress"' in panel and '"share_progress": _progress' in panel
    assert 'body["wip"] = as_wip' in panel and '"Publish as finished" if up and wip' in panel
    # Pressed, it lists and credits the model: in the gallery and by name, so followers see it.
    start = panel.index("func publish(as_wip: bool = false)")
    head = panel[start:panel.index("state = \"publishing\"", start)]
    assert "_list.button_pressed = true" in head and "_credit.button_pressed = true" in head


def test_a_work_in_progress_is_only_shown_by_name() -> None:
    """Its feed rows and Talk posts carry its designer's name, so a link-only
    model, or one they chose not to credit, is refused before anything is
    written, and a finish of one that is no longer listed is not posted."""
    share = (ROOT / "api/share.js").read_text()
    publish = share[share.index("async function publish("):]
    refusal = publish.index("if (wip && !(listed && author))")
    assert refusal < publish.index("await putFile(") and refusal < publish.index('db("shared_models"')
    assert "if (wipHere && (wip || (finished && listed && author)))" in publish
    finish = (ROOT / "api/_wip.js").read_text()
    assert "const shown = model && model.listed === true && Boolean(model.author);" in finish
