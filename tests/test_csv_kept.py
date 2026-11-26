"""Every CSV Godot can see is kept as data, never imported as a translation.

Godot imports a .csv as a translation table unless its .import says "keep",
and writes one .translation file beside it for each of its columns. A
fixture CSV with no such file grew untracked .translation files in every
worktree that imported: the collection's in October (541e8c306), then the
lists' (tests/fixtures/lists/rebrickable_sets.csv, mirrorsave2 and
greenreds, 2026-11-26), and each unit deleted them by hand.

So each CSV Godot scans (outside a hidden folder or one with a .gdignore)
has a .import beside it, tracked, that says importer="keep". The app's
words are in locale/*.po, so no CSV here is meant to be a translation.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def tracked(*patterns: str) -> list[str]:
    out = subprocess.run(["git", "ls-files", "--", *patterns], cwd=ROOT, capture_output=True, text=True,
                         check=True).stdout
    return [line for line in out.splitlines() if line]


def scanned_by_godot(path: str) -> bool:
    """Whether Godot's import sees [path]: no hidden folder on its way, and
    no folder on its way holding a .gdignore."""
    parts = Path(path).parts[:-1]
    for at in range(len(parts)):
        if parts[at].startswith("."):
            return False
        if (ROOT.joinpath(*parts[:at + 1]) / ".gdignore").exists():
            return False
    return True


def test_every_scanned_csv_is_kept() -> None:
    csvs = [path for path in tracked("*.csv") if scanned_by_godot(path)]
    assert csvs, "no CSV found: the test would prove nothing"
    imports = set(tracked("*.csv.import"))
    wrong = []
    for path in csvs:
        beside = path + ".import"
        if beside not in imports:
            wrong.append(f"{path}: no tracked {beside}")
        elif 'importer="keep"' not in (ROOT / beside).read_text():
            wrong.append(f"{beside}: does not say importer=\"keep\"")
    assert not wrong, "; ".join(wrong)


def test_no_translation_file_is_tracked() -> None:
    assert tracked("*.translation") == []
