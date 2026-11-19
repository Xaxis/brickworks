#!/usr/bin/env python3
"""A stand-in for /api/collection (m3review, kept by m3fix for
src/dev/m3review_probe.gd): one in-memory row, the ops the app's sets= path
sends (add from sets, built), and fault switches.

  python3 -I tools/collection_standin.py PORT

POST /ctl {"drop_adds": N, "drop_builts": M}: the next N add ops (M built
ops) are MADE at the "account" and then answered 502 every time they are
sent (the app sends an op up to three times with one id), as a reply lost
after the write. m3fix added drop_builts; POST /ctl {"reset": true} empties
the row.
GET /ctl: the row as kept, and every op received, for the probe to compare.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROW = {"sets": [], "parts": [], "places": {}, "updated_at": None, "rev": 0}
SEEN = {}        # op id -> reply already given
DROP = {"adds": 0, "builts": 0, "ids": set()}
LOG = []


def number(word):
    text = word.strip().lower()
    import re
    if text and not re.search(r"-[0-9]{1,3}$", text):
        text += "-1"
    return text


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _shown(self):
        return {k: ROW[k] for k in ("sets", "parts", "places", "updated_at", "rev")}

    def do_GET(self):
        if self.path.startswith("/ctl"):
            return self._send(200, {"row": ROW, "log": LOG})
        if self.path.startswith("/api/collection"):
            return self._send(200, self._shown())
        self._send(404, {"error": "no such path"})

    def do_POST(self):
        n = int(self.headers.get("content-length") or 0)
        body = json.loads(self.rfile.read(n) or b"{}")
        if self.path.startswith("/ctl"):
            DROP["adds"] = int(body.get("drop_adds", 0))
            DROP["builts"] = int(body.get("drop_builts", 0))
            if body.get("reset"):
                ROW["sets"].clear()
                LOG.clear()
            return self._send(200, {"ok": True})
        if not self.path.startswith("/api/collection"):
            return self._send(404, {"error": "no such path"})
        op_id = body.get("id")
        LOG.append({"op": body.get("op") or ("add" if body.get("from") else "?"), "from": body.get("from"),
                    "text": body.get("text"), "sets": body.get("sets"), "id": op_id})
        if op_id in DROP["ids"]:
            return self._send(502, {"error": "Bad gateway"})
        if op_id in SEEN:
            return self._send(200, SEEN[op_id])
        if body.get("from") == "sets":
            words = [w for w in str(body.get("text", "")).replace(",", " ").split() if w]
            for w in words:
                ROW["sets"].append({"set": number(w), "qty": 1, "spares": False, "src": "hand"})
            ROW["rev"] += 1
            reply = dict(self._shown(), imported={"sets": len(words), "parts": 0}, left_out=[])
            SEEN[op_id] = reply
            if DROP["adds"] > 0:
                DROP["adds"] -= 1
                DROP["ids"].add(op_id)
                return self._send(502, {"error": "Bad gateway"})
            return self._send(200, reply)
        if body.get("op") == "built":
            for one in body.get("sets", []):
                for entry in ROW["sets"]:
                    if entry["set"] == one["set"]:
                        entry["built"] = one["built"]
                        break
            ROW["rev"] += 1
            reply = self._shown()
            SEEN[op_id] = reply
            if DROP["builts"] > 0:
                DROP["builts"] -= 1
                DROP["ids"].add(op_id)
                return self._send(502, {"error": "Bad gateway"})
            return self._send(200, reply)
        self._send(400, {"error": "the stand-in has no op %r" % body.get("op")})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
