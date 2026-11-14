"""Every request the app makes of a server goes through PageFetch.

In a browser an HTTPRequest is polled once a frame, and each of its states
took a frame: the relay's answer to a Claude call left two frames after the
tab had it and its ask for the next call three, 510 and 780 ms with frames
of 250 ms (framefetch, 2026-11-14, tools/web/framefetch_flow.mjs). PageFetch
asks the page's own fetch at once and is answered between frames. So an
HTTPRequest made anywhere under src/ but these, each of which has a reason
of its own, fails here: a new one would wait for frames again.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

MADE = re.compile(r"\bHTTPRequest\.new\(\)")

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
    # The assistant's calls to the person's own AI, seconds to minutes each,
    # and stopped mid-call by cancel_request: left as they were (framefetch).
    "src/ai/assistant.gd": "the assistant's model calls",
    "src/ai/designer_loop.gd": "the designer's model calls",
    "src/ai/model_test.gd": "a model's test calls",
    "src/ai/real_snippets.gd": "real sets' snippets for the assistant",
    "src/ai/reference_finder.gd": "the assistant's picture search",
}


def code_of(line: str) -> str:
    """[param line] up to a # that is not in a string, its strings emptied."""
    quote = ""
    kept = []
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = ""
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


def made_in(text: str) -> list[int]:
    """The lines of GDScript [param text] that make an HTTPRequest."""
    return [n for n, line in enumerate(text.split("\n"), 1) if MADE.search(code_of(line))]


def test_finds_one_made():
    planted = "\n".join([
        "func _a() -> void:",
        "\tvar http := HTTPRequest.new()",
        "\t## An HTTPRequest.new() was polled once a frame.",
        "\tvar words: String = \"HTTPRequest.new()\"",
        "\tadd_child(HTTPRequest.new())",
    ])
    assert made_in(planted) == [2, 5]


def test_every_request_goes_through_page_fetch():
    found = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        name = str(path.relative_to(ROOT))
        if name.startswith("src/dev/") or name in KEPT:
            continue
        for n in made_in(path.read_text(encoding="utf-8")):
            found.append("%s:%d" % (name, n))
    assert not found, (
        "an HTTPRequest made outside PageFetch: in a browser it waits for frames before it "
        "leaves and again before it is read; use PageFetch.ask:\n  " + "\n  ".join(found))


def test_each_kept_one_still_makes_one():
    """A reason kept for a file that no longer makes one is a reason for nothing."""
    gone = [name for name in KEPT if not made_in((ROOT / name).read_text(encoding="utf-8"))]
    assert not gone, "no HTTPRequest made here any more; take it out of KEPT: " + ", ".join(gone)
