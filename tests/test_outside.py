"""Nothing opens a link or a folder but Outside (src/ui/outside.gd).

An agent's shell carries the owner's desktop, and a probe that pressed
Documentation opened brickworks.diy/docs in a browser on the owner's screen
for seven minutes (2026-10-29). Twenty other buttons called OS.shell_open or
OS.shell_show_in_file_manager straight. Outside opens nothing in a probe's
run; a call that goes round it opens on the owner's screen again. So every
.gd file under src/ and tools/ is read, its comments blanked, for the
system's openers by name: Godot's two, and the programs they run, which
OS.execute or OS.create_process could start as well.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTSIDE = ROOT / "src" / "ui" / "outside.gd"

OPENERS = re.compile(
    r"\bshell_open\b|\bshell_show_in_file_manager\b"
    r"|[\"'](?:xdg-open|gio|gvfs-open|kde-open5?|exo-open|gnome-open)[\"']")


def without_comments(line: str) -> str:
    """[param line] up to a # that is not in a string."""
    quote = ""
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = ""
        elif c in "\"'":
            quote = c
        elif c == "#":
            return line[:i]
        i += 1
    return line


def direct_opens(text: str) -> list[tuple[int, str]]:
    """Each line of GDScript [param text] that calls the system's opener: (number, line)."""
    return [(n, line.strip()) for n, line in enumerate(text.split("\n"), 1)
            if OPENERS.search(without_comments(line))]


def test_finds_each_way_round():
    planted = "\n".join([
        "func _a() -> void:",
        "\tOS.shell_open(url)",
        "\tlink.pressed.connect(func() -> void: OS.shell_open(Deployment.api_base() + \"/\"))",
        "\tvar show: Callable = Callable(OS, \"shell_show_in_file_manager\")",
        "\tOS.execute(\"xdg-open\", [url])",
        "\tOS.create_process('gio', [\"open\", url])",
        "\tOS.execute(\"kde-open5\", [url])",
    ])
    assert [n for n, _ in direct_opens(planted)] == [2, 3, 4, 5, 6, 7]


def test_passes_what_goes_through_outside():
    fine = "\n".join([
        "\tOutside.open_link(url)  # not OS.shell_open: it opens nothing in a probe",
        "## OS.shell_open opened a browser on the owner's screen.",
        "\tSaveTo.show_with = Callable(Outside, \"show_in_folder\")",
        "\tsay(\"Choose # gio to read\")",
        "\tvar giorgio: String = \"gio is a word\"",
    ])
    assert direct_opens(fine) == []


def test_only_outside_opens():
    found = []
    for folder in ("src", "tools"):
        for path in sorted((ROOT / folder).rglob("*.gd")):
            if path == OUTSIDE:
                continue
            for n, line in direct_opens(path.read_text(encoding="utf-8")):
                found.append("%s:%d: %s" % (path.relative_to(ROOT), n, line))
    assert not found, (
        "the system's opener called round Outside (src/ui/outside.gd), so a probe "
        "pressing it opens on the owner's screen; use Outside.open_link or "
        "Outside.show_in_folder:\n  " + "\n  ".join(found))


def test_outside_still_opens():
    """The person's own app opens what they chose: Outside itself calls both."""
    text = OUTSIDE.read_text(encoding="utf-8")
    assert "OS.shell_open(" in text and "OS.shell_show_in_file_manager(" in text
