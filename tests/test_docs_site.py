"""brickworks.diy/docs (tools/docs_site.py, from docs-site/) keeps in step with
what it documents: every feature in the feature map is on a page or named
as one a person never meets, every link goes somewhere, and the pages made
from the app's own tables say what those tables say."""

from __future__ import annotations

import importlib.util
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

_spec = importlib.util.spec_from_file_location("docs_site", ROOT / "tools/docs_site.py")
docs_site = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(docs_site)

DUMP = "godot --headless --path . --script src/dev/docs_menus.gd -- --menus-to=docs-site/generated/menus.json"


def test_every_feature_is_documented_and_every_link_resolves() -> None:
    """Like the feature map's own Stop hook: a feature added to
    .claude/skills/verify/features.json with no page fails here."""
    problems = docs_site.check()
    assert not problems, "\n".join(problems)


def _menu_names(items: list) -> list[str]:
    out = []
    for item in items:
        if "submenu" in item:
            out.append(">" + item["submenu"])
            out.extend(_menu_names(item.get("items", [])))
        elif item.get("line"):
            out.append("-")
        else:
            out.append(item["name"])
    return out


def test_the_menus_page_is_the_apps_menus() -> None:
    """docs-site/generated/menus.json is written off the real window; when
    src/ui/shell.gd's menus or a command's words change, it is written again."""
    shell = (ROOT / "src/ui/shell.gd").read_text(encoding="utf-8")
    menus = re.search(r"const MENUS: Array = \[(.*?)\n\]\n", shell, re.S).group(1)
    subs_text = re.search(r"const SUBMENUS: Dictionary = \{(.*?)\n\}\n", shell, re.S).group(1)
    subs = {k: re.findall(r'"([>a-z_0-9-]+)"', v)
            for k, v in re.findall(r'"([a-z_]+)": \[(.*?)\]', subs_text, re.S)}

    def expand(names: list[str]) -> list[str]:
        out = []
        for name in names:
            out.append(name)
            if name.startswith(">"):
                out.extend(expand(subs.get(name[1:], [])))
        return out

    wanted = {title: expand(re.findall(r'"([>a-z_0-9-]+)"', items))
              for title, items in re.findall(r'\["(\w+)", \[(.*?)\]\]', menus, re.S)}
    dump = json.loads((ROOT / "docs-site/generated/menus.json").read_text(encoding="utf-8"))
    have = {menu["title"]: _menu_names(menu["items"]) for menu in dump["menus"]}
    assert have == wanted, f"the menus changed: write docs-site/generated/menus.json again with\n  {DUMP}"
    # And the app's own menu, from the mark (Shell.APP_MENU).
    app_menu = re.findall(r'"([a-z_-]+)"', re.search(r"const APP_MENU: Array = \[(.*?)\]\n", shell).group(1))
    assert _menu_names(dump.get("app_menu", [])) == app_menu, \
        f"the Brickworks menu changed: write docs-site/generated/menus.json again with\n  {DUMP}"
    # The words of every command added by name (most are), as the dump has them.
    words = dict(re.findall(r'_add\("([a-z_0-9]+)", "([^"]+)",', shell))  # a plain literal, not one per platform
    said = {item["name"]: item["words"] for menu in dump["menus"] for item in _flat(menu["items"])}
    differ = [f"{name}: {said[name]!r} in the dump, {words[name]!r} in shell.gd"
              for name in said if name in words and said[name] != words[name]]
    assert not differ, "\n".join(differ) + f"\nwrite the menus again with\n  {DUMP}"


def _flat(items: list) -> list:
    out = []
    for item in items:
        if "submenu" in item:
            out.extend(_flat(item.get("items", [])))
        elif "name" in item:
            out.append(item)
    return out


def test_the_shortcuts_are_every_binding_the_app_lists() -> None:
    text = (ROOT / "src/ui/controls_hint.gd").read_text(encoding="utf-8")
    start = text.index("static func for_touch(")
    end = text.index("\nconst ON_THE_STRIP")
    listed = text[start:end].count("Binding.new(")
    start = text.index("static func for_keyboard(")
    end = text.index("\nstatic func _section(")
    listed += text[start:end].count("Binding.new(")
    sections = docs_site.keyboard()
    rows = [row for _, section in sections for row in section]
    assert len(rows) == listed, (len(rows), listed)
    names = [name for name, _ in sections]
    assert names[:5] == ["Building", "Selecting", "The view", "The timeline", "Panels"], names
    undo = [does for keys, does, _ in rows if keys == ["Ctrl-Z"]]
    assert undo == ["undo"], undo
    # The keys the browser keeps for itself are said to be the desktop's alone.
    desktop = sorted(k for keys, _, only in rows if only for k in keys)
    assert desktop == ["Ctrl-N", "Ctrl-Q"], desktop


def test_the_pages_are_built_whole(tmp_path: Path) -> None:
    count = docs_site.build(tmp_path)
    nav = json.loads((ROOT / "docs-site/_nav.json").read_text(encoding="utf-8"))
    assert count == sum(len(group["pages"]) for group in nav)
    pages = [tmp_path / "docs.html", *sorted((tmp_path / "docs").glob("*.html"))]
    assert len(pages) == count
    for page in pages:
        text = page.read_text(encoding="utf-8")
        name = page.stem
        assert text.count("<h1>") == 1, name
        assert '<a class="skip" href="#main">' in text and '<main id="main"' in text, name
        assert '<link rel="canonical" href="https://brickworks.diy/docs' in text, name
        assert '<nav class="docs-side" id="docs-side" aria-label="Documentation">' in text, name
        assert text.count('aria-current="page"') >= 1, name
        assert "<script>" not in text, f"{name}: the site's policy allows no inline script"
    tools = json.loads((ROOT / "tools/mcp_tools.json").read_text(encoding="utf-8"))
    reference = (tmp_path / "docs/mcp-tools.html").read_text(encoding="utf-8")
    missing = [tool["name"] for tool in tools if f'id="{tool["name"]}"' not in reference]
    assert not missing, missing
    index = json.loads((tmp_path / "docs/search.json").read_text(encoding="utf-8"))
    assert any(row["u"] == "/docs/fresh-eyes" for row in index)
    assert any(row["u"].startswith("/docs/build-together") for row in index)


def test_a_feature_named_twice_or_unknown_is_said() -> None:
    page = docs_site.Page("x", {}, "")
    docs_site.render(page, "## A\n<!-- covers\nui:one\n-->\n## B\n<!-- covers\nui:two\n-->\n")
    assert page.covers == {"ui:one": "a", "ui:two": "b"}
    try:
        docs_site.render(docs_site.Page("y", {}, ""), "<!-- covers\nui:one\nui:one\n-->\n")
    except SystemExit as said:
        assert "twice" in str(said)
    else:
        raise AssertionError("a feature covered twice on one page was let through")


def test_a_tools_words_changed_by_hand_fail_until_its_doc_is_read_again(monkeypatch) -> None:
    """The tool list's words and each tool's doc cannot part quietly: a
    description changed by hand fails the check, and so does a doc whose
    tool is gone; written again (--write), the doc matches."""
    _, pages = docs_site.load()
    assert not docs_site.tool_problems(pages)
    real = docs_site.app_tools()
    changed = [dict(tool) for tool in real]
    changed[0]["description"] += " And one more sentence."
    monkeypatch.setattr(docs_site, "app_tools", lambda: changed)
    problems = docs_site.tool_problems(pages)
    assert any(f"docs-site/tools/{changed[0]['name']}.md is behind" in p for p in problems), problems
    doc = docs_site.tool_docs()[changed[0]["name"]]
    rewritten = docs_site.with_said(doc, changed[0])
    assert rewritten.count("And one more sentence.") == 1 and doc.notes in rewritten
    monkeypatch.setattr(docs_site, "app_tools", lambda: real[1:])
    problems = docs_site.tool_problems(pages)
    assert any(p.startswith(f"docs-site/tools/{real[0]['name']}.md is the doc of no tool") for p in problems), problems


def test_an_example_a_tool_would_refuse_is_said() -> None:
    schema = {"type": "object", "additionalProperties": False, "required": ["name"],
              "properties": {"name": {"type": "string"}, "view": {"type": "string", "enum": ["front", "top"]},
                             "bricks": {"type": "array", "items": {"type": "integer"}}}}
    assert docs_site.schema_problems({"name": "x", "view": "top", "bricks": [1, 2]}, schema, "t") == []
    said = docs_site.schema_problems({"view": "side", "bricks": [1, "2"], "colour": 4}, schema, "t")
    assert said == ["t lacks name, which it needs", 't.view is "side", not one of [\'front\', \'top\']',
                    't.bricks[1] is "2", not integer', "t has colour, which the tool does not take"], said


def _gd_read(literal: str) -> str:
    """A GDScript triple-quoted string as Godot reads it: a backslash at a
    line's end joins the lines, and a doubled backslash is one."""
    assert literal.startswith('"""') and literal.endswith('"""')
    body = literal[3:-3]
    return re.sub(r"\\(\\|\n)", lambda m: "\\" if m.group(1) == "\\" else "", body)


def test_the_words_a_session_is_told_are_the_pages_exactly() -> None:
    """src/ai/connector_guide.gd holds design-session.md's said blocks to the
    byte: the generator's line breaks are GDScript's to join again."""
    said = docs_site.said_blocks()
    made = docs_site.connector_guide()
    for name, (const, _) in docs_site.SAID_BLOCKS.items():
        literal = re.search(rf'^const {const} := ("""[\s\S]*?""")$', made, re.M).group(1)
        assert _gd_read(literal) == said[name], name
    tricky = 'a "quoted" path C:\\x\\ and ' + "word " * 40
    assert _gd_read(docs_site.gd_string(tricky)) == tricky
    assert "You design LEGO® models with this app's tools" in said["head"]
