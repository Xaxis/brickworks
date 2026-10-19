"""A merged sub-build keeps every part's exact shape.

An exact shape (tools/build_exact.py) is BrickNet's, the part's own; our
mesh hash is only its file name. A rebuilt mesh has a new hash, and the
merge of covers2 left 942 parts with no shape under it (2026-10-19). These
merge a small sub-build into a throwaway catalogue and read the shapes back.
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import merge_subbuild  # noqa: E402

CONTROLS = 50


def entry(part_id: str, mesh: str) -> dict:
    return {"id": part_id, "mesh": mesh, "connector_counts": {"stud": 1}}


def merge(tmp: Path, shapes: dict[str, bytes], rebuilt: dict[str, str]) -> int:
    """Merge a sub-build rebuilding `rebuilt` (id -> new mesh) over a
    catalogue of tyre (mesh old1), plain (old2) and the controls."""
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
    before = merge_subbuild.GENERATED
    merge_subbuild.GENERATED = generated
    try:
        return merge_subbuild.main(["merge_subbuild.py", str(built), str(affected)])
    finally:
        merge_subbuild.GENERATED = before


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
