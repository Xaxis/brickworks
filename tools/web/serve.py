#!/usr/bin/env python3
"""Serve a web build locally with the headers the threaded build needs.

Python's http.server will not do: a Godot build with threads refuses to
start unless the page is cross-origin isolated, which takes two headers
no static server sends by default. Without them the failure looks like
the engine hanging rather than like a missing header.

    tools/web/serve.py [dir] [port]
"""

from __future__ import annotations

import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".lbm": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, *args) -> None:  # quiet
        pass


def main() -> int:
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8099
    server = ThreadingHTTPServer(
        ("127.0.0.1", port), partial(Handler, directory=directory))
    print(f"serving {directory} at http://127.0.0.1:{port}/ (COOP/COEP on)")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
