#!/usr/bin/env python3
"""Which of the first screen's scripts the start never runs, and what each costs.

    python3 tools/web/start_uses.py LOG [LOG ...] [--root=DIR] [--top=N] [--json=FILE]
        [--phase=SECONDS] [--grew=MB]

LOG is the output of src/dev/start_uses.gd run under Godot's script profiler
(-d --profiling): the profiler's totals name every function that ran from
the engine's start until the window had settled with nobody touching it.
Given several (a phone's window and a desktop's), a script that ran in any
of them counted as run.

The first screen (tools/web/start_closure.py) is every script the start
compiles; a script of it none of whose functions ran is compiled only for a
press that has not come. Its static initializer runs as it loads, so is not
counted as a use.

Each such script is said with what would leave the first screen with it
were it loaded on first use (Later): itself and what only it names, in
tokens (start_closure.tokens: comments are a third of this code's bytes and
cost no compile), and the first screen's scripts that name it, which are
what would have to reach it through Later instead. Given the scripts' phase
in seconds (--phase) and what the Wasm memory grew by in it (--grew), a row
is given its share of each by its tokens: an estimate, which the export's
own start_phases pairs then measure.

A script of constants alone has no function to run, so it is said as never
run whatever reads it: what reads its tables decides.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import start_closure as sc  # noqa: E402

# What runs as a script loads, used or not.
NOT_A_USE = ("@static_initializer", "_static_init")


def ran(log: str) -> set[str]:
    """The scripts with a function in the profiler's totals."""
    text = Path(log).read_text(errors="replace")
    at = text.rfind("ACCUMULATED:")
    if at < 0:
        sys.exit(f"start_uses: {log} has no profiler totals (run start_uses.gd with -d --profiling)")
    if "start_uses: the window built" not in text:
        sys.exit(f"start_uses: {log}'s window was never built")
    # Each function is two lines: "N:res://path.gd::line::Class.name", then
    # its times and "tcalls: N". The totals list every function compiled,
    # those never called among them, with 0.
    out = set()
    lines = text[at:].splitlines()
    for i, line in enumerate(lines[:-1]):
        found = re.match(r"^\d+:(res://[^:]+\.gd)::\d+::(.*)$", line)
        calls = re.search(r"tcalls:\s*(\d+)", lines[i + 1])
        if found and calls and int(calls.group(1)) > 0 \
                and not found.group(2).rsplit(".", 1)[-1].endswith(NOT_A_USE):
            out.add(found.group(1))
    return out


def leaving(root: Path, deps: dict[str, set[str]], seeds: list[str], stops: set[str], deferred: set[str]) -> set[str]:
    """The first screen's scripts no longer compiled were [param deferred] loaded on first use."""
    def walk(stop: set[str]) -> set[str]:
        seen = set(seeds) - stop
        queue = list(seen)
        while queue:
            for nxt in deps.get(queue.pop(), ()):
                if nxt not in stop and nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        return seen
    return walk(stops) - walk(stops | deferred)


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args:
        sys.exit(__doc__)
    root = Path(opts.get("root", HERE.parent.parent)).resolve()
    used: set[str] = set()
    for log in args:
        used |= ran(log)
    classes, deps = sc.graph(root)
    by_path = {path: name for name, path in classes.items()}
    texts = sc.scripts(root)
    stops = set(sc.later(root).values())
    seeds = sc.first_screen(root)
    first = sc.closure(root)
    size = {p: sc.tokens(texts[p]) for p in texts}
    total = sum(size[p] for p in first)
    unused = sorted(first - used)
    rows = []
    for path in unused:
        gone = leaving(root, deps, seeds, stops, {path})
        namers = sorted(p for p in first - gone if path in deps.get(p, ()))
        rows.append({"script": path, "class": by_path.get(path, ""), "tokens_own": size[path],
                     "leaves": sorted(gone), "tokens": sum(size[p] for p in gone),
                     "ran_among_leaving": sorted(gone & used), "named_by": namers})
    rows.sort(key=lambda r: -r["tokens"])
    ran_tokens = sum(size[p] for p in first & used)
    print(f"first screen: {len(first)} scripts, {total / 1e3:.0f}k tokens; "
          f"{len(first & used)} ran at the start ({ran_tokens / 1e3:.0f}k, {100 * ran_tokens / total:.0f}%), "
          f"{len(unused)} never did ({(total - ran_tokens) / 1e3:.0f}k, {100 - 100 * ran_tokens / total:.0f}%)")
    phase, grew = float(opts.get("phase", 0)), float(opts.get("grew", 0))
    cost = f", ~s of a {phase:g} s phase, ~MB of {grew:g}" if phase and grew else ""
    print(f"never ran, by what would leave the first screen with it (k tokens, share{cost}):")
    for r in rows[: int(opts.get("top", 60))]:
        namers = ", ".join(by_path.get(p, p.rsplit("/", 1)[-1]) for p in r["named_by"][:6])
        more = f" +{len(r['named_by']) - 6}" if len(r["named_by"]) > 6 else ""
        share = r["tokens"] / total
        est = f" {share * phase:4.1f} s {share * grew:4.0f} MB" if cost else ""
        print(f"  {r['tokens'] / 1e3:5.1f}k {100 * share:4.1f}%{est}  {r['class'] or r['script']}"
              f" ({len(r['leaves'])} scripts; named by {len(r['named_by'])}: {namers}{more})")
    if "json" in opts:
        Path(opts["json"]).write_text(json.dumps({"first_screen": sorted(first), "ran": sorted(used & first),
                                                  "tokens": total, "rows": rows}, indent=1))


if __name__ == "__main__":
    main()
