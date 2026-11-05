"""The scripts the app's first screen compiles, read from its sources.

Loading a script compiles every class it names, and theirs, before a line
of it runs (GDScriptCache::finish_compiling). The first screen is
src/main.tscn's scripts and all they name, stopping at the classes Later
loads on first use (src/later.gd, Later.PATHS): what a first visit to the
web app compiles before it draws anything, about 0.37 s a megabyte of
source on the box (webstart2, 2026-11-05).

tests/test_later.py holds the first screen to naming none of Later's
classes; tools/web/pck_split.py keeps only these scripts in the pack the
engine waits for, and sends the rest with the data pack.

It reads the scripts as Godot's compiler does for this purpose: every class
name outside comments and strings, preloads, and extends by path.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def strip(text: str) -> str:
    """The script with its comments and strings taken out."""
    text = re.sub(r'"""[\s\S]*?"""', '""', text)
    out = []
    for line in text.split("\n"):
        line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
        at = line.find("#")
        if at >= 0:
            line = line[:at]
        out.append(line)
    return "\n".join(out)


def scripts(root: Path = ROOT) -> dict[str, str]:
    """Every script of the app by res:// path; the probes in src/dev are not the app's."""
    out = {}
    for path in (root / "src").rglob("*.gd"):
        rel = path.relative_to(root).as_posix()
        if rel.startswith("src/dev/"):
            continue
        out["res://" + rel] = path.read_text()
    return out


def graph(root: Path = ROOT) -> tuple[dict[str, str], dict[str, set[str]]]:
    """Each class's script, and the scripts each script names."""
    texts = scripts(root)
    classes = {}
    for path, text in texts.items():
        found = re.search(r"^class_name\s+(\w+)", text, re.M)
        if found:
            classes[found.group(1)] = path
    deps: dict[str, set[str]] = {}
    for path, text in texts.items():
        named = set()
        for word in set(re.findall(r"\b([A-Z]\w*)\b", strip(text))):
            if word in classes and classes[word] != path:
                named.add(classes[word])
        for loaded in re.findall(r'preload\(\s*"(res://[^"]+\.gd)"\s*\)', text):
            if loaded in texts:
                named.add(loaded)
        base = re.search(r'^extends\s+"(res://[^"]+)"', text, re.M)
        if base and base.group(1) in texts:
            named.add(base.group(1))
        deps[path] = named
    return classes, deps


def later(root: Path = ROOT) -> dict[str, str]:
    """Later.PATHS: class name -> script."""
    text = (root / "src" / "later.gd").read_text()
    table = text[text.index("const PATHS"):]
    table = table[:table.index("\n}")]
    return dict(re.findall(r'&"(\w+)":\s*"(res://[^"]+)"', table))


def first_screen(root: Path = ROOT) -> list[str]:
    """The scripts the main scene names: where the start's compile begins."""
    scene = (root / "src" / "main.tscn").read_text()
    return sorted(set(re.findall(r'path="(res://[^"]+\.gd)"', scene)))


def closure(root: Path = ROOT) -> set[str]:
    """What the first screen compiles: main.tscn's scripts and every script
    they name, and theirs, but none of Later's (nor what only they name)."""
    _, deps = graph(root)
    stops = set(later(root).values())
    seen = set(first_screen(root))
    queue = list(seen)
    while queue:
        for nxt in deps.get(queue.pop(), ()):
            if nxt not in stops and nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    return seen


def outside(root: Path = ROOT) -> set[str]:
    """The app's scripts the first screen does not compile, by res:// path."""
    return set(scripts(root)) - closure(root)
