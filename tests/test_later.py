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

It reads the scripts as Godot's compiler does for this purpose
(tools/web/start_closure.py): every class name outside comments and
strings, preloads, and extends by path.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"


# How the scripts are read, and the first screen walked: shared with
# tools/web/pck_split.py, which sends what the first screen does not
# compile with the data pack.
sys.path.insert(0, str(ROOT / "tools" / "web"))
from start_closure import first_screen as _first_screen  # noqa: E402
from start_closure import graph as _graph  # noqa: E402
from start_closure import later as _later  # noqa: E402
from start_closure import scripts as _scripts  # noqa: E402


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


def test_the_connector_made_with_the_window_names_no_other_later_class():
    """Claude's connector is made as the window is built when the assistant is
    shown (Main._make_connector), so a tab that goes out of view before its
    first frame still switches on and runs its frames out of view. That is
    cheap only while it names none of Later's other classes: CommandSocket,
    the assistant or ViewerTools named there brought all of the assistant's
    code, 4.2 MB, into the start (hidden_boot, 2026-11-01)."""
    classes, deps = _graph()
    later = _later()
    connector = later["ClaudeConnector"]
    seen = {connector}
    queue = [connector]
    while queue:
        for nxt in deps.get(queue.pop(), ()):
            if nxt not in seen:
                seen.add(nxt)
                queue.append(nxt)
    by_path = {path: name for name, path in classes.items()}
    named = sorted(by_path.get(p, p) for p in seen & set(later.values()) if p != connector)
    assert not named, f"ClaudeConnector compiles {', '.join(named)}; reach them with Later.script"


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


def test_a_features_first_run_names_its_class_and_member():
    """Shell.FIRST_USE says a command's first run first, as a slow one is,
    while its feature is not loaded or made: each class is one Later loads,
    and each member one main.gd makes on first use (its _made)."""
    shell = (SRC / "ui" / "shell.gd").read_text()
    table = shell[shell.index("const FIRST_USE: Dictionary = {"):]
    table = table[:table.index("\n}")]
    rows = re.findall(r'"(\w+)": \[&"(\w+)", "(\w*)"\]', table)
    assert len(rows) >= 15
    later = _later()
    main = (SRC / "main.gd").read_text()
    commands = set(re.findall(r'_add\("(\w+)"', shell))
    for command, name, member in rows:
        assert command in commands, f"FIRST_USE names {command}, which is no command"
        assert name in later, f"FIRST_USE[{command}] is {name}, which Later does not load"
        assert not member or re.search(rf"^var {member}_made\b", main, re.M), \
            f"FIRST_USE[{command}] is {member}, which main.gd does not make on first use"
