#!/usr/bin/env python3
"""Read the app's accessibility tree as a screen reader reads it, on Linux.

    dbus-run-session -- python3 -I tools/a11y_tree.py DIR -- GODOT ARGS...

Runs GODOT ARGS with a screen reader said to be on, and answers its asks:
each ask_N.json the app writes in DIR is answered with tree_N.json.
  {"do": "read"}              the windows in the app's tree, and its focus
  {"do": "away", "xid": X}    the keys taken from X window X and given
                              back, as a person switching to another
                              program and back does; then a read

Godot speaks to a screen reader through AccessKit, which on Linux is
AT-SPI: a bus of its own (org.a11y.Bus) that the session bus names. The
app joins it when the bus says a screen reader is on (org.a11y.Status
ScreenReaderEnabled, read by Godot's FreeDesktopAtSPIMonitor), so that is
set here, as Orca sets it, and Godot's own "auto" mode then turns its
accessibility on: no flag of the app's is changed. What is read back is
what Orca reads: each window's role, name and states (MODAL among them),
and which element has the focus.

Only in a session bus of its own (dbus-run-session): on the person's own
bus it would turn their desktop's screen reader setting on. Exit 2 when
not, or when AT-SPI cannot be read; else the app's exit.
Used by src/dev/a11y_modal_probe.gd.
"""
import ctypes
import ctypes.util
import json
import os
import subprocess
import sys
import time

WINDOWS = {"dialog", "frame", "window", "alert", "file chooser", "color chooser"}
# How deep a walk goes: the app's tree is its scene's, a dialog's question
# a dozen levels into its dialog.
DEEPEST = 60


def refuse(why: str) -> int:
    print("a11y_tree: " + why, flush=True)
    return 2


def main() -> int:
    if len(sys.argv) < 4 or sys.argv[2] != "--":
        return refuse("usage: dbus-run-session -- python3 -I tools/a11y_tree.py DIR -- GODOT ARGS...")
    folder, command = sys.argv[1], sys.argv[3:]
    bus = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    if not bus or "/run/user/" in bus:
        return refuse("not in a session bus of its own (%s): run it under dbus-run-session"
                      % (bus or "none"))
    try:
        import gi
        gi.require_version("Atspi", "2.0")
        from gi.repository import Atspi, Gio, GLib
    except (ImportError, ValueError) as e:
        return refuse("no AT-SPI for Python here (%s)" % e)
    session = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    for what in ("IsEnabled", "ScreenReaderEnabled"):
        session.call_sync("org.a11y.Bus", "/org/a11y/bus", "org.freedesktop.DBus.Properties", "Set",
                          GLib.Variant("(ssv)", ("org.a11y.Status", what, GLib.Variant("b", True))),
                          None, Gio.DBusCallFlags.NONE, -1, None)
    print("a11y_tree: a screen reader said to be on, in this session's own bus", flush=True)
    os.makedirs(folder, exist_ok=True)
    app_run = subprocess.Popen(command)
    answered = 0
    while app_run.poll() is None:
        ask = os.path.join(folder, "ask_%d.json" % (answered + 1))
        if not os.path.exists(ask):
            GLib.MainContext.default().iteration(False)
            time.sleep(0.05)
            continue
        answered += 1
        try:
            with open(ask) as f:
                wanted = json.load(f)
        except (OSError, ValueError):
            # Being written: read it again.
            answered -= 1
            time.sleep(0.05)
            continue
        if wanted.get("do") == "away":
            wanted["away"] = away(int(wanted.get("xid", 0)))
        # The app sends its tree at most 60 times a second.
        time.sleep(0.25)
        answer = read(Atspi, app_run.pid)
        answer["asked"] = wanted
        out = os.path.join(folder, "tree_%d.json" % answered)
        with open(out + ".part", "w") as f:
            json.dump(answer, f)
        os.replace(out + ".part", out)
    return app_run.returncode


def read(Atspi, pid: int) -> dict:
    started = time.monotonic()
    desktop = Atspi.get_desktop(0)
    apps = []
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app is not None:
            apps.append(app)
    if not apps:
        return {"error": "no application in the tree", "windows": [], "focus": None}
    # This bus is the run's own: the app is the one there, or the one of its pid.
    app = next((a for a in apps if a.get_process_id() == pid), apps[0])
    Atspi.Accessible.set_cache_mask(app, Atspi.Cache.NONE)
    app.clear_cache()
    found = {"windows": [], "focus": None, "nodes": 0}
    walk(Atspi, app, [], found, 0)
    found["app"] = app.get_name()
    found["ms"] = round((time.monotonic() - started) * 1000)
    return found


def walk(Atspi, node, path: list, found: dict, depth: int) -> None:
    if node is None or depth > DEEPEST:
        return
    found["nodes"] += 1
    try:
        role = node.get_role_name()
        states = node.get_state_set()
        showing = states.contains(Atspi.StateType.SHOWING)
        if role in WINDOWS:
            found["windows"].append({"path": path, "role": role, "name": node.get_name(),
                                     "modal": states.contains(Atspi.StateType.MODAL),
                                     "showing": showing})
        if states.contains(Atspi.StateType.FOCUSED):
            found["focus"] = {"path": path, "role": role, "name": node.get_name()}
        # A hidden branch holds nothing a person meets.
        if depth > 0 and not showing and role not in WINDOWS:
            return
        for i in range(node.get_child_count()):
            walk(Atspi, node.get_child_at_index(i), path + [i], found, depth + 1)
    except Exception as e:  # a node gone while read: said, not fatal
        found.setdefault("gone", []).append("%s: %s" % (path, e))


def away(xid: int) -> str:
    """The keys to no window, then back to xid: the app's FocusOut, FocusIn."""
    x = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
    x.XOpenDisplay.restype = ctypes.c_void_p
    x.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x.XSetInputFocus.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    x.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x.XOpenDisplay(None)
    if not display or not xid:
        return "no display" if not display else "no window"
    nothing, revert_to_parent = 0, 2
    x.XSetInputFocus(display, nothing, revert_to_parent, 0)
    x.XSync(display, 0)
    time.sleep(0.5)
    x.XSetInputFocus(display, xid, revert_to_parent, 0)
    x.XSync(display, 0)
    x.XCloseDisplay(display)
    return "the keys taken from the window and given back to %d" % xid


if __name__ == "__main__":
    sys.exit(main())
