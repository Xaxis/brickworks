#!/usr/bin/env python3
"""An OpenAI-compatible model that scripts a design, for proving the designer loop.

    python3 -I tools/provider_stub.py --port 9621 --log OUT.jsonl [--fail-first N]
        [--pace S] [--cut-stream N]

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
And in OpenAI's Responses (POST /v1/responses, a bearer key), as strict as
it is where its adapter could go wrong: functions flat and, unless they say
"strict": false, held to strict mode (every property required,
additionalProperties false: the app's schemas fail it); every array saying
what its items are; each function_call answered by a function_call_output of
its call_id, and none answering no call; pictures as input_image data: URLs,
in a message or in a function_call_output's output; and with "store": false,
every reply's reasoning item sent back carrying the encrypted content the
reply gave it (given only when "include" asks for it), and none of its
function_calls sent back by id without it.

Each logs what OpenAI's does, and "pictures_in_answers": the pictures inside
the last tool answers themselves, where these three APIs take them.

A request that asks for its reply streamed ("stream": true, or Gemini's
:streamGenerateContent?alt=sse) gets the same reply as server-sent events, as
that API writes them: Chat Completions' chunks of deltas, each call's
arguments in pieces under its index, the usage in a last chunk when
stream_options asks, then [DONE]; Anthropic's message_start to message_stop,
thinking, its signature, words and each tool_use's input in pieces, the usage
said again at the end; Responses' events, each function_call's arguments as
deltas, then response.completed with the whole response; Gemini's responses of
a part each, words in pieces, lines ending in a carriage return and a newline.
--pace S waits S seconds after each event (0.03), so a reply is still being
written while its start is read. --cut-stream N closes the connection half way
through the first streamed reply after N replies, as a dropped connection does.
A reply's ids come from where it is in the conversation, never from how many
requests came before, so the same request gets the same reply streamed or whole.
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


ENCRYPTED = "stub-encrypted-%d"
CONTENT_TYPES = ("input_text", "input_image")


def strict_problems(name, schema, where=()):
    """What strict mode refuses in a function's [schema], in OpenAI's words."""
    out = []
    if not isinstance(schema, dict):
        return out
    if schema.get("type") == "object":
        if schema.get("additionalProperties") is not False:
            out.append("Invalid schema for function '%s': In context=%r, 'additionalProperties' is "
                       "required to be supplied and to be false." % (name, where))
        properties = schema.get("properties") or {}
        missing = [key for key in properties if key not in (schema.get("required") or [])]
        if missing:
            out.append("Invalid schema for function '%s': In context=%r, 'required' is required to "
                       "be supplied and to be an array including every key in properties. Missing "
                       "'%s'." % (name, where, missing[0]))
        for key, one in properties.items():
            out += strict_problems(name, one, where + ("properties", key))
    if isinstance(schema.get("items"), dict):
        out += strict_problems(name, schema["items"], where + ("items",))
    return out


def content_problems(parts, where):
    """What Responses refuses in a list of content parts."""
    out = []
    for part in parts:
        kind = part.get("type") if isinstance(part, dict) else None
        if kind not in CONTENT_TYPES:
            out.append("Invalid value: %r at %s. Supported values are: 'input_text', 'input_image', "
                       "and 'input_file'." % (kind, where))
        elif kind == "input_image" and not DATA_URL.match(str(part.get("image_url", ""))):
            out.append("%s: an input_image that is not a data: URL" % where)
        elif kind == "input_text" and not isinstance(part.get("text"), str):
            out.append("%s: an input_text with no text" % where)
    return out


def responses_view(body):
    """A Responses request read: (problems, view)."""
    out = []
    tools = body.get("tools") or []
    for tool in tools:
        name = tool.get("name", "")
        if tool.get("type") != "function" or not re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", name) \
                or "function" in tool:
            out.append("tools: %r is not a flat function with a valid name" % name)
            continue
        params = tool.get("parameters") or {}
        if params.get("type") != "object":
            out.append("tools: %s's parameters are not an object schema" % name)
        for where in bare_arrays(params):
            out.append("Invalid schema for function '%s': In context=%r, array schema missing items."
                       % (name, where))
        if tool.get("strict") is not False:
            out += strict_problems(name, params)
    store = body.get("store", True) is not False
    encrypted = "reasoning.encrypted_content" in (body.get("include") or [])
    called, answered, replies, reasoned, in_reply = [], set(), 0, set(), False
    answers, pictures, all_answers, last_pictures = [], 0, [], []
    for n, item in enumerate(body.get("input") or []):
        kind = item.get("type") or ("message" if "role" in item else None)
        mine = kind in ("reasoning", "function_call") or (kind == "message"
                                                           and item.get("role") == "assistant")
        if mine and not in_reply:
            # A reply is a run of the model's own items: reasoning, calls, words.
            replies += 1
            answers, pictures = [], 0
        in_reply = mine
        if kind == "reasoning":
            rs = str(item.get("id"))
            reasoned.add(rs)
            if not store and item.get("encrypted_content") != ENCRYPTED % int(rs.split("_")[-1]):
                out.append("Item with id '%s' not found. Items are not persisted when `store` is set "
                           "to false. Try again with `store` set to true, or remove this item from "
                           "your input." % rs)
        elif kind == "function_call":
            fc = item.get("id")
            if fc and not store and "rs_" + fc.split("_")[1] not in reasoned:
                out.append("Item '%s' of type 'function_call' was provided without its required "
                           "'reasoning' item: 'rs_%s'." % (fc, fc.split("_")[1]))
            try:
                json.loads(item.get("arguments"))
            except (TypeError, ValueError):
                out.append("input[%d]: arguments that are not JSON" % n)
            called.append(item.get("call_id"))
        elif kind == "function_call_output":
            call = item.get("call_id")
            if call not in called:
                out.append("No tool call found for function call output with call_id %s." % call)
            answered.add(call)
            output = item.get("output")
            if isinstance(output, list):
                out += content_problems(output, "input[%d].output" % n)
                pictures += sum(1 for part in output if isinstance(part, dict)
                                and part.get("type") == "input_image")
                answers.append("\n".join(part.get("text", "") for part in output
                                         if isinstance(part, dict) and part.get("type") == "input_text"))
            elif isinstance(output, str):
                answers.append(output)
            else:
                out.append("input[%d].output: a string or a list of content" % n)
                answers.append("")
            all_answers.append(answers[-1])
        elif kind != "message" or item.get("role") not in ("user", "assistant", "system", "developer"):
            out.append("input[%d]: Invalid value: %r." % (n, kind))
        elif item.get("role") == "user" and isinstance(item.get("content"), list):
            out += content_problems(item["content"], "input[%d].content" % n)
            last_pictures = [part["image_url"].split(",", 1)[1] for part in item["content"]
                             if isinstance(part, dict) and part.get("type") == "input_image"
                             and DATA_URL.match(str(part.get("image_url", "")))]
    for call in called:
        if call not in answered:
            out.append("No tool output found for function call %s." % call)
    if not str(body.get("instructions") or "").strip():
        out.append("instructions: no text")
    return out, {"replies": replies, "said": "\n".join(answers), "pictures": pictures,
                 "fresh": "fresh pair of eyes" in "\n".join(all_answers),
                 "tools": [t.get("name", "") for t in tools],
                 "guide": "HOW TO WORK" in str(body.get("instructions")),
                 "last_pictures": last_pictures, "encrypted": encrypted}


def native_reply(api, view, model):
    """Test's answer or the design's next step, in [api]'s own shape: (status, payload)."""
    if view["tools"] == ["record_answer"]:
        calls, words = ([], "ready") if model == "stub-notools" else \
            ([("record_answer", {"answer": "ready"})], "")
    elif not view["tools"] and view["last_pictures"]:
        if model == "stub-blind":
            message = "This model does not support image input."
            return 400, _error(api, 400, message)
        calls, words = [], colour_of_base64(view["last_pictures"][-1]).capitalize() + "."
    else:
        calls, words = scripted(view["replies"], view["said"])
    reply = view["replies"] + 1
    if api == "responses":
        reasoning = {"type": "reasoning", "id": "rs_%d" % reply, "summary": []}
        if view["encrypted"]:
            reasoning["encrypted_content"] = ENCRYPTED % reply
        output = [reasoning]
        output += [{"type": "function_call", "id": "fc_%d_%d" % (reply, n),
                    "call_id": "call_%d_%d" % (reply, n), "name": name,
                    "arguments": json.dumps(args), "status": "completed"}
                   for n, (name, args) in enumerate(calls)]
        if words:
            output.append({"type": "message", "id": "msg_%d" % reply, "role": "assistant",
                           "status": "completed", "content": [
                               {"type": "output_text", "text": words, "annotations": []}]})
        return 200, {"id": "resp_stub_%d" % reply, "object": "response", "status": "completed",
                     "model": model, "output": output, "error": None, "incomplete_details": None,
                     "usage": {"input_tokens": 1500, "input_tokens_details": {"cached_tokens": 1000},
                               "output_tokens": 40, "output_tokens_details": {"reasoning_tokens": 10},
                               "total_tokens": 1540}}
    if api == "anthropic":
        content = [{"type": "thinking", "thinking": THOUGHT % reply, "signature": SIGNATURE % reply}]
        if words:
            content.append({"type": "text", "text": words})
        content += [{"type": "tool_use", "id": "toolu_%d_%d" % (reply, n), "name": name,
                     "input": args} for n, (name, args) in enumerate(calls)]
        return 200, {"id": "msg_stub_%d" % reply, "type": "message", "role": "assistant",
                     "model": model, "content": content,
                     "stop_reason": "tool_use" if calls else "end_turn",
                     "usage": {"input_tokens": 500, "cache_read_input_tokens": 1000,
                               "cache_creation_input_tokens": 0, "output_tokens": 40}}
    parts = [{"text": "Thinking it over.", "thought": True}]
    for n, (name, args) in enumerate(calls):
        part = {"functionCall": {"name": name, "args": args, "id": "fc_%d_%d" % (reply, n)}}
        if n == 0:
            part["thoughtSignature"] = GEMINI_SIGNATURE % reply
        parts.append(part)
    if words:
        parts.append({"text": words})
    return 200, {"candidates": [{"content": {"role": "model", "parts": parts},
                                 "finishReason": "STOP"}],
                 "usageMetadata": {"promptTokenCount": 1500, "cachedContentTokenCount": 1000,
                                   "candidatesTokenCount": 30, "thoughtsTokenCount": 10}}


def _error(api, code, message):
    """A refusal in [api]'s own shape."""
    if api == "anthropic":
        return {"type": "error", "error": {"type": "rate_limit_error" if code == 429
                                           else "invalid_request_error", "message": message}}
    if api == "gemini":
        return {"error": {"code": code, "message": message,
                          "status": "RESOURCE_EXHAUSTED" if code == 429 else "INVALID_ARGUMENT"}}
    return {"error": {"message": message, "type": "rate_limit_exceeded" if code == 429
                      else "invalid_request_error", "param": None, "code": None}}


def pieces(text, size=24):
    """[text] as a model writes it: a few characters at a time."""
    return [text[at:at + size] for at in range(0, len(text), size)]


def chat_events(payload, usage):
    """A completion as Chat Completions streams it: (event name, data) each."""
    choice = payload["choices"][0]
    message = choice["message"]
    head = {"id": payload["id"], "object": "chat.completion.chunk", "model": payload["model"]}

    def chunk(delta, finish=None):
        return dict(head, choices=[{"index": 0, "delta": delta, "finish_reason": finish}])

    out = [chunk({"role": "assistant", "content": None})]
    out += [chunk({"content": piece}) for piece in pieces(message.get("content") or "")]
    for n, call in enumerate(message.get("tool_calls") or []):
        out.append(chunk({"tool_calls": [{"index": n, "id": call["id"], "type": "function",
                                          "function": {"name": call["function"]["name"], "arguments": ""}}]}))
        out += [chunk({"tool_calls": [{"index": n, "function": {"arguments": piece}}]})
                for piece in pieces(call["function"]["arguments"])]
    out.append(chunk({}, choice["finish_reason"]))
    if usage:
        out.append(dict(head, choices=[], usage=payload["usage"]))
    return [(None, one) for one in out] + [(None, "[DONE]")]


def anthropic_events(payload):
    """A message as Anthropic streams it."""
    start = {key: value for key, value in payload.items() if key != "content"}
    start.update(content=[], stop_reason=None, usage=dict(payload["usage"], output_tokens=1))
    out = [("message_start", {"type": "message_start", "message": start})]
    for index, block in enumerate(payload["content"]):
        def delta(kind, **said):
            return ("content_block_delta", {"type": "content_block_delta", "index": index,
                                            "delta": dict(said, type=kind)})
        if block["type"] == "thinking":
            opened = {"type": "thinking", "thinking": ""}
            deltas = [delta("thinking_delta", thinking=piece) for piece in pieces(block["thinking"])]
            deltas.append(delta("signature_delta", signature=block["signature"]))
        elif block["type"] == "text":
            opened = {"type": "text", "text": ""}
            deltas = [delta("text_delta", text=piece) for piece in pieces(block["text"])]
        else:
            opened = dict(block, input={})
            deltas = [delta("input_json_delta", partial_json=piece)
                      for piece in pieces(json.dumps(block["input"]))]
        out.append(("content_block_start", {"type": "content_block_start", "index": index,
                                            "content_block": opened}))
        out += deltas
        out.append(("content_block_stop", {"type": "content_block_stop", "index": index}))
    out.append(("message_delta", {"type": "message_delta", "delta": {"stop_reason": payload["stop_reason"]},
                                  "usage": {"output_tokens": payload["usage"]["output_tokens"]}}))
    out.append(("message_stop", {"type": "message_stop"}))
    return out


def responses_events(payload):
    """A response as Responses streams it."""
    begun = dict(payload, status="in_progress", output=[], usage=None)
    out = [("response.created", {"type": "response.created", "response": begun}),
           ("response.in_progress", {"type": "response.in_progress", "response": begun})]
    for index, item in enumerate(payload["output"]):
        at = {"item_id": item["id"], "output_index": index}
        if item["type"] == "function_call":
            out.append(("response.output_item.added", {"type": "response.output_item.added",
                                                       "output_index": index,
                                                       "item": dict(item, arguments="", status="in_progress")}))
            out += [("response.function_call_arguments.delta",
                     dict(at, type="response.function_call_arguments.delta", delta=piece))
                    for piece in pieces(item["arguments"])]
            out.append(("response.function_call_arguments.done",
                        dict(at, type="response.function_call_arguments.done", arguments=item["arguments"])))
        elif item["type"] == "message":
            out.append(("response.output_item.added", {"type": "response.output_item.added",
                                                       "output_index": index,
                                                       "item": dict(item, content=[], status="in_progress")}))
            text = item["content"][0]["text"]
            out += [("response.output_text.delta", dict(at, type="response.output_text.delta",
                                                         content_index=0, delta=piece))
                    for piece in pieces(text)]
            out.append(("response.output_text.done", dict(at, type="response.output_text.done",
                                                          content_index=0, text=text)))
        else:
            out.append(("response.output_item.added", {"type": "response.output_item.added",
                                                       "output_index": index, "item": item}))
        out.append(("response.output_item.done", {"type": "response.output_item.done",
                                                  "output_index": index, "item": item}))
    out.append(("response.completed", {"type": "response.completed", "response": payload}))
    return [(name, dict(data, sequence_number=n)) for n, (name, data) in enumerate(out)]


def gemini_events(payload):
    """A response as Gemini streams it with alt=sse: a part or a piece of one a response."""
    candidate = payload["candidates"][0]
    parts = []
    for part in candidate["content"]["parts"]:
        if "text" in part and "functionCall" not in part:
            parts += [dict(part, text=piece) for piece in pieces(part["text"])]
        else:
            parts.append(part)
    out = []
    for n, part in enumerate(parts):
        one = {"content": {"role": "model", "parts": [part]}}
        if n == len(parts) - 1:
            one["finishReason"] = candidate["finishReason"]
        out.append((None, {"candidates": [one], "usageMetadata": payload["usageMetadata"]}))
    return out


class Stub(BaseHTTPRequestHandler):
    log_path = ""
    fail_first = 0
    delay = 0.0
    seen = 0
    pace = 0.03
    cut_after = -1

    def log_message(self, *_args):
        pass

    def _send(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _answer(self, api, status, payload, body, replies, record):
        """[payload], whole or streamed as the request asked; [record] says which,
        and whether the stream was cut."""
        streamed = status == 200 and record["streamed"]
        cut = streamed and replies == Stub.cut_after
        if cut:
            Stub.cut_after = -1
        record["cut"] = cut
        with open(Stub.log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps(record) + "\n")
        if not streamed:
            return self._send(status, payload)
        events = {"chat": lambda: chat_events(payload, (body.get("stream_options") or {}).get("include_usage")),
                  "anthropic": lambda: anthropic_events(payload),
                  "responses": lambda: responses_events(payload),
                  "gemini": lambda: gemini_events(payload)}[api]()
        # Chunked, as the providers send a stream: HTTP/1.1 for this answer
        # alone, and the connection closed after it.
        self.protocol_version = "HTTP/1.1"
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("transfer-encoding", "chunked")
        self.send_header("connection", "close")
        self.end_headers()
        end = "\r\n" if api == "gemini" else "\n"
        for n, (name, data) in enumerate(events):
            if cut and n == len(events) // 2:
                return None
            said = data if isinstance(data, str) else json.dumps(data)
            event = (("event: %s%s" % (name, end) if name else "") + "data: %s%s%s" % (said, end, end)).encode()
            self.wfile.write(b"%x\r\n%s\r\n" % (len(event), event))
            self.wfile.flush()
            time.sleep(Stub.pace)
        self.wfile.write(b"0\r\n\r\n")
        return None

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
        """A request in Anthropic's, Gemini's or Responses' own shape."""
        if api == "anthropic":
            wrong, view = anthropic_view(body)
            if not self.headers.get("anthropic-version"):
                wrong.append("anthropic-version: header is required")
            model = body.get("model")
        elif api == "responses":
            wrong, view = responses_view(body)
            model = body.get("model")
        else:
            wrong, view = gemini_view(body)
            model = urlparse(self.path).path.rsplit("/", 1)[-1].split(":")[0]
            if self.path.split("?")[0].endswith(":streamGenerateContent") and "alt=sse" not in self.path:
                wrong.append("alt=sse: the stub streams only server-sent events")
        record = {"n": Stub.seen, "api": api, "path": self.path, "model": model,
                  "key_is_stub": self._key_is_stub(), "tools": len(view["tools"]),
                  "tool_names": sorted(view["tools"]), "system_has_guide": view["guide"],
                  "replies": view["replies"], "pictures_in_answers": view["pictures"],
                  "last_tools": view["said"][:600], "fresh_look_asked": view["fresh"],
                  "problems": wrong, "bytes": size,
                  "test": view["tools"] == ["record_answer"] or (not view["tools"] and bool(view["last_pictures"])),
                  "streamed": bool(body.get("stream")) or ":streamGenerateContent" in self.path}
        if api == "responses":
            record.update({"store": body.get("store"), "include": body.get("include"),
                           "reasoning": body.get("reasoning"),
                           "max_output_tokens": body.get("max_output_tokens")})
        time.sleep(Stub.delay)
        status, payload = (400, None) if wrong else native_reply(api, view, model)
        if not wrong and Stub.seen <= Stub.fail_first:
            status = 429
        record["status"] = status
        if status == 429:
            payload = _error(api, 429, "Rate limit reached (stub)")
        elif wrong:
            payload = _error(api, 400, "; ".join(wrong))
        self._answer(api, status, payload, body, view["replies"], record)

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
        if path.endswith(":generateContent") or path.endswith(":streamGenerateContent"):
            return self._native("gemini", body, size)
        if path.endswith("/v1/responses"):
            return self._native("responses", body, size)
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
            "streamed": bool(body.get("stream")),
        }
        time.sleep(Stub.delay)
        tested = None if wrong else test_reply(body, messages)
        record["test"] = tested is not None
        status = 400 if wrong else tested[0] if tested is not None else 200
        if not wrong and Stub.seen <= Stub.fail_first:
            status = 429
        record["status"] = status
        replies = record["replies"]
        if status == 429:
            return self._answer("chat", 429, {"error": {"message": "Rate limit reached (stub)",
                                                        "type": "rate_limit"}}, body, replies, record)
        if wrong:
            return self._answer("chat", 400, {"error": {"message": "; ".join(wrong),
                                                        "type": "invalid_request_error"}}, body, replies, record)
        if tested is not None and tested[0] != 200:
            return self._answer("chat", tested[0], tested[1], body, replies, record)
        calls, words = tested[1] if tested is not None else step(messages)
        reply = replies + 1
        message = {"role": "assistant", "content": words or None}
        if calls:
            message["tool_calls"] = [{"id": "call_%d_%d" % (reply, n), "type": "function",
                                      "function": {"name": name, "arguments": json.dumps(args)}}
                                     for n, (name, args) in enumerate(calls)]
        self._answer("chat", 200, {
            "id": "chatcmpl-stub-%d" % reply, "object": "chat.completion", "model": body.get("model"),
            "choices": [{"index": 0, "message": message,
                         "finish_reason": "tool_calls" if calls else "stop"}],
            "usage": {"prompt_tokens": len(json.dumps(messages)) // 4, "completion_tokens": 40,
                      "prompt_tokens_details": {"cached_tokens": 1000}},
        }, body, replies, record)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--fail-first", type=int, default=0)
    parser.add_argument("--delay", type=float, default=0.0)
    parser.add_argument("--pace", type=float, default=0.03)
    parser.add_argument("--cut-stream", type=int, default=-1)
    args = parser.parse_args()
    Stub.log_path = args.log
    Stub.fail_first = args.fail_first
    Stub.delay = args.delay
    Stub.pace = args.pace
    Stub.cut_after = args.cut_stream
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Stub)
    print("provider stub on 127.0.0.1:%d" % args.port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
