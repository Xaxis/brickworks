#!/usr/bin/env python3
"""A stand-in for Rebrickable's user API, for src/dev/collection_probe.gd.

    python3 tests/fixtures/collection/fake_rebrickable.py 8798

Answers the three calls RebrickableAccount makes, in the shape Rebrickable's
API v3 documents for them (rebrickable.com/api/v3/docs): POST
/api/v3/users/_token/ trades a username and password for a user token, and
GET /api/v3/users/{token}/sets/ and /parts/ page their results ("count",
"next", "results"). The sets come in two pages, so following "next" is
tested. Any key but "good-key" is refused with 401 and Rebrickable's
"detail", and a token other than "tok" with 404.

Serves until killed; the probe that starts it kills it.
"""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8798
BASE = f"http://127.0.0.1:{PORT}/api/v3"

SETS = [
    {"list_id": 1, "quantity": 2, "include_spares": False,
     "set": {"set_num": "6020-1", "name": "Magic Shop", "year": 1993}},
    {"list_id": 1, "quantity": 1, "include_spares": True,
     "set": {"set_num": "10237-1", "name": "The Tower of Orthanc", "year": 2013}},
]
PARTS = [
    {"list_id": 7, "quantity": 12, "part": {"part_num": "3001", "name": "Brick 2 x 4"},
     "color": {"id": 4, "name": "Red"}},
    {"list_id": 7, "quantity": 5, "part": {"part_num": "3023", "name": "Plate 1 x 2"},
     "color": {"id": 71, "name": "Light Bluish Gray"}},
]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:  # quiet
        pass

    def _send(self, status: int, body: dict) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _key_ok(self) -> bool:
        if self.headers.get("Authorization", "") != "key good-key":
            self._send(401, {"detail": "Invalid key."})
            return False
        return True

    def do_POST(self) -> None:
        if not self._key_ok():
            return
        length = int(self.headers.get("content-length", "0"))
        form = parse_qs(self.rfile.read(length).decode())
        if urlparse(self.path).path != "/api/v3/users/_token/":
            self._send(404, {"detail": "Not found."})
        elif form.get("username") == ["builder"] and form.get("password") == ["secret pass"]:
            self._send(201, {"user_token": "tok"})
        else:
            self._send(400, {"detail": "Invalid username or password."})

    def do_GET(self) -> None:
        if not self._key_ok():
            return
        url = urlparse(self.path)
        page = int(parse_qs(url.query).get("page", ["1"])[0])
        if url.path == "/api/v3/users/tok/sets/":
            rows = SETS[:1] if page == 1 else SETS[1:]
            more = f"{BASE}/users/tok/sets/?page=2&page_size=1000" if page == 1 else None
            self._send(200, {"count": len(SETS), "next": more, "previous": None, "results": rows})
        elif url.path == "/api/v3/users/tok/parts/":
            self._send(200, {"count": len(PARTS), "next": None, "previous": None, "results": PARTS})
        else:
            self._send(404, {"detail": "Not found."})


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
