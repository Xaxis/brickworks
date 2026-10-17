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

With --parts-url it stands in for the deployment as it is: /api/account
names that URL, as the deployment names PARTS_URL, so a local export reads
the real parts bucket (its geometry, and the LDraw files a carried part is
drawn from, tools/storage_ldraw.py):

    tools/web/serve.py build/web 8840 --parts-url "$PARTS_URL"

Done here rather than by intercepting requests in the browser, because
interception never saw the app's fetches: a check that throttled them
there scrolled 4,680 parts deep and counted none.

With --share it also plays a shared model's link, as api/share.js does:
/api/share?id=<any id> answers with the model in that file, and /m/<id>
sends the browser on to the viewer, /index.html?view=<id>, as the link's
page does. So the viewer and Build it can be driven on a local export
with nobody's account and no row in the database:

    tools/web/serve.py build/web 8761 --parts assets/generated/parts --delay 0 \\
        --share models/house.ldr
"""

from __future__ import annotations

import argparse
import json
import random
import re
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".lbm": "application/octet-stream",
    }
    parts: Path | None = None
    parts_url: str = ""
    delay: float = 0.0
    share: Path | None = None

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802 - the name http.server calls
        path = self.path.split("?", 1)[0]
        if self.share is not None and self._shared(path):
            return
        if self.parts_url and path == "/api/account":
            self._send(200, "application/json",
                       json.dumps({"parts_url": self.parts_url}).encode())
            return
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

    def _shared(self, path: str) -> bool:
        """The link's two addresses, played from --share's file. True if answered."""
        assert self.share is not None
        link = re.fullmatch(r"/m/([A-Za-z0-9]{10})/?", path)
        if link:
            self.send_response(302)
            self.send_header("Location", f"/index.html?view={link.group(1)}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return True
        if path != "/api/share":
            return False
        query = parse_qs(self.path.split("?", 1)[1] if "?" in self.path else "")
        shared_id = (query.get("id") or [""])[0]
        if not re.fullmatch(r"[A-Za-z0-9]{10}", shared_id):
            self._send(404, "application/json", b'{"error": "no such link"}')
            return True
        text = self.share.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        name = next((line[2:].strip() for line in lines
                     if line.startswith("0 ") and not line.startswith(("0 FILE", "0 !", "0 Name:"))),
                    self.share.stem)
        parts = sum(1 for line in lines if line.startswith("1 ") and line.lower().rstrip().endswith(".dat"))
        host = self.headers.get("Host", "127.0.0.1")
        body = {"id": shared_id, "name": name, "author": "Served Locally", "parts": parts,
                "url": f"http://{host}/m/{shared_id}", "model": text}
        self._send(200, "application/json", json.dumps(body).encode())
        print(f"share {shared_id}", flush=True)
        return True

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
    parser.add_argument("--parts-url", help="answer /api/account with this as where parts live")
    parser.add_argument("--delay", type=float, default=2500.0, help="milliseconds")
    parser.add_argument("--share", help="answer /api/share?id= and /m/<id> with this model")
    args = parser.parse_args()
    if args.parts:
        Handler.parts = Path(args.parts).resolve()
        Handler.delay = args.delay / 1000.0
    if args.share:
        Handler.share = Path(args.share).resolve()
    if args.parts_url:
        Handler.parts_url = args.parts_url
    server = ThreadingHTTPServer(
        ("127.0.0.1", args.port), partial(Handler, directory=args.directory))
    print(f"serving {args.directory} at http://127.0.0.1:{args.port}/ (COOP/COEP on)"
          + (f", parts from {args.parts} after {args.delay:.0f} ms" if args.parts else "")
          + (f", parts at {args.parts_url}" if args.parts_url else ""),
          flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
