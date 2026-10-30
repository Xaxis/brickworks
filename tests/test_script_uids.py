"""Every script and shader Godot scans has its .uid committed beside it.

Godot's import makes a .uid beside each script that has none. Left
untracked, it differs in every checkout, keeps every merged worktree from
retiring, and stops a fast-forward of the main checkout once a release
does carry it (ship.sh). 107 scripts were committed without theirs
(2026-10-30).
"""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _tracked(pattern: str) -> set[str]:
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", pattern],
                         capture_output=True, text=True, check=True).stdout
    return set(out.splitlines())


def _scanned(path: str) -> bool:
    """Whether Godot scans [path]: no hidden folder on the way, and no
    folder on the way holding a .gdignore."""
    parts = Path(path).parts
    if any(part.startswith(".") for part in parts[:-1]):
        return False
    return not any((ROOT.joinpath(*parts[:n]) / ".gdignore").exists() for n in range(1, len(parts)))


# The kinds Godot gives a .uid of its own.
KINDS = ("*.gd", "*.gdshader", "*.gdshaderinc")


def test_every_scanned_script_has_its_uid_committed() -> None:
    uids = _tracked("*.uid")
    missing = sorted(f for kind in KINDS for f in _tracked(kind) if _scanned(f) and f + ".uid" not in uids)
    assert not missing, (f"{len(missing)} scripts and shaders have no .uid committed, e.g. {missing[:5]}: "
                         "commit the .uid Godot's import made beside each")


def test_a_script_under_a_gdignore_is_not_scanned() -> None:
    # web/ holds a .gdignore; the check must not ask for a .uid there.
    assert (ROOT / "web/.gdignore").exists()
    assert not _scanned("web/some_script.gd")
    assert _scanned("src/main.gd")
