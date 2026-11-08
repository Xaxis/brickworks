#!/usr/bin/env python3
"""Press a window's close button the way an X11 window manager does.

    python3 -I tools/x11_close.py --atoms     make the atoms a window manager makes
    python3 -I tools/x11_close.py WINDOW      send WINDOW (an X id) WM_DELETE_WINDOW

What the title bar's X, Alt+F4 and a session ending send the window: a
ClientMessage of WM_PROTOCOLS naming WM_DELETE_WINDOW. Godot asks for that
atom only if it exists, as it does on a desktop, where the window manager
made it first; on a bare Xvfb nothing has, so a window started there never
says it takes a close request. --atoms makes them, before the app starts,
while something else (the probe's own window) keeps the server from
resetting. Exit 0 when done, 2 with no display. By libX11 through ctypes:
there is no xdotool here. Used by src/dev/dialog_close_probe.gd.
"""
import ctypes
import ctypes.util
import sys

x = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
x.XOpenDisplay.restype = ctypes.c_void_p
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XInternAtom.restype = ctypes.c_ulong
x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
x.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
x.XCloseDisplay.argtypes = [ctypes.c_void_p]


class ClientMessage(ctypes.Structure):
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong), ("send_event", ctypes.c_int),
                ("display", ctypes.c_void_p), ("window", ctypes.c_ulong),
                ("message_type", ctypes.c_ulong), ("format", ctypes.c_int),
                ("l", ctypes.c_long * 5)]


class XEvent(ctypes.Union):
    _fields_ = [("xclient", ClientMessage), ("pad", ctypes.c_long * 24)]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[2])
        return 2
    display = x.XOpenDisplay(None)
    if not display:
        print("x11_close: no display")
        return 2
    protocols = x.XInternAtom(display, b"WM_PROTOCOLS", 0)
    delete = x.XInternAtom(display, b"WM_DELETE_WINDOW", 0)
    if sys.argv[1] != "--atoms":
        window = int(sys.argv[1], 0)
        event = XEvent()
        event.xclient.type = 33  # ClientMessage
        event.xclient.send_event = 1
        event.xclient.display = display
        event.xclient.window = window
        event.xclient.message_type = protocols
        event.xclient.format = 32
        event.xclient.l[0] = delete
        event.xclient.l[1] = 0  # CurrentTime
        x.XSendEvent(display, window, 0, 0, ctypes.byref(event))
    x.XSync(display, 0)
    x.XCloseDisplay(display)
    print("x11_close: %s" % ("atoms made" if sys.argv[1] == "--atoms"
                             else "WM_DELETE_WINDOW sent to %s" % sys.argv[1]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
