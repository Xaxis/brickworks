#!/usr/bin/env python3
"""The names a row of /admin › Analytics may hold, as closed sets the server
keeps (infix, 2026-11-18; docs/ANALYTICS.md, api/_analytics.js).

A beacon is the browser's word, and anybody can send one. Before this, any
name that fit the pattern was a row and a line in the owner's read: 4,000
made-up names made the read 948 KB (inreview H2). Now a name is kept only
when the code that counts it names it:

  site view      the site's own pages (each English page's canonical path)
                 and web/tally.js's page templates
  site act       an API web/tally.js watches (its ACTS) and an op that API's
                 code answers, or the HTTP method it answers without one
  studio tool    the studio's tools (src/ui/edit_verbs.gd MODES)
  studio panel   web/tally.js's PANELS
  studio press   a control the studio names to the page (every
                 controls_by_name in src/, and the view cube's faces: each
                 word its body names, and its file's words where it keys
                 by a variable); a name made from a prefix and a number or
                 a word of its own file is a family: the prefix and each
                 word it can take
  studio command a command of the studio's palette (src/ui/shell.gd)
  studio run     Simulate, Render (by kind), a booklet, Together
  error          a script of the site's (web/*.js) or the studio's
                 (src/**/*.gd) and a line

  python3 tools/insights_names.py           writes api/_insights_names.js
  python3 tools/insights_names.py --check   says whether it is up to date
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "api" / "_insights_names.js"
NAME = re.compile(r"^[a-z0-9_:/#.-]{1,60}$")


def name_of(text: str, digits: bool = False) -> str:
    """web/tally.js nameOf, for ASCII: lower case, spaces as _, digits as #."""
    plain = re.sub(r"\s+", "_", text.strip().lower())
    if not digits:
        plain = re.sub(r"[0-9]+", "#", plain)
    return re.sub(r"[^a-z0-9_:/#.-]", "", plain)[:60]


def strings(text: str) -> list[str]:
    return re.findall(r'"((?:[^"\\\n]|\\.){1,60})"', text)


def bodies(text: str, func: str) -> list[str]:
    """Each body of [func] in a GDScript file: its indented lines."""
    return [m.group(1) for m in re.finditer(rf"^func {func}\([^\n]*\n((?:[ \t]+[^\n]*\n|[ \t]*\n)*)", text, re.M)]


def tally_js() -> str:
    return (ROOT / "web" / "tally.js").read_text(encoding="utf-8")


def site_views() -> set[str]:
    out = {"/other"}
    src = tally_js()
    out.update(re.search(r'TEMPLATE_NAMES = "([^"]+)"', src).group(1).split(" "))
    for page in (ROOT / "web").rglob("*.html"):
        rel = page.relative_to(ROOT / "web").as_posix()
        if re.match(r"^(de|fr|es)/", rel) or rel.startswith(("_", "e/", "b/")):
            continue
        found = re.search(r'<link rel="canonical" href="https?://[^/"]+(/[^"]*)"', page.read_text(encoding="utf-8", errors="replace"))
        if not found:
            continue
        path = re.sub(r"^/(de|fr|es)(?=/|$)", "", found.group(1)).rstrip("/") or "/"
        if re.match(r"^/[a-z0-9_/.-]{0,79}$", path):
            out.add(path)
    return out


def acts() -> set[str]:
    src = tally_js()
    fns = re.findall(r'"([a-z_]+)"', re.search(r"const ACTS = new Set\(\[([^\]]+)\]\)", src).group(1))
    skip = set(re.findall(r'"([a-z_]+)"', re.search(r"const NOT_ACTS = new Set\(\[([^\]]+)\]\)", src).group(1)))
    out = {"account.signed_in"}
    for fn in fns:
        files = [ROOT / "api" / f"{fn}.js"]
        text = "\n".join(f.read_text(encoding="utf-8") for f in files if f.exists())
        ops: set[str] = set()
        ops.update(re.findall(r'\bop\s*===\s*"([a-z_]+)"', text))
        ops.update(re.findall(r'"([a-z_]+)"\s*===\s*op\b', text))
        for listed in re.findall(r"\[((?:\s*\"[a-z_]+\",?)+)\s*\]\.includes\(op\)", text):
            ops.update(re.findall(r'"([a-z_]+)"', listed))
        for listed in re.findall(r"(?:const|let) [A-Z_]+ = (?:new Set\()?\[((?:\s*\"[a-z_]+\",?\s*)+)\]", text):
            ops.update(re.findall(r'"([a-z_]+)"', listed))
        # An op table: { name: () => ..., } as api/admin.js keeps one.
        ops.update(re.findall(r"^\s+([a-z_]+): (?:async )?\([^)]*\) =>", text, re.M))
        ops.update(["post", "put", "patch", "delete"])
        out.update(f"{fn}.{op}" for op in ops if op not in skip and NAME.match(f"{fn}.{op}"))
    return out


def modes() -> set[str]:
    text = (ROOT / "src" / "ui" / "edit_verbs.gd").read_text(encoding="utf-8")
    block = re.search(r"const MODES: Array\[String\] = \[([^\]]+)\]", text).group(1)
    return set(re.findall(r'"([a-z_]+)"', block))


def panels() -> set[str]:
    block = re.search(r"const PANELS = \{(.*?)\n\};", tally_js(), re.S).group(1)
    return set(re.findall(r"(?:^|[\s,])([a-z_]+): ", block))


def commands() -> set[str]:
    out: set[str] = set()
    for path in (ROOT / "src").rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        if "_add(" not in text and "command(" not in text:
            continue
        out.update(name_of(n) for n in re.findall(r'\b_add\(\s*"([a-z][a-z0-9_]*)"', text))
        # The tables a loop adds: [["name", "Words", ...], ...].
        if path.name == "shell.gd":
            out.update(name_of(n) for n in re.findall(r'\[\s*"([a-z][a-z0-9_]*)",\s*"[A-Z0-9]', text))
            for const in re.findall(r'const COMMAND(?:: String)? = "([a-z_]+)"', text):
                out.add(name_of(const + "1"))
    for path in (ROOT / "src").rglob("*.gd"):
        for const in re.findall(r'const COMMAND(?:: String)? := ?"([a-z_]+)"|const COMMAND = "([a-z_]+)"',
                                path.read_text(encoding="utf-8")):
            word = next(c for c in const if c)
            out.add(name_of(word + "1"))
    out.add("find_part")
    return {n for n in out if n and NAME.match(n)}


def controls() -> tuple[set[str], dict[str, int], list[list[str]]]:
    """The studio's named controls: exact names, families {prefix: its file's
    words, by place}, and each file's words. A family also ends in a number
    (#), a command or a tool."""
    exact: set[str] = set()
    families: dict[str, int] = {}
    files: list[list[str]] = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        # Main's _page_controls names some of its own, and a body that
        # merges a helper's names (named.merge(_palette_controls())) has
        # that helper's too.
        found = bodies(text, "controls_by_name") + bodies(text, "face_points") + bodies(text, "_page_controls")
        for body in list(found):
            for helper in re.findall(r"\.merge\(\s*(_?[a-z][a-z0-9_]*)\(\)", body):
                found += bodies(text, helper)
        if not found:
            continue
        # The words a family in this file can end in: its own short words,
        # as a name.
        words = sorted({w for w in (name_of(s) for s in strings(text)) if re.match(r"^[a-z0-9_#]{1,24}$", w)})
        place = len(files)
        used = False
        for body in found:
            # A key as the page is told it, words and all ("part search"),
            # which the page's nameOf makes part_search.
            for key in re.findall(r'"([A-Za-z0-9_ ]+)"\s*:', body):
                exact.add(name_of(key))
            for key in re.findall(r'\[\s*"([A-Za-z0-9_ ]+)"\s*\]\s*=', body):
                exact.add(name_of(key))
            # Any other word the body names (a key chosen from a list:
            # name if name in ["new", "open", "save"] else "tool_" + name).
            for word in strings(body):
                if re.match(r"^[A-Za-z0-9_ ]{1,40}$", word):
                    exact.add(name_of(word))
            # A key held in a variable (out[name] = _arrows[name]) is one of
            # its file's own words.
            if re.search(r"\[\s*(?:str\()?[a-z_][a-z0-9_.]*\)?\s*\]\s*=", body):
                exact.update(words)
            for line in body.splitlines():
                # "prefix_" + word, "prefix %d" % n, and a key built in a variable first.
                for prefix in (re.findall(r'"([A-Za-z0-9_ ]*[_ ])"\s*\+', line)
                               + re.findall(r'"([A-Za-z0-9_ ]*[_ ])%d"\s*%', line)):
                    # "tile picture " is told as tile_picture_#: its space a _.
                    families.setdefault(name_of(prefix.replace(" ", "_")), place)
                    used = True
                for prefix in re.findall(r'(?:prefix|key)\s*\+\s*"([a-z0-9_]+)"', line):
                    exact.add(name_of(prefix))
        # A prefix kept in a variable or a const: var prefix := "claude_"
        for prefix in re.findall(r'(?:var|const) (?:prefix|PREFIX)[^=\n]*=\s*"([a-z0-9_]*)"', text):
            for body in found:
                for rest in re.findall(r'prefix\s*\+\s*"([a-z0-9_]+)"', body):
                    exact.add(name_of(prefix + rest))
        if used:
            files.append(words)
    # The bin's Techniques tiles, "technique " and each technique's name
    # (src/ai/techniques.gd).
    table = (ROOT / "src" / "ai" / "techniques.gd").read_text(encoding="utf-8")
    exact.update(name_of("technique " + n) for n in re.findall(r'"name":\s*"([^"]{1,48})"', table))
    return {n for n in exact if NAME.match(n)}, {p: f for p, f in families.items() if p}, files


def errors() -> dict[str, list[str]]:
    js = sorted({p.name for p in (ROOT / "web").rglob("*.js")} | {"page", "external"})
    gd = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "src").rglob("*.gd"))
    return {"js": [name_of(n, True) for n in js], "gd": [name_of(n, True) for n in gd]}


def mcp_tools() -> list[str]:
    """Every tool the connector serves: the studio's (tools/mcp_tools.json)
    and the relay's own (api/mcp.js RELAY_TOOLS)."""
    names = {one["name"] for one in json.loads((ROOT / "tools" / "mcp_tools.json").read_text(encoding="utf-8"))}
    relay = (ROOT / "api" / "mcp.js").read_text(encoding="utf-8")
    block = re.search(r"const RELAY_TOOLS = \[(.*?)\n\];", relay, re.S)
    names.update(re.findall(r'name: "([a-z_]+)"', block.group(1) if block else ""))
    return sorted(n.lower() for n in names if NAME.match(n.lower()))


def build() -> dict:
    tool_names = modes()
    command_names = commands()
    press, families, files = controls()
    render_kinds = set()
    for path in (ROOT / "src").rglob("*.gd"):
        render_kinds.update(re.findall(r'_last = \{"kind": "([a-z]+)"', path.read_text(encoding="utf-8")))
    exact = {
        "site": {
            "view": sorted(site_views()),
            "act": sorted(acts()),
            "load": ["site_cls", "site_fcp", "site_inp", "site_lcp", "site_ttfb"],
        },
        "studio": {
            "view": ["/app"],
            "tool": sorted(tool_names),
            "panel": sorted(panels()),
            "press": sorted(press),
            "command": sorted(command_names),
            "run": sorted({"simulate", "render", "booklet", "together", "pin_resolved"} | {f"render_{k}" for k in render_kinds}),
            "milestone": ["first_part", "first_save", "studio"],
            "part": ["placed"],
            "save": ["model"],
            "load": sorted(f"studio_{m}" for m in ["compiled", "made", "ready", "data", "catalogue", "ui", "ttfb"]),
            "frames": ["frame_ms", "frame_p95_ms"],
        },
    }
    return {
        "exact": exact,
        # A press of a family: its prefix, then a number (#), a command, a
        # tool or a word of the file that makes it (by its place in "words").
        "families": dict(sorted(families.items())),
        "words": files,
        "errors": errors(),
        "mcp": mcp_tools(),
    }


def render(data: dict) -> str:
    return ("// Made by tools/insights_names.py from the code that counts each name: never edit by hand.\n"
            "// The names a row of /admin › Analytics may hold (api/_analytics.js, docs/ANALYTICS.md).\n"
            f"export const NAMES = {json.dumps(data, separators=(',', ':'))};\n")


def main() -> int:
    text = render(build())
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("insights_names: api/_insights_names.js is not what the code names: run python3 tools/insights_names.py")
            return 1
        print("insights_names: up to date")
        return 0
    OUT.write_text(text, encoding="utf-8")
    data = build()
    sizes = {k: len(v) for k, v in data["exact"]["studio"].items()} | {f"site_{k}": len(v) for k, v in data["exact"]["site"].items()}
    print(f"insights_names: wrote {OUT.relative_to(ROOT)} ({len(text)} bytes): {sizes}, "
          f"{len(data['families'])} families from {len(data['words'])} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
