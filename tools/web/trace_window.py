#!/usr/bin/env python3
"""Where a stretch of a page's time went, from a Chrome trace.

    python3 tools/web/trace_window.py TRACE.json --from=MS --to=MS [--top=25]
    python3 tools/web/trace_window.py TRACE.json --later=GrabDrag
    python3 tools/web/trace_window.py TRACE.json --compile

TRACE.json is one of `load_check --trace=DIR`'s, with its .marks.json beside
it. MS are on the page's clock (performance.now), as load_check's marks are:
the page's zero is found from load_check's own console stamp. --later=NAME
is the first use of NAME (window.brickworksLoaded); --compile the start's
compile, from the engine's "Build configuration" line to Main's "compiled".

For each thread with samples in the stretch it says V8's sampled CPU
profile: where the samples fell (wasm, the engine's JS, GC, idle), the
functions with the most self time, and the trace's own events in it (GC,
the wasm compiler's tiers) by total time. A wasm function with no name in
the build is "wasm $N" by its index, the same in every build of one engine.

Written for lazycompile (2026-11-05): why the grab compiled after the start
took about 3x its share of the start's compile.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import re
import sys


def read_trace(path: str) -> list[dict]:
    with open(path) as f:
        text = f.read()
    data = json.loads(text) if text.lstrip().startswith(("{", "[")) else None
    if isinstance(data, dict):
        return data.get("traceEvents", [])
    return data or []


def page_zero(events: list[dict]) -> tuple[int, float]:
    """(pid, trace µs of the page's 0 ms), from load_check's console stamp."""
    for e in events:
        if e.get("name") == "TimeStamp":
            msg = str(((e.get("args") or {}).get("data") or {}).get("message", ""))
            m = re.match(r"load_check zero ([0-9.]+)", msg)
            if m:
                return e["pid"], e["ts"] - float(m.group(1)) * 1000.0
    sys.exit("trace_window: no 'load_check zero' stamp in the trace")


def thread_names(events: list[dict]) -> dict[tuple[int, int], str]:
    names = {}
    for e in events:
        if e.get("ph") == "M" and e.get("name") == "thread_name":
            names[(e["pid"], e["tid"])] = (e.get("args") or {}).get("name", "")
    return names


class Profile:
    """One thread's sampled profile: its nodes and (µs, node) samples."""

    def __init__(self, pid: int, tid: int, start: float):
        self.pid, self.tid = pid, tid
        self.t = start
        self.nodes: dict[int, dict] = {}
        self.samples: list[tuple[float, int]] = []

    def add_chunk(self, data: dict) -> None:
        prof = data.get("cpuProfile") or {}
        for n in prof.get("nodes", []) or []:
            self.nodes[n["id"]] = n
        for node, dt in zip(prof.get("samples", []) or [], data.get("timeDeltas", []) or []):
            self.t += dt
            self.samples.append((self.t, node))


def profiles(events: list[dict]) -> list[Profile]:
    by_id: dict[tuple[int, str], Profile] = {}
    for e in events:
        if e.get("name") == "Profile" and e.get("ph") == "P":
            start = ((e.get("args") or {}).get("data") or {}).get("startTime", e["ts"])
            by_id[(e["pid"], e["id"])] = Profile(e["pid"], e["tid"], start)
    for e in events:
        if e.get("name") == "ProfileChunk":
            p = by_id.get((e["pid"], e["id"]))
            if p is not None:
                p.add_chunk((e.get("args") or {}).get("data") or {})
    return list(by_id.values())


def frame_name(node: dict) -> str:
    cf = node.get("callFrame") or {}
    name = cf.get("functionName") or ""
    url = cf.get("url") or ""
    if url.startswith("wasm://"):
        m = re.match(r"\$?(?:func|wasm-function\[)?(\d+)\]?", name)
        return f"wasm ${m.group(1)}" if m else f"wasm {name}"
    if name.startswith("("):
        return name
    short = url.rsplit("/", 1)[-1]
    return f"{name or '(anonymous)'} [{short}:{cf.get('lineNumber', 0) + 1}]" if short else (name or "(anonymous)")


def kind_of(node: dict) -> str:
    cf = node.get("callFrame") or {}
    name, url = cf.get("functionName") or "", cf.get("url") or ""
    if url.startswith("wasm://"):
        return "wasm"
    if name in ("(garbage collector)", "(idle)", "(program)", "(root)"):
        return name
    return "js"


def summarise(path: str, a: float, b: float, top: int, label: str) -> None:
    events = read_trace(path)
    pid, zero = page_zero(events)
    lo, hi = zero + a * 1000.0, zero + b * 1000.0
    names = thread_names(events)
    print(f"{label}: {os.path.basename(path)}, page clock {a:.0f} to {b:.0f} ms ({b - a:.0f} ms)")
    for p in sorted(profiles(events), key=lambda p: (p.pid != pid, p.tid)):
        inside = [(t, n) for t, n in p.samples if lo <= t <= hi]
        if len(inside) < 5:
            continue
        # Each sample stands for the time to the next one.
        weight: dict[int, float] = collections.Counter()
        for i, (t, n) in enumerate(inside):
            nxt = inside[i + 1][0] if i + 1 < len(inside) else min(hi, t + 1000.0)
            weight[n] += max(0.0, nxt - t)
        total = sum(weight.values())
        kinds: dict[str, float] = collections.Counter()
        selfs: dict[str, float] = collections.Counter()
        incl: dict[str, float] = collections.Counter()
        for n, w in weight.items():
            node = p.nodes.get(n, {})
            kinds[kind_of(node)] += w
            selfs[frame_name(node)] += w
            seen = set()
            at = node
            while at:
                key = frame_name(at)
                if key not in seen:
                    incl[key] += w
                    seen.add(key)
                at = p.nodes.get(at.get("parent")) if at.get("parent") else None
        busy = total - kinds.get("(idle)", 0.0)
        tname = names.get((p.pid, p.tid), "")
        print(f"\n  thread {tname or p.tid} (pid {p.pid}{', the page' if p.pid == pid else ''}): "
              f"{total / 1000:.0f} ms sampled, {busy / 1000:.0f} ms busy, {len(inside)} samples")
        print("    by kind: " + ", ".join(f"{k} {v / 1000:.0f} ms" for k, v in kinds.most_common()))
        print(f"    self time, top {top}:")
        for k, v in selfs.most_common(top):
            print(f"      {v / 1000:8.1f} ms  {100 * v / max(busy, 1):5.1f}%  {k}")
        js = [(k, v) for k, v in incl.most_common() if not k.startswith(("wasm ", "("))][:12]
        if js:
            print("    the engine's JS, inclusive (what wasm called out to):")
            for k, v in js:
                print(f"      {v / 1000:8.1f} ms  {k}")
    # The trace's own events in the stretch, by thread: GC, compiles, tiers.
    spans: dict[tuple[int, int], dict[str, list[float]]] = collections.defaultdict(lambda: collections.defaultdict(lambda: [0.0, 0]))
    open_: dict[tuple[int, int, str], list[float]] = collections.defaultdict(list)
    for e in events:
        ph, ts = e.get("ph"), e.get("ts", 0)
        key = (e.get("pid"), e.get("tid"))
        if ph == "X":
            s, d = ts, e.get("dur", 0)
            ov = min(hi, s + d) - max(lo, s)
            if ov > 0 and e.get("name") not in ("ProfileChunk", "RunTask", "ThreadControllerImpl::RunTask"):
                spans[key][e["name"]][0] += ov
                spans[key][e["name"]][1] += 1
        elif ph == "B":
            open_[(key[0], key[1], e.get("name"))].append(ts)
        elif ph == "E":
            stack = open_.get((key[0], key[1], e.get("name")))
            if stack:
                s = stack.pop()
                ov = min(hi, ts) - max(lo, s)
                if ov > 0:
                    spans[key][e["name"]][0] += ov
                    spans[key][e["name"]][1] += 1
        elif ph in ("i", "I", "n") and lo <= ts <= hi:
            spans[key][e.get("name", "?") + " (instant)"][1] += 1
    print("\n  trace events in it (overlap with the stretch), by thread:")
    for key in sorted(spans, key=lambda k: (k[0] != pid, k[1])):
        rows = sorted(spans[key].items(), key=lambda kv: (-kv[1][0], -kv[1][1]))
        rows = [r for r in rows if r[1][0] >= 2000 or (r[1][0] == 0 and r[1][1] >= 3)][:12]
        if not rows:
            continue
        print(f"    {names.get(key, '') or key[1]} (pid {key[0]}):")
        for name, (us, count) in rows:
            print(f"      {us / 1000:8.1f} ms  x{count:<6} {name}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("trace")
    ap.add_argument("--from", dest="a", type=float)
    ap.add_argument("--to", dest="b", type=float)
    ap.add_argument("--later", default="")
    ap.add_argument("--compile", action="store_true")
    ap.add_argument("--top", type=int, default=25)
    args = ap.parse_args()
    marks_path = re.sub(r"\.json$", ".marks.json", args.trace)
    marks = json.load(open(marks_path)) if os.path.exists(marks_path) else {}
    if args.later:
        # [when it began, how long], on the page's clock (Later._note).
        began, ms = (marks.get("loaded") or {})[args.later]
        summarise(args.trace, began, began + ms, args.top, f"first use of {args.later}")
    elif args.compile:
        m = marks.get("marks") or {}
        up = next((t for t, line in m.get("said", []) if line.startswith("Build configuration")), None)
        done = (m.get("boot") or {}).get("compiled")
        if up is None or done is None:
            sys.exit("trace_window: no engine line or no 'compiled' mark in the marks")
        summarise(args.trace, up, done, args.top, "the start's compile")
    else:
        summarise(args.trace, args.a, args.b, args.top, "stretch")


if __name__ == "__main__":
    main()
