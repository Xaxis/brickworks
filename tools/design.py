#!/usr/bin/env python3
"""Design a model from a sentence, and write it where the app can open it.

    tools/design.py "a small lighthouse"
    tools/design.py "a red sports car" --out models/car.ldr --effort max

This drives the assistant the application itself uses: the one that can
turn a part onto any of its six faces, look at what it has built, and
revise it.

There used to be a second designer here, written in Python, and this
called that one instead.  It built studs-up and only studs-up -- its
rotation was quarter turns about the vertical axis and it had no notion
of a face at all -- so a tiled wall, lettering, a grille, a curved
bonnet and a sail were all out of reach.  Asked for "a windmill with
four sails and a tapering tower" it spent eight of its ten turns
finding that out, concluded the checker mangled rotated parts, and
delivered a cross of stepped bricks that read as nothing in
particular.  The assistant this calls, given the same sentence, built
the windmill: a tapering tower with windows, a cap, and four arms
carrying lattice sails.

Two designers also meant two validators, and they had already drifted.

It wants a window.  The critique that makes the difference works by
rendering the model and looking at it, and --headless has nothing to
render with, so it falls back to reading the model as letters and the
result is worse.  Use --headless only where there is no display.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Lines Godot prints on the way up that say nothing about the design.
NOISE = (
    "Godot Engine v",
    "Vulkan ",
    "Metal ",
    "OpenGL ",
    "https://godotengine.org",
    "TextServer:",
    "CoreAudio:",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("brief", help="what to build")
    parser.add_argument("--out", default="", help="where to write the .ldr")
    parser.add_argument("--effort", default="",
                        choices=["", "low", "medium", "high", "xhigh", "max"],
                        help="how hard to think; the app's setting otherwise")
    parser.add_argument("--model", default="",
                        help="which model to use; the app's setting otherwise")
    parser.add_argument("--headless", action="store_true",
                        help="no window, and no pictures to judge the "
                             "design by — worse results, for machines "
                             "without a display")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    godot = shutil.which("godot")
    if godot is None:
        print("no godot on the path — the designer runs inside the app",
              file=sys.stderr)
        return 2

    out = Path(args.out) if args.out else ROOT / "models" / "design.ldr"
    out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    command = [godot, "--path", str(ROOT)]
    if args.headless:
        command.append("--headless")
    else:
        command += ["--resolution", "1400x900"]
    command += ["--", f"--ask={args.brief}", f"--out={out}"]
    if args.effort:
        command.append(f"--effort={args.effort}")
    if args.model:
        command.append(f"--model={args.model}")

    print(f"designing: {args.brief}")
    if args.headless:
        print("  (headless: it cannot look at what it builds, so it "
              "cannot revise it)")
    started = time.time()
    return _run(command, quiet=args.quiet, started=started)


def _run(command: list[str], *, quiet: bool, started: float) -> int:
    """Run it, passing its progress through as it happens.

    A design takes many minutes and silence is indistinguishable from a
    hang, which is the whole reason the old one printed as it went.
    """
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )
    assert process.stdout is not None
    for line in process.stdout:
        line = line.rstrip()
        if not line or any(line.startswith(n) for n in NOISE):
            continue
        if quiet and line.startswith("  ["):
            continue
        print(line, flush=True)
    code = process.wait()
    print(f"{time.time() - started:.0f}s")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
