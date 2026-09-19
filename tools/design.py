#!/usr/bin/env python3
"""Design a model from a sentence, and write it where the app can open it.

    tools/design.py "a small lighthouse"
    tools/design.py "a red sports car" --out models/car.ldr --effort max

Prints what it is doing as it goes, because a design takes a while and
silence is indistinguishable from a hang.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from brain.catalogue import load           # noqa: E402
from brain.designer import design          # noqa: E402
from brain.model import to_ldr             # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("brief", help="what to build")
    parser.add_argument("--out", default="", help="where to write the .ldr")
    parser.add_argument("--effort", default="high",
                        choices=["low", "medium", "high", "xhigh", "max"])
    parser.add_argument("--repairs", type=int, default=3,
                        help="how many times it may repair a failing design")
    parser.add_argument("--turns", type=int, default=24,
                        help="how many conversation turns it may take")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    catalogue = load()
    started = time.time()

    def say(text: str) -> None:
        if not args.quiet:
            print(f"  [{time.time() - started:5.1f}s] {text}", flush=True)

    print(f"designing: {args.brief}")
    result = design(
        args.brief,
        catalogue=catalogue,
        max_repairs=args.repairs,
        max_turns=args.turns,
        effort=args.effort,
        on_event=say,
    )

    print()
    for note in result.transcript[-2:]:
        print(note.strip()[:700])
    print()
    if len(result.model) == 0:
        print("no design was submitted")
    else:
        print(result.report.summary())
    if len(result.model) and not result.report.ok:
        print(result.report.as_feedback())
    print(
        f"rounds={result.rounds} tools={result.tool_calls} "
        f"tokens in={result.input_tokens:,} out={result.output_tokens:,} "
        f"{time.time() - started:.0f}s")

    counts = result.model.part_counts()
    if counts:
        top = sorted(counts.items(), key=lambda kv: -kv[1])[:6]
        print("parts: " + ", ".join(f"{k}x{v}" for k, v in top))

    out = Path(args.out) if args.out else ROOT / "models" / "design.ldr"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(to_ldr(result.model, catalogue.sizes(), author="Brickworks"))
    print(f"wrote {out} ({len(result.model)} parts)")
    return 0 if result.report.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
