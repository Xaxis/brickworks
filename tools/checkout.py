"""Which checkout a catalogue tool writes, and never through a link out of it.

A staging tree's assets/generated is a link to its own copy of the
catalogue, and that copy may still hold links back into the shared one.
A tool that wrote the catalogue of the tree its script lives in, or wrote
a file through such a link, wrote the shared catalogue from a staging
tree: tools/refresh_catalogue.py did, through a copy's elements.json
(2026-11-07). tools/refresh_catalogue.py and tools/merge_subbuild.py write
the checkout they are run in (tree_of) and refuse a file or folder that
links out of the folder it is named in (inside), before writing anything.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class Outside(Exception):
    """A file a tool would write is a link out of the folder it is in:
    writing it would write another tree's catalogue."""


def tree_of(here: Path) -> Path:
    """The checkout a command run in ``here`` is in: the nearest folder up
    from it holding project.godot, or the tools' own when none does."""
    for folder in (here, *here.parents):
        if (folder / "project.godot").is_file():
            return folder
    return ROOT


def inside(path: Path) -> Path:
    """``path``, when writing it writes the file in the folder it is named
    in. Outside when it is a link out of that folder, a dangling one too.
    The folder may itself be a link: a staging tree's assets/generated is
    one to its catalogue."""
    if path.resolve().parent != path.parent.resolve():
        raise Outside(f"{path} is a link to {path.resolve()}, out of "
                      f"{path.parent.resolve()}: not written through")
    return path
