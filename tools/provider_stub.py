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
parameters in which every array says what its items are ("array schema missing
items", which OpenAI answers the app's attach.align with, given as the app
serves it). Anything else is a 400 with OpenAI's kind of words. Each request is
written to --log as one line: what it carried, never the key itself (only
whether it was the one STUB_KEY names). --fail-first N answers the first N
requests 429, as a rate limit would; --delay S waits S seconds before each
answer, as a model thinking does.

For Settings, AI (src/ui/ai_settings.gd) it is also a provider's list and the
model Test asks: GET /v1/models lists MODELS (and refuses a key that is not
STUB_KEY, when one is set, as OpenAI does); a request whose only tool is
record_answer is Test's first call, answered with that call; a request with
no tools and a picture is Test's second, answered with the colour the picture
really is, read from its PNG. Model "stub-blind" refuses pictures with a 400,
as a model without vision does, and "stub-notools" answers in words where a
tool was asked for.

The same design, and the same Test, are answered in Anthropic's Messages
(POST /v1/messages, x-api-key) and in Gemini's own API (POST
/v1beta/models/M:generateContent, x-goog-api-key), each as strict as its API
where its adapter could go wrong. Anthropic: max_tokens, roles alternating,
each tool_use answered by a tool_result first in the next message, pictures
as base64 image blocks, and every reply's thinking block sent back unchanged,
signature and all. Gemini: function declarations in its OpenAPI subset (no
additionalProperties, no object without properties), each functionCall
answered by a functionResponse of its name and id, in order, the
thoughtSignature on a call's part sent back exactly, pictures as inlineData.
Each logs what OpenAI's does, and "pictures_in_answers": the pictures inside
the last tool answers themselves, where these two APIs take them.
"""

import argparse
import base64
import json
import os
import re
import struct
import sys
import time
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

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
MODELS = ["stub-sees", "stub-blind", "stub-notools", "gpt-6.1-sol"]
COLOURS = {"red": (220, 26, 26), "green": (26, 166, 51), "blue": (26, 64, 230),
           "yellow": (250, 217, 26), "black": (5, 5, 5), "white": (250, 250, 250)}


def first_pixel(png):
    """The first pixel of an 8-bit RGB or RGBA PNG, as (r, g, b). Every PNG
    filter leaves the first pixel of the first row as it is."""
    at, idat = 8, b""
    kind = 2
    while at < len(png):
        size, name = struct.unpack(">I4s", png[at:at + 8])
        data = png[at + 8:at + 8 + size]
        if name == b"IHDR":
            kind = data[9]
        elif name == b"IDAT":
            idat += data
        at += 12 + size
    raw = zlib.decompress(idat)
    return tuple(raw[1:4]) if kind in (2, 6) else (raw[1],) * 3


def colour_of(data_url):
    """The colour a picture is, by name: the nearest of COLOURS."""
    return colour_of_base64(data_url.split(",", 1)[1])


def colour_of_base64(data):
    pixel = first_pixel(base64.b64decode(data))
    return min(COLOURS, key=lambda name: sum((a - b) ** 2 for a, b in zip(COLOURS[name], pixel)))


def good_picture(mime, data):
    """A picture as these APIs take one: an image type, and base64 of some size."""
    try:
        base64.b64decode(data, validate=True)
    except (ValueError, TypeError):
        return False
    return str(mime).startswith("image/") and len(data or "") >= 100


def test_reply(body, messages):
    """Settings, AI's Test, answered as a model would: (status, payload) or
    None when this is no test."""
    tools = [(t.get("function") or {}).get("name") for t in body.get("tools") or []]
    model = body.get("model")
    pictures = [part["image_url"]["url"] for m in messages if isinstance(m.get("content"), list)
                for part in m["content"] if part.get("type") == "image_url"]
    if tools == ["record_answer"]:
        if model == "stub-notools":
            return 200, ([], "ready")
        return 200, ([("record_answer", {"answer": "ready"})], "")
    if not tools and pictures:
        if model == "stub-blind":
            return 400, {"error": {"message": "This model does not support image input.",
                                   "type": "invalid_request_error"}}
        return 200, ([], colour_of(pictures[-1]).capitalize() + ".")
    return None


def bare_arrays(schema, where=()):
    """Where in [schema] an array does not say what its items are, as the
    context OpenAI names in refusing it."""
    found = []
    if not isinstance(schema, dict):
        return found
    if schema.get("type") == "array" and "items" not in schema:
        found.append(where)
    for name, one in (schema.get("properties") or {}).items():
        found += bare_arrays(one, where + ("properties", name))
    for key in ("items", "additionalProperties"):
        if isinstance(schema.get(key), dict):
            found += bare_arrays(schema[key], where + (key,))
    for key in ("anyOf", "oneOf", "allOf"):
        for n, one in enumerate(schema.get(key) or []):
            found += bare_arrays(one, where + (key, n))
    return found


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
        else:
            for where in bare_arrays(fn["parameters"]):
                out.append("Invalid schema for function '%s': In context=%r, array schema missing items."
                           % (fn["name"], where))
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
    return scripted(sum(1 for m in messages if m.get("role") == "assistant"), last_tools(messages))


def scripted(replies, said):
    """The design's reply after [replies] replies, the last answers [said]."""
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


THOUGHT = "Planning reply %d."
SIGNATURE = "stub-signature-%d"
GEMINI_SIGNATURE = "stub-thought-%d"
REFUSED = {"additionalProperties", "$schema", "$id", "$ref", "definitions", "$defs", "default",
           "examples", "const", "patternProperties"}


def refused_words(schema):
    """Schema words Gemini's function declarations refuse, anywhere in [schema]."""
    found = []
    if isinstance(schema, dict):
        for word, value in schema.items():
            if word in REFUSED:
                found.append(word)
            elif word == "properties" and isinstance(value, dict):
                for one in value.values():
                    found += refused_words(one)
            else:
                found += refused_words(value)
    elif isinstance(schema, list):
        for one in schema:
            found += refused_words(one)
    return found


def anthropic_view(body):
    """An Anthropic request read: (problems, view)."""
    out = []
    messages = body.get("messages") or []
    if not isinstance(body.get("max_tokens"), int):
        out.append("max_tokens: Field required")
    for tool in body.get("tools") or []:
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", tool.get("name", "")) \
                or (tool.get("input_schema") or {}).get("type") != "object":
            out.append("tools: %r is not a tool with an object input_schema" % tool.get("name"))
    waiting, replies, answers, pictures, all_answers = [], 0, [], 0, []
    for n, message in enumerate(messages):
        role = message.get("role")
        content = message.get("content")
        blocks = content if isinstance(content, list) else [{"type": "text", "text": str(content)}]
        if role != ("user" if n % 2 == 0 else "assistant"):
            out.append("messages: roles must alternate between user and assistant, starting with user")
            break
        if role == "assistant":
            replies += 1
            first = blocks[0] if blocks else {}
            if first.get("type") != "thinking" or first.get("thinking") != THOUGHT % replies \
                    or first.get("signature") != SIGNATURE % replies:
                out.append("messages.%d.content.0: a thinking block must be sent back as it came, "
                           "its signature with it" % n)
            waiting = [b.get("id") for b in blocks if b.get("type") == "tool_use"]
            continue
        results = [b for b in blocks if b.get("type") == "tool_result"]
        lead = [b.get("tool_use_id") for b in blocks[:len(waiting)] if b.get("type") == "tool_result"]
        if waiting and lead != waiting:
            out.append("messages.%d: tool_use ids were found without tool_result blocks immediately "
                       "after: %s" % (n, ", ".join(waiting)))
        elif not waiting and results:
            out.append("messages.%d: unexpected tool_use_id found in tool_result blocks" % n)
        waiting = []
        answers, pictures = [], 0
        for block in blocks:
            inner = block.get("content") if block.get("type") == "tool_result" else [block]
            inner = inner if isinstance(inner, list) else [{"type": "text", "text": str(inner)}]
            for one in inner:
                if one.get("type") == "image":
                    source = one.get("source") or {}
                    if source.get("type") != "base64" or not good_picture(source.get("media_type"),
                                                                          source.get("data")):
                        out.append("messages.%d: an image that is not base64" % n)
                    if block.get("type") == "tool_result":
                        pictures += 1
                elif one.get("type") == "text" and block.get("type") == "tool_result":
                    answers.append(one.get("text", ""))
        all_answers += answers
    system = body.get("system")
    return out, {"replies": replies, "said": "\n".join(answers), "pictures": pictures,
                 "fresh": "fresh pair of eyes" in "\n".join(all_answers),
                 "tools": [t.get("name", "") for t in body.get("tools") or []],
                 "guide": "HOW TO WORK" in json.dumps(system),
                 "last_pictures": [b["source"]["data"] for b in blocks if b.get("type") == "image"]
                 if messages else []}


def gemini_view(body):
    """A Gemini request read: (problems, view)."""
    out = []
    declared = [d for tool in body.get("tools") or [] for d in tool.get("functionDeclarations") or []]
    for n, one in enumerate(declared):
        params = one.get("parameters")
        if params is None:
            continue
        for word in refused_words(params):
            out.append("Invalid JSON payload received. Unknown name \"%s\" at "
                       "'tools[0].function_declarations[%d].parameters'" % (word, n))
        if params.get("type") == "object" and not params.get("properties"):
            out.append("tools[0].function_declarations[%d].parameters.properties: should be "
                       "non-empty for OBJECT type" % n)
    if not ((body.get("systemInstruction") or {}).get("parts") or [{}])[0].get("text"):
        out.append("systemInstruction: no text")
    waiting, replies, answers, pictures, all_answers, last = [], 0, [], 0, [], []
    for n, content in enumerate(body.get("contents") or []):
        role, parts = content.get("role"), content.get("parts") or []
        if role == "model":
            replies += 1
            waiting = [p["functionCall"] for p in parts if "functionCall" in p]
            if waiting:
                first = next(p for p in parts if "functionCall" in p)
                if first.get("thoughtSignature") != GEMINI_SIGNATURE % replies:
                    out.append("contents[%d]: Function call is missing a thought_signature" % n)
            continue
        if role != "user":
            out.append("contents[%d]: role must be user or model" % n)
        responses = [p["functionResponse"] for p in parts if "functionResponse" in p]
        if waiting and (len(responses) != len(waiting) or any(
                r.get("name") != c.get("name") or r.get("id") != c.get("id")
                for r, c in zip(responses, waiting))):
            out.append("contents[%d]: Please ensure that the number of function response parts is "
                       "equal to the number of function call parts of the function call turn, "
                       "each of its name and id" % n)
        elif not waiting and responses:
            out.append("contents[%d]: a function response answering no call" % n)
        waiting = []
        answers, pictures = [], 0
        last = [p["inlineData"]["data"] for p in parts if "inlineData" in p]
        for one in parts:
            if "inlineData" in one and not good_picture(one["inlineData"].get("mimeType"),
                                                         one["inlineData"].get("data")):
                out.append("contents[%d]: inlineData that is not a base64 picture" % n)
        for response in responses:
            said = response.get("response") or {}
            answers.append(str(said.get("result", said.get("error", ""))))
            for one in response.get("parts") or []:
                if "inlineData" in one:
                    pictures += 1
                    if not good_picture(one["inlineData"].get("mimeType"), one["inlineData"].get("data")):
                        out.append("contents[%d]: a function response's picture is not base64" % n)
        all_answers += answers
    return out, {"replies": replies, "said": "\n".join(answers), "pictures": pictures,
                 "fresh": "fresh pair of eyes" in "\n".join(all_answers),
                 "tools": [d.get("name", "") for d in declared],
                 "guide": "HOW TO WORK" in json.dumps(body.get("systemInstruction")),
                 "last_pictures": last}


def native_reply(api, view, model):
    """Test's answer or the design's next step, in [api]'s own shape: (status, payload)."""
    if view["tools"] == ["record_answer"]:
        calls, words = ([], "ready") if model == "stub-notools" else \
            ([("record_answer", {"answer": "ready"})], "")
    elif not view["tools"] and view["last_pictures"]:
        if model == "stub-blind":
            message = "This model does not support image input."
            return 400, ({"type": "error", "error": {"type": "invalid_request_error", "message": message}}
                         if api == "anthropic" else
                         {"error": {"code": 400, "message": message, "status": "INVALID_ARGUMENT"}})
        calls, words = [], colour_of_base64(view["last_pictures"][-1]).capitalize() + "."
    else:
        calls, words = scripted(view["replies"], view["said"])
    reply = view["replies"] + 1
    if api == "anthropic":
        content = [{"type": "thinking", "thinking": THOUGHT % reply, "signature": SIGNATURE % reply}]
        if words:
            content.append({"type": "text", "text": words})
        content += [{"type": "tool_use", "id": "toolu_%d_%d" % (Stub.seen, n), "name": name,
                     "input": args} for n, (name, args) in enumerate(calls)]
        return 200, {"id": "msg_stub_%d" % Stub.seen, "type": "message", "role": "assistant",
                     "model": model, "content": content,
                     "stop_reason": "tool_use" if calls else "end_turn",
                     "usage": {"input_tokens": 500, "cache_read_input_tokens": 1000,
                               "cache_creation_input_tokens": 0, "output_tokens": 40}}
    parts = [{"text": "Thinking it over.", "thought": True}]
    for n, (name, args) in enumerate(calls):
        part = {"functionCall": {"name": name, "args": args, "id": "fc_%d_%d" % (Stub.seen, n)}}
        if n == 0:
            part["thoughtSignature"] = GEMINI_SIGNATURE % reply
        parts.append(part)
    if words:
        parts.append({"text": words})
    return 200, {"candidates": [{"content": {"role": "model", "parts": parts},
                                 "finishReason": "STOP"}],
                 "usageMetadata": {"promptTokenCount": 1500, "cachedContentTokenCount": 1000,
                                   "candidatesTokenCount": 30, "thoughtsTokenCount": 10}}


class Stub(BaseHTTPRequestHandler):
    log_path = ""
    fail_first = 0
    delay = 0.0
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

    def _key_is_stub(self):
        """The key came as STUB_KEY, in the header this request's API puts it in."""
        key = os.environ.get("STUB_KEY")
        return bool(key) and key in (self.headers.get("x-api-key"), self.headers.get("x-goog-api-key"),
                                     (self.headers.get("authorization") or "")[len("Bearer "):])

    def _key_refused(self):
        """A key that is not STUB_KEY, when one is set: a 401."""
        return bool(os.environ.get("STUB_KEY")) and not self._key_is_stub()

    def do_GET(self):
        path = urlparse(self.path).path
        if not path.endswith("/models"):
            return self._send(404, {"error": {"message": "no such path " + self.path}})
        with open(Stub.log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps({"path": self.path, "listed": True,
                                  "key_refused": self._key_refused()}) + "\n")
        if self._key_refused():
            return self._send(401, {"error": {"message": "Incorrect API key provided (stub).",
                                              "type": "invalid_request_error"}})
        if path.startswith("/v1beta/"):
            return self._send(200, {"models": [
                {"name": "models/" + name, "displayName": name,
                 "supportedGenerationMethods": ["generateContent", "countTokens"]} for name in MODELS]
                + [{"name": "models/stub-embedding", "supportedGenerationMethods": ["embedContent"]}]})
        self._send(200, {"object": "list", "data": [
            {"id": name, "object": "model", "owned_by": "stub", "display_name": name} for name in MODELS]})

    def _native(self, api, body, size):
        """A request in Anthropic's or Gemini's own shape."""
        if api == "anthropic":
            wrong, view = anthropic_view(body)
            if not self.headers.get("anthropic-version"):
                wrong.append("anthropic-version: header is required")
            model = body.get("model")
        else:
            wrong, view = gemini_view(body)
            model = urlparse(self.path).path.rsplit("/", 1)[-1].split(":")[0]
        record = {"n": Stub.seen, "api": api, "path": self.path, "model": model,
                  "key_is_stub": self._key_is_stub(), "tools": len(view["tools"]),
                  "tool_names": sorted(view["tools"]), "system_has_guide": view["guide"],
                  "replies": view["replies"], "pictures_in_answers": view["pictures"],
                  "last_tools": view["said"][:600], "fresh_look_asked": view["fresh"],
                  "problems": wrong, "bytes": size,
                  "test": view["tools"] == ["record_answer"] or (not view["tools"] and bool(view["last_pictures"]))}
        time.sleep(Stub.delay)
        status, payload = (400, None) if wrong else native_reply(api, view, model)
        if not wrong and Stub.seen <= Stub.fail_first:
            status = 429
        record["status"] = status
        with open(Stub.log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps(record) + "\n")
        if status == 429:
            message = "Rate limit reached (stub)"
            return self._send(429, {"type": "error", "error": {"type": "rate_limit_error", "message": message}}
                              if api == "anthropic" else
                              {"error": {"code": 429, "message": message, "status": "RESOURCE_EXHAUSTED"}})
        if wrong:
            message = "; ".join(wrong)
            return self._send(400, {"type": "error", "error": {"type": "invalid_request_error", "message": message}}
                              if api == "anthropic" else
                              {"error": {"code": 400, "message": message, "status": "INVALID_ARGUMENT"}})
        self._send(status, payload)

    def do_POST(self):
        Stub.seen += 1
        size = int(self.headers.get("content-length") or 0)
        try:
            body = json.loads(self.rfile.read(size) or b"{}")
        except ValueError:
            return self._send(400, {"error": {"message": "not JSON", "type": "invalid_request_error"}})
        path = urlparse(self.path).path
        if path.endswith("/v1/messages"):
            return self._native("anthropic", body, size)
        if path.endswith(":generateContent"):
            return self._native("gemini", body, size)
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
            "temperature": body.get("temperature"),
            "max_tokens": body.get("max_tokens", body.get("max_completion_tokens")),
            "reasoning_effort": body.get("reasoning_effort"),
        }
        time.sleep(Stub.delay)
        tested = None if wrong else test_reply(body, messages)
        record["test"] = tested is not None
        status = 400 if wrong else tested[0] if tested is not None else 200
        if not wrong and Stub.seen <= Stub.fail_first:
            status = 429
        record["status"] = status
        with open(Stub.log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps(record) + "\n")
        if status == 429:
            return self._send(429, {"error": {"message": "Rate limit reached (stub)", "type": "rate_limit"}})
        if wrong:
            return self._send(400, {"error": {"message": "; ".join(wrong), "type": "invalid_request_error"}})
        if tested is not None and tested[0] != 200:
            return self._send(*tested)
        calls, words = tested[1] if tested is not None else step(messages)
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
    parser.add_argument("--delay", type=float, default=0.0)
    args = parser.parse_args()
    Stub.log_path = args.log
    Stub.fail_first = args.fail_first
    Stub.delay = args.delay
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Stub)
    print("provider stub on 127.0.0.1:%d" % args.port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
