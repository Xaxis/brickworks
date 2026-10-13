#!/usr/bin/env python3
"""Two windows of the desktop app, each on a model of its own.

    tools/windows_check.py

Every window of the app reads and writes the one data folder, as every
tab of the site shares the browser's storage. Until 2026-10-13 they shared
the one autosave too: two windows reopened the same model, and whichever
wrote last decided what both reopened. Now each window holds a session of
its own (src/parts/tab_session.gd), and this proves it with real
processes in a data folder of their own (never the person's):

  1. A working model from before sessions is in the folder. Two apps
     start together; each holds a session of its own, with its process id
     in it, and only one takes the old working model.
  2. Each is given a different model over its port (tools/brick.py's
     socket), and each one's autosave lands in its own session.
  3. Both stop. Started again one after the other, the first takes the
     session written most recently and the second the other: each window
     reopens a model, and they are the two models, not one twice.

Starts and stops only the apps it started. Headless, so no window opens.
"""

from __future__ import annotations

import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from brickworks_mcp import App  # noqa: E402

PORTS = (8851, 8852)
PATIENCE = 240.0
failures = 0


def check(what: str, ok: bool) -> bool:
    global failures
    print("  %s  %s" % ("ok  " if ok else "FAIL", what))
    if not ok:
        failures += 1
    return ok


def listening(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2.0):
            return True
    except OSError:
        return False


def start(port: int, data: Path, logs: Path) -> subprocess.Popen:
    env = dict(os.environ, XDG_DATA_HOME=str(data))
    log = open(logs / ("app-%d.log" % port), "w")
    return subprocess.Popen(
        ["godot", "--headless", "--path", str(ROOT), "--", "--mcp=%d" % port],
        stdout=log, stderr=subprocess.STDOUT, env=env, start_new_session=True)


def wait_listening(apps: dict[int, subprocess.Popen]) -> bool:
    since = time.time()
    while time.time() - since < PATIENCE:
        if all(listening(port) for port in apps):
            return True
        if any(app.poll() is not None for app in apps.values()):
            return False
        time.sleep(0.5)
    return False


def stop(apps: dict[int, subprocess.Popen]) -> None:
    for app in apps.values():
        if app.poll() is None:
            os.killpg(app.pid, signal.SIGTERM)
    for app in apps.values():
        try:
            app.wait(timeout=20)
        except subprocess.TimeoutExpired:
            os.killpg(app.pid, signal.SIGKILL)
            app.wait()


def call(port: int, tool: str, arguments: dict) -> str:
    """One tool over the app's port, as the words it answered with."""
    answer = App(port).ask(tool, arguments)
    said = [str(block.get("text", "")) for block in answer.get("content") or []
            if isinstance(block, dict)]
    return "\n".join(said) or str(answer.get("error", ""))


def tower(count: int, colour: int) -> dict:
    return {"bricks": [{"part": "3001", "color": colour, "x": 0, "y": 3 * n, "z": 0, "rot": 0}
                       for n in range(count)]}


def alive(pid: int) -> bool:
    """A process of the apps this started: godot is a wrapper here, so the
    id a session holds is the engine's own, not the one Popen gave."""
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def sessions(user: Path) -> dict[str, dict]:
    found: dict[str, dict] = {}
    root = user / "sessions"
    if not root.is_dir():
        return found
    for one in sorted(root.iterdir()):
        if not one.is_dir() or one.name == "probe":
            continue
        pid_file = one / "held" / "pid"
        autosave = one / "autosave.ldr"
        found[one.name] = {
            "pid": int(pid_file.read_text().strip() or 0) if pid_file.exists() else 0,
            "bricks": sum(1 for line in autosave.read_text().splitlines()
                          if line.startswith("1 ")) if autosave.exists() else -1,
            "at": autosave.stat().st_mtime if autosave.exists() else 0.0,
        }
    return found


def bricks_in(port: int) -> int:
    said = call(port, "look_at_model", {})
    for line in said.splitlines():
        if line.endswith("parts are on the baseplate."):
            return int(line.split()[0])
    return -1


def main() -> int:
    scratch = Path(tempfile.mkdtemp(prefix="brickworks-windows-"))
    data = scratch / "data"
    user = data / "godot" / "app_userdata" / "Brickworks"
    user.mkdir(parents=True)
    # The working model of before: a tower of seven, in the one old place.
    (user / "autosave.ldr").write_text(
        "0 Old Tower\n0 Name: autosave.ldr\n"
        + "".join("1 4 0 %d 0 1 0 0 0 1 0 0 0 1 3001.dat\n" % (-24 * n) for n in range(7)))
    apps: dict[int, subprocess.Popen] = {}
    try:
        print("\ntwo windows, started together")
        apps = {port: start(port, data, scratch) for port in PORTS}
        if not check("both apps listen on their ports", wait_listening(apps)):
            return 1
        found = sessions(user)
        held = {name: one["pid"] for name, one in found.items() if alive(one["pid"])}
        pids = set(held.values())
        check("each holds a session of its own: %s" % ", ".join(
            "%s by %d" % (name, pid) for name, pid in held.items()),
            len(held) == 2 and len(pids) == 2)
        olds = [port for port in PORTS if bricks_in(port) == 7]
        check("one of them, and only one, reopened the working model from before (port %s)"
              % olds, len(olds) == 1)
        check("...and the old one place is empty now",
              not (user / "autosave.ldr").exists())

        print("\na model of its own in each")
        # Seconds apart, so which was written last is plain to the second.
        for port, count, colour in ((PORTS[0], 3, 4), (PORTS[1], 5, 1)):
            call(port, "clear_model", {})
            call(port, "submit_design", tower(count, colour))
            time.sleep(5.0)
        time.sleep(2.0)
        found = sessions(user)
        counts = sorted(one["bricks"] for one in found.values() if one["pid"] in pids)
        check("each window's autosave is its own: %s parts" % counts, counts == [3, 5])
        mine = [one for one in found.values() if one["pid"] in pids]
        stop(apps)
        if not mine:
            check("...so there is nothing to reopen", False)
            return 1
        newest = max(mine, key=lambda one: one["at"])

        print("\nthe windows closed, and opened again one after the other")
        first = {PORTS[0]: start(PORTS[0], data, scratch)}
        if not check("the first listens", wait_listening(first)):
            return 1
        reopened_first = bricks_in(PORTS[0])
        second = {PORTS[1]: start(PORTS[1], data, scratch)}
        apps = {**first, **second}
        if not check("the second listens", wait_listening(second)):
            return 1
        reopened_second = bricks_in(PORTS[1])
        check("the first reopens the model written last (%d parts): %d"
              % (newest["bricks"], reopened_first), reopened_first == newest["bricks"])
        check("the second reopens the other, not the same one again: %d" % reopened_second,
              sorted([reopened_first, reopened_second]) == [3, 5])
    finally:
        stop(apps)
        shutil.rmtree(scratch, ignore_errors=True)
    print("")
    print("%d FAILURE(S)" % failures if failures
          else "two windows of the app, each on a model of its own")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
