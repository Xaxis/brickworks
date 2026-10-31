"""The first screen compiles only what it needs.

Loading a script compiles every class it names, and theirs, before a line of
it runs (GDScriptCache::finish_compiling). main.gd named 147 classes and
nearly all of the app's scripts named each other in one cycle, so a first
visit to the web app compiled all 308 of them, 19.8 MB of tokens, before it
drew anything (webstart, 2026-10-30).

The features the first screen does not need are reached by name through
src/later.gd (Later.PATHS) and loaded the first time something asks for one.
That holds only while nothing the first screen compiles names one of them:
a type, a static, a constant or a .new() of a Later class anywhere in the
first screen's code brings it back, and with it everything it names. This
fails then, and says which script named it and how the start reaches that
script.

It reads the scripts as Godot's compiler does for this purpose: every class
name outside comments and strings, preloads, and extends by path.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"


def _strip(text: str) -> str:
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


def _scripts() -> dict[str, str]:
    """Every script of the app by res:// path; the probes in src/dev are not the app's."""
    out = {}
    for path in SRC.rglob("*.gd"):
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith("src/dev/"):
            continue
        out["res://" + rel] = path.read_text()
    return out


def _graph() -> tuple[dict[str, str], dict[str, set[str]]]:
    """Each class's script, and the scripts each script names."""
    scripts = _scripts()
    classes = {}
    for path, text in scripts.items():
        found = re.search(r"^class_name\s+(\w+)", text, re.M)
        if found:
            classes[found.group(1)] = path
    deps: dict[str, set[str]] = {}
    for path, text in scripts.items():
        named = set()
        for word in set(re.findall(r"\b([A-Z]\w*)\b", _strip(text))):
            if word in classes and classes[word] != path:
                named.add(classes[word])
        for loaded in re.findall(r'preload\(\s*"(res://[^"]+\.gd)"\s*\)', text):
            if loaded in scripts:
                named.add(loaded)
        base = re.search(r'^extends\s+"(res://[^"]+)"', text, re.M)
        if base and base.group(1) in scripts:
            named.add(base.group(1))
        deps[path] = named
    return classes, deps


def _later() -> dict[str, str]:
    """Later.PATHS: class name -> script."""
    text = (SRC / "later.gd").read_text()
    table = text[text.index("const PATHS"):]
    table = table[:table.index("\n}")]
    return dict(re.findall(r'&"(\w+)":\s*"(res://[^"]+)"', table))


def _first_screen() -> list[str]:
    """The scripts the main scene names: where the start's compile begins."""
    scene = (SRC / "main.tscn").read_text()
    return sorted(set(re.findall(r'path="(res://[^"]+\.gd)"', scene)))


def test_later_names_each_class_by_its_own_script():
    """A name in Later.PATHS is the class_name of the script it points at."""
    later = _later()
    assert len(later) > 20
    for name, path in later.items():
        file = ROOT / path.removeprefix("res://")
        assert file.exists(), f"Later.PATHS[{name}] is {path}, which is not there"
        assert re.search(rf"^class_name\s+{name}\s*$", file.read_text(), re.M), \
            f"{path} is not class_name {name}"


def test_the_first_screen_names_no_class_it_loads_later():
    """Nothing the start compiles names a class Later loads on first use."""
    classes, deps = _graph()
    later = set(_later().values())
    seeds = _first_screen()
    assert "res://src/main.gd" in seeds
    # Walked from the main scene, stopping at Later's classes: a step into
    # one is a script of the first screen naming it.
    came_from: dict[str, str | None] = {seed: None for seed in seeds}
    queue = list(seeds)
    named_later: list[tuple[str, str]] = []
    while queue:
        at = queue.pop(0)
        for nxt in sorted(deps.get(at, ())):
            if nxt in later:
                named_later.append((at, nxt))
                continue
            if nxt not in came_from:
                came_from[nxt] = at
                queue.append(nxt)
    by_path = {path: name for name, path in classes.items()}
    lines = []
    for at, nxt in named_later:
        chain = [at]
        while came_from[chain[-1]] is not None:
            chain.append(came_from[chain[-1]])
        how = " <- ".join(by_path.get(p, p) for p in chain)
        lines.append(f"{by_path.get(at, at)} names {by_path.get(nxt, nxt)} "
                     f"(start: {how}); reach it with Later.script or Later.make")
    assert not lines, "\n".join(lines)
    # And what the start does compile is the smaller part of the app.
    size = {p: len(t) for p, t in _scripts().items()}
    share = sum(size[p] for p in came_from) / sum(size.values())
    assert share < 0.6, f"the first screen compiles {share:.0%} of the app's scripts"


def _body(text: str, signature: str) -> list[str]:
    """The lines of the function at [signature], unindented, to its end."""
    lines = text.split("\n")
    start = next(n for n, line in enumerate(lines) if line.strip().startswith(signature))
    indent = len(lines[start]) - len(lines[start].lstrip("\t"))
    out = [lines[start].strip()]
    for line in lines[start + 1:]:
        if line.strip() and len(line) - len(line.lstrip("\t")) <= indent:
            break
        out.append(line[indent:].rstrip())
    while out and not out[-1]:
        out.pop()
    return out


def _table(text: str, name: str) -> str:
    start = text.index(f"const {name}: Dictionary = {{")
    return text[start:text.index("\n}", start)]


def test_the_cores_nests_are_the_assistants():
    """Nests (src/parts/nests.gd) is the core's copy of the assistant's rule
    for a pane in its frame, so that putting one in by hand does not load
    the assistant: the same table, and the same lines."""
    nests = (SRC / "parts" / "nests.gd").read_text()
    assistant = (SRC / "ai" / "assistant.gd").read_text()
    assert _table(nests, "NESTS") == _table(assistant, "NESTS")
    assert _body(nests, "static func _seated_in(") == _body(assistant, "static func _seated_in(")
    assert _body(nests, "static func turned(") == _body(assistant, "static func turned(")
    assert _body(nests, "static func angles_of(") == _body(assistant, "static func angles_of(")


def test_the_cores_footprint_is_the_assistants():
    """Footprint (src/assembly/footprint.gd) is the core's copy of where the
    assistant says a part's footprint starts, so that opening a model with
    parts off their studs does not load the assistant: the same lines."""
    footprint = (SRC / "assembly" / "footprint.gd").read_text()
    assistant = (SRC / "ai" / "assistant.gd").read_text()
    for signature in ("func _work_out_corner(", "func _figure_part(",
                      "func _footprint_start(", "static func _nearest_line("):
        assert _body(footprint, signature) == _body(assistant, signature), signature
    stud = re.compile(r"^const STUD := .*$", re.M)
    assert stud.search(footprint).group(0) == stud.search(assistant).group(0)


def test_the_bins_count_of_techniques_is_theirs():
    """The parts bin's Techniques tab says how many there are without loading
    them (PartsBin.TECHNIQUES_COUNT): Techniques.all(), what is written less
    what is withdrawn."""
    techniques = (SRC / "ai" / "techniques.gd").read_text()
    written = _body(techniques, "static func written(")
    names = [re.match(r'\t\t\t"name": "([^"]+)"', line)[1] for line in written
             if re.match(r'\t\t\t"name": "', line)]
    withdrawn = re.findall(r'^\t"([^"]+)":', _table(techniques, "WITHDRAWN"), re.M)
    count = len([name for name in names if name not in withdrawn])
    bin_ = (SRC / "ui" / "parts_bin.gd").read_text()
    said = int(re.search(r"^const TECHNIQUES_COUNT := (\d+)$", bin_, re.M)[1])
    assert said == count, (f"there are {count} techniques, and the parts bin says {said}: "
                           f"set PartsBin.TECHNIQUES_COUNT to {count}")
