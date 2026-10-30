#!/usr/bin/env python3
"""The documentation at brickworks.diy/docs, made from docs-site/.

    tools/docs_site.py OUT       write OUT/docs.html, OUT/docs/<page>.html, OUT/docs/search.json
    tools/docs_site.py --check   say what the docs miss, and exit 1 if anything

The owner, 2026-10-29: "an advanced 'docs' page ... documenting cleanly
every detail of the app and user site features". The words are Markdown in
docs-site/, one file a page, in the order docs-site/_nav.json gives; this
turns them into static pages with the site's header and footer
(web/_shell.html), a sidebar, a table of contents, previous and next, and
the index web/docs.js searches. tools/site.py runs it at every deploy, as
it writes the changelog.

Four pages are made from what they describe, so they cannot drift from it:
the MCP tool reference from tools/mcp_tools.json, the keyboard shortcuts
from ControlsHint.for_keyboard() (src/ui/controls_hint.gd) and the menus'
keys, the menus from docs-site/generated/menus.json (written off the real
window by src/dev/docs_menus.gd; tests/test_docs_site.py fails when
src/ui/shell.gd's menus no longer match it), and the changelog from
CHANGELOG.md.

--check fails when a feature in the feature map (.claude/skills/verify/
features.json) is in no page and not named in docs-site/internal.txt as
something a person never meets, when a page names a feature the map does
not have, and when a link or picture on a page goes nowhere. A section says
what it documents with a comment under its heading:

    ## Box select
    <!-- covers
    ui:box select
    -->
"""

from __future__ import annotations

import fnmatch
import html
import importlib.util
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs-site"
WEB = ROOT / "web"
SITE = "https://brickworks.diy"
FEATURES = ROOT / ".claude/skills/verify/features.json"



def _tool(name: str):
    """tools/<name>.py, by its path: the standard library has a module named
    site, and Python has it loaded before anything here runs."""
    spec = importlib.util.spec_from_file_location(f"brickworks_{name}", Path(__file__).resolve().parent / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


site_shell = _tool("site_shell")  # the site's one header and footer

# -- Markdown -----------------------------------------------------------------
# The few things these pages use, and no more: headings with ids, paragraphs,
# lists one level deep, tables, fenced code, callouts (> [!NOTE]), a picture
# on a line of its own, and in a line `code`, **bold**, *words*, [links](/x)
# and [[Ctrl+K]] for keys. A line that starts with an HTML tag is passed on.

KEY = re.compile(r"\[\[(\]|[^\]]+\]?)\]\]")  # [[]]] is the key ], [[Shift+]]] Shift and ]


def slug(text: str) -> str:
    words = re.sub(r"<[^>]+>", "", text).lower()
    words = re.sub(r"[^a-z0-9]+", "-", html.unescape(words)).strip("-")
    return words or "section"


def keys(text: str) -> str:
    """[[Ctrl+Shift+Z]] as keys, each its own <kbd>."""
    parts = [p.strip() for p in re.split(r"(?<!^)\+(?!$)", text)]
    return '<kbd class="keys">' + "+".join(f"<kbd>{html.escape(p)}</kbd>" for p in parts) + "</kbd>"


def inline(text: str) -> str:
    held: list[str] = []

    def hold(snippet: str) -> str:
        held.append(snippet)
        return f"\x00{len(held) - 1}\x00"

    text = re.sub(r"`([^`]+)`", lambda m: hold(f"<code>{html.escape(m.group(1))}</code>"), text)
    text = KEY.sub(lambda m: hold(keys(m.group(1))), text)
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![*\w])\*([^*\s][^*]*)\*(?![*\w])", r"<em>\1</em>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                  lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>', text)
    return re.sub(r"\x00(\d+)\x00", lambda m: held[int(m.group(1))], text)


def plain(fragment: str) -> str:
    """The words of some HTML, as search reads them."""
    text = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", fragment, flags=re.S)
    # A tag inside a line of words joins them; any other parts them.
    text = re.sub(r"</?(?:a|code|strong|em|kbd|span|b|i|small|mark)\b[^>]*>", "", text)
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


def webp_size(path: Path) -> tuple[int, int] | None:
    """A WebP picture's width and height, read off its header."""
    try:
        head = path.read_bytes()[:30]
    except OSError:
        return None
    if head[:4] != b"RIFF" or head[8:12] != b"WEBP":
        return None
    kind = head[12:16]
    if kind == b"VP8 ":
        w, h = struct.unpack("<HH", head[26:30])
        return w & 0x3FFF, h & 0x3FFF
    if kind == b"VP8L":
        b = head[21:25]
        bits = int.from_bytes(b, "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if kind == b"VP8X":
        return int.from_bytes(head[24:27], "little") + 1, int.from_bytes(head[27:30], "little") + 1
    return None


class Page:
    def __init__(self, name: str, meta: dict, body: str) -> None:
        self.name = name
        self.meta = meta
        self.body = body
        self.title = meta.get("title", name)
        self.nav = meta.get("nav", self.title)
        self.description = meta.get("description", "")
        self.html = ""
        self.headings: list[tuple[int, str, str]] = []  # level, id, words (HTML)
        self.covers: dict[str, str] = {}  # feature id: the section's id ("" the page)
        self.sections: list[tuple[str, str, str]] = []  # id, heading, words, for search
        self.section = ""

    @property
    def url(self) -> str:
        return "/docs" if self.name == "index" else f"/docs/{self.name}"


def render(page: Page, markdown: str) -> None:
    out: list[str] = []
    ids: set[str] = set()
    current = ""
    lines = markdown.splitlines()
    i = 0
    para: list[str] = []

    def flush() -> None:
        if para:
            out.append(f"<p>{inline(' '.join(s.strip() for s in para))}</p>")
            para.clear()

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            flush()
            i += 1
            continue
        if stripped.startswith("<!-- covers"):
            flush()
            i += 1
            while i < len(lines) and lines[i].strip() != "-->":
                feature = lines[i].strip()
                if feature:
                    if feature in page.covers:
                        raise SystemExit(f"docs: {page.name}.md covers {feature} twice")
                    page.covers[feature] = current
                i += 1
            i += 1
            continue
        if stripped.startswith("<!--"):
            flush()
            while i < len(lines) and "-->" not in lines[i]:
                i += 1
            i += 1
            continue
        head = re.match(r"^(#{2,4})\s+(.*?)(?:\s+\{#([a-z0-9_-]+)\})?\s*$", line)
        if head:
            flush()
            level = len(head.group(1))
            words = inline(head.group(2))
            anchor = head.group(3) or slug(head.group(2))
            base, n = anchor, 2
            while anchor in ids:
                anchor, n = f"{base}-{n}", n + 1
            ids.add(anchor)
            current = anchor
            page.headings.append((level, anchor, words))
            label = html.escape(plain(words), quote=True)
            out.append(f'<h{level} id="{anchor}">{words}<a class="anchor" href="#{anchor}" '
                       f'aria-label="Link to {label}"></a></h{level}>')
            i += 1
            continue
        if stripped.startswith("```"):
            flush()
            lang = stripped[3:].strip()
            i += 1
            code: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            i += 1
            if lang.startswith("said "):
                # Words an assistant is given (SAID_BLOCKS), shown as they read.
                title = SAID_BLOCKS.get(lang[5:].strip(), ("", "What an assistant is told"))[1]
                body = "".join(f"<p>{'<br>'.join(html.escape(line) for line in chunk)}</p>"
                               for chunk in _paragraphs(code))
                out.append(f'<aside class="callout note said" aria-label="{html.escape(title)}">'
                           f'<p class="callout-title">{html.escape(title)}</p>{body}</aside>')
                continue
            label = f' data-lang="{html.escape(lang)}"' if lang else ""
            out.append(f'<div class="code"{label}><pre><code>{html.escape(chr(10).join(code))}</code></pre></div>')
            continue
        if stripped.startswith(">"):
            flush()
            quoted: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quoted.append(lines[i].strip()[1:].strip())
                i += 1
            kind = "note"
            said = re.match(r"^\[!(NOTE|TIP|WARNING)\]\s*(.*)$", quoted[0])
            if said:
                kind = said.group(1).lower()
                quoted[0] = said.group(2)
            title = {"note": "Note", "tip": "Tip", "warning": "Careful"}[kind]
            body = "".join(f"<p>{inline(' '.join(chunk))}</p>" for chunk in _paragraphs(quoted))
            out.append(f'<aside class="callout {kind}" aria-label="{title}"><p class="callout-title">{title}</p>{body}</aside>')
            continue
        picture = re.match(r"^!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"([^\"]*)\")?\)$", stripped)
        if picture:
            flush()
            alt, src, caption = picture.group(1), picture.group(2), picture.group(3) or ""
            size = webp_size(WEB / src.lstrip("/")) if src.startswith("/img/") else None
            dims = f' width="{size[0]}" height="{size[1]}"' if size else ""
            cap = f"<figcaption>{inline(caption)}</figcaption>" if caption else ""
            out.append(f'<figure class="shot"><img src="{html.escape(src)}" alt="{html.escape(alt)}"'
                       f'{dims} loading="lazy" decoding="async">{cap}</figure>')
            i += 1
            continue
        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1].strip()):
            flush()
            cells = lambda row: [c.strip() for c in row.strip().strip("|").split("|")]  # noqa: E731
            header = cells(line)
            i += 2
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            thead = "".join(f'<th scope="col">{inline(c)}</th>' for c in header)
            tbody = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>" for row in rows)
            out.append(f'<div class="table"><table><thead><tr>{thead}</tr></thead><tbody>{tbody}</tbody></table></div>')
            continue
        bullet = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if bullet and not bullet.group(1):
            flush()
            ordered = bullet.group(2)[0].isdigit()
            items: list[list[str]] = []
            subs: list[list[str]] = []
            while i < len(lines):
                one = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if one and not one.group(1):
                    items.append([one.group(3)])
                    subs.append([])
                elif one and items:
                    subs[-1].append(one.group(3))
                elif lines[i].startswith("  ") and lines[i].strip() and items:
                    if subs[-1]:
                        subs[-1][-1] += " " + lines[i].strip()
                    else:
                        items[-1].append(lines[i].strip())
                else:
                    break
                i += 1
            tag = "ol" if ordered else "ul"
            parts = []
            for words, sub in zip(items, subs):
                inner = "".join(f"<li>{inline(s)}</li>" for s in sub)
                parts.append(f"<li>{inline(' '.join(words))}{f'<ul>{inner}</ul>' if inner else ''}</li>")
            out.append(f"<{tag}>{''.join(parts)}</{tag}>")
            continue
        if stripped.startswith("<"):
            flush()
            out.append(line)
            i += 1
            continue
        para.append(line)
        i += 1
    flush()
    page.html += "\n".join(out)


def _paragraphs(lines: list[str]) -> list[list[str]]:
    chunks: list[list[str]] = [[]]
    for line in lines:
        if line:
            chunks[-1].append(line)
        elif chunks[-1]:
            chunks.append([])
    return [c for c in chunks if c]


def front_matter(text: str) -> tuple[dict, str]:
    """A page's head and the rest: `key: words` a line, and a key with
    nothing after its colon is a list, one `  - item` a line under it."""
    meta: dict = {}
    if not text.startswith("---\n"):
        return meta, text
    end = text.index("\n---\n", 4)
    key = ""
    for line in text[4:end].splitlines():
        item = re.match(r"^\s+-\s+(.*)$", line)
        if item and isinstance(meta.get(key), list):
            meta[key].append(item.group(1).strip())
        elif ":" in line:
            key, value = (part.strip() for part in line.split(":", 1))
            meta[key] = value if value else []
    return meta, text[end + 5:]


def read_page(path: Path) -> Page:
    meta, text = front_matter(path.read_text(encoding="utf-8"))
    return Page(path.stem, meta, text)


def named_tools(page: Page) -> list[str]:
    """The MCP tools a page explains to people (`tools:` in its head)."""
    return [t.strip() for t in str(page.meta.get("tools", "")).split(",") if t.strip()]


# -- the tools, and what each one's doc says -------------------------------------
# Every tool a session is served has a doc of its own, docs-site/tools/<name>.md:
# an example call and any words for people, which are the doc's own, and the
# words the tool list gives the tool, which are the app's (src/, served by the
# app and kept in tools/mcp_tools.json by mcp_sync_probe) or the relay's
# (api/mcp.js, its tabs and select_tab) and copied in by --write, so a
# description that changes is read against its doc before it lands.

TOOL_DOCS = SRC / "tools"
SAID = re.compile(r"<!-- the tool list's words[^\n]*-->\n```text\n(.*?)\n```\n", re.S)
SAID_NOTE = ("<!-- the tool list's words: tools/docs_site.py --write copies them here from "
             "{source}; --check fails while they differ -->")


def app_tools() -> list[dict]:
    return json.loads((ROOT / "tools/mcp_tools.json").read_text(encoding="utf-8"))


def relay_tools() -> list[dict]:
    """The relay's own two (RELAY_TOOLS in api/mcp.js), read as the JSON its
    literal nearly is: comments out, joined strings joined, keys quoted."""
    text = (ROOT / "api/mcp.js").read_text(encoding="utf-8")
    found = re.search(r"^const RELAY_TOOLS = (\[.*?^\]);", text, re.S | re.M)
    if not found:
        raise SystemExit("docs: api/mcp.js has no `const RELAY_TOOLS = [...]`; tools/docs_site.py relay_tools() reads it")
    literal = re.sub(r"^\s*//.*$", "", found.group(1), flags=re.M)
    literal = re.sub(r'"\s*\+\s*"', "", literal)
    literal = re.sub(r"([{,]\s*)([A-Za-z_]\w*):", r'\1"\2":', literal)
    literal = re.sub(r",(\s*[}\]])", r"\1", literal)
    try:
        tools = json.loads(literal)
    except json.JSONDecodeError as said:
        raise SystemExit(f"docs: api/mcp.js's RELAY_TOOLS no longer reads as JSON ({said}); "
                         "tools/docs_site.py relay_tools() must learn it") from None
    return [{"name": t["name"], "description": t["description"], "input_schema": t.get("inputSchema", {}),
             "annotations": t.get("annotations", {}), "relay": True} for t in tools]


def all_tools() -> list[dict]:
    return app_tools() + relay_tools()


class ToolDoc:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.text = path.read_text(encoding="utf-8")
        self.meta, rest = front_matter(self.text)
        self.name = str(self.meta.get("tool", ""))
        said = SAID.search(rest)
        self.said = said.group(1) if said else None
        # The words for people: everything but the copy of the tool list's.
        self.notes = SAID.sub("", rest).strip()
        try:
            self.example = json.loads(str(self.meta.get("example", "")))
        except json.JSONDecodeError:
            self.example = None


def tool_docs() -> dict[str, ToolDoc]:
    return {p.stem: ToolDoc(p) for p in sorted(TOOL_DOCS.glob("*.md"))}


def with_said(doc: ToolDoc, tool: dict) -> str:
    """The doc's text with the tool list's words as they are now."""
    source = "api/mcp.js" if tool.get("relay") else "tools/mcp_tools.json"
    block = SAID_NOTE.format(source=source) + "\n```text\n" + tool["description"] + "\n```\n"
    if SAID.search(doc.text):
        return SAID.sub(lambda _: block, doc.text, count=1)
    return doc.text.rstrip() + "\n\n" + block


def schema_problems(value, schema: dict, at: str) -> list[str]:
    """Where an example call breaks the tool's input schema: a key it does
    not take, one it needs and lacks, a value of the wrong type or not one
    of its enum."""
    kinds = {"string": str, "integer": int, "number": (int, float), "boolean": bool, "object": dict, "array": list}
    wanted = schema.get("type")
    if wanted:
        types = wanted if isinstance(wanted, list) else [wanted]
        fits = any(isinstance(value, kinds[t]) and not (t in ("integer", "number") and isinstance(value, bool))
                   for t in types if t in kinds)
        if not fits:
            return [f"{at} is {json.dumps(value)[:40]}, not {' or '.join(types)}"]
    if "enum" in schema and value not in schema["enum"]:
        return [f"{at} is {json.dumps(value)}, not one of {schema['enum']}"]
    found: list[str] = []
    if isinstance(value, dict):
        props = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                found.append(f"{at} lacks {key}, which it needs")
        for key, one in value.items():
            if key in props:
                found += schema_problems(one, props[key], f"{at}.{key}")
            elif schema.get("additionalProperties") is False:
                found.append(f"{at} has {key}, which the tool does not take")
    if isinstance(value, list) and isinstance(schema.get("items"), dict):
        for n, one in enumerate(value):
            found += schema_problems(one, schema["items"], f"{at}[{n}]")
    return found


def tool_problems(pages: list[Page]) -> list[str]:
    """Every tool has its doc, every doc is a tool's, each doc's copy of the
    tool list's words is the list's own, its example is a call the tool
    takes, and every tool a page names is a tool."""
    problems: list[str] = []
    tools = {t["name"]: t for t in all_tools()}
    docs = tool_docs()
    for name, tool in tools.items():
        doc = docs.get(name)
        where = f"docs-site/tools/{name}.md"
        if doc is None:
            problems.append(f"{name} has no doc: write {where} (an example, as docs-site/tools/undo.md has one), "
                            "then tools/docs_site.py --write")
            continue
        if doc.name != name:
            problems.append(f"{where} says tool: {doc.name or '(none)'}, not {name}")
        if doc.said != tool["description"]:
            problems.append(f"{where} is behind what the tool list says of {name}: read the doc against the new "
                            "words, change its example or notes if they no longer hold, then tools/docs_site.py --write")
        if doc.example is None:
            problems.append(f"{where} has no example: an `example:` line, the call's arguments as JSON")
        else:
            problems += [f"{where}'s example: {p}" for p in schema_problems(doc.example, tool["input_schema"], name)]
    for name in docs:
        if name not in tools:
            problems.append(f"docs-site/tools/{name}.md is the doc of no tool the app or the relay serves "
                            "(renamed or gone? tools/mcp_tools.json, api/mcp.js)")
    explained: set[str] = set()
    for page in pages:
        for name in named_tools(page):
            explained.add(name)
            if name not in tools:
                problems.append(f"{page.name}.md names the tool {name}, which there is none of")
        for name in set(re.findall(r'href="/docs/mcp-tools#([a-z_]+)"', page.html)):
            if name not in tools and not page.name == "mcp-tools":
                problems.append(f"{page.name}.md links to the tool {name}, which there is none of")
    for name in tools:
        if name not in explained:
            problems.append(f"no page names {name} in its `tools:`: add it to the page that explains what it does")
    return problems


# -- the pages made from their sources -----------------------------------------


def explained_in() -> dict[str, list[tuple[str, str]]]:
    """tool -> the pages that name it in their `tools:`, (title, address)."""
    found: dict[str, list[tuple[str, str]]] = {}
    for group in json.loads((SRC / "_nav.json").read_text(encoding="utf-8")):
        for name in group["pages"]:
            page = read_page(SRC / f"{name}.md")
            for tool in named_tools(page):
                found.setdefault(tool, []).append((page.title, page.url))
    return found


def example_call(args: dict) -> str:
    one_line = json.dumps(args, ensure_ascii=False)
    return one_line if len(one_line) <= 72 else json.dumps(args, ensure_ascii=False, indent=2)


def mcp_tools() -> str:
    """Every tool a session has in Brickworks: the app's, from
    tools/mcp_tools.json, and the connector's own two, from api/mcp.js, each
    with its doc's example and words (docs-site/tools/). What it is called,
    whether it only looks, what it takes, and where it is explained."""
    tools = all_tools()
    docs = tool_docs()
    pages = explained_in()
    groups = [
        ("Look and read", "Change nothing: safe to allow always.",
         lambda t: not t.get("relay") and t["annotations"].get("readOnlyHint")),
        ("Build and change", "Change the model in the open tab. Each change is one undo step.",
         lambda t: not t["annotations"].get("readOnlyHint") and not t["annotations"].get("destructiveHint")),
        ("Replace or take away", "Can replace or remove what is on the baseplate. Each is still one undo step.",
         lambda t: not t["annotations"].get("readOnlyHint") and t["annotations"].get("destructiveHint")),
        ("Choose the tab", "The connector's own two, for the tab a chat works in. They change no model, and "
         "a session on the desktop's own port has no need of them.",
         lambda t: t.get("relay")),
    ]
    own = sum(1 for t in tools if not t.get("relay"))
    out = [f"<p>Brickworks has <strong>{own} tools</strong>, and the connector adds "
           f"<strong>{len(tools) - own}</strong> of its own for choosing a tab. This page is made from the "
           "same tables the app and the connector serve, so it is always the current list. Through the "
           "connector every tool also takes <code>target</code>: the tab to do that one call in, by its id or "
           "its model's name.</p>"]
    summary = []
    for title, _, test in groups:
        for tool in tools:
            if test(tool):
                a = tool["annotations"]
                summary.append(f'<tr><td><a href="#{tool["name"]}"><code>{tool["name"]}</code></a></td>'
                               f'<td>{html.escape(a.get("title", ""))}</td><td>{title}</td></tr>')
    out.append('<div class="table"><table><thead><tr><th scope="col">Tool</th><th scope="col">What it does</th>'
               f'<th scope="col">Kind</th></tr></thead><tbody>{"".join(summary)}</tbody></table></div>')
    md = []
    for title, words, test in groups:
        md.append(f"## {title}\n\n{words}\n")
        for tool in tools:
            if not test(tool):
                continue
            a = tool["annotations"]
            doc = docs.get(tool["name"])
            md.append(f"### {a.get('title', tool['name'])} {{#{tool['name']}}}\n")
            badges = [f"<code>{tool['name']}</code>"]
            badges.append('<span class="pill">Read-only</span>' if a.get("readOnlyHint") else
                          '<span class="pill">Changes the model</span>')
            if a.get("destructiveHint"):
                badges.append('<span class="pill">Can replace or remove</span>')
            if a.get("openWorldHint"):
                badges.append('<span class="pill">Reaches the web</span>')
            if a.get("idempotentHint"):
                badges.append('<span class="pill">Same result twice</span>')
            md.append(f'<p class="tool-badges">{" ".join(badges)}</p>\n')
            md.append(f"<p>{html.escape(tool['description'])}</p>\n")
            if doc is not None and doc.notes:
                md.append(doc.notes + "\n")
            props = tool.get("input_schema", {}).get("properties", {})
            required = set(tool.get("input_schema", {}).get("required", []))
            if props:
                rows = []
                for name, spec in props.items():
                    kind = spec.get("type", "")
                    if isinstance(kind, list):
                        kind = " or ".join(kind)
                    if spec.get("enum"):
                        kind += ": " + ", ".join(str(v) for v in spec["enum"])
                    if kind == "array" and isinstance(spec.get("items"), dict) and spec["items"].get("type"):
                        kind = f"array of {spec['items']['type']}"
                    need = "yes" if name in required else ""
                    rows.append(f"<tr><td><code>{html.escape(name)}</code></td><td>{html.escape(str(kind))}</td>"
                                f"<td>{need}</td><td>{html.escape(spec.get('description', ''))}</td></tr>")
                md.append('<div class="table params"><table><thead><tr><th scope="col">Takes</th>'
                          '<th scope="col">Type</th><th scope="col">Needed</th><th scope="col">What it is</th>'
                          f'</tr></thead><tbody>{"".join(rows)}</tbody></table></div>\n')
            else:
                md.append("<p class=\"note\">Takes nothing.</p>\n")
            if doc is not None and doc.example is not None:
                md.append(f"For example:\n\n```json\n{example_call(doc.example)}\n```\n")
            where = pages.get(tool["name"], [])
            if where:
                md.append("Explained in " + ", ".join(f"[{t}]({u})" for t, u in where) + ".\n")
    return "\n".join(out) + "\n\n" + "\n".join(md)


def _binding_keys(raw: str) -> list[str]:
    """Binding.new's first argument as the words each key is, the platform's
    modifier written Ctrl."""
    found = []
    for item in re.findall(r'"((?:[^"\\]|\\.)*)"(\s*%\s*_hold\(\))?', raw):
        words, held = item
        found.append(words.replace("%s", "Ctrl") if held else words)
    return found


def keyboard() -> list[tuple[str, list[tuple[list[str], str, bool]]]]:
    """ControlsHint.for_keyboard() and for_touch(), read off
    src/ui/controls_hint.gd: [(section, [(keys, what it does, desktop only)])].
    Says so and stops when the file no longer reads as this expects, rather
    than list less than the app answers to."""
    text = (ROOT / "src/ui/controls_hint.gd").read_text(encoding="utf-8")

    def body(name: str) -> str:
        start = re.search(rf"^static func {name}\(.*?$", text, re.M)
        if not start:
            raise SystemExit(f"docs: src/ui/controls_hint.gd has no {name}(); the shortcuts page reads it")
        end = re.search(r"^(static func|func|const|class|##)", text[start.end():], re.M)
        return text[start.end(): start.end() + (end.start() if end else len(text))]

    def bindings(chunk: str) -> list[tuple[list[str], str, bool]]:
        rows = []
        # What follows this is the desktop's alone: a browser keeps the keys.
        desktop = chunk.find('if not OS.has_feature("web")')
        for m in re.finditer(r"Binding\.new\(", chunk):
            depth, j = 1, m.end()
            while depth and j < len(chunk):
                depth += {"(": 1, ")": -1}.get(chunk[j], 0)
                j += 1
            call = chunk[m.end(): j - 1]
            # The list's own ], not one inside a key's quotes ("[", "]").
            quoted, keys_end = False, 0
            for at, ch in enumerate(call):
                if ch == '"' and call[at - 1: at] != "\\":
                    quoted = not quoted
                elif ch == "]" and not quoted:
                    keys_end = at + 1
                    break
            keys_ = _binding_keys(call[:keys_end])
            rest = call[keys_end:].lstrip(", \n\t")
            said = re.match(r'"((?:[^"\\]|\\.)*)"', rest)
            if said:
                does = said.group(1)
                if re.match(r'\s*%', rest[said.end():]):
                    raise SystemExit("docs: a binding's words are made with %; tools/docs_site.py keyboard() must learn it")
            else:
                does = "turn or slide, as the navigation preset (Settings, Navigate like) has it"
            rows.append((keys_, does.replace('\\"', '"'), 0 <= desktop < m.start()))
        if not rows:
            raise SystemExit("docs: no Binding.new rows where the shortcuts page looks in controls_hint.gd")
        return rows

    kb = body("for_keyboard")
    sections: list[tuple[str, list]] = []
    for m in re.finditer(r'_section\(everything, "([^"]+)", (\[|_view_bindings\(\)|rest)', kb):
        name, what = m.group(1), m.group(2)
        if what == "[":
            depth, j = 1, m.end()
            while depth and j < len(kb):
                depth += {"[": 1, "]": -1}.get(kb[j], 0)
                j += 1
            sections.append((name, bindings(kb[m.end(): j])))
        elif what == "rest":
            start = kb.index("var rest")
            sections.append((name, bindings(kb[start: m.start()])))
        else:
            sections.append((name, bindings(body("_view_bindings"))))
    if len(sections) < 4:
        raise SystemExit(f"docs: read {len(sections)} sections of keys from controls_hint.gd, expected the five")
    sections.append(("On a touchscreen", bindings(body("for_touch"))))
    return sections


GESTURES = {"click", "drag", "double-click", "right-click", "right-drag", "middle-drag", "scroll",
            "pinch", "2 fingers", "tap", "hold", "arrows", "edges", "hold, then drag",
            "middle double-click", "shift-double-click", "Turn", "Tip", "Undo", "Redo"}
MODIFIERS = {"shift": "Shift", "alt": "Alt", "Ctrl": "Ctrl", "space": "Space"}


def key_html(words: str) -> str:
    """One binding's key as keys and gestures: "Ctrl-shift-Z" as three keys,
    "alt-drag" as a key and a gesture."""
    if words in GESTURES or words in ("-", "+"):
        return f'<span class="gesture">{html.escape(words)}</span>' if words in GESTURES else f"<kbd>{words}</kbd>"
    parts = []
    rest = words
    while "-" in rest:
        head, tail = rest.split("-", 1)
        if head in MODIFIERS and tail:
            parts.append(f"<kbd>{MODIFIERS[head]}</kbd>")
            rest = tail
        else:
            break
    if rest in GESTURES or " " in rest and rest not in ("Page Up", "Page Down"):
        parts.append(f'<span class="gesture">{html.escape(rest)}</span>')
    else:
        parts.append(f"<kbd>{html.escape(rest[:1].upper() + rest[1:] if len(rest) > 1 and rest.islower() and rest not in ('arrows',) else rest)}</kbd>")
    return '<span class="keys">' + "+".join(parts) + "</span>"


def menus_data() -> dict:
    return json.loads((SRC / "generated/menus.json").read_text(encoding="utf-8"))


def shortcuts() -> str:
    out = ["Made from the list the app's own **Keys and controls** panel draws ([[F1]] or [[,]] in the app), "
           "and from the menus' keys, so it says exactly what the app answers to.\n",
           "> [!NOTE]\n> On a Mac, press Cmd wherever this page says Ctrl.\n"]
    for section, rows in keyboard():
        out.append(f"## {section}\n")
        body = []
        for keys_, does, desktop in rows:
            shown = " ".join(key_html(k) for k in keys_)
            note = ' <span class="pill">Desktop app</span>' if desktop else ""
            body.append(f"<tr><td>{shown}</td><td>{html.escape(does[:1].upper() + does[1:])}{note}</td></tr>")
        out.append('<div class="table keys-table"><table><thead><tr><th scope="col">Press</th>'
                   f'<th scope="col">What it does</th></tr></thead><tbody>{"".join(body)}</tbody></table></div>\n')
    out.append("## In the menus\n\nEvery menu command that has a key of its own. "
               "[Menus and commands](/docs/menus) lists them all.\n")
    rows = []
    for menu in menus_data()["menus"]:
        for item in _flat(menu["items"]):
            if item.get("key"):
                shown = '<span class="keys">' + "+".join(f"<kbd>{html.escape(k)}</kbd>" for k in item["key"].split("+")) + "</span>"
                rows.append(f"<tr><td>{shown}</td><td>{html.escape(item['words'].rstrip('…'))}</td>"
                            f"<td>{html.escape(menu['title'])}</td></tr>")
    out.append('<div class="table keys-table"><table><thead><tr><th scope="col">Press</th>'
               '<th scope="col">Command</th><th scope="col">Menu</th></tr></thead>'
               f'<tbody>{"".join(rows)}</tbody></table></div>\n')
    return "\n".join(out)


def _flat(items: list) -> list:
    out = []
    for item in items:
        if "submenu" in item:
            out.extend(_flat(item.get("items", [])))
        elif "name" in item:
            out.append(item)
    return out


def _menu_rows(items: list) -> str:
    rows = []
    for item in items:
        if item.get("line") or "submenu" in item:
            continue
        key = item.get("key", "")
        shown = ('<span class="keys">' + "+".join(f"<kbd>{html.escape(k)}</kbd>" for k in key.split("+")) + "</span>") if key else ""
        tip = html.escape(item.get("tip", ""))
        rows.append(f'<tr id="cmd-{item["name"]}"><td>{html.escape(item["words"])}</td><td>{shown}</td><td>{tip}</td></tr>')
    return ('<div class="table menu-table"><table><thead><tr><th scope="col">Command</th><th scope="col">Key</th>'
            f'<th scope="col">What it does</th></tr></thead><tbody>{"".join(rows)}</tbody></table></div>\n')


def menus() -> str:
    data = menus_data()
    out = ["<p>Every command in the app's menus, in the order the menus have them, with its key and the "
           "words its tooltip says. Made from the app itself, so it matches the version on the web.</p>",
           "> [!NOTE]\n> On a Mac, press Cmd wherever this page says Ctrl. In a browser, File has **New tab** "
           "where the desktop app has **New window**, and nothing that would close the page.\n"]
    for menu in data["menus"]:
        out.append(f"## {menu['title']} {{#{slug(menu['title'])}-menu}}\n")
        out.append(_menu_rows(menu["items"]))
        for item in menu["items"]:
            if "submenu" in item:
                out.append(f"### {menu['title']} › {item['words']} {{#{slug(menu['title'])}-{item['submenu'].replace('_', '-')}}}\n")
                if item.get("items"):
                    out.append(_menu_rows(item["items"]))
                    for sub in item["items"]:
                        if "submenu" in sub and sub.get("items"):
                            out.append(f"<p class=\"note\">{html.escape(sub['words'])}:</p>")
                            out.append(_menu_rows(sub["items"]))
                else:
                    out.append("<p>Filled as it opens, with what is yours: your recent models, or the steps you can go back to.</p>\n")
    out.append("## On a part {#on-a-part}\n\nA right click on a part (a long press on a touchscreen) offers these, "
               "for the part or the selection it is in.\n")
    out.append(_menu_rows(data["on_a_part"]))
    return "\n".join(out)


def changelog() -> str:
    changelog_site = _tool("site")  # its reading of CHANGELOG.md; it runs this, so asked for here
    found = changelog_site.sections((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"))
    releases = json.loads((WEB / "releases.json").read_text(encoding="utf-8"))
    by_version = {r["version"]: r for r in releases.get("releases", [])}
    out = ["<p>What changed in the latest releases. The <a href=\"/changelog\">full changelog</a> "
           "has every release since the first.</p>"]
    shown = 0
    for section in found:
        if not section["blocks"]:
            continue
        version = section["version"]
        if version.lower() == "unreleased":
            out.append("## On the web now {#web}\n")
            out.append('<p class="note">In the app at <a href="/app">brickworks.diy/app</a>; in the next desktop release.</p>')
        else:
            date = by_version.get(version, {}).get("date") or section["date"]
            out.append(f"## Brickworks {version} {{#v{version.replace('.', '-')}}}\n")
            out.append(f'<p class="note"><time datetime="{html.escape(date)}">{changelog_site.day(date)}</time> · '
                       '<a href="/download">Download</a></p>')
        items: list[str] = []
        for kind, words in section["blocks"]:
            if kind != "li" and items:
                out.append(f"<ul>{''.join(items)}</ul>")
                items = []
            if kind == "h3":
                out.append(f"<p class=\"release-part\"><strong>{changelog_site.inline(words)}</strong></p>")
            elif kind == "li":
                items.append(f"<li>{changelog_site.inline(words)}</li>")
            else:
                out.append(f"<p>{changelog_site.inline(words)}</p>")
        if items:
            out.append(f"<ul>{''.join(items)}</ul>")
        shown += 1
        if shown >= 6:
            break
    return "\n".join(out)


GENERATED = {"mcp_tools": mcp_tools, "shortcuts": shortcuts, "menus": menus, "changelog": changelog}


# -- the site ------------------------------------------------------------------


def load() -> tuple[list[dict], list[Page]]:
    nav = json.loads((SRC / "_nav.json").read_text(encoding="utf-8"))
    pages: list[Page] = []
    seen: set[str] = set()
    for group in nav:
        for name in group["pages"]:
            if name in seen:
                raise SystemExit(f"docs: {name} is twice in docs-site/_nav.json")
            seen.add(name)
            path = SRC / f"{name}.md"
            if not path.exists():
                raise SystemExit(f"docs: docs-site/_nav.json names {name}, and there is no docs-site/{name}.md")
            page = read_page(path)
            page.section = group["title"]
            made = page.meta.get("generated")
            body = page.body
            if made:
                if made not in GENERATED:
                    raise SystemExit(f"docs: {name}.md asks for generated: {made}, which is none of {sorted(GENERATED)}")
                body = body.rstrip() + "\n\n" + GENERATED[made]() + "\n"
            render(page, body)
            pages.append(page)
    loose = sorted(p.stem for p in SRC.glob("*.md") if p.stem not in seen)
    if loose:
        raise SystemExit(f"docs: docs-site/{loose[0]}.md is in no group of docs-site/_nav.json")
    for page in pages:
        page.sections = _split(page)
    return nav, pages


def _split(page: Page) -> list[tuple[str, str, str]]:
    """The page cut at each heading: (id, heading, its words) for search."""
    parts = re.split(r'(<h[23] id="[^"]+">.*?</h[23]>)', page.html)
    found = [("", page.title, plain(parts[0])[:600])]
    for n in range(1, len(parts), 2):
        anchor = re.search(r'id="([^"]+)"', parts[n]).group(1)
        found.append((anchor, plain(parts[n]), plain(parts[n + 1] if n + 1 < len(parts) else "")[:900]))
    return found


ICON_SEARCH = ('<svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" '
               'stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/>'
               '<path d="m20 20-3.5-3.5"/></svg>')


def sidebar(nav: list[dict], pages: dict[str, Page], here: Page) -> str:
    groups = []
    for n, group in enumerate(nav):
        links = []
        for name in group["pages"]:
            page = pages[name]
            current = ' aria-current="page"' if page is here else ""
            links.append(f'<li><a href="{page.url}"{current}>{html.escape(page.nav)}</a></li>')
        groups.append(f'<p class="docs-group" id="g{n}">{html.escape(group["title"])}</p>'
                      f'<ul aria-labelledby="g{n}">{"".join(links)}</ul>')
    return "".join(groups)


def toc(page: Page) -> str:
    depth = int(page.meta.get("toc", "3"))
    items = [(lvl, anchor, words) for lvl, anchor, words in page.headings if lvl <= depth]
    if len(items) < 2:
        return ""
    links = "".join(f'<li class="l{lvl}"><a href="#{anchor}">{plain(words)}</a></li>' for lvl, anchor, words in items)
    return (f'<aside class="docs-toc" aria-labelledby="toc-title"><p class="docs-toc-title" id="toc-title">On this page</p>'
            f'<ul>{links}</ul></aside>')


def pager(order: list[Page], page: Page) -> str:
    at = order.index(page)
    parts = []
    if at > 0:
        prev = order[at - 1]
        parts.append(f'<a class="prev" rel="prev" href="{prev.url}"><small>Previous · {html.escape(prev.section)}</small>'
                     f'<span>{html.escape(prev.nav)}</span></a>')
    if at + 1 < len(order):
        nxt = order[at + 1]
        parts.append(f'<a class="next" rel="next" href="{nxt.url}"><small>Next · {html.escape(nxt.section)}</small>'
                     f'<span>{html.escape(nxt.nav)}</span></a>')
    return f'<nav class="docs-pager" aria-label="Previous and next page">{"".join(parts)}</nav>'


def document(nav: list[dict], pages: dict[str, Page], order: list[Page], page: Page) -> str:
    head, header, footer = site_shell.shell()
    title = "Brickworks documentation" if page.name == "index" else f"{page.title} · Brickworks docs"
    description = html.escape(page.description, quote=True)
    crumbs = ('<nav class="crumbs" aria-label="Breadcrumb"><a href="/docs">Docs</a>'
              + ("" if page.name == "index" else f' <span aria-hidden="true">›</span> {html.escape(page.section)}')
              + "</nav>")
    lede = f'<p class="lede">{inline(page.description)}</p>' if page.description else ""
    # The start page opens on its search, as a docs site's front door does;
    # every other page says which part of the docs it is in, over its title.
    eyebrow = html.escape("Documentation" if page.name == "index" else page.section)
    start = (f'<button type="button" class="docs-search-open big" data-docs-search aria-label="Search the docs">{ICON_SEARCH}'
             '<span>Search the docs</span><kbd class="keys"><kbd>Ctrl</kbd><kbd>K</kbd></kbd></button>'
             if page.name == "index" else "")
    return f"""<!DOCTYPE html>
<!-- Made by tools/docs_site.py from docs-site/{page.name}.md: edit that, not this. -->
<html lang="en">
<head>
<meta charset="utf-8">
<script defer src="https://overlook.technology/s.js" data-site="ws_3frcuzvdsh" data-exclude="/m/**,/u/**,/c/**,/oauth/**,/admin"></script>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{html.escape(title)}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{SITE}{page.url}">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="/favicon-180.png">
<meta property="og:type" content="article">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="{html.escape(title, quote=True)}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{SITE}{page.url}">
<meta property="og:image" content="{SITE}/share.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="{SITE}/share.png">
{head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/docs.css">
<script src="/follow.js" type="module"></script>
<script defer src="/docs.js"></script>
</head>
<body class="docs-page">
<a class="skip" href="#main">Skip to content</a>
{header}
<div class="docs-layout wrap wide">
<div class="docs-bar">
<button type="button" class="docs-menu-button" aria-expanded="false" aria-controls="docs-side">Browse the docs</button>
<button type="button" class="docs-search-open" data-docs-search aria-label="Search the docs">{ICON_SEARCH}<span>Search</span></button>
</div>
<nav class="docs-side" id="docs-side" aria-label="Documentation">
<button type="button" class="docs-search-open wide" data-docs-search aria-keyshortcuts="Control+K Meta+K" aria-label="Search the docs">{ICON_SEARCH}<span>Search</span><kbd class="keys"><kbd>Ctrl</kbd><kbd>K</kbd></kbd></button>
{sidebar(nav, pages, page)}
</nav>
<main id="main" class="docs-main" tabindex="-1">
{crumbs}
<article class="docs-article">
<header class="docs-head{' start' if page.name == 'index' else ''}">
<p class="eyebrow">{eyebrow}</p>
<h1>{html.escape(page.title)}</h1>
{lede}
{start}
</header>
{page.html}
</article>
<p class="docs-help">Something missing, or not as the app does it? <a href="https://github.com/Xaxis/brickworks-releases/issues">Say so on GitHub</a>, or see <a href="/faq">the questions people ask</a>.</p>
{pager(order, page)}
</main>
{toc(page)}
</div>
{footer}
<dialog class="docs-search" aria-labelledby="docs-search-title">
<form method="dialog" class="docs-search-box" role="search">
<h2 class="docs-search-title" id="docs-search-title">Search the docs</h2>
<label class="docs-search-field">{ICON_SEARCH}<span class="visually-hidden">Search for</span>
<input type="search" name="q" autocomplete="off" spellcheck="false" placeholder="Search the docs" role="combobox" aria-expanded="false" aria-controls="docs-results" aria-autocomplete="list">
</label>
<button type="submit" class="cta ghost small" value="close">Close</button>
</form>
<p class="docs-search-said" role="status" aria-live="polite"></p>
<ul class="docs-results" id="docs-results" role="listbox" aria-label="Results"></ul>
<p class="docs-search-hint"><span><kbd>↑</kbd><kbd>↓</kbd> to choose</span><span><kbd>Enter</kbd> to open</span><span><kbd>Esc</kbd> to close</span></p>
</dialog>
</body>
</html>
"""


def search_index(pages: list[Page]) -> list[dict]:
    rows = []
    for page in pages:
        for anchor, heading, words in page.sections:
            rows.append({"p": page.title, "s": page.section, "h": heading if anchor else "",
                         "u": page.url + (f"#{anchor}" if anchor else ""), "t": words})
    return rows


def build(out: Path) -> int:
    nav, pages = load()
    by_name = {p.name: p for p in pages}
    docs = out / "docs"
    docs.mkdir(parents=True, exist_ok=True)
    for page in pages:
        target = out / "docs.html" if page.name == "index" else docs / f"{page.name}.html"
        target.write_text(document(nav, by_name, pages, page), encoding="utf-8")
    (docs / "search.json").write_text(json.dumps(search_index(pages), ensure_ascii=False, separators=(",", ":")),
                                      encoding="utf-8")
    return len(pages)


# -- what the app is given from the docs ------------------------------------------
# Two GDScript files are made from docs-site/ and committed, so the app needs
# no build step: what a session is told first (src/ai/connector_guide.gd,
# from the ```said blocks of the page on a design session) and the docs page
# of each panel, for Help, Documentation (src/ui/docs_pages.gd, from the
# `panels:` in the pages' heads). --write writes them; --check fails while
# either is not what the docs make.

GUIDE_GD = ROOT / "src/ai/connector_guide.gd"
PAGES_GD = ROOT / "src/ui/docs_pages.gd"
SAID_PAGE = "design-session"
# A ```said block's name: the constant it is, and what the page says it is.
SAID_BLOCKS = {
    "connected": ("CONNECTED", "Said first through the connector, before the rest"),
    "head": ("HEAD", "The start of the instructions, which every session is given"),
    "method": ("METHOD", "Said once, in a connector chat's first answer"),
}
SAID_FENCE = re.compile(r"^```said (\w+)\n(.*?)\n```$", re.S | re.M)


def said_blocks() -> dict[str, str]:
    """name -> its words, from the page on a design session."""
    text = (SRC / f"{SAID_PAGE}.md").read_text(encoding="utf-8")
    found = {m.group(1): m.group(2) for m in SAID_FENCE.finditer(text)}
    if set(found) != set(SAID_BLOCKS):
        raise SystemExit(f"docs: docs-site/{SAID_PAGE}.md has the said blocks {sorted(found)}, "
                         f"not {sorted(SAID_BLOCKS)}")
    return found


def gd_string(text: str, width: int = 76) -> str:
    """[text] as a GDScript string literal, exactly: long lines broken at a
    space with a backslash, which GDScript joins again."""
    if '"""' in text:
        raise SystemExit('docs: a said block has """ in it, which no GDScript string can hold as written')
    lines = []
    for line in text.replace("\\", "\\\\").split("\n"):
        while len(line) > width and line.rfind(" ", 0, width) > 0:
            cut = line.rfind(" ", 0, width) + 1
            lines.append(line[:cut] + "\\")
            line = line[cut:]
        lines.append(line)
    return '"""' + "\n".join(lines) + '"""'


def connector_guide() -> str:
    said = said_blocks()
    consts = "\n\n".join(f"## {SAID_BLOCKS[name][1]}.\nconst {SAID_BLOCKS[name][0]} := {gd_string(said[name])}"
                          for name in SAID_BLOCKS)
    return (f"## What a session is told, word for word as docs-site/{SAID_PAGE}.md shows\n"
            "## people: made from that page by tools/docs_site.py --write, so the docs\n"
            "## and the assistants read the same words. Edit the page, not this;\n"
            "## tests/test_docs_site.py fails while the two differ. Assistant serves\n"
            "## HEAD and METHOD, ClaudeConnector CONNECTED.\n"
            f"class_name ConnectorGuide\n\n{consts}\n")


def panels(pages: list[Page]) -> list[tuple[str, str, str]]:
    """(the panel's class, its docs address, the page) from each page's
    `panels:`, as `ClassName#section`."""
    found = []
    for page in pages:
        for item in str(page.meta.get("panels", "")).split(","):
            if item.strip():
                name, _, anchor = item.strip().partition("#")
                found.append((name.strip(), page.url + (f"#{anchor.strip()}" if anchor.strip() else ""), page.name))
    return found


def docs_pages(pages: list[Page]) -> str:
    rows = "".join(f'\t"{name}": "{url}",\n' for name, url, _ in sorted(panels(pages)))
    return ("## The docs page of each panel the window opens, which Help, Documentation\n"
            "## opens while that panel is in front (Shell.docs_page): made by\n"
            "## tools/docs_site.py --write from the `panels:` in docs-site's page heads.\n"
            "## Edit those, not this; tests/test_docs_site.py fails while the two differ.\n"
            f'class_name DocsPages\n\nconst SITE := "{SITE}"\n\nconst PANELS := {{\n{rows}}}\n')


def made_files(pages: list[Page]) -> dict[Path, str]:
    """Every file the docs make that is committed, and what it must say."""
    tools = {t["name"]: t for t in all_tools()}
    files = {GUIDE_GD: connector_guide(), PAGES_GD: docs_pages(pages)}
    for name, doc in tool_docs().items():
        if name in tools:
            files[doc.path] = with_said(doc, tools[name])
    return files


def write() -> list[Path]:
    _, pages = load()
    changed = []
    for path, text in made_files(pages).items():
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8")
            changed.append(path)
    return changed


def head_problems(pages: list[Page]) -> list[str]:
    """Every page a person reads has its head for the AI (ai:), the files the
    docs make are what they make, and each panel named is a class of the
    app's with a section of that name."""
    problems = []
    for page in pages:
        if not page.meta.get("generated") and not str(page.meta.get("ai", "")).strip():
            problems.append(f"{page.name}.md has no `ai:` in its head: a paragraph saying, to an assistant, "
                            "what the page's feature is and does")
        if not isinstance(page.meta.get("rules", []), list):
            problems.append(f"{page.name}.md's `rules:` is not a list (one `  - rule` a line under it)")
    classes = set()
    for script in (ROOT / "src").rglob("*.gd"):
        found = re.search(r"^class_name (\w+)", script.read_text(encoding="utf-8"), re.M)
        if found:
            classes.add(found.group(1))
    anchors = {p.name: {a for _, a, _ in p.headings} for p in pages}
    seen: set[str] = set()
    for name, url, page in panels(pages):
        if name in seen:
            problems.append(f"the panel {name} is in two pages' `panels:`")
        seen.add(name)
        if name not in classes:
            problems.append(f"{page}.md names the panel {name}, which is no class_name in src/")
        anchor = url.partition("#")[2]
        if anchor and anchor not in anchors[page]:
            problems.append(f"{page}.md sends the panel {name} to #{anchor}, which is no heading on it")
    for path, text in made_files(pages).items():
        if not path.exists() or path.read_text(encoding="utf-8") != text:
            problems.append(f"{path.relative_to(ROOT)} is not what docs-site/ makes: tools/docs_site.py --write"
                            + (" (after reading the doc against the tool's new words)" if path.suffix == ".md" else ""))
    return problems


# -- the check -------------------------------------------------------------------


def internal() -> list[tuple[str, str]]:
    rules = []
    for line in (SRC / "internal.txt").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        pattern, _, why = line.partition("  #")
        if not why.strip():
            raise SystemExit(f"docs: docs-site/internal.txt says no why for {pattern.strip()}")
        rules.append((pattern.strip(), why.strip()))
    return rules


def is_internal(feature: dict, rules: list[tuple[str, str]]) -> bool:
    for pattern, _ in rules:
        if pattern.startswith("entry:"):
            if fnmatch.fnmatchcase(feature.get("entry", ""), pattern[6:]):
                return True
        elif fnmatch.fnmatchcase(feature["id"], pattern):
            return True
    return False


def routes() -> set[str]:
    """The site's own addresses a docs page may link to, besides its pages."""
    found = {"/", "/app", "/docs", "/collections", "/sitemap.xml", "/changelog"}
    for page in WEB.glob("*.html"):
        if not page.name.startswith("_") and page.stem not in ("index", "404", "authorize"):
            found.add(f"/{page.stem}")
    return found


def moved() -> dict[str, str]:
    """docs-site/_moved.json: a page's old name and its new one, which
    tools/deploy.sh answers with a 308 so an old link still lands."""
    found = json.loads((SRC / "_moved.json").read_text(encoding="utf-8"))
    return {old: new for old, new in found.items() if not old.startswith("$")}


def check() -> list[str]:
    problems: list[str] = []
    nav, pages = load()
    names = {p.name for p in pages}
    for old, new in moved().items():
        if new not in names:
            problems.append(f"docs-site/_moved.json sends {old} to {new}, which is no page")
        if old in names:
            problems.append(f"docs-site/_moved.json moves {old}, which is still a page")
    features = json.loads(FEATURES.read_text(encoding="utf-8"))["features"]
    ids = {f["id"] for f in features}
    rules = internal()
    covered: dict[str, str] = {}
    for page in pages:
        for feature, anchor in page.covers.items():
            if feature in covered:
                problems.append(f"{feature} is covered twice: {covered[feature]} and {page.url}#{anchor}")
            covered[feature] = f"{page.url}#{anchor}"
            if feature not in ids:
                problems.append(f"{page.name}.md covers {feature}, which the feature map does not have "
                                "(renamed or gone? see .claude/skills/verify/features.json)")
    for feature in features:
        if feature["id"] not in covered and not is_internal(feature, rules):
            problems.append(f"{feature['id']} ({feature['entry']}) is in no docs page: add it to a section's "
                            "<!-- covers --> in docs-site/, or to docs-site/internal.txt with why a person never meets it")
    for pattern, _ in rules:
        if not pattern.startswith("entry:") and "*" not in pattern and pattern not in ids:
            problems.append(f"docs-site/internal.txt names {pattern}, which the feature map does not have")
    # Every link and picture on every page goes somewhere.
    anchors = {p.url: {a for _, a, _ in p.headings} for p in pages}
    for page in pages:
        for attr, target in re.findall(r'(href|src)="([^"]+)"', page.html):
            target = html.unescape(target)
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, frag = target.partition("#")
            path = path.split("?")[0]
            if not path:
                path = page.url
            if path.startswith("/docs"):
                if path not in anchors:
                    problems.append(f"{page.name}.md links to {target}: no such docs page")
                elif frag and frag not in anchors[path] and not frag.startswith("cmd-"):
                    problems.append(f"{page.name}.md links to {target}: no such heading on {path}")
            elif path.startswith(("/img/", "/m/", "/u/", "/c/", "/api/", "/oauth/", "/library/")):
                if path.startswith("/img/") and not (WEB / path.lstrip("/")).exists():
                    problems.append(f"{page.name}.md shows {target}, which is not in web/")
            elif path not in routes():
                problems.append(f"{page.name}.md links to {target}, which is no page of the site")
    problems += tool_problems(pages)
    problems += head_problems(pages)
    return problems


def main(argv: list[str]) -> int:
    if argv == ["--check"]:
        problems = check()
        for problem in problems:
            print(f"docs: {problem}")
        if problems:
            print(f"docs: {len(problems)} problem(s)")
            return 1
        _, pages = load()
        covered = sum(len(p.covers) for p in pages)
        print(f"docs: {len(pages)} pages, {covered} features covered, every link resolves")
        return 0
    if argv == ["--write"]:
        for path in write():
            print(f"docs: wrote {path.relative_to(ROOT)}")
        return 0
    if len(argv) != 1 or argv[0].startswith("-"):
        print((__doc__ or "").strip())
        return 2
    n = build(Path(argv[0]))
    print(f"docs: {n} page(s) in {argv[0]}/docs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
