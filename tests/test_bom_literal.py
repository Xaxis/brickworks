"""No script the app ships says the byte-order mark as a string literal.

An exported script (the web build, every release) keeps its strings as
UTF-8, and the engine's reading of UTF-8 drops a leading mark, so a
"\\ufeff" literal is "" there, while the probes, run from the source, see
the mark. `text.begins_with("\\ufeff")` was then true of every text, and each
file opened in a browser lost its first character (mlfix's preview, 2026-11-12:
"0 FILE" read as " FILE", the steps, booklet and .io flows red with every
probe green). The mark is LdrModel.bom(), made as the script runs.
src/dev is left out: the probes are never exported for the web, and run
from the source everywhere.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# The escape, any case, or the mark itself, in a line of code (a comment
# may name it).
MARK = re.compile(r"\\u[fF][eE][fF][fF]|\ufeff")


def marks_in(root: Path) -> list[str]:
    found = []
    for path in sorted(root.rglob("*.gd")):
        if (root / "dev") in path.parents:
            continue
        text = path.read_text(encoding="utf-8").removeprefix("\ufeff")
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            if MARK.search(line):
                found.append(f"{path.relative_to(root.parent)}:{number}: {line.strip()}")
    return found


def test_no_bom_literal_in_shipped_scripts() -> None:
    found = marks_in(SRC)
    assert not found, "say the mark as LdrModel.bom(), not a literal:\n" + "\n".join(found)
