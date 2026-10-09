#!/usr/bin/env python3
"""Is a process matching this pattern running, and stop it if asked.

    tools/running.py build_meshes.py           # exit 0 if yes, 1 if no
    tools/running.py --stop design.py          # and end the ones it finds

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

``--stop`` exists for the same reason one step on.  Finding a run with
``ps -eo pid,args | grep design.py`` and killing what comes back kills
the shells *waiting* on that run too, because an ``until`` loop polling
for it has the pattern in its own command line.  Done here, that ended
two background waiters along with the run — the same fault as the one
above, wearing a different hat.

Ancestors are not enough to fix it: a sibling shell polling for the run
is nobody's ancestor.  So a command line that is plainly a wait rather
than the work — a loop keyword, or a call to a tool whose whole job is
to ask whether something is running — is left alone.  That is a
heuristic and it is written here rather than implied, because the first
version claimed this in a docstring and did not do it, and the test
below is what said so.
"""

from __future__ import annotations

import os
import signal
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


## A command line holding one of these is waiting for something, not
## doing it.  ``timeout`` is not here: a run wrapped in one is the run.
WAITING = (" until ", "until !", "while !", " while ", "pgrep", "running.py")


def waiting(args: str) -> bool:
    """Whether this command line is a poll for the work, not the work."""
    return any(mark in args for mark in WAITING)


def stop(pattern: str) -> tuple[list[tuple[int, str]], list[tuple[int, str]]]:
    """End what matches, deepest first. Returns (ended, left alone).

    Deepest first so a wrapper cannot outlive and restart its child, and
    so the thing being waited for dies before whatever is watching it.
    """
    ended, spared = [], []
    for row in sorted(matches(pattern),
                      key=lambda row: -len(_ancestors(row[0]))):
        if waiting(row[1]):
            spared.append(row)
            continue
        try:
            os.kill(row[0], signal.SIGTERM)
        except OSError:
            pass
        ended.append(row)
    return ended, spared


def main(argv: list[str]) -> int:
    ending = len(argv) == 3 and argv[1] == "--stop"
    if len(argv) != 2 and not ending:
        print(f"usage: {Path(__file__).name} [--stop] <pattern>",
              file=sys.stderr)
        return 2
    pattern = argv[2] if ending else argv[1]
    if not ending:
        found = matches(pattern)
        for pid, args in found:
            print("%7d  %.110s" % (pid, args))
        if not found:
            print(f"nothing matching '{pattern}' is running")
        return 0 if found else 1

    found, spared = stop(pattern)
    for pid, args in found:
        print("ended   %7d  %.100s" % (pid, args))
    for pid, args in spared:
        print("waiting %7d  %.100s" % (pid, args))
    if not found:
        print(f"nothing matching '{pattern}' was running")
    return 0 if found else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
