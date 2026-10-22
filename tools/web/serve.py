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
A part's exact shape, /parts/<hash>.bwx, is read from exact/ beside that
directory, as the bucket has it beside the geometry ("exact <name>").

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

Given as ID=FILE, and as often as wanted, each link plays its own file
(share_steps_flow.mjs serves three sizes of one model at once); a plain
FILE answers every other id.

With --library it stands in for the parts store's library (src/net/
model_library.gd) and the gallery's list, as the library screen and
open_model library= read them: /api/account names this server as the
store, /library/index.json and /library/covers/ are read from DIR, and
/library/omr/<file> from vendor/omr/files. DIR's gallery.json, when there
is one, is the gallery: /api/share?op=list answers its models (q matched
in their names and authors, kind and size kept to), /api/share?id= each
model's file with its author and licence, and /m/<id>.webp its cover from
DIR/covers/. tests/fixtures/library is one (src/dev/library_probe.gd):

    tools/web/serve.py tests/fixtures/library 8931 --library tests/fixtures/library
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
    shares: dict[str, Path] = {}
    library: Path | None = None
    omr: Path | None = None

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802 - the name http.server calls
        path = self.path.split("?", 1)[0]
        if self.library is not None and self._library(path):
            return
        if (self.share is not None or self.shares) and self._shared(path):
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
        if self.parts is not None and path.startswith("/parts/") and path.endswith((".lbm", ".bwx")):
            time.sleep(self.delay * (1.0 + random.random()))
            name = Path(path).name
            # A part's exact shape lies beside its geometry in the bucket
            # (tools/web_pack.py), and in exact/ beside parts/ here.
            source = (self.parts.parent / "exact" if name.endswith(".bwx") else self.parts) / name
            if not source.is_file():
                self._send(404, "text/plain", b"")
                return
            print(f"{'exact' if name.endswith('.bwx') else 'part'} {name}", flush=True)
            self._send(200, "application/octet-stream", source.read_bytes())
            return
        super().do_GET()

    def _library(self, path: str) -> bool:
        """The store's library/ and the gallery, played from --library. True if answered."""
        assert self.library is not None
        host = self.headers.get("Host", "127.0.0.1")
        if path == "/api/account":
            self._send(200, "application/json", json.dumps({"parts_url": f"http://{host}/"}).encode())
            return True
        if path.startswith("/library/"):
            rest = path[len("/library/"):]
            if ".." in rest or "\\" in rest:
                self._send(404, "text/plain", b"")
                return True
            source = (self.omr / rest[len("omr/"):] if rest.startswith("omr/") and self.omr
                      else self.library / rest)
            if not source.is_file():
                self._send(404, "text/plain", b"")
                return True
            kind = {".json": "application/json", ".webp": "image/webp"}.get(source.suffix,
                                                                           "text/plain")
            print(f"library {rest}", flush=True)
            self._send(200, kind, source.read_bytes())
            return True
        gallery = self.library / "gallery.json"
        if not gallery.is_file():
            return False
        models = json.loads(gallery.read_text(encoding="utf-8"))["models"]
        cover = re.fullmatch(r"/m/([A-Za-z0-9]{10})\.webp", path)
        if cover:
            picture = self.library / "covers" / f"{cover.group(1)}.webp"
            if picture.is_file():
                self._send(200, "image/webp", picture.read_bytes())
            else:
                self._send(404, "text/plain", b"")
            return True
        if path != "/api/share":
            return False
        query = parse_qs(self.path.split("?", 1)[1] if "?" in self.path else "")
        asked = {key: (values or [""])[0] for key, values in query.items()}
        root = Path(__file__).resolve().parents[2]
        if asked.get("op") == "list":
            words = asked.get("q", "").lower().split()
            sizes = {"small": (0, 199), "medium": (200, 999), "large": (1000, 1 << 30)}
            least, most = sizes.get(asked.get("size", ""), (0, 1 << 30))
            found = [model for model in models
                     if all(word in f"{model['name']} {model['author']}".lower() for word in words)
                     and (not asked.get("kind") or model.get("kind") == asked["kind"])
                     and least <= model["parts"] <= most]
            cards = [{"id": model["id"], "name": model["name"], "author": model["author"],
                      "parts": model["parts"], "kind": model.get("kind"), "licence": model["licence"],
                      "builds": 0, "url": f"http://{host}/m/{model['id']}",
                      "thumb": f"http://{host}/m/{model['id']}.webp"} for model in found]
            page = max(1, int(asked.get("page", "1") or 1))
            print(f"gallery list {asked}", flush=True)
            self._send(200, "application/json", json.dumps(
                {"models": cards[(page - 1) * 24:page * 24], "more": len(cards) > page * 24,
                 "per_page": 24}).encode())
            return True
        model = next((one for one in models if one["id"] == asked.get("id")), None)
        if model is None:
            return False
        text = (root / model["file"]).read_text(encoding="utf-8", errors="replace")
        print(f"share {model['id']}", flush=True)
        self._send(200, "application/json", json.dumps({
            "id": model["id"], "name": model["name"], "author": model["author"],
            "parts": model["parts"], "licence": model["licence"], "version": 1, "newest": 1,
            "url": f"https://brickworks.diy/m/{model['id']}", "model": text}).encode())
        return True

    def _shared(self, path: str) -> bool:
        """The link's two addresses, played from --share's file. True if answered."""
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
        played = self.shares.get(shared_id, self.share)
        if not re.fullmatch(r"[A-Za-z0-9]{10}", shared_id) or played is None:
            self._send(404, "application/json", b'{"error": "no such link"}')
            return True
        text = played.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        name = next((line[2:].strip() for line in lines
                     if line.startswith("0 ") and not line.startswith(("0 FILE", "0 !", "0 Name:"))),
                    played.stem)
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
    parser.add_argument("--library", help="answer the store's library/ and the gallery from here")
    parser.add_argument("--omr", default="vendor/omr/files", help="where library/omr/ is read from")
    parser.add_argument("--share", action="append", default=[],
                        help="answer /api/share?id= and /m/<id> with this model (FILE, or ID=FILE)")
    args = parser.parse_args()
    if args.parts:
        Handler.parts = Path(args.parts).resolve()
        Handler.delay = args.delay / 1000.0
    for given in args.share:
        shared_id, _, file = given.rpartition("=")
        if shared_id:
            Handler.shares[shared_id] = Path(file).resolve()
        else:
            Handler.share = Path(file).resolve()
    if args.parts_url:
        Handler.parts_url = args.parts_url
    if args.library:
        Handler.library = Path(args.library).resolve()
        Handler.omr = Path(args.omr).resolve()
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
