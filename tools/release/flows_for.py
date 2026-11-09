#!/usr/bin/env python3
"""The preview checks whose flows visit what a change touched.

    tools/release/flows_for.py                 changes since main
    tools/release/flows_for.py --since REF     since another ref
    tools/release/flows_for.py web/gallery.js api/_owned.js

The feature map follows imports, and a browser flow reaches a page by its
address, not by an import, so `featuremap affected` never lists one. Three
times a unit broke a flow it did not know visited its page: share_flow after
Versions, follows_flow on Designers, and share_flow, tested and builds on
Discovery's gallery shelves, which held m84 for an hour (2026-10-19).

A changed page is its address. A script or stylesheet is the address of
every page that loads it, following imports between scripts. An API file is
its route and the addresses tools/deploy.sh sends to it (/m/ to share.js).
A helper (api/_x.js) is the routes of the API files that import it. Then
every flow in tools/web that names one of those addresses, and the
preview_checks.sh names that run it. A changed flow is its own checks, and a
changed module in tools/web the checks of every flow that imports it: a flow
fixed on its own branch was first run on the release preview, and four
release previews held on checks on 2026-10-22.

A flow reaches the app's window by its controls' names, as it reaches a page
by its address: a Godot script in src/ is every flow that quotes a control
name the script gives ("page_canvas", or "page_picture_4" from
"page_picture_%d"). booklet_edit_flow drives the page editor and was not
named for a change to it, and rel-m226 held on it (2026-10-30). What a
script reaches through other scripts is left to the feature map.

A name is a key of what the script's controls_by_name returns, whatever
its shape: words with spaces ("part search"), one word ("techniques"), or
made ("technique " + its name, "tile picture %d", "tool_" + a command,
prefix + "_comments"). Only words joined by underscores were read, so the
parts bin named no flow, and bin_flow went unrun on rel-m273 to m276 and on
binrow's change to the bin's shelves (2026-11-09).

A flow that crawls every page of the site names none of them: it says so
with a line `// flows_for: every page` (coming_soon_check.mjs), and visits
whatever page of web/ or the documentation changed (2026-11-07).

What a session hears through the connector is made in the tab, and reaches
it at /api/mcp: a script that shapes it (RELAY_FROM) is the relay's address
too, so it names every flow that drives the relay, as api/mcp.js does.
"""

from __future__ import annotations

import argparse
import bisect
import functools
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
WEB, API, FLOWS = ROOT / "web", ROOT / "api", ROOT / "tools" / "web"
DOCS_FROM = {"tools/docs_site.py", "web/docs.css", "web/docs.js", "tools/mcp_tools.json",
             "src/ui/controls_hint.gd", "CHANGELOG.md", ".claude/skills/verify/features.json"}
# What a session hears through the connector: the tab's end of the relay (the
# method said once, the sittings, every answer sent), the method's words and
# the guide, the tools' answers and jobs, what a client that shows pages is
# given, and the tool list the relay serves. connector_guide.gd named no flow,
# and claude_connector.gd only those quoting a tool it happened to name; the
# method's first words changed there in rel-m237, and model_view, which
# pinned them, went unrun until rel-m250 (mcpview, 2026-11-02).
RELAY_FROM = {"src/net/claude_connector.gd", "src/ai/connector_guide.gd", "src/ai/assistant.gd",
              "src/net/command_socket.gd", "src/net/tool_jobs.gd", "src/net/model_views.gd",
              "src/net/model_scene.gd", "src/net/viewer_tools.gd", "tools/mcp_tools.json"}


def changed(since: str) -> list[str]:
    out = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", f"{since}...HEAD"],
                         capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def page_address(html: Path) -> str:
    return "/" if html.stem == "index" else f"/{html.stem}"


def loaders(name: str, seen: set[str]) -> set[str]:
    """The addresses of the pages that load web/[name], directly or through
    another script that imports it."""
    if name in seen:
        return set()
    seen.add(name)
    found: set[str] = set()
    # Loaded, not mentioned: a src or href, or an import.
    quoted = rf"""["'](?:/|\./)?{re.escape(name)}(?:\?[^"']*)?["']"""
    pattern = re.compile(rf"""(?:src|href)\s*=\s*{quoted}|from\s+{quoted}|import\(\s*{quoted}""")
    for html in WEB.glob("*.html"):
        if pattern.search(html.read_text(errors="ignore")):
            found.add(page_address(html))
    for script in WEB.glob("*.js"):
        if script.name != name and pattern.search(script.read_text(errors="ignore")):
            found |= loaders(script.name, seen)
    return found


def routed_to(api_name: str) -> set[str]:
    """Addresses tools/deploy.sh sends to api/[api_name]: the literal start
    of each route's source, as far as it goes before a pattern begins."""
    deploy = (ROOT / "tools" / "deploy.sh").read_text(errors="ignore")
    found = {f"/api/{api_name}"}
    for source, dest in re.findall(r'"src":\s*"([^"]+)",\s*"dest":\s*"([^"]+)"', deploy):
        if re.match(rf"/api/{re.escape(api_name)}(\?|$)", dest):
            literal = re.split(r"[(\[.?*+\\$]", source)[0]
            if len(literal) > 1:
                found.add(literal)
    return found


def addresses(path: str, seen: set[str] | None = None) -> set[str]:
    # api/_auth.js and api/_oc.js import each other: each file is followed
    # once (2026-10-24; a change to _oc.js recursed until Python gave up).
    seen = set() if seen is None else seen
    if path in seen:
        return set()
    seen.add(path)
    p = Path(path)
    relay = {"/api/mcp"} if path in RELAY_FROM else set()
    # The documentation is made, not copied (tools/docs_site.py): its words,
    # its maker, its own stylesheet and script, and what it is made from are
    # the address /docs.
    if p.parts[:1] == ("docs-site",) or path in DOCS_FROM:
        return relay | {"/docs"}
    if p.parts[:1] == ("web",):
        if p.suffix == ".html":
            return {page_address(p)}
        if p.suffix in (".js", ".css"):
            return loaders(p.name, set())
        return set()
    if p.parts[:1] == ("api",) and p.suffix == ".js":
        name = p.stem
        if not name.startswith("_"):
            return routed_to(name)
        found: set[str] = set()
        pattern = re.compile(rf"""["']\./{re.escape(p.name)}["']""")
        for api in API.glob("*.js"):
            if api.name != p.name and pattern.search(api.read_text(errors="ignore")):
                found |= addresses(f"api/{api.name}", seen)
        return found
    return relay


# A control name: words joined by underscores ("page_add_arrow"), quoted.
CONTROL = re.compile(r'"([a-z][a-z0-9]*(?:_[a-z0-9]+)+)"')
# A name made with a number ("page_picture_%d"): its words before the number.
NUMBERED = re.compile(r'"([a-z][a-z0-9]*(?:_[a-z0-9]+)*_)%[ds]')
# What a flow quotes that a name could be (words, digits, spaces, _ . -),
# and a template's words before its first ${...}: the start of a name it
# makes. A message ("booklet edit flow: ...") is no name, nor a lone word
# compared or given as a value (op === "list", { op: "list" }: the API's);
# "signed_in" compared is the state a script gives, and is. Nor is a lone
# word the page's own document is searched by (getElementById("view")).
QUOTED = re.compile(r"""(["'`])([a-z][a-z0-9 _.\-]*(?:\$\{[^"'`\n]*)?)\1""")
PAGES_OWN = re.compile(r"(?:getElementById|querySelector(?:All)?|closest|contains|[gs]etAttribute"
                       r"|getBy\w+|locator|waitForEvent|\.on|\.once|\.get)\(\s*$")
# A name read as a property: c.parts_rail, or any read straight off the
# page's copy, (window.brickworksControls || {}).tooltip.
PROPERTY = re.compile(r"(?<=[\w$)\]])\.([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\b"
                      r"|brickworksControls(?:\s*\|\|\s*\{\s*\}\s*\))?\.([a-z]\w*)")

# What gives the page the window's names (Main._tell_page): each script's
# controls_by_name, the view cube's corners and Main's gathering of them.
GIVERS = ("controls_by_name", "face_points", "_page_controls")
FUNC = re.compile(r"^([ \t]*)(?:static\s+)?func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*(\w+))?", re.M)
SPEC = re.compile(r"%[-+ #0-9.]*[a-zA-Z]")


def _functions(text: str) -> dict[str, tuple[str, str, str]]:
    """Each function of a GDScript: its body, what it returns, its parameters."""
    found: dict[str, tuple[str, str, str]] = {}
    lines = text.split("\n")
    starts = [0] + [m.end() for m in re.finditer("\n", text)]
    for m in FUNC.finditer(text):
        at = bisect.bisect_right(starts, m.end()) - 1
        body = [lines[at][m.end() - starts[at]:]]
        for at in range(at + 1, len(lines)):
            line = lines[at]
            words = line.lstrip()
            if words and not words.startswith("#") and len(line) - len(words) <= len(m.group(1)):
                break
            body.append(line)
        was = found.get(m.group(2), ("", "", ""))
        found[m.group(2)] = (was[0] + "\n".join(body) + "\n", m.group(4) or was[1], m.group(3) + was[2])
    return found


def _strings(code: str) -> tuple[list[tuple[int, int, str, int]], dict[int, int]]:
    """Each "..." in GDScript [code], outside comments and '...': where it
    starts and ends, its words, and the bracket it is in (-1, none); and
    where each bracket closes."""
    found: list[tuple[int, int, str, int]] = []
    closes: dict[int, int] = {}
    opened: list[int] = []
    at = 0
    while at < len(code):
        c = code[at]
        if c == "#":
            at = code.find("\n", at)
            if at < 0:
                break
        elif c in "\"'":
            end = at + 1
            while end < len(code) and code[end] not in (c, "\n"):
                end += 2 if code[end] == "\\" else 1
            if c == '"':
                found.append((at, end + 1, code[at + 1:end], opened[-1] if opened else -1))
            at = end
        elif c in "([{":
            opened.append(at)
        elif c in ")]}" and opened:
            closes[opened.pop()] = at
        at += 1
    return found, closes


def _given(code: str, text: str) -> set[str]:
    """The names the strings of [code] give a dictionary: "part search",
    "techniques", or the shape of one made, "tile picture %d", "tool_%s",
    "%s_comments". Not a call's argument, a comparison, an index read or a
    value; [text] is the whole script, for its locals."""
    found: set[str] = set()
    strings, closes = _strings(code)
    for start, end, words, inside in strings:
        if not re.match(r"_*[a-z]", words):
            continue
        before, after = code[:start].rstrip(), code[end:].lstrip()
        bracket = code[inside] if inside >= 0 else ""
        if bracket == "(":
            # find_children("favourite_*"): each it finds is named by its own name.
            if re.fullmatch(r"[a-z][^*%]*\*", words):
                found.add(words[:-1] + "%s")
            continue
        if before.endswith(("==", "!=")) or after.startswith(("==", "!=")):
            continue
        if bracket == "[":
            if re.match(r"[\w\])]", code[inside - 1:inside]):
                if not re.match(r"\s*=(?!=)", code[closes.get(inside, len(code)) + 1:]):
                    continue
            elif code[:inside].rstrip().endswith("%"):
                continue
        if bracket == "{" and not after.startswith((":", "+", "%")) and not before.endswith("+"):
            continue
        if "%" in words and not (after.startswith("%") and not after.startswith("%=")):
            continue
        shape = SPEC.sub(lambda s: "%d" if s.group().endswith("d") else "%s", words)
        if after.startswith("+") and not after.startswith("+="):
            shape += "%s"
        if before.endswith("+"):
            # A local's own start is named where it is made: key + "_done".
            local = re.search(r"(\w+)\s*\+$", before)
            if local and re.search(rf"^[ \t]+var\s+{local.group(1)}\b", text, re.M):
                continue
            shape = "%s" + shape
        found.add(shape)
    return found


def _giving(functions: dict[str, tuple[str, str, str]]) -> set[str]:
    """GIVERS, and the functions of the same script they gather names
    from: one that returns a Dictionary or a String, or is handed one."""
    giving = {name for name in GIVERS if name in functions}
    while True:
        more = {name for g in giving for name in re.findall(r"\b(\w+)\(", functions[g][0])
                if name in functions and name not in giving
                and (functions[name][1] in ("Dictionary", "String") or "Dictionary" in functions[name][2])}
        if not more:
            return giving
        giving |= more


def _gives(text: str) -> set[str]:
    """The names, and shapes of names, a script gives the window: what
    its givers put in their dictionaries, and what is put anywhere under a
    member they hand on whole (page_editor's _named)."""
    functions = _functions(text)
    found: set[str] = set()
    handed: set[str] = set()
    for name in _giving(functions):
        body = functions[name][0]
        found |= _given(body, text)
        handed |= set(re.findall(r"\breturn\s+(\w+)\s*(?:$|if\b)", body, re.M))
        handed |= set(re.findall(r"\b(\w+)\.duplicate\(", body))
        handed |= set(re.findall(r"\bmerged?\(\s*(\w+)\s*\)", body))
        handed |= {m[1] for m in re.findall(r"\w+\[(\w+)\]\s*=\s*(\w+)\[\1\]", body)}
    _, closes = _strings(text)
    for member in handed & set(re.findall(r"^var\s+(\w+)", text, re.M)):
        for m in re.finditer(rf"\b{member}\[", text):
            close = closes.get(m.end() - 1)
            if close is not None and re.match(r"\s*=(?!=)", text[close + 1:]):
                found |= _given(text[m.end():close], text)
    return found


@functools.cache
def _app_scripts() -> tuple[tuple[str, str], ...]:
    return tuple((str(p.relative_to(ROOT)), p.read_text(errors="ignore"))
                 for p in sorted((ROOT / "src").rglob("*.gd")) if p.parts[len(ROOT.parts) + 1] != "dev")


@functools.cache
def _namings() -> tuple[tuple[str, tuple[tuple[str, str], ...]], ...]:
    """Each app script that gives the window names, and each name its
    givers put in a dictionary: the key's code, and its line with the lines
    opening the blocks it is in."""
    found = []
    for _, text in _app_scripts():
        if not any(giver in text for giver in GIVERS):
            continue
        functions = _functions(text)
        put: list[tuple[str, str]] = []
        for name in _giving(functions):
            body = functions[name][0]
            _, closes = _strings(body)
            starts = [0] + [m.end() for m in re.finditer("\n", body)]
            lines = body.split("\n")
            for m in re.finditer(r"\w\[", body):
                close = closes.get(m.end() - 1)
                value = re.match(r"\s*=(?!=)[^\n]*", body[close + 1:]) if close is not None else None
                if not value:
                    continue
                at = bisect.bisect_right(starts, m.start()) - 1
                context = [body[starts[at]:close + 1 + value.end()]]
                depth = len(lines[at]) - len(lines[at].lstrip())
                for line in reversed(lines[:at]):
                    words = line.lstrip()
                    if words and not words.startswith("#") and len(line) - len(words) < depth:
                        context.append(line)
                        depth = len(line) - len(words)
                put.append((body[m.end():close], "\n".join(context)))
        found.append((text, tuple(put)))
    return tuple(found)


def _named_for(cls: str) -> set[str]:
    """The names another script gives a control of class [cls]: one whose
    line or blocks name the class (a tooltip up, Tooltips.is_tooltip;
    About's links, Credits.LIST), and one whose line takes it from a member
    of the class (Main's named["parts_rail"] = _bin_dock.rail(), a SideDock)
    or from a meta a value of the class was set in (the bin's "tile picture
    %d", get_meta("tile"), a ThumbTile)."""
    found: set[str] = set()
    for text, put in _namings():
        if cls not in text or not re.search(rf"\b{cls}\b", text):
            continue
        held = re.findall(rf"^var\s+(\w+)\s*:\s*{cls}\b", text, re.M)
        made = set(re.findall(rf"\bvar\s+(\w+)\s*(?::\s*{cls}\b|:=\s*{cls}\.new\()", text))
        metas = [key for key, value in re.findall(r'set_meta\(\s*"(\w+)"\s*,\s*(\w+)\s*\)', text) if value in made]
        named = re.compile(rf"\b{cls}\b")
        holds = re.compile("|".join([rf"\b{w}\b" for w in held] + [rf'get_meta\(\s*"{key}"' for key in metas]) or "$^")
        for key, context in put:
            if named.search(context) or holds.search(context.split("\n", 1)[0]):
                found |= _given(key, text)
    return found


def controls(path: str) -> tuple[set[str], set[str], set[str]]:
    """The control names a Godot script in src/ quotes, the words before
    the number of those it numbers, and the names and shapes it gives the
    window (or another script gives its controls); none for a probe in
    src/dev."""
    p = Path(path)
    if p.parts[:1] != ("src",) or p.parts[:2] == ("src", "dev") or p.suffix != ".gd":
        return set(), set(), set()
    file = ROOT / p
    if not file.exists():
        return set(), set(), set()
    text = file.read_text(errors="ignore")
    given = _gives(text)
    cls = re.search(r"^class_name\s+(\w+)", text, re.M)
    if cls:
        given |= _named_for(cls.group(1))
    return set(CONTROL.findall(text)), set(NUMBERED.findall(text)), given


def _shape(shape: str) -> str:
    return "".join({"%d": r"\d+", "%s": ".+"}.get(part, re.escape(part)) for part in re.split(r"(%[ds])", shape))


@functools.cache
def _shapes(given: frozenset[str]) -> tuple[re.Pattern[str] | None, tuple[str, ...]]:
    """One pattern for the shapes of [given], and the words each starts with."""
    shapes = sorted(s for s in given if "%" in s)
    pattern = re.compile("|".join(f"(?:{_shape(s)})" for s in shapes)) if shapes else None
    return pattern, tuple(head for head in (s.split("%")[0] for s in shapes) if head)


@functools.cache
def _flow_words(text: str) -> tuple[frozenset[str], frozenset[str], frozenset[str]]:
    """What a flow quotes that could be a name, the starts of the names it
    makes, and the names it reads as properties."""
    quoted: set[str] = set()
    starts: set[str] = set()
    for m in QUOTED.finditer(text):
        word = m.group(2)
        before = text[max(0, m.start() - 24):m.start()]
        if re.fullmatch(r"[a-z0-9]+", word) and (
                before.rstrip().endswith(("==", "!=")) or re.search(r"\w:\s*$", before)
                or PAGES_OWN.search(before) or text[m.end():m.end() + 8].lstrip().startswith(("==", "!="))):
            continue
        if "${" in word:
            starts.add(word.split("${")[0])
        else:
            quoted.add(word)
    read = {name for pair in PROPERTY.findall(text) for name in pair if name}
    return frozenset(quoted), frozenset(starts), frozenset(read)


def reaches(flow: Path, names: set[str], numbered: set[str], given: set[str] = frozenset()) -> set[str]:
    """The names of [names] the flow quotes, and those of [numbered] with a
    number after them; the names [given] (a name, or a shape: "tile
    picture %d") it quotes or reads (c.parts_rail); and a name it makes
    (`tile picture ${n}`) that starts as a shape does."""
    quoted, starts, read = _flow_words(flow.read_text(errors="ignore"))
    pattern, heads = _shapes(frozenset(given))
    heads = heads + tuple(numbered)

    def gives(word: str) -> bool:
        return word in given or (pattern is not None and pattern.fullmatch(word) is not None)

    found = {name for name in read if gives(name)}
    found |= {word for word in quoted if word in names or gives(word)
              or any(word.startswith(start) and word[len(start):][:1].isdigit() for start in numbered)}
    found |= {start + "${…}" for start in starts if any(start.startswith(head) for head in heads)}
    return found


def importers(name: str, seen: set[str]) -> set[str]:
    """tools/web/[name] and every module there that imports it, directly or
    through another that does."""
    if name in seen:
        return set()
    seen.add(name)
    found = {name}
    pattern = re.compile(rf"""(?:from\s+|import\(\s*)["']\./{re.escape(name)}["']""")
    for module in FLOWS.glob("*.mjs"):
        if module.name != name and pattern.search(module.read_text(errors="ignore")):
            found |= importers(module.name, seen)
    return found


def checks() -> dict[str, list[str]]:
    """Flow file name -> the preview_checks.sh names that run it."""
    text = (ROOT / "tools" / "release" / "preview_checks.sh").read_text(errors="ignore")
    named: dict[str, list[str]] = {}
    for name, flow in re.findall(r'^\s*\[([a-z_0-9]+)\]="tools/web/([a-z_0-9]+\.mjs)', text, re.M):
        named.setdefault(flow, []).append(name)
    return named


# A flow that visits every page of the site, and says so.
EVERY_PAGE = re.compile(r"^// flows_for: every page$", re.M)


def a_page(address: str) -> bool:
    """Whether [address] is a page the site is put together with
    (tools/site.py): one of web/'s, or the documentation's."""
    if address in ("/", "/docs"):
        return True
    return re.fullmatch(r"/[a-z0-9-]+", address) is not None and (WEB / f"{address[1:]}.html").exists()


def visits(flow: Path, address: str) -> bool:
    text = flow.read_text(errors="ignore")
    if EVERY_PAGE.search(text) and a_page(address):
        return True
    if address == "/":
        # The home page: a page sent to the site itself and nothing after it.
        # A bare goto(url) is no sign: the app's flows are given the app's own.
        return re.search(r"""goto\(\s*`\$\{[^}]+\}/`""", text) is not None
    # The address begins a path ("${site}/gallery", "/m/"), so /admin is not
    # found inside /api/admin.
    return re.search(rf"""(?<![A-Za-z0-9_.-]){re.escape(address)}(?![A-Za-z0-9_-])""", text) is not None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*")
    parser.add_argument("--since", default="main")
    args = parser.parse_args()
    files = args.files or changed(args.since)
    wanted: dict[str, set[str]] = {}
    for path in files:
        for address in addresses(path):
            wanted.setdefault(address, set()).add(path)
    modules = [p for p in files if Path(p).parent == Path("tools/web") and p.endswith(".mjs")]
    scripts = {p: controls(p) for p in files}
    scripts = {p: given for p, given in scripts.items() if any(given)}
    if not wanted and not modules and not scripts:
        print("no page, API route, control or browser flow changed: nothing for the browser flows here")
        return 0
    named = checks()
    found: dict[str, set[str]] = {}
    unchecked: set[str] = set()
    for flow in sorted(FLOWS.glob("*.mjs")):
        hits = {a for a in wanted if visits(flow, a)}
        if not hits:
            continue
        names = named.get(flow.name)
        if not names:
            unchecked.add(flow.name)
            continue
        for name in names:
            found.setdefault(name, set()).update(f"{a} ({', '.join(sorted(wanted[a]))})" for a in hits)
    for flow in sorted(FLOWS.glob("*.mjs")):
        for path, given in scripts.items():
            hits = reaches(flow, *given)
            if not hits:
                continue
            if not named.get(flow.name):
                unchecked.add(flow.name)
                continue
            for name in named[flow.name]:
                found.setdefault(name, set()).add(f"{path} ({', '.join(sorted(hits)[:4])})")
    orphans: set[str] = set()
    for path in modules:
        runs = [(flow, name) for flow in sorted(importers(Path(path).name, set())) for name in named.get(flow, [])]
        if not runs:
            orphans.add(Path(path).name)
        for flow, name in runs:
            found.setdefault(name, set()).add(f"{path} ({'its flow' if flow == Path(path).name else 'imported'})")
    for name in sorted(found):
        print(f"{name:16} {', '.join(sorted(found[name]))}")
    if unchecked:
        print(f"also visit them, with no preview check: {', '.join(sorted(unchecked))}")
    if orphans:
        print(f"changed, and no preview check runs them: {', '.join(sorted(orphans))}")
    # site and frames run on every ship (tools/release/ship.sh) whatever is named.
    print("checks: " + (" ".join(sorted(found)) or "none named; site and frames run on every ship"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
