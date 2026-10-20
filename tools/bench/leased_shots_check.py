#!/usr/bin/env python3
"""Prove a headless app's leased drawer draws the pictures a window draws.

    python3 tools/bench/leased_shots_check.py --model X.ldr --out DIR [--port 9040]
                                              [--history | --windows-only]

The design bench runs the app headless and has each picture drawn by a short
process on the GPU's lease (src/ai/leased_shots.gd, src/dev/draw_shots.gd),
where it used to run the app in a window on the lease for the whole session.
This opens one model both ways, the window on the lease and the headless app
with its drawer, asks each for the same pictures over MCP (view_model from
several sides and close, a change's picture with what it changed picked
out), and compares them pixel for pixel: the PNGs are kept in DIR/window and
DIR/leased. Exit 0 when every picture came both ways and every pair is the
same picture or differs in at most --most pixels (16 of a million): a window's
own pictures differ by that much from run to run, 1 to 9 pixels of a change's
picture on 2026-10-20, scattered single pixels, most likely where faces tie
and the card breaks the tie by the order things were made in. With --history a second window is asked the views
the other way round first, and the bar is the larger of --most and what the
two windows differ by; --windows-only runs the two windows alone.

The apps run one after the other, each with a user folder of its own under
DIR, on --port and the ports after it.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from mcp_check import Relay, listening  # noqa: E402

CORE = Path.home() / ".claude" / "claude-core" / "bin"
GPU = str(CORE / "gpu")
SCREEN = "-screen 0 1600x900x24"
DRAWER = [GPU, "xvfb-run", "-a", f"--server-args={SCREEN}", "godot"]

ASKED = [
    ("corner", "view_model", {"from": "corner"}),
    ("front", "view_model", {"from": "front"}),
    ("top", "view_model", {"from": "top"}),
    ("close", "view_model", {"from": "corner", "where": {
        "x_from": 0, "x_to": 8, "y_from": 0, "y_to": 12, "z_from": 0, "z_to": 8}}),
    # A change answers with a picture, what it changed picked out in magenta.
    ("recolour", "edit_model", {"recolor": [{"bricks": [1, 2, 3], "color": 4}]}),
    ("after", "view_model", {"from": "back"}),
]


def start(mode: str, model: Path, out: Path, port: int, name: str) -> subprocess.Popen:
    data = out / f"{name}_data"
    data.mkdir(parents=True, exist_ok=True)
    log = out / f"{name}_godot.log"
    tail = ["--", f"--mcp={port}", f"--model={model}"]
    if mode == "window":
        command = [GPU, "xvfb-run", "-a", f"--server-args={SCREEN}", "godot", "--path", str(ROOT),
                   "--log-file", str(log), *tail]
    else:
        command = ["godot", "--headless", "--path", str(ROOT), "--log-file", str(log), *tail,
                   "--draw-by=" + json.dumps(DRAWER)]
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    env.update(XDG_DATA_HOME=str(data), MESA_VK_WSI_DEBUG="sw")
    app = subprocess.Popen(command, cwd=ROOT, env=env, stdout=(out / f"{name}.log").open("w"),
                           stderr=subprocess.STDOUT, start_new_session=True)
    waited = time.time()
    while time.time() - waited < 600:
        if app.poll() is not None:
            raise SystemExit(f"{name}: the app exited {app.returncode}; see {out / (name + '.log')}")
        if listening(port):
            return app
        time.sleep(0.5)
    raise SystemExit(f"{name}: never listened on {port}")


def drive(mode: str, model: Path, out: Path, port: int,
          order: list[tuple[str, str, dict]] = ASKED) -> dict[str, list[bytes]]:
    app = start("leased" if mode == "leased" else "window", model, out, port, mode)
    relay = Relay(port)
    # A call that outlasts the socket's wait becomes a job, followed to its
    # answer as a session follows it: a picture waiting for the GPU's lease.
    relay.follow = True
    pictures: dict[str, list[bytes]] = {}
    try:
        relay.call("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                  "clientInfo": {"name": "leased_shots_check", "version": "1"}})
        relay.notify("notifications/initialized")
        # The model is opened from the command line: wait until it is all down.
        last, steady = "", 0
        # Asked while a big model still opens, look_at_model has crashed the
        # app (mechanism.gd's table, 2026-10-20): give it a moment first.
        time.sleep(10.0)
        for _ in range(240):
            said = "".join(b.get("text", "") for b in relay.call("tools/call", {
                "name": "look_at_model", "arguments": {}}).get("result", {}).get("content", []))
            head = said[:120]
            steady = steady + 1 if head == last and "brick" in head.lower() else 0
            last = head
            if steady >= 3:
                break
            time.sleep(2.0)
        print(f"{mode}: {last[:100]!r}", flush=True)
        (out / mode).mkdir(exist_ok=True)
        for name, tool, arguments in order:
            began = time.time()
            blocks = relay.call("tools/call", {"name": tool, "arguments": arguments}) \
                .get("result", {}).get("content", [])
            images = [base64.b64decode(b["data"]) for b in blocks if b.get("type") == "image"]
            pictures[name] = images
            for k, png in enumerate(images):
                (out / mode / f"{name}_{k}.png").write_bytes(png)
            print(f"{mode}: {name}: {len(images)} picture(s) in {time.time() - began:.1f} s",
                  flush=True)
    finally:
        relay.stop()
        app.terminate()
        try:
            app.wait(timeout=30)
        except subprocess.TimeoutExpired:
            app.kill()
            app.wait()
    return pictures


def differs(one: bytes, other: bytes) -> tuple[int, int]:
    """(pixels that differ, pixels), decoded."""
    from PIL import Image, ImageChops
    a = Image.open(io.BytesIO(one)).convert("RGBA")
    b = Image.open(io.BytesIO(other)).convert("RGBA")
    if a.size != b.size:
        return a.size[0] * a.size[1], a.size[0] * a.size[1]
    diff = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v else 0)
    return sum(1 for v in diff.getdata() if v), a.size[0] * a.size[1]


def compare(what: str, one_side: dict[str, list[bytes]], other_side: dict[str, list[bytes]],
            most: int) -> tuple[bool, int]:
    """Each picture of one side against the other's: (all within `most` pixels, the most
    that differed)."""
    print(what)
    within, worst = True, 0
    for name, _tool, _arguments in ASKED:
        a, b = one_side.get(name, []), other_side.get(name, [])
        if not a or len(a) != len(b):
            print(f"  FAIL  {name}: {len(a)} picture(s) one side, {len(b)} the other")
            within = False
            continue
        for k, (one, other) in enumerate(zip(a, b)):
            if one == other:
                print(f"  ok    {name}_{k}: the same PNG, byte for byte ({len(one)} bytes)")
                continue
            n, total = differs(one, other)
            worst = max(worst, n)
            print(f"  {'ok  ' if n <= most else 'FAIL'}  {name}_{k}: {n} of {total} pixels differ")
            within = within and n <= most
    return within, worst


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, default=9040)
    parser.add_argument("--history", action="store_true",
                        help="also a second window asked in another order, for how much a "
                        "window's own pictures vary with what it drew before; the drawer's are "
                        "then held to that")
    parser.add_argument("--most", type=int, default=16,
                        help="pixels a picture may differ by, as two windows' do")
    parser.add_argument("--windows-only", action="store_true",
                        help="only the two windows of --history")
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    model = args.model.resolve()
    window = drive("window", model, args.out, args.port)
    leased = {} if args.windows_only else drive("leased", model, args.out, args.port + 1)
    most = args.most
    if args.history or args.windows_only:
        # The unchanged model's views the other way round, then the change.
        turned = [*reversed(ASKED[:4]), *ASKED[4:]]
        again = drive("window2", model, args.out, args.port + 2, turned)
        _, apart = compare("a window against a window asked in another order:", window, again,
                           1 << 30)
        most = max(most, apart)
        if args.windows_only:
            return 0
    same, _ = compare(f"the window against the leased drawer, {most} pixels at most:", window,
                      leased, most)
    return 0 if same else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
