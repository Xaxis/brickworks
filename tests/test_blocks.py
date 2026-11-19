"""Blocking a person (docs/SOCIAL.md section 9), held to what it promises.

supabase/block.sql keeps who blocked whom where no client reads it, and its
triggers refuse a follow or a comment across a block whatever writes it;
tools/block_try.sql proves its answers in a rolled-back dry run on the live
project, and tools/web/block_flow.mjs the whole of it with three accounts.
Here: the pure functions every path shares, the words, and the promises in
the files themselves (additive, row security, never told).
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/block.sql").read_text()
BLOCKS = (ROOT / "api/_blocks.js").read_text()


def node(script: str):
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True, capture_output=True, text=True,
                          timeout=120)
    return json.loads(done.stdout)


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_a_thread_goes_with_its_hidden_comment_and_nothing_else_does() -> None:
    comments = [{"id": 1, "parent": None}, {"id": 2, "parent": 1}, {"id": 3, "parent": None}, {"id": 4, "parent": 3},
                {"id": 5, "parent": 3}]
    said = node(f"""
import {{ commentsShown }} from "./api/_blocks.js";
const all = {json.dumps(comments)};
console.log(JSON.stringify({{ none: commentsShown(all, new Set()).map((c) => c.id),
  first: commentsShown(all, new Set([1])).map((c) => c.id),
  reply: commentsShown(all, new Set([4])).map((c) => c.id) }}));
""")
    assert said["none"] == [1, 2, 3, 4, 5]
    # Comment 1 hidden: its reply 2 with it; the other thread whole.
    assert said["first"] == [3, 4, 5]
    # A reply hidden alone: its comment and the other reply stay.
    assert said["reply"] == [1, 2, 3, 5]


def test_rows_and_cards_leave_by_their_writer_or_their_model() -> None:
    said = node("""
import { rowsWithout, withoutBlocked } from "./api/_blocks.js";
const rows = [{ by: { handle: "bob" }, model: "AAAAAAAAAA" }, { by: { handle: "cy" }, model: "BBBBBBBBBB" },
  { by: { handle: "cy" }, model: "CCCCCCCCCC" }, { by: null, model: "" }];
const cards = [{ id: "AAAAAAAAAA", by: { handle: "bob" } }, { id: "BBBBBBBBBB", by: { handle: "cy" } },
  { id: "CCCCCCCCCC", by: { handle: "cy" } }, null];
console.log(JSON.stringify({
  rows: rowsWithout(rows, new Set(["bob"]), new Set(["CCCCCCCCCC"])).map((r) => r.model),
  none: rowsWithout(rows, new Set()).length,
  cards: withoutBlocked(cards, new Set(["CCCCCCCCCC"]), new Set(["bob"])).map((c) => c.id) }));
""")
    assert said["rows"] == ["BBBBBBBBBB", ""]
    assert said["none"] == 4
    assert said["cards"] == ["BBBBBBBBBB"]


def test_the_one_who_blocked_is_told_why_and_the_one_blocked_only_that_it_cannot() -> None:
    said = node("""
import { refuseFor, WORDS } from "./api/_blocks.js";
const asked = (state, kind) => { try { refuseFor(state, kind); return null; } catch (e) { return [e.status, e.message]; } };
const kinds = ["follow", "comment", "reply", "photo", "list", "like", "remix", "collect"];
console.log(JSON.stringify({ kinds: kinds.map((kind) =>
  [kind, asked("blocked", kind), asked("blocked_by", kind), asked(null, kind)]), words: WORDS }));
""")
    assert len(said["kinds"]) == 8
    for kind, blocked, blocked_by, neither in said["kinds"]:
        assert blocked[0] == 409 and "You blocked" in blocked[1] and "Settings › Blocked people" in blocked[1], kind
        # Neutral: no word of a block, a 403 like any other refusal; a
        # publish's 409, as its other refusals, since the app answers a 403
        # there by publishing again at a new link.
        assert blocked_by[0] == (409 if kind == "remix" else 403), kind
        assert not re.search(r"block", blocked_by[1], re.I) and blocked_by[1].startswith("You can’t "), kind
        assert neither is None
    words = said["words"]
    assert words["yourself"][0] == 409 and words["nobody"] == [404, "Nobody here has that handle."]


def test_a_handle_is_checked_at_the_edge() -> None:
    said = node("""
import { handleOf } from "./api/_blocks.js";
console.log(JSON.stringify(["Bob-Try", " bob ", "b", "bo--b", "-bob", "bob!", null, 12, "a".repeat(25), "\\u200bbob\\u00a0", "\\ufeffBob"].map(handleOf)));
""")
    assert said == ["bob-try", "bob", "", "", "", "", "", "", "", "bob", "bob"]


def test_a_follows_answer_says_a_block_only_to_whoever_made_it() -> None:
    blocks = (ROOT / "api/_follows.js").read_text()
    said = node(f"""
{re.search(r"function blockSaid\(said, block\) \{.*?\n\}", blocks, re.S).group(0)}
const WORDS_SAID = "You blocked them.";
console.log(JSON.stringify([blockSaid({{ you_follow: true, may: true }}, "blocked"),
  blockSaid({{ you_follow: false, may: true }}, "blocked_by"), blockSaid({{ you_follow: true, may: true }}, null)]));
""".replace("BLOCK_WORDS.you_follow[1]", "WORDS_SAID"))
    assert said[0] == {"you_follow": False, "may": False, "you_block": True, "why_not": "You blocked them."}
    # The person blocked: as if nobody had, may: true; the press is refused in neutral words.
    assert said[1] == {"you_follow": False, "may": True, "you_block": False}
    assert said[2] == {"you_follow": True, "may": True, "you_block": False}


def test_block_sql_is_additive_with_row_security_and_no_client_role() -> None:
    sql = code(SQL)
    assert not re.search(r"\b(alter|drop)\s+(table|function|policy|trigger|view)\b", sql, re.I) or \
        all(m.group(0).lower().startswith("alter table public.blocks") for m in re.finditer(r"\balter\s+table\s+\S+", sql, re.I))
    assert "create table if not exists public.blocks" in sql
    assert "alter table public.blocks enable row level security" in sql
    assert re.search(r"revoke all on public\.blocks from public, anon, authenticated, service_role", sql)
    functions = set(re.findall(r"create or replace function public\.(\w+)\(", sql))
    assert {"block_person", "block_list", "block_between", "block_on", "block_hidden", "block_models", "block_named",
            "block_counts", "block_count_against", "block_row_barred", "blocks_guard_follow", "blocks_guard_comment",
            "blocks_guard_collection_follow", "blocks_guard_photo", "blocks_guard_like", "blocks_guard_remix",
            "blocks_guard_collect"} <= functions
    for name in functions:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", sql), name
        assert "security definer" in sql
    # Nothing it creates is a client's: every grant goes to the server's role alone.
    assert set(re.findall(r"grant execute on function public\.\w+\([^)]*\) to (\w+);", sql)) == {"service_role"}
    # A trigger on each table a block refuses a write to.
    for table in ("follows", "collection_follows", "model_comments", "build_photos", "model_likes", "shared_models",
                  "model_collection_items"):
        assert re.search(rf"create or replace trigger \w+\s+before insert(?: or update(?: of \w+)?)? on public\.{table}\b", sql), \
            table
    # A remix link a model already had stays: only a new one is refused.
    remix = re.search(r"function public\.blocks_guard_remix\(\).*?\$\$;", sql, re.S).group(0)
    assert "new.remixed_from is not distinct from old.remixed_from" in remix
    # A list filled many at once keeps the rest: the row is left out, not refused.
    collect = re.search(r"function public\.blocks_guard_collect\(\).*?\$\$;", sql, re.S).group(0)
    assert "return null;" in collect and "raise" not in collect


def test_nobody_is_told_of_a_block() -> None:
    # Nothing in block.sql writes a notification, a mail or a feed row.
    assert not re.search(r"insert into public\.(notification|follow_rows|comment_digests|mail)", code(SQL))
    # The admin export leaves out who blocked the account, even the count.
    console = (ROOT / "api/_console_people.js").read_text()
    assert 'delete tables["blocks.blocked"];' in console and 'delete more["blocks.blocked"];' in console
    # The answers: who blocked whom is the caller's own list alone.
    assert 'response.setHeader("Cache-Control", "private, no-store")' in BLOCKS


def test_every_new_word_has_its_three_languages() -> None:
    words = [w for w in re.findall(r'"((?:[^"\\]|\\.)*[A-Z](?:[^"\\]|\\.)*)"\]', BLOCKS)]
    page = (ROOT / "web/block.js").read_text()
    # A sentence written over lines is its literals joined.
    for said in re.findall(r'say\(((?:"(?:[^"\\]|\\.)*"\s*\+\s*)*"(?:[^"\\]|\\.)*")', page):
        words.append("".join(re.findall(r'"((?:[^"\\]|\\.)*)"', said)))
    assert len(words) >= 15
    for lang in ("de", "fr", "es"):
        table = json.loads((ROOT / f"web/_lang/{lang}.json").read_text())["scripts"]
        missing = [w for w in words if w not in table and not w.startswith("say ")]
        assert not missing, (lang, missing)


def test_a_blocked_persons_work_leaves_the_model_page_and_the_latest() -> None:
    share = (ROOT / "api/share.js").read_text()
    page = re.search(r"async function leaveOffBlocked\(.*?\n\}", share, re.S).group(0)
    # The owner's blocks, as the page is everybody's; their counts with them.
    assert "blockedHandles(own.owner)" in page and "page.remixes = " in page and "lists.count = " in page
    # A new remix link refused before any file is written.
    publish = share[share.index("const parent = await remixOf(body.remixed_from, id);"):]
    assert publish.index('refuseFor(await standingBetween(owner, parent.owner), "remix")') < publish.index("putFile(")
    follows = (ROOT / "api/_follows.js").read_text()
    latest = re.search(r"export async function latest\(.*?\n\}", follows, re.S).group(0)
    assert '"private, no-store"' in latest and "withoutBlocked(" in latest and "rowsWithout(photos" in latest
    # Its two pages ask as the person, at a URL of its own the CDN keeps for nobody.
    for page in ("web/feed.js", "web/first-steps.js"):
        assert "/api/people?op=latest&mine=1" in (ROOT / page).read_text(), page
    # The connector's search and reads, and the app's Library, ask with the session.
    tool = (ROOT / "src/net/gallery_tool.gd").read_text()
    assert 'var token: String = await _token()\n\tif sort == "owned"' in tool
    assert '"/api/people?op=comments&id=" + id, 256 * 1024, token)' in tool
    assert '"/api/people?op=photos&id=" + id, 64 * 1024, token)' in tool
    library = (ROOT / "src/ui/library_dialog.gd").read_text()
    assert 'query.append("mine=1")' in library and "512 * 1024, null, headers)" in library
