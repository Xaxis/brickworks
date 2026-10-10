#!/usr/bin/env python3
"""Serve a web build locally with the headers the threaded build needs.

Python's http.server will not do: a Godot build with threads refuses to
start unless the page is cross-origin isolated, which takes two headers
no static server sends by default. Without them the failure looks like
the engine hanging rather than like a missing header.

    tools/web/serve.py [dir] [port]
    tools/web/serve.py build/web 8761 --parts assets/generated/parts --delay 2500

With --parts it also stands in for the deployment, on a slow network:
/api/account names /parts/ on this server as where geometry lives, and
each /parts/<hash>.lbm is read from that directory after --delay
milliseconds and up to as much again. A line "part <name>" is printed
for each one served, so a browser check can tell the network was used.

Done here rather than by intercepting requests in the browser, because
interception never saw the app's fetches: a check that throttled them
there scrolled 4,680 parts deep and counted none.
"""

from __future__ import annotations

import argparse
import json
import random
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".lbm": "application/octet-stream",
    }
    parts: Path | None = None
    delay: float = 0.0

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802 - the name http.server calls
        path = self.path.split("?", 1)[0]
        if self.parts is not None and path == "/api/account":
            host = self.headers.get("Host", "127.0.0.1")
            self._send(200, "application/json",
                       json.dumps({"parts_url": f"http://{host}/parts/"}).encode())
            return
        if self.parts is not None and path.startswith("/parts/") and path.endswith(".lbm"):
            time.sleep(self.delay * (1.0 + random.random()))
            name = Path(path).name
            source = self.parts / name
            if not source.is_file():
                self._send(404, "text/plain", b"")
                return
            print(f"part {name}", flush=True)
            self._send(200, "application/octet-stream", source.read_bytes())
            return
        super().do_GET()

    def _send(self, status: int, kind: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:  # quiet
        pass


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Serve a web build locally with the headers the threaded build needs.")
    parser.add_argument("directory", nargs="?", default="build/web")
    parser.add_argument("port", nargs="?", type=int, default=8099)
    parser.add_argument("--parts", help="serve /parts/*.lbm from here, slowly")
    parser.add_argument("--delay", type=float, default=2500.0, help="milliseconds")
    args = parser.parse_args()
    if args.parts:
        Handler.parts = Path(args.parts).resolve()
        Handler.delay = args.delay / 1000.0
    server = ThreadingHTTPServer(
        ("127.0.0.1", args.port), partial(Handler, directory=args.directory))
    print(f"serving {args.directory} at http://127.0.0.1:{args.port}/ (COOP/COEP on)"
          + (f", parts from {args.parts} after {args.delay:.0f} ms" if args.parts else ""),
          flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
