"""The scripts the app's first screen compiles, read from its sources.

Loading a script compiles every class it names, and theirs, before a line
of it runs (GDScriptCache::finish_compiling). The first screen is every
script project.godot has the engine load before anything of the app's
runs (the main loop, each autoload, the main scene and the scenes it
holds), and all they name, stopping at the classes Later
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


def class_list(texts: dict[str, str]) -> dict[str, str]:
    """The global class list as Godot builds it from these scripts: each
    class_name and the script that declares it."""
    classes = {}
    for path, text in texts.items():
        found = re.search(r"^class_name\s+(\w+)", text, re.M)
        if found:
            classes[found.group(1)] = path
    return classes


def graph(root: Path = ROOT) -> tuple[dict[str, str], dict[str, set[str]]]:
    """Each class's script, and the scripts each script names."""
    texts = scripts(root)
    classes = class_list(texts)
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


def project_settings(root: Path = ROOT) -> dict[str, dict[str, str]]:
    """project.godot as section -> key -> value, a string's quotes taken
    off: what the engine reads before it loads a script."""
    out: dict[str, dict[str, str]] = {"": {}}
    section = out[""]
    for line in (root / "project.godot").read_text().splitlines():
        head = re.match(r"^\[([^\]]+)\]\s*$", line)
        if head:
            section = out.setdefault(head.group(1), {})
            continue
        found = re.match(r'^([\w/.]+)=(?:"((?:\\.|[^"\\])*)"|(.*))$', line)
        if found:
            quoted = found.group(2)
            section[found.group(1)] = quoted if quoted is not None else found.group(3)
    return out


def by_uid(ref: str, root: Path = ROOT) -> str:
    """The res:// path a uid:// names: a script's .uid beside it, or the uid
    in a scene's or a resource's header."""
    src = root / "src"
    for file in src.rglob("*.uid"):
        if file.read_text().strip() == ref:
            return "res://" + file.relative_to(root).as_posix().removesuffix(".uid")
    for file in [*src.rglob("*.tscn"), *src.rglob("*.tres")]:
        with file.open() as f:
            if f'uid="{ref}"' in f.readline():
                return "res://" + file.relative_to(root).as_posix()
    raise ValueError(f"project.godot names {ref}, and nothing in src/ has that uid")


def scripts_of(ref: str, root: Path = ROOT, seen: set[str] | None = None) -> set[str]:
    """The scripts loading a script, scene or resource loads: a script is
    itself; a scene or a resource, each script it names and those of the
    scenes and resources it names, as far as they go."""
    path = by_uid(ref, root) if ref.startswith("uid://") else ref
    file = root / path.removeprefix("res://")
    if not path.startswith("res://") or not file.is_file():
        raise ValueError(f"project.godot names {ref}, which is not there")
    if path.endswith(".gd"):
        return {path}
    seen = set() if seen is None else seen
    seen.add(path)
    out: set[str] = set()
    for named in re.findall(r'^\[ext_resource\b[^\n]*?\bpath="(res://[^"]+)"', file.read_text(), re.M):
        if named.endswith(".gd"):
            out.add(named)
        elif named.endswith((".tscn", ".tres")) and named not in seen:
            out |= scripts_of(named, root, seen)
    return out


# The main loops the engine has of its own (run/main_loop_type); any other
# is a script's class_name.
ENGINE_LOOPS = frozenset({"SceneTree", "MainLoop"})


def first_screen(root: Path = ROOT) -> list[str]:
    """Where the start's compile begins: every script the engine loads
    before anything of the app's runs, read from project.godot's entry
    points: the main loop (run/main_loop_type, a class by name, made first),
    each autoload, and the main scene (run/main_scene) with the scenes it
    holds. An entry point left in the data pack is not there when the engine
    loads it, and the web app never starts: so it went when the main loop
    became a class of our own (BrickworksLoop, 2026-11-07). One it cannot
    place is an error, never a script quietly left out."""
    settings = project_settings(root)
    app = settings.get("application", {})
    if "run/main_scene" not in app:
        raise ValueError("project.godot names no run/main_scene")
    seeds = scripts_of(app["run/main_scene"], root)
    loop = app.get("run/main_loop_type", "SceneTree")
    if loop not in ENGINE_LOOPS:
        classes = class_list(scripts(root))
        if loop not in classes:
            raise ValueError(f"project.godot's main loop is {loop}, and no script of the app is class_name {loop}")
        seeds.add(classes[loop])
    for ref in settings.get("autoload", {}).values():
        seeds |= scripts_of(ref.removeprefix("*"), root)
    return sorted(seeds)


def closure(root: Path = ROOT) -> set[str]:
    """What the first screen compiles: its seeds (first_screen) and every script
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
