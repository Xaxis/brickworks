"""A sub-file's name in an LDraw file, as LDraw's own readers take it.

The app's rule (src/parts/ldr_model.gd: _key, file_name_of, reference_of,
section_key) and the server's (api/_subfiles.js), for the tools that read a
file's sub-models. A FILE line's name is its text after the word, and a
placing line's reference its text after the fourteenth field, each as
written with what LDraw takes for space trimmed; the two are compared in any
case, "\\" and "/" the same, and nothing else. The first block of a name is
the one a reference means, and the model's own block (the first) is in no
table, as LDView reads a file: a later block of the model's name is the one
a reference to that name means. Keyed by a bare name with "\\" left in,
omr.py never followed a part's "s\\..." sub-files (7 of 1,576 OMR files were
counted otherwise than LDView counts them; 42125-1 6,169 of 6,721).
"""

from __future__ import annotations

import re

# C's isspace: what LDraw's readers trim round a name. Not str.strip()'s
# whitespace, which takes \x1c to \x1f too, a name of control characters.
SPACE = " \t\n\v\f\r"
_RUN = re.compile(r"[ \t\n\v\f\r]+")
# The model's own block, keyed by what no name can be: a name is never
# space at its ends.
MAIN = " "


def key(name: str) -> str:
    """A sub-file's name as LDraw compares it, a FILE's and a reference's alike."""
    return name.strip(SPACE).replace("\\", "/").lower()


def fields(line: str) -> list[str]:
    """The fields of [line], split on LDraw's space alone."""
    trimmed = line.strip(SPACE)
    return _RUN.split(trimmed) if trimmed else []


def after_fields(line: str, count: int) -> str:
    """[line] after its first [count] fields, as written, its space trimmed:
    a FILE line's name (2), a placing line's reference (14)."""
    rest = line.strip(SPACE)
    for _ in range(count):
        at = _RUN.search(rest)
        if at is None:
            return ""
        rest = rest[at.end():]
    return rest


def is_file_line(line: str) -> bool:
    words = fields(line)
    return len(words) >= 2 and words[0] == "0" and words[1].upper() == "FILE"


def blocks(text: str) -> dict[str, tuple[str, list[str]]]:
    """Each block of [text] as LDraw's readers take it, by its key: (its
    name as written, its lines after its FILE line), the model's own first
    by MAIN, and a later block of a name another has left out. A text of no
    FILE lines is the model's own lines alone."""
    out: dict[str, tuple[str, list[str]]] = {}
    current: list[str] | None = None
    loose: list[str] = []
    for line in text.splitlines():
        words = fields(line)
        if len(words) >= 2 and words[0] == "0" and words[1].upper() in ("FILE", "NOFILE"):
            current = None
            if words[1].upper() == "FILE":
                name = after_fields(line, 2)
                at = MAIN if not out else key(name)
                if at not in out:
                    current = []
                    out[at] = (name, current)
            continue
        if current is not None:
            current.append(line)
        elif not out:
            loose.append(line)
    if not out:
        out[MAIN] = ("", loose)
    return out
