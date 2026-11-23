"""Every request the app makes of a server goes through PageFetch.

In a browser an HTTPRequest is polled once a frame, and each of its states
took a frame: the relay's answer to a Claude call left two frames after the
tab had it and its ask for the next call three, 510 and 780 ms with frames
of 250 ms (framefetch, 2026-11-14, tools/web/framefetch_flow.mjs). PageFetch
asks the page's own fetch at once and is answered between frames. An
HTTPClient polled by hand waits for frames the same way. So, under src/ but
these KEPT files, each of which has a reason of its own, this fails any
HTTPRequest or HTTPClient: one made (.new(), ClassDB.instantiate), named at
all (a type, an alias), or a node of one in a scene; and a KEPT file that
hands one out to the rest (a function that returns one, an alias of the
class). Only the result and method constants (HTTPRequest.RESULT_*,
HTTPClient.METHOD_*), which PageFetch.ask speaks, may be named anywhere.
The first version matched only "HTTPRequest.new()", and five other ways in
went through it (ffreview, 2026-11-14).
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CLASS = r"HTTP(?:Request|Client)"
BY_NAME = r"ClassDB\s*\.\s*instantiate\s*\(\s*&?[\"']%s[\"']" % CLASS
# Each read in a line's code: (pattern, whether its strings are kept).
# The class named, other than for one of the constants PageFetch speaks.
NAMED = [(re.compile(r"\b%s\b(?!\s*\.\s*(?:RESULT|METHOD)_[A-Z0-9_]+\b)" % CLASS), False)]
# Made: by .new(), or by its name through ClassDB (a String or a StringName).
MADE = [(re.compile(r"\b%s\s*\.\s*new\s*\(" % CLASS), False), (re.compile(r"\b" + BY_NAME), True)]
# Handed out of a KEPT file: a function that returns one, one made and
# returned, or the class itself kept under another name.
HANDED = [(re.compile(r"->\s*%s\b|\breturn\s+%s\s*\.\s*new\s*\("
                      r"|^\s*(?:static\s+)?(?:const|var)\s+\w+\s*(?::\s*\w+\s*)?:?=\s*%s\s*$" % (CLASS, CLASS, CLASS)), False),
          (re.compile(r"\breturn\s+" + BY_NAME), True)]
# A node or resource of one in a scene.
IN_SCENE = re.compile(r"\btype\s*=\s*\"%s\"" % CLASS)

# Where an HTTPRequest is still made, and why.
KEPT = {
    # The one that makes one off the web.
    "src/net/page_fetch.gd": "PageFetch itself, off the web",
    # Off the web only: in a browser each goes its own way already.
    "src/net/together.gd": "off the web; in a browser Together._ask_page is the page's fetch",
    "src/parts/part_library.gd": "off the web; in a browser PartLibrary._ask_page is the page's fetch",
    "src/net/updater.gd": "the desktop's own update, written to a file on a thread",
    "src/net/claude_connector.gd": "the desktop's word that it is alive (the page's worker says it in a browser)",
    # What PageFetch does not carry.
    "src/net/model_library.gd": "a set's file of up to 36 MB, said a megabyte at a time as it comes",
    "src/net/brickognize.gd": "a picture sent as bytes (request_raw)",
    "src/net/photo_upload.gd": "a build's photo sent as bytes (request_raw)",
    # The assistant's calls to the person's own AI, seconds to minutes each,
    # and stopped mid-call by cancel_request: left as they were (framefetch).
    "src/ai/assistant.gd": "the assistant's model calls",
    "src/ai/designer_loop.gd": "the designer's model calls",
    "src/ai/model_test.gd": "a model's test calls",
    "src/ai/real_snippets.gd": "real sets' snippets for the assistant",
    "src/ai/reference_finder.gd": "the assistant's picture search",
    "src/ai/stream.gd": "a model's answer read as it is written, an HTTPClient by hand (Streamer)",
}


def code_of(line: str, strings: bool = False) -> str:
    """[param line] up to a # that is not in a string, its strings emptied
    unless [param strings]."""
    quote = ""
    kept = []
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                if strings:
                    kept.append(line[i:i + 2])
                i += 1
            elif c == quote:
                quote = ""
                kept.append(c)
            elif strings:
                kept.append(c)
        elif c in "\"'":
            quote = c
            kept.append(c)
        elif c == "#":
            break
        else:
            kept.append(c)
        i += 1
    return "".join(kept)


def found_in(text: str, *kinds: list) -> list[int]:
    """The lines of GDScript [param text] whose code matches any pattern of
    [param kinds]: a name read with the line's strings emptied, a name given
    ClassDB read with them as written."""
    lines = []
    for n, line in enumerate(text.split("\n"), 1):
        code = {False: code_of(line), True: code_of(line, strings=True)}
        if any(pattern.search(code[strings]) for kind in kinds for pattern, strings in kind):
            lines.append(n)
    return lines


def made_in(text: str) -> list[int]:
    """The lines of GDScript [param text] that make an HTTPRequest or an HTTPClient."""
    return found_in(text, MADE)


def scripts():
    for path in sorted((ROOT / "src").rglob("*.gd")):
        name = str(path.relative_to(ROOT))
        if not name.startswith("src/dev/"):
            yield name, path.read_text(encoding="utf-8")


def test_finds_each_way_in():
    planted = "\n".join([
        "func _a() -> void:",
        "\tvar http := HTTPRequest.new()",
        "\t## An HTTPRequest.new() was polled once a frame.",
        "\tvar words: String = \"HTTPRequest.new()\"",
        "\tadd_child(HTTPRequest.new())",
        "\tvar made: HTTPRequest = ClassDB.instantiate(\"HTTPRequest\")",
        "\tvar by_name = ClassDB.instantiate(&'HTTPClient')",
        "\tvar client := HTTPClient.new()",
        "const Asker = HTTPRequest",
        "\tif got[0] != HTTPRequest.RESULT_SUCCESS or method == HTTPClient.METHOD_POST:",
        "\tPageFetch.ask(self, url, PackedStringArray(), HTTPClient . METHOD_GET)",
        "\tvar status: HTTPClient.Status = client.get_status()",
        "\tvar label: String = \"an HTTPClient\"  # an HTTPRequest",
    ])
    assert made_in(planted) == [2, 5, 6, 7, 8]
    assert found_in(planted, NAMED, MADE) == [2, 5, 6, 7, 8, 9, 12]
    kept = "\n".join([
        "static func planted_request() -> HTTPRequest:",
        "\treturn HTTPRequest.new()",
        "func _quiet() -> void:",
        "\tvar http := HTTPRequest.new()",
        "\tadd_child(http)",
        "const Asker = HTTPRequest",
        "static var asker := HTTPClient",
        "func made():",
        "\treturn ClassDB.instantiate(\"HTTPRequest\")",
    ])
    assert found_in(kept, HANDED) == [1, 2, 6, 7, 9]
    assert IN_SCENE.search('[node name="Ask" type="HTTPRequest" parent="."]')
    assert not IN_SCENE.search('[node name="Ask" type="Node"]')


def test_every_request_goes_through_page_fetch():
    found = []
    for name, text in scripts():
        if name in KEPT:
            continue
        found += ["%s:%d" % (name, n) for n in found_in(text, NAMED, MADE)]
    assert not found, (
        "an HTTPRequest or HTTPClient outside PageFetch: in a browser it waits for frames before it "
        "leaves and again before it is read; use PageFetch.ask:\n  " + "\n  ".join(found))


def test_kept_ones_hand_none_out():
    """A KEPT file's reason is its own: one it hands to another file is that file's."""
    found = []
    for name, text in scripts():
        if name in KEPT:
            found += ["%s:%d" % (name, n) for n in found_in(text, HANDED)]
    assert not found, (
        "a KEPT file hands an HTTPRequest or HTTPClient out (a function returning one, or the class "
        "under another name); make the request in it, or use PageFetch.ask:\n  " + "\n  ".join(found))


def test_no_scene_holds_one():
    found = []
    for path in sorted([*(ROOT / "src").rglob("*.tscn"), *(ROOT / "src").rglob("*.tres")]):
        name = str(path.relative_to(ROOT))
        if name.startswith("src/dev/"):
            continue
        found += ["%s:%d" % (name, n) for n, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1)
                  if IN_SCENE.search(line)]
    assert not found, "an HTTPRequest or HTTPClient node in a scene; use PageFetch.ask:\n  " + "\n  ".join(found)


def test_each_kept_one_still_makes_one():
    """A reason kept for a file that no longer makes one is a reason for nothing."""
    gone = [name for name in KEPT if not made_in((ROOT / name).read_text(encoding="utf-8"))]
    assert not gone, "no HTTPRequest or HTTPClient made here any more; take it out of KEPT: " + ", ".join(gone)
