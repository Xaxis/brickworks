#!/usr/bin/env python3
"""Drive a running Brickworks from the shell.

    tools/brick.py __ping__
    tools/brick.py search_parts '{"query": "wedge 4x2", "limit": 10}'
    tools/brick.py view_model '{"from": "front"}' --png=/tmp/front.png
    tools/brick.py clear_model

Same tools as MCP, same socket, no MCP wrapping — for when the thing
driving the app is a shell script, or a person reading the answers, or an
agent that would rather see the picture as a file it can open.

Needs an app started with --mcp. Pictures are written where --png says and
the path is printed; everything else goes to stdout as it came.
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from brickworks_mcp import DEFAULT_PORT, App  # noqa: E402


def main(argv: list[str]) -> int:
    port = DEFAULT_PORT
    png: Path | None = None
    words: list[str] = []
    for argument in argv[1:]:
        if argument.startswith("--port="):
            port = int(argument.split("=", 1)[1])
        elif argument.startswith("--png="):
            png = Path(argument.split("=", 1)[1])
        elif argument in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            words.append(argument)
    if not words:
        print(__doc__, file=sys.stderr)
        return 2

    tool = words[0]
    try:
        arguments = json.loads(words[1]) if len(words) > 1 else {}
    except ValueError as bad:
        print("brick: that is not JSON: %s" % bad, file=sys.stderr)
        return 2

    try:
        answer = App(port).ask(tool, arguments)
    except ConnectionError as gone:
        print(gone, file=sys.stderr)
        return 1

    if not answer.get("ok", False):
        print(answer.get("error", "the app said no"), file=sys.stderr)
        return 1
    if "tools" in answer:
        for tool_def in answer["tools"]:
            print("%-20s %s" % (tool_def["name"], tool_def.get("description", "")[:120]))
        return 0

    pictures = 0
    for block in answer.get("content", []):
        if block.get("type") == "image":
            pictures += 1
            if png is None:
                print("[a picture, %d bytes — pass --png=PATH to keep it]"
                      % len(block.get("data", "")))
                continue
            where = png if pictures == 1 else png.with_name(
                "%s-%d%s" % (png.stem, pictures, png.suffix))
            where.write_bytes(base64.b64decode(block["data"]))
            print("[picture: %s]" % where)
        else:
            print(block.get("text", ""))
    # Everything the socket said that was neither text nor a picture, so a
    # new field cannot go unnoticed.
    for key in answer:
        if key not in ("id", "ok", "content", "tools"):
            print("[%s: %s]" % (key, answer[key]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
