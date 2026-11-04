#!/usr/bin/env python3
"""Every AI app Brickworks connects to, from assets/assistants.json, as the
site says it.

The app's Connect your AI reads the table (src/net/assistants.gd); the site
is made from the same rows here, so the two cannot disagree (the owner,
2026-11-02: any AI as easy to connect as Claude; docs/ANY_ASSISTANT.md, U4):

  - a docs page for each assistant, /docs/connect-<id>, from one template,
    docs-site/_connect.md (tools/docs_site.py, at every deploy);
  - the cards on /docs/connect and in the FAQ's Bring your own AI
    (web/faq.html, between its assistants marks; tools/docs_site.py --write
    writes them, --check fails while they differ).

And what a page may say about adding Brickworks to one (ways()): every
command that adds the connector, every install link that carries its
address, and every link to an assistant's own page for adding a server
must be the one its row makes. tests/test_assistant_pages.py holds every
page of the site and the docs to that.
"""

from __future__ import annotations

import base64
import html
import json
import re
from pathlib import Path
from urllib.parse import quote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / "assets/assistants.json"
ADDRESS = "https://brickworks.diy/api/mcp"


def table() -> dict:
    return json.loads(TABLE.read_text(encoding="utf-8"))


def rows() -> list[dict]:
    return [row for row in table()["assistants"] if row.get("id")]


def page_name(row: dict) -> str:
    """Its docs page: connect-claude, connect-le-chat, connect-gemini-cli."""
    return "connect-" + row["id"].replace("_", "-")


def called(row: dict) -> str:
    """What a sentence calls it: its name, or "your AI app" for Another app."""
    return row.get("called") or row["name"]


def uri(words: str) -> str:
    """Godot's String.uri_encode: everything but letters, digits and -_.~."""
    return quote(words, safe="")


def fill(words: str, address: str = ADDRESS, message: str = "") -> str:
    """[words] with the server's and [address]'s places filled in, exactly as
    Assistants.fill (src/net/assistants.gd) fills them for the app."""
    server = table()["server"]
    plain = message
    for awkward in ['"', "$", "`", "\\", "!", "%"]:
        plain = plain.replace(awkward, "")
    places = {
        "address": address, "address_uri": uri(address),
        "name": server["name"], "name_uri": uri(server["name"]), "key": server["key"],
        # Godot's JSON.stringify: no spaces, keys sorted.
        "config_base64": uri(base64.b64encode(json.dumps({"url": address}, separators=(",", ":"),
                                                          sort_keys=True).encode()).decode()),
        "config_json_uri": uri(json.dumps({"name": server["key"], "type": "http", "url": address},
                                          separators=(",", ":"), sort_keys=True)),
        "message": plain, "message_uri": uri(message),
    }
    return re.sub(r"\{(\w+)\}", lambda m: places.get(m.group(1), m.group(0)), words)


def adding(row: dict) -> str:
    """The link, page or command that adds Brickworks to [row]; "" for none."""
    return fill(row.get("add", ""))


# -- the cards ----------------------------------------------------------------

# How each way reads on a card, in a line: the row's way, in the words a
# person reads on the cards (the table's "ways" says it for the app).
WAY_LINES = {
    "link": "One link opens it with Brickworks filled in.",
    "command": "One command, to run in a terminal.",
    "open": "Copy the address and paste it in, on its own page.",
    "copy": "Copy the address wherever it takes a remote MCP server.",
}


def way_line(row: dict) -> str:
    return WAY_LINES[row["way"]]


def faq_cards() -> str:
    """The FAQ's cards, one an assistant, as the chooser lists them: its name,
    its way, who may, and its docs page."""
    items = []
    for row in rows():
        items.append(
            f'\t\t\t\t\t<li class="card assistant">\n'
            f'\t\t\t\t\t\t<h3><a href="/docs/{page_name(row)}">{html.escape(row["name"], quote=False)}</a></h3>\n'
            f'\t\t\t\t\t\t<p class="how">{html.escape(way_line(row), quote=False)}</p>\n'
            f'\t\t\t\t\t\t<p class="for">{html.escape(row["plan"], quote=False)}</p>\n'
            f'\t\t\t\t\t</li>\n')
    return (f"\t\t\t\t<!-- assistants: made from assets/assistants.json by tools/docs_site.py --write; "
            f"edit the table, not this -->\n"
            f'\t\t\t\t<ul class="assistants" aria-label="AI apps">\n{"".join(items)}\t\t\t\t</ul>\n'
            f"\t\t\t\t<!-- /assistants -->\n")


FAQ_BLOCK = re.compile(r"\t*<!-- assistants:.*?<!-- /assistants -->\n", re.S)


def with_cards(page: str) -> str:
    """web/faq.html with its cards as the table makes them."""
    if not FAQ_BLOCK.search(page):
        raise SystemExit("assistants: web/faq.html has no <!-- assistants: ... <!-- /assistants --> block")
    return FAQ_BLOCK.sub(lambda _: faq_cards(), page, count=1)


# -- what a page says -----------------------------------------------------------

# A command that adds Brickworks over the connector: the assistant's command
# line, `mcp add`, and the connector's address somewhere after it, up to the
# end of the line or of the markup around it.
COMMAND = re.compile(r"\b([a-z][\w-]*) mcp add\b[^\n<`\"()]*?" + re.escape(ADDRESS)
                     + r"(?:\s*&&\s*[a-z][\w-]* mcp [\w -]*[\w-])?")
LINK = re.compile(r"""(?:https?://|[a-z]+:)[^\s"'<>()\]`]+""")


def _bare(address: str) -> str:
    parts = urlsplit(address)
    return f"{parts.scheme}:{'//' + parts.netloc if parts.netloc else ''}{parts.path}"


def _under(link: str, page: str) -> bool:
    """[link] is [page], or a page below it, on the same site or app."""
    a, b = urlsplit(link), urlsplit(page)
    return (a.scheme, a.netloc) == (b.scheme, b.netloc) and a.path.startswith(b.path.rstrip("/"))


def ways(text: str) -> list[str]:
    """Each way of adding Brickworks [text] gives that no row of the table
    makes: a command that adds the connector, an install link carrying its
    address, or a link to an assistant's own page for adding a server (or a
    page below it) that is not its row's. A row's page bare (its query left
    off) is where a person who has added it already goes, and its new chat
    where a chat starts, so those stand too."""
    made = {row["id"]: adding(row) for row in rows()}
    commands = {made[row["id"]] for row in rows() if row["way"] == "command"}
    commands |= {c.split(" && ")[0] for c in commands}  # its first half: the adding, before signing in
    clis = {made[row["id"]].split(" ")[0] for row in rows() if row["way"] == "command"}
    pages = {made[row["id"]] for row in rows() if row["way"] in ("link", "open") and made[row["id"]]}
    # A new chat's page as it is, or a link's with its message filled in.
    chats = {(row.get("new_chat") or {}).get("to", "") for row in rows()} - {""}
    chats = {fill(c) for c in chats if "{" not in c}, {c.split("{")[0] for c in chats if "{" in c}
    found: list[str] = []
    plain = html.unescape(text)
    for match in COMMAND.finditer(plain):
        command = match.group(0).strip().rstrip(".,;:")
        if match.group(1) in clis and command not in commands:
            found.append(f"the command `{command}`, where the table makes "
                         + " or ".join(f"`{c}`" for c in sorted(commands) if c.startswith(match.group(1) + " ")))
    for match in LINK.finditer(plain):
        link = match.group(0).rstrip(".,;:")
        if (link in pages or link in {_bare(p) for p in pages} or link in chats[0]
                or any(link.startswith(c) for c in chats[1])):
            continue
        page = next((p for p in sorted(pages) if _under(link, p)), "")
        if page:
            found.append(f"the link {link}, where the table makes {page}")
        elif uri(ADDRESS) in link or (ADDRESS in link and not link.startswith(ADDRESS)):
            found.append(f"the install link {link}, which no row of the table makes")
    return found


# A paid plan said to be needed for Claude's connector: every Claude plan
# has it, Free with one custom connector (docs/ANY_ASSISTANT.md B.1).
CLAUDE_PAID = re.compile(r"Claude[’']?s? (?:Pro|Max|Team)(?: plan)?,? (?:or|and) (?:Pro|Max|Team)|"
                         r"\bpaid Claude plan")


def plan_claims(text: str) -> list[str]:
    return [f"“{m.group(0)}”: every Claude plan adds it (the table: {rows()[0]['plan']})"
            for m in CLAUDE_PAID.finditer(html.unescape(text))]
