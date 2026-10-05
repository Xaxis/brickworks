#!/usr/bin/env python3
"""Is a process matching this pattern running?

    tools/running.py build_meshes.py        # exit 0 if yes, 1 if no

Why this exists.  ``pgrep -f <pattern>`` matches the command line of the
shell that invoked it, because that command line contains the pattern.
It therefore answers "running" about a process that has already exited,
every single time, and it did so four times in one sitting — once
reporting a design run still alive after it had finished.

The usual bracket trick, ``grep "[b]uild"``, does not fix it either: the
pattern still appears in this script's own argv and in the parent
shell's, so a search for a process that does not exist finds two.  What
actually works is to ignore this process, its ancestors, and anything
running this script, which is what the walk below does.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _ancestors(pid: int) -> set[int]:
    """This process and every process that started it."""
    chain = set()
    while pid > 1 and pid not in chain:
        chain.add(pid)
        try:
            stat = Path(f"/proc/{pid}/stat").read_text()
        except OSError:
            break
        # The command name can contain spaces and brackets, so the fields
        # after it are found from the last ')' rather than by splitting.
        after = stat[stat.rindex(")") + 1:].split()
        pid = int(after[1]) if len(after) > 1 else 0
    return chain


def matches(pattern: str) -> list[tuple[int, str]]:
    skip = _ancestors(os.getpid())
    mine = Path(__file__).name
    found = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid in skip:
            continue
        try:
            args = (entry / "cmdline").read_bytes().decode("utf-8", "replace")
        except OSError:
            continue
        args = args.replace("\0", " ").strip()
        if pattern in args and mine not in args:
            found.append((pid, args))
    return found


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {Path(__file__).name} <pattern>", file=sys.stderr)
        return 2
    found = matches(argv[1])
    for pid, args in found:
        print("%7d  %.110s" % (pid, args))
    if not found:
        print(f"nothing matching '{argv[1]}' is running")
    return 0 if found else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
