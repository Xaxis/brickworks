"""Every command the window names is a tool's, or the window's own.

mcp_sync_probe checks this against the running app, but only ship.sh runs
it, so a unit that adds a menu command learns of a miss when its release is
held: rel-m220 held at "back_to_site in neither AppTools.COMMANDS nor
WINDOW_ONLY" (2026-10-30), and beta374's feedback and beta_hub would have
held the next. This reads the same tables from the source, so ci_gate says
it in seconds. It sees only commands named in a literal _add("id", ...) in
src/ui/shell.gd; the probe stays the authority for the rest.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "src/ui/shell.gd"
TOOLS = ROOT / "src/net/app_tools.gd"


def _table(source: str, name: str) -> list[str]:
    """The keys of `const NAME: Dictionary = {...}` in [source]."""
    start = source.index(f"const {name}: Dictionary = {{")
    body = source[start:source.index("\n}", start)]
    # Several keys share a line ("new": "clear_model", "clear": ...): every
    # quoted word followed by a colon is a key; the values never are.
    return re.findall(r'"([^"]+)"\s*:', body)


def _placed(keys: list[str], command: str) -> bool:
    # As mcp_sync_probe._matches: a key ending in * takes every id it begins.
    return any(k == command or (k.endswith("*") and command.startswith(k[:-1])) for k in keys)


def _commands() -> list[str]:
    code = "\n".join(line.split("#", 1)[0] for line in SHELL.read_text().splitlines())
    return sorted(set(re.findall(r'\b_add\(\s*"([a-z0-9_]+)"', code)))


def test_every_named_command_is_placed() -> None:
    tools = TOOLS.read_text()
    keys = _table(tools, "COMMANDS") + _table(tools, "WINDOW_ONLY")
    commands = _commands()
    assert len(commands) > 100, f"read only {len(commands)} commands from shell.gd"
    unplaced = [c for c in commands if not _placed(keys, c)]
    assert not unplaced, (
        f"{', '.join(unplaced)} in neither AppTools.COMMANDS nor WINDOW_ONLY "
        "(src/net/app_tools.gd): a tool's, or the window's own with why")


def test_the_check_finds_an_unplaced_command() -> None:
    # The same reading, against a table without one command it must name.
    tools = TOOLS.read_text()
    keys = [k for k in _table(tools, "COMMANDS") + _table(tools, "WINDOW_ONLY") if k != "about"]
    assert "about" in _commands() and not _placed(keys, "about")
