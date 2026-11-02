"""Tests for tools/web_pack.py's mark_exact: the web catalogue says which parts have no exact shape.

The app asked storage for every part's exact shape and took the 400 for one that
was never made to mean "none": a failed request in every visitor's console, the
example car's tyre among them (2026-11-02). These pin that a part is marked
only where its shape is in none of the folders the build reads or fetches from,
that a mark from an earlier pack is taken off a part that has one now, and that
the count said is the parts marked.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import web_pack  # noqa: E402


def test_marks_only_the_parts_with_no_shape_in_any_folder():
    with tempfile.TemporaryDirectory() as scratch:
        pack, remote = Path(scratch) / "exact", Path(scratch) / "remote"
        pack.mkdir()
        remote.mkdir()
        (pack / "aaaa.bwx").write_bytes(b"BWX1")
        (remote / "bbbb.bwx").write_bytes(b"BWX1")
        (remote / "cccc.lbm").write_bytes(b"LBM1")
        document = {"parts": [
            {"id": "3001", "mesh": "aaaa"},
            {"id": "3020", "mesh": "bbbb", "exact": False},
            {"id": "3641", "mesh": "cccc"},
            {"id": "123", "mesh": "cccc", "moved_to": "3641"},
            {"id": "custom"},
        ]}
        none = web_pack.mark_exact(document, pack, remote, Path(scratch) / "absent")
        by_id = {part["id"]: part for part in document["parts"]}
        assert none == 2
        assert "exact" not in by_id["3001"]
        assert "exact" not in by_id["3020"]
        assert by_id["3641"]["exact"] is False
        assert by_id["123"]["exact"] is False
        assert "exact" not in by_id["custom"]


def test_no_folder_marks_every_part_with_a_mesh():
    document = {"parts": [{"id": "3001", "mesh": "aaaa"}, {"id": "3020", "mesh": "bbbb"}]}
    assert web_pack.mark_exact(document, Path("/nonexistent/exact")) == 2
    assert all(part["exact"] is False for part in document["parts"])
