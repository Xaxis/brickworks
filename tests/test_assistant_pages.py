"""The site and the docs say what assets/assistants.json says, the table the
app's Connect your AI reads (docs/ANY_ASSISTANT.md, U4).

Each AI app has its docs page, /docs/connect-<id>, made from one template
and its row at every deploy (tools/docs_site.py); the cards on /docs/connect
and in the FAQ come from the same rows (tools/assistants.py); and no page
of the site or the docs gives a way of adding Brickworks to an app that its
row does not make: a command, an install link, or the app's own page for
adding a server. When two places disagreed, a person following the site
got another answer than the app's (the FAQ offered Claude alone; the docs
told ChatGPT's steps their own way).
"""

from __future__ import annotations

import html
import importlib.util
import json
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

_spec = importlib.util.spec_from_file_location("docs_site", ROOT / "tools/docs_site.py")
docs_site = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(docs_site)
assistants = docs_site.assistants  # tools/assistants.py, as the docs read it

ROWS = assistants.rows()
HEADINGS = ["before", "add", "sign-in", "build", "trouble"]
# What docs-site/_connect.md says for each way, and for no other.
WAY_WORDS = {"link": "Or press this link yourself", "command": "It copies this command",
             "open": "opens {name}'s own page", "copy": "for any app that takes a remote MCP server. Or copy it here"}


def build(out: Path) -> Path:
    docs_site.build(out)
    return out / "docs"


def test_every_assistant_has_its_page_with_its_way(tmp_path: Path) -> None:
    built = build(tmp_path)
    for row in ROWS:
        page = built / f"{assistants.page_name(row)}.html"
        assert page.exists(), f"no /docs/{assistants.page_name(row)} for {row['name']}"
        text = page.read_text(encoding="utf-8")
        ids = re.findall(r'<h2 id="([a-z-]+)"', text)
        assert ids == HEADINGS, (row["id"], ids)
        assert html.escape(row["plan"], quote=False) in text, row["id"]
        assert docs_site.checked_day(row["checked"]) in text, row["id"]
        made = assistants.adding(row)
        if row["way"] == "link":
            assert f'href="{html.escape(made)}"' in text, (row["id"], made)
        elif row["way"] == "command":
            assert f"<code>{html.escape(made, quote=False)}</code>" in text, (row["id"], made)
        elif row["way"] == "open":
            assert f'href="{html.escape(made)}"' in text and f"<code>{assistants.ADDRESS}</code>" in text, row["id"]
        else:
            assert f"<code>{assistants.ADDRESS}</code>" in text, row["id"]
        for step in row["steps"]:
            assert f"<li>{docs_site.inline(step)}</li>" in text, (row["id"], step)
        # Its way's words are on its page, and no other way's.
        for way, words in WAY_WORDS.items():
            assert ((words.format(name=row["name"]) in text) == (way == row["way"])), (row["id"], way)


def test_the_cards_and_the_sidebar_list_every_one_in_the_tables_order(tmp_path: Path) -> None:
    built = build(tmp_path)
    hub = (built / "connect.html").read_text(encoding="utf-8")
    cards = re.findall(r'<ul class="docs-cards">(.*?)</ul>', hub, re.S)
    linked = [m for chunk in cards for m in re.findall(r'href="/docs/(connect-[a-z-]+)"', chunk)]
    assert linked == [assistants.page_name(row) for row in ROWS]
    side = re.search(r'<nav class="docs-side".*?</nav>', hub, re.S).group(0)
    listed = re.findall(r'href="/docs/(connect-[a-z-]+)"', side)
    assert listed == [assistants.page_name(row) for row in ROWS]
    # The old address is Claude's own page still.
    assert (built / "connect-claude.html").exists()


def test_the_faqs_cards_are_the_tables() -> None:
    faq = (ROOT / "web/faq.html").read_text(encoding="utf-8")
    assert assistants.with_cards(faq) == faq, "web/faq.html's cards are not the table's: tools/docs_site.py --write"
    block = assistants.FAQ_BLOCK.search(faq).group(0)
    for row in ROWS:
        assert f'href="/docs/{assistants.page_name(row)}"' in block, row["id"]
        assert html.escape(row["plan"], quote=False) in block, row["id"]


def test_no_page_says_a_way_the_table_does_not() -> None:
    _, pages = docs_site.load()
    problems = docs_site.way_problems(pages)
    assert not problems, "\n".join(problems)


@pytest.mark.parametrize("said", [
    # Claude Code's command without its transport, as an old page might say it.
    "Run `claude mcp add brickworks https://brickworks.diy/api/mcp` in a terminal.",
    '<code class="cmd">codex mcp add bw --url https://brickworks.diy/api/mcp</code>',
    "gemini mcp add brickworks https://brickworks.diy/api/mcp",
    # Claude's form with another name, and ChatGPT's page somewhere else.
    '<a href="https://claude.ai/customize/connectors?modal=add-custom-connector&amp;connectorName=brickworks'
    '&amp;connectorUrl=https%3A%2F%2Fbrickworks.diy%2Fapi%2Fmcp">Add</a>',
    "Open [chatgpt.com/plugins](https://chatgpt.com/plugins/new) and press +.",
    # An install link no row makes.
    "cursor://anysphere.cursor-deeplink/mcp/install?name=brickworks&config=e30%3D",
    "vscode:mcp/install?%7B%22url%22%3A%22https%3A%2F%2Fbrickworks.diy%2Fapi%2Fmcp%22%7D",
])
def test_a_way_the_table_does_not_make_is_caught(said: str) -> None:
    assert assistants.ways(said), said


@pytest.mark.parametrize("said", [
    "claude mcp add --transport http brickworks https://brickworks.diy/api/mcp",
    "codex mcp add brickworks --url https://brickworks.diy/api/mcp && codex mcp login brickworks",
    "codex mcp add brickworks --url https://brickworks.diy/api/mcp",
    "Open your connectors at https://claude.ai/customize/connectors and press Connect.",
    "Open https://chatgpt.com/plugins, press +.",
    # Brickworks' own bridge into a desktop window is not the connector.
    "claude mcp add brickworks -- /path/to/brickworks/tools/brickworks_mcp.py",
    "The address: https://brickworks.diy/api/mcp",
])
def test_the_tables_own_ways_pass(said: str) -> None:
    assert not assistants.ways(said), assistants.ways(said)


def test_a_page_that_keeps_an_old_way_after_the_table_changes_is_caught(monkeypatch) -> None:
    """The red: Claude Code's row says another command, and the pages people
    read that give its command by hand (docs-site/claude-code.md) fail."""
    rows = json.loads(json.dumps(ROWS))
    code = next(row for row in rows if row["id"] == "claude_code")
    code["add"] = "claude mcp add --transport http --scope user {key} {address}"
    monkeypatch.setattr(assistants, "rows", lambda: rows)
    _, pages = docs_site.load()
    problems = docs_site.way_problems(pages)
    assert any(p.startswith("docs-site/claude-code.md says the command") for p in problems), problems


@pytest.mark.parametrize("said, caught", [
    ("The connector needs Claude Pro or Max.", True),
    ("On a paid Claude plan, add it as a custom connector.", True),
    ("Claude's Pro and Max plans add it.", True),
    ("Pro, Max and Enterprise, on the web; not on phones yet.", False),
    ("Every Claude plan: Free adds one custom connector.", False),
])
def test_a_claude_plan_said_to_be_needed_is_caught(said: str, caught: bool) -> None:
    assert bool(assistants.plan_claims(said)) == caught, said


def test_links_are_filled_as_the_app_fills_them() -> None:
    """What Assistants.fill (src/net/assistants.gd) gives for the same places,
    printed by Godot 4.7 on 2026-11-03: the site's links are the app's."""
    assert assistants.fill("{config_base64}") == "eyJ1cmwiOiJodHRwczovL2JyaWNrd29ya3MuZGl5L2FwaS9tY3AifQ%3D%3D"
    assert assistants.fill("{config_json_uri}") == (
        "%7B%22name%22%3A%22brickworks%22%2C%22type%22%3A%22http%22%2C%22url%22%3A%22https%3A%2F%2F"
        "brickworks.diy%2Fapi%2Fmcp%22%7D")
    assert assistants.fill("{address_uri} {name_uri}") == "https%3A%2F%2Fbrickworks.diy%2Fapi%2Fmcp Brickworks"
    assert assistants.fill("{message_uri}", message="Use my Brickworks tab k7qd (“Castle”) for this chat.") == (
        "Use%20my%20Brickworks%20tab%20k7qd%20%28%E2%80%9CCastle%E2%80%9D%29%20for%20this%20chat.")


def test_every_assistant_is_named_as_its_owners_mark() -> None:
    """The footer says the AI apps' names are their owners' marks, and the
    terms' notices name the owner of each app the table lists."""
    shell = (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    assert "AI apps named here are trademarks of their owners" in shell
    notices = (ROOT / "web/terms.html").read_text(encoding="utf-8")
    notices = notices[notices.index('id="notices"'):notices.index('id="when-these-change"')]
    for row in ROWS:
        if not row.get("called"):
            assert re.search(rf"\b{re.escape(row['name'])}\b[^.]* trademarks? of ", notices), \
                f"/terms#notices does not name whose mark {row['name']} is"
