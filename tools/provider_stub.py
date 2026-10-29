#!/usr/bin/env python3
"""An OpenAI-compatible model that scripts a design, for proving the designer loop.

    python3 -I tools/provider_stub.py --port 9621 --log OUT.jsonl [--fail-first N]

POST /v1/chat/completions answers as Chat Completions does, with tool calls a
real model would make: clear the baseplate and look a part up (two calls in one
reply), submit a small tower, look at it, save it, answer the fresh look the
save asks for, save again, then say what it built and stop. Which step comes is
read off the request (how many replies it holds), so the loop under test
carries the whole conversation each time, as a real provider needs.

It is as strict as OpenAI where the loop could go wrong: a reply's tool calls
must each be answered by a tool message before anything else, a picture must be
a data: URL in a user message, and the tools must be functions with object
parameters. Anything else is a 400 with OpenAI's kind of words. Each request is
written to --log as one line: what it carried, never the key itself (only
whether it was the one STUB_KEY names). --fail-first N answers the first N
requests 429, as a rate limit would.
"""

import argparse
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOWER = {
    "name": "A red tower",
    "description": "a slender red tower",
    "floor": "none",
    "bricks": [{"part": "3003", "color": 4, "x": 10, "y": 3 * n, "z": 10, "rot": 0}
               for n in range(6)],
    "assemblies": [{"name": "tower", "x_from": 10, "x_to": 12, "z_from": 10, "z_to": 12}],
}
EYES = {
    "reads_as": "a red column of six bricks",
    "generic": "one straight stack with no roof",
    "changes": ["step the top in one stud", "a pointed roof", "windows on each face"],
}
DATA_URL = re.compile(r"^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]{100,}$")


def problems(body):
    """What OpenAI would refuse in this request, or []."""
    out = []
    tools = body.get("tools") or []
    for tool in tools:
        fn = tool.get("function") or {}
        if tool.get("type") != "function" or not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", fn.get("name", "")):
            out.append("tools: %r is not a function with a valid name" % fn.get("name"))
        elif (fn.get("parameters") or {}).get("type") != "object":
            out.append("tools: %s's parameters are not an object schema" % fn["name"])
    messages = body.get("messages") or []
    if not messages or messages[0].get("role") != "system":
        out.append("messages: the first is not the system prompt")
    waiting = []
    for n, message in enumerate(messages):
        role = message.get("role")
        if waiting and role != "tool":
            out.append("messages[%d]: an assistant message with 'tool_calls' must be followed by "
                       "tool messages responding to each 'tool_call_id' (%s)" % (n, ", ".join(waiting)))
            waiting = []
        if role == "assistant":
            waiting = [call["id"] for call in message.get("tool_calls") or []]
            for call in message.get("tool_calls") or []:
                try:
                    json.loads(call["function"]["arguments"])
                except (KeyError, ValueError):
                    out.append("messages[%d]: arguments that are not JSON" % n)
        elif role == "tool":
            if message.get("tool_call_id") not in waiting:
                out.append("messages[%d]: a tool message answering no call (%s)" % (n, message.get("tool_call_id")))
            else:
                waiting.remove(message["tool_call_id"])
            if not isinstance(message.get("content"), str):
                out.append("messages[%d]: a tool message's content is not text" % n)
        elif role == "user" and isinstance(message.get("content"), list):
            for part in message["content"]:
                if part.get("type") == "image_url" and not DATA_URL.match(part["image_url"]["url"]):
                    out.append("messages[%d]: a picture that is not a data: URL" % n)
    if waiting:
        out.append("messages: tool calls never answered (%s)" % ", ".join(waiting))
    return out


def tool_text(messages):
    return "\n".join(m["content"] for m in messages if m.get("role") == "tool")


def pictures_after_last_tools(messages):
    """The pictures in the user message after the last run of tool messages."""
    count = 0
    for message in reversed(messages):
        if message.get("role") == "user" and isinstance(message.get("content"), list):
            count += sum(1 for part in message["content"] if part.get("type") == "image_url")
        elif message.get("role") == "tool":
            break
        else:
            return 0
    return count


def last_tools(messages):
    out = []
    for message in reversed(messages):
        if message.get("role") == "tool":
            out.append(message["content"])
        elif out:
            break
    return "\n".join(reversed(out))


def step(messages):
    """The reply for this point in the design: (tool calls, words)."""
    replies = sum(1 for m in messages if m.get("role") == "assistant")
    said = last_tools(messages)
    script = [
        [("clear_model", {}), ("search_parts", {"query": "brick 2 x 2"})],
        [("submit_design", TOWER)],
        [("view_model", {})],
        [("save_model", {"name": "stub-tower.ldr"})],
        [("fresh_eyes", EYES)] if "fresh pair of eyes" in said else [("save_model", {"name": "stub-tower.ldr"})],
        [("save_model", {"name": "stub-tower.ldr"})],
    ]
    if replies < len(script):
        return script[replies], ""
    return [], "I built a red tower of six 2 x 2 bricks and saved it as stub-tower.ldr."


class Stub(BaseHTTPRequestHandler):
    log_path = ""
    fail_first = 0
    seen = 0

    def log_message(self, *_args):
        pass

    def _send(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        Stub.seen += 1
        size = int(self.headers.get("content-length") or 0)
        try:
            body = json.loads(self.rfile.read(size) or b"{}")
        except ValueError:
            return self._send(400, {"error": {"message": "not JSON", "type": "invalid_request_error"}})
        messages = body.get("messages") or []
        wrong = problems(body) if self.path.endswith("/chat/completions") else ["no such path " + self.path]
        auth = self.headers.get("authorization") or ""
        record = {
            "n": Stub.seen,
            "path": self.path,
            "model": body.get("model"),
            "key_is_stub": bool(os.environ.get("STUB_KEY")) and auth == "Bearer " + os.environ["STUB_KEY"],
            "tools": len(body.get("tools") or []),
            "tool_names": sorted((t.get("function") or {}).get("name", "") for t in body.get("tools") or []),
            "system_has_guide": bool(messages) and "HOW TO WORK" in str(messages[0].get("content")),
            "roles": [m.get("role") for m in messages],
            "replies": sum(1 for m in messages if m.get("role") == "assistant"),
            "pictures_after_tools": pictures_after_last_tools(messages),
            "last_tools": last_tools(messages)[:600],
            "fresh_look_asked": "fresh pair of eyes" in tool_text(messages),
            "problems": wrong,
            "bytes": size,
        }
        status = 400 if wrong else 200
        if not wrong and Stub.seen <= Stub.fail_first:
            status = 429
        record["status"] = status
        with open(Stub.log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps(record) + "\n")
        if status == 429:
            return self._send(429, {"error": {"message": "Rate limit reached (stub)", "type": "rate_limit"}})
        if wrong:
            return self._send(400, {"error": {"message": "; ".join(wrong), "type": "invalid_request_error"}})
        calls, words = step(messages)
        message = {"role": "assistant", "content": words or None}
        if calls:
            message["tool_calls"] = [{"id": "call_%d_%d" % (Stub.seen, n), "type": "function",
                                      "function": {"name": name, "arguments": json.dumps(args)}}
                                     for n, (name, args) in enumerate(calls)]
        self._send(200, {
            "id": "chatcmpl-stub-%d" % Stub.seen, "object": "chat.completion", "model": body.get("model"),
            "choices": [{"index": 0, "message": message,
                         "finish_reason": "tool_calls" if calls else "stop"}],
            "usage": {"prompt_tokens": size // 4, "completion_tokens": 40,
                      "prompt_tokens_details": {"cached_tokens": 1000}},
        })


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--fail-first", type=int, default=0)
    args = parser.parse_args()
    Stub.log_path = args.log
    Stub.fail_first = args.fail_first
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Stub)
    print("provider stub on 127.0.0.1:%d" % args.port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
