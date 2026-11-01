"""The LEGO Group's mark written wrong, as docs/TRADEMARKS.md says.

tests/test_trademarks.py holds every public word to these, and
tools/release.py holds a release's notes to them before it is built.
This file is not read as public text, so it may spell the faults out.
"""

from __future__ import annotations

import re

# The LEGO Group's mark written wrong (docs/TRADEMARKS.md): each wrong use,
# what to write instead, and a sentence it must catch. tests/test_trademarks.py
# holds every public word to these; check_version holds a release's notes to
# them before it is built, since a published tag cannot be taken back: 0.13.0's
# said "the names LEGO gives them" and is tagged so (2026-11-01).
MARK_FAULTS: list[tuple[re.Pattern[str], str, str]] = [
    (re.compile(r"\bLEGO\b(?!®|\(R\)| Group)"),
     "LEGO carries its ® each time it is used, but not in the LEGO Group", "real LEGO bricks"),
    (re.compile(r"LEGO(?:®|\(R\)) Group"), "no ® in the company's name: the LEGO Group",
     "as the LEGO® Group built it"),
    (re.compile(r"\bLegos?\b"), "LEGO is written in capitals", "a Lego set"),
    (re.compile(r"\b(?:LEGO|Lego|lego)s\b"), "LEGO is never plural: LEGO bricks", "Build with LEGOs"),
    (re.compile(r"\b(?:LEGO|Lego)®?['’]s\b"), "LEGO is never possessive: the LEGO Group's",
     "LEGO®'s own colours"),
    (re.compile(r"\bLEGO®? (?:made|makes|built|builds|sells|sold|has|had|never|calls|called|"
                r"names|did|does|designs|designed|moulds|moulded|prints|printed|replaced|"
                r"retired|stopped|added)\b"),
     "LEGO is an adjective, not the company: the LEGO Group made it", "as LEGO® made it"),
    (re.compile(r"\b(?:laid|built|made) in LEGO\b(?!®? (?:bricks|parts|elements|pieces|plates|"
                r"tiles|sets?|colou?rs|Digital))"),
     "LEGO is an adjective: laid in LEGO bricks", "a sculpt laid in LEGO® at any size"),
    (re.compile(r"\bLEGO®? CAD\b"), "not a LEGO product: a CAD app for LEGO bricks",
     "the LEGO® CAD app"),
    # "LEGO® Art," is the mark itself, named in the disclaimer's list.
    (re.compile(r"\bLEGO®? Art\b(?!®? sets?\b|,)"),
     "LEGO Art is the LEGO Group's line, not our feature: Brick Art, or LEGO Art sets",
     "laid as LEGO® Art"),
]

