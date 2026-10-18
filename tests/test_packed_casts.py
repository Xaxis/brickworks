"""No GDScript writes to a packed array through a cast.

On Godot 4.7.2, `(by_id[k] as PackedInt64Array).append(x)` appends to a copy
the cast made, and the array in the Dictionary stays as it was. The same goes
for every other write (resize, fill, sort, an index assigned...) and for a
packed array in an Array. `by_id[k].append(x)`, with no cast, does write, as
does an Array (not packed) through a cast. Three of these were found on
2026-10-17: the planner's `_supports_of` never learnt what a part's cover rests
on, and the steps score built every copy of a repeated sub-model but the first
in no step (docs/INSTRUCTIONS.md). Each read as correct and failed silently.

So every .gd file under src/ and tools/ is read, its comments and strings
blanked, and each `as Packed...Array)` checked for what follows it: a call
that writes, or an index with an assignment after it.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

WRITES = {"append", "push_back", "append_array", "resize", "fill", "set", "remove_at",
          "insert", "sort", "reverse", "erase", "clear"}
"""The packed arrays' methods that change them. PackedByteArray's encode_*
(encode_u8, encode_float...) write too, and are matched by their prefix."""

CAST = re.compile(r"\bas\s+(Packed\w*Array)\s*\)")
ASSIGN = re.compile(r"(?:\*\*|<<|>>|[-+*/%&|^])?=(?!=)")


def code_only(text: str) -> str:
    """The text with every comment and string's contents blanked, newlines kept."""
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "#":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c in "\"'":
            raw = i > 0 and text[i - 1] == "r"
            quote = text[i:i + 3] if text[i:i + 3] in ('"""', "'''") else c
            out.append(" " * len(quote))
            i += len(quote)
            while i < n and not text.startswith(quote, i):
                if text[i] == "\\" and not raw and i + 1 < n:
                    out.append("  " if text[i + 1] != "\n" else " \n")
                    i += 2
                    continue
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            out.append(" " * len(quote))
            i += len(quote)
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _skip_blank(code: str, at: int) -> int:
    """Past spaces, tabs and a backslash continuing the line."""
    while at < len(code):
        if code[at] in " \t":
            at += 1
        elif code.startswith("\\\n", at):
            at += 2
        else:
            break
    return at


def writes_through_casts(text: str) -> list[tuple[int, str]]:
    """Each write through a packed-array cast in GDScript [param text]: (line, the line)."""
    code = code_only(text)
    lines = text.split("\n")
    found: list[tuple[int, str]] = []
    for match in CAST.finditer(code):
        at = _skip_blank(code, match.end())
        writes = False
        if code.startswith(".", at):
            name = re.match(r"\.\s*(\w+)\s*\(", code[at:])
            writes = bool(name) and (name.group(1) in WRITES
                                     or name.group(1).startswith("encode_"))
        elif code.startswith("[", at):
            depth, end = 0, at
            while end < len(code):
                if code[end] in "([{":
                    depth += 1
                elif code[end] in ")]}":
                    depth -= 1
                    if depth == 0:
                        break
                end += 1
            writes = bool(ASSIGN.match(code, _skip_blank(code, end + 1)))
        if writes:
            line = code.count("\n", 0, match.start()) + 1
            found.append((line, lines[line - 1].strip()))
    return found


# -- the check reads what it should ------------------------------------------

PLANTED_WRITES = [
    "(under_it[top] as PackedInt64Array).append(node.id)",
    "(by_step[k] as PackedInt32Array).push_back(7)",
    "(a[0] as PackedVector3Array).append_array(more)",
    "(d[k] as PackedFloat32Array).resize(4)",
    "(d[k] as PackedInt32Array).fill(0)",
    "(d[k] as PackedInt32Array).set(0, 1)",
    "(d[k] as PackedInt32Array).remove_at(0)",
    "(d[k] as PackedStringArray).insert(0, \"x\")",
    "(d[k] as PackedInt64Array).sort()",
    "(d[k] as PackedInt64Array).reverse()",
    "(d[k] as PackedColorArray).erase(Color.RED)",
    "(d[k] as PackedInt32Array).clear()",
    "(d[k] as PackedByteArray).encode_u32(0, 9)",
    "(d[k] as PackedInt32Array)[0] = 9",
    "(d[k] as PackedFloat64Array)[i + f(j)] += 1.5",
    "(d[k] as PackedInt32Array) [0] <<= 1",
    "((d[k]) as PackedInt32Array).append(1)",
    "(d[k] as PackedInt32Array) \\\n\t\t.append(1)",
]

PLANTED_SAFE = [
    "d[k].append(1)",
    "(d[k] as Array).append(1)",
    "var first: int = (d[k] as PackedInt32Array)[0]",
    "if (d[k] as PackedInt32Array)[0] == 1:",
    "if (d[k] as PackedInt32Array)[0] >= 1 and (d[k] as PackedInt32Array)[1] <= 2:",
    "var n: int = (d[k] as PackedInt32Array).size()",
    "var copy := (d[k] as PackedInt32Array).duplicate()",
    "var keep := (d[k] as PackedInt32Array).has(4)",
    "out.append((d[k] as PackedInt32Array)[0])",
    "# (d[k] as PackedInt32Array).append(1), in a comment",
    "print(\"(d[k] as PackedInt32Array).append(1)\")",
    "var s := '(d[k] as PackedInt32Array)[0] = 1'",
]


def test_every_planted_write_is_found():
    for line in PLANTED_WRITES:
        assert writes_through_casts(line), f"not found: {line}"


def test_no_safe_line_is_found():
    for line in PLANTED_SAFE:
        assert not writes_through_casts(line), f"found, and it is safe: {line}"


def test_a_write_is_found_on_its_own_line():
    text = "func f() -> void:\n\t# a note\n\tvar x := 1\n\t(d[k] as PackedInt32Array).append(x)\n"
    assert writes_through_casts(text) == [(4, "(d[k] as PackedInt32Array).append(x)")]


def test_strings_and_comments_are_blanked_in_place():
    text = 'var a := "x # y" # z\nvar b := """\n# not a comment\n"""\n'
    code = code_only(text)
    assert len(code) == len(text)
    assert code.count("\n") == text.count("\n")
    assert "#" not in code and "x" not in code.split(":=")[1]


# -- the code -----------------------------------------------------------------

def test_no_gdscript_writes_through_a_packed_array_cast():
    found = []
    for top in ("src", "tools"):
        for path in sorted((ROOT / top).rglob("*.gd")):
            for line, said in writes_through_casts(path.read_text(errors="replace")):
                found.append(f"{path.relative_to(ROOT)}:{line}: {said}")
    assert not found, ("a write through a packed-array cast writes to a copy; hold an "
                       "Array, or write without the cast:\n  " + "\n  ".join(found))
