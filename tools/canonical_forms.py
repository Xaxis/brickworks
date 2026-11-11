"""Write src/parts/canonical_forms.gd: every character Unicode writes both as
one and as a letter and its marks, by the second.

"Café" with its é as one character (U+00E9) and as "e" and U+0301 are one
name to a macOS disk and to every libarchive unzip (bsdtar, Windows' and
macOS's tar), which keep the second file over the first, unsaid; Godot
has no Unicode normalisation to see it. SubmodelFile._one_key reads this
table to take two names as one only where such a disk or unzip does:
equal, case aside, once each character is its canonical decomposition
(NFD). Before it, the key stripped every accent, and "Cafe" beside "Café"
became Café_2.ldr (se4check).

Built from Python's own unicodedata, so it is the Unicode version of the
Python that runs it (15.0 for 3.12). Hangul syllables are left out: their
decomposition is arithmetic, worked out in SubmodelFile.

  python3 tools/canonical_forms.py          write it
  python3 tools/canonical_forms.py --check  exit 1 when the file differs
"""
import sys
import unicodedata
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "src" / "parts" / "canonical_forms.gd"


def escaped(text: str) -> str:
    out = ""
    for ch in text:
        code = ord(ch)
        if 0x20 <= code < 0x7F and ch not in '"\\':
            out += ch
        elif code <= 0xFFFF:
            out += "\\u%04X" % code
        else:
            out += "\\U%06X" % code
    return out


def table() -> str:
    pairs = []
    for code in range(0x110000):
        if 0xAC00 <= code <= 0xD7A3:
            continue
        decomposition = unicodedata.decomposition(chr(code))
        if not decomposition or decomposition.startswith("<"):
            continue
        pairs.append("%d: \"%s\"" % (code, escaped(unicodedata.normalize("NFD", chr(code)))))
    lines = []
    for n in range(0, len(pairs), 8):
        lines.append("\t" + ", ".join(pairs[n:n + 8]) + ",")
    head = [
        "## Every character Unicode writes both as one and as a letter followed by",
        "## its marks (\"é\", and \"e\" and U+0301), by the second: its canonical",
        "## decomposition in full (NFD), %d characters of Unicode %s. Hangul's" % (
            len(pairs), unicodedata.unidata_version),
        "## syllables are not here: theirs is arithmetic (SubmodelFile._one_key).",
        "## Read by SubmodelFile._one_key alone, loaded when a zip of sub-models is",
        "## named, so not with the first screen.",
        "##",
        "## Written by tools/canonical_forms.py from Python's unicodedata: run it",
        "## again rather than edit this file.",
        "extends RefCounted",
        "",
        "const DECOMPOSED: Dictionary = {",
    ]
    return "\n".join(head + lines + ["}", ""])


def main() -> int:
    text = table()
    if "--check" in sys.argv:
        same = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("canonical_forms: %s" % ("up to date" if same else "differs from tools/canonical_forms.py"))
        return 0 if same else 1
    OUT.write_text(text, encoding="utf-8")
    print("canonical_forms: wrote %s (%d bytes)" % (OUT, len(text.encode("utf-8"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
