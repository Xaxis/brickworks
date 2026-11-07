"""A merged sub-build keeps every part's exact shape.

An exact shape (tools/build_exact.py) is BrickNet's, the part's own; our
mesh hash is only its file name. A rebuilt mesh has a new hash, and the
merge of covers2 left 942 parts with no shape under it (2026-10-19). These
merge a small sub-build into a throwaway catalogue and read the shapes back.

A merge writes the catalogue of the checkout it is run in, and never
through a link out of it: the last four tests.
"""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import merge_subbuild  # noqa: E402

CONTROLS = 50


def entry(part_id: str, mesh: str) -> dict:
    return {"id": part_id, "mesh": mesh, "connector_counts": {"stud": 1}}


def merge(tmp: Path, shapes: dict[str, bytes], rebuilt: dict[str, str],
          old_writes: Path | None = None) -> int:
    """Merge a sub-build rebuilding `rebuilt` (id -> new mesh) over a
    catalogue of tyre (mesh old1), plain (old2) and the controls, run in a
    checkout whose assets/generated is a link to it, as a staging tree's is."""
    generated, built = tmp / "generated", tmp / "built"
    for folder in (generated / "parts", generated / "exact", built / "parts"):
        folder.mkdir(parents=True)
    whole = [entry("tyre", "old1"), entry("plain", "old2")]
    whole += [entry(f"c{n}", f"cm{n}") for n in range(CONTROLS)]
    for item in whole:
        (generated / "parts" / f"{item['mesh']}.lbm").write_bytes(b"mesh")
    for mesh, data in shapes.items():
        (generated / "exact" / f"{mesh}.bwx").write_bytes(data)
    (generated / "catalogue.json").write_text(json.dumps({"parts": whole}))
    fresh = [entry(i, m) for i, m in rebuilt.items()]
    fresh += [entry(f"c{n}", f"cm{n}") for n in range(CONTROLS)]
    for item in fresh:
        (built / "parts" / f"{item['mesh']}.lbm").write_bytes(b"mesh")
    (built / "catalogue.json").write_text(json.dumps({"parts": fresh}))
    affected = tmp / "affected.txt"
    affected.write_text("\n".join(rebuilt) + "\n")
    tree = tmp / "stage"
    (tree / "assets").mkdir(parents=True)
    (tree / "project.godot").write_text("")
    (tree / "assets" / "generated").symlink_to(generated)
    return run_in(tree, built, affected, old_writes or generated)


def run_in(tree: Path, built: Path, affected: Path, old_writes: Path) -> int:
    """merge_subbuild run in ``tree``. The merge before this wrote
    GENERATED, the catalogue of its script's own checkout, which in a
    worktree is a link to the shared one: that is pointed at ``old_writes``
    in this test's folder (made a copy of the tree's catalogue when it is
    not there), so no merge this runs can write a real catalogue."""
    before = getattr(merge_subbuild, "GENERATED", None)
    if before is not None:
        if not old_writes.exists():
            shutil.copytree(tree / "assets" / "generated", old_writes)
        setattr(merge_subbuild, "GENERATED", old_writes)
    was = Path.cwd()
    os.chdir(tree)
    try:
        return merge_subbuild.main(["merge_subbuild.py", str(built), str(affected)])
    finally:
        os.chdir(was)
        if before is not None:
            setattr(merge_subbuild, "GENERATED", before)


def test_a_rebuilt_part_keeps_its_shape_under_its_new_mesh():
    with tempfile.TemporaryDirectory() as name:
        tmp = Path(name)
        code = merge(tmp, {"old1": b"BWX1 tyre"}, {"tyre": "new1"})
        assert code == 0
        assert (tmp / "generated/exact/new1.bwx").read_bytes() == b"BWX1 tyre"
        # The old name stays: a shipped build still asks for it.
        assert (tmp / "generated/exact/old1.bwx").exists()


def test_a_part_with_no_shape_is_given_none():
    with tempfile.TemporaryDirectory() as name:
        tmp = Path(name)
        code = merge(tmp, {"old1": b"BWX1 tyre"}, {"tyre": "new1", "plain": "new2"})
        assert code == 0
        assert not (tmp / "generated/exact/new2.bwx").exists()


def test_a_shape_already_under_the_new_mesh_is_left_alone():
    with tempfile.TemporaryDirectory() as name:
        tmp = Path(name)
        code = merge(tmp, {"old1": b"BWX1 old", "new1": b"BWX1 built"}, {"tyre": "new1"})
        assert code == 0
        assert (tmp / "generated/exact/new1.bwx").read_bytes() == b"BWX1 built"


# merge_subbuild wrote ROOT/assets/generated, the checkout its script is
# in: run from a staging tree, a worktree's copy of the script merged into
# that worktree's catalogue, a link to the shared one, as refresh_catalogue
# did (animals, 2026-11-07). It writes the checkout it is run in, and
# refuses a file or folder that links out of the folder it is named in.

def test_a_merge_writes_the_checkout_it_is_run_in():
    with tempfile.TemporaryDirectory() as name:
        tmp = Path(name)
        code = merge(tmp, {"old1": b"BWX1 tyre"}, {"tyre": "new1"}, old_writes=tmp / "own")
        assert code == 0
        merged = {e["id"]: e for e in json.loads((tmp / "generated/catalogue.json").read_text())["parts"]}
        assert merged["tyre"]["mesh"] == "new1"
        assert (tmp / "generated/exact/new1.bwx").read_bytes() == b"BWX1 tyre"


def _linked(tmp: Path, link: str) -> tuple[Path, Path]:
    """A staging tree's private catalogue with ``link`` still a link into
    the shared one, and the shared one."""
    assert merge(tmp, {"old1": b"BWX1 tyre"}, {}) == 0   # made, merged with nothing
    private, shared = tmp / "generated", tmp / "shared"
    (shared / "exact").mkdir(parents=True)
    if link == "catalogue.json":
        (private / "catalogue.json").rename(shared / "catalogue.json")
        (private / "catalogue.json").symlink_to(shared / "catalogue.json")
    elif link == "parts":
        (private / "parts").rename(shared / "parts")
        (private / "parts").symlink_to(shared / "parts")
    else:
        # The tyre's shape under its new mesh: a link into the shared
        # exact folder that leads to nothing yet.
        (private / "exact" / "new1.bwx").symlink_to(shared / "exact" / "new1.bwx")
    return private, shared


def _files(folder: Path) -> dict[str, bytes]:
    return {str(p.relative_to(folder)): p.read_bytes()
            for p in sorted(folder.rglob("*")) if p.is_file()}


@pytest.mark.parametrize("link", ["catalogue.json", "parts", "exact shape"])
def test_a_link_out_of_its_catalogue_is_never_written_through(link: str):
    with tempfile.TemporaryDirectory() as name:
        tmp = Path(name)
        private, shared = _linked(tmp, link)
        had_shared, had_private = _files(shared), _files(private)
        built = tmp / "built"
        (built / "parts" / "new1.lbm").write_bytes(b"mesh new1")
        fresh = json.loads((built / "catalogue.json").read_text())
        fresh["parts"].append(entry("tyre", "new1"))
        (built / "catalogue.json").write_text(json.dumps(fresh))
        (tmp / "affected.txt").write_text("tyre\n")
        code = run_in(tmp / "stage", built, tmp / "affected.txt", private)
        assert _files(shared) == had_shared
        assert code == 1
        assert _files(private) == had_private
