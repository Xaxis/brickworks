"""tools/storage_parts.py: a listing that found every mesh up is written down, keyed by the
bucket and each mesh's name and size, and a run asked about the very same meshes within a day
takes it for the bucket's answer instead of listing 90,000 names again (fastship, 2026-11-23).
Any other set of meshes, an old stamp, --check and --all list as before; a listing that finds
something to upload writes nothing down."""
from __future__ import annotations

import importlib.util
import json
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("storage_parts", ROOT / "tools/storage_parts.py")
storage_parts = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(storage_parts)


def test_the_key_is_exactly_what_was_asked_about():
    base = storage_parts.stamp_key("https://x.supabase.co", {"a.lbm": 10, "b.bwx": 20})
    assert base == storage_parts.stamp_key("https://x.supabase.co", {"b.bwx": 20, "a.lbm": 10})
    assert base != storage_parts.stamp_key("https://x.supabase.co", {"a.lbm": 10})
    assert base != storage_parts.stamp_key("https://x.supabase.co", {"a.lbm": 10, "b.bwx": 21})
    assert base != storage_parts.stamp_key("https://x.supabase.co", {"a.lbm": 10, "c.bwx": 20})
    assert base != storage_parts.stamp_key("https://y.supabase.co", {"a.lbm": 10, "b.bwx": 20})


def test_a_stamp_answers_only_its_own_key_within_a_day(tmp_path):
    stamp = tmp_path / "stamp.json"
    assert storage_parts.stamped("k", stamp) is None
    storage_parts.write_stamp("k", 3, stamp)
    assert storage_parts.stamped("k", stamp)
    assert storage_parts.stamped("other", stamp) is None
    at = json.loads(stamp.read_text())["at"]
    day = storage_parts.STAMP_HOURS * 3600
    assert storage_parts.stamped("k", stamp, now=at + day - 60)
    assert storage_parts.stamped("k", stamp, now=at + day + 1) is None
    assert storage_parts.stamped("k", stamp, now=at - 60) is None  # a clock gone back
    stamp.write_text("{not json")
    assert storage_parts.stamped("k", stamp) is None
    assert not list(tmp_path.glob("*.part"))


@pytest.fixture
def bucket(tmp_path, monkeypatch):
    """A checkout of three meshes, a bucket that holds what `up` names, and a count of listings."""
    parts = tmp_path / "assets/generated/parts"
    parts.mkdir(parents=True)
    for name in ("aa.lbm", "bb.lbm", "cc.lbm"):
        (parts / name).write_bytes(name.encode() * 10)
    state = {"up": {"aa.lbm", "bb.lbm", "cc.lbm"}, "listings": 0, "uploads": []}

    def listing(url, key):
        state["listings"] += 1
        return set(state["up"])

    def upload(url, key, path):
        state["uploads"].append(path.name)
        state["up"].add(path.name)

    monkeypatch.setattr(storage_parts, "ROOT", tmp_path)
    monkeypatch.setattr(storage_parts, "STAMP", tmp_path / "cache/storage_parts.json")
    monkeypatch.setattr(storage_parts, "env", lambda: ("https://x.supabase.co", "secret"))
    monkeypatch.setattr(storage_parts, "listing", listing)
    monkeypatch.setattr(storage_parts, "upload", upload)
    state["parts"] = parts
    return state


def run(monkeypatch, *args):
    monkeypatch.setattr(sys, "argv", ["storage_parts.py", *args])
    return storage_parts.main()


def test_the_second_run_for_the_same_meshes_lists_nothing(bucket, monkeypatch, capsys):
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 1
    assert "to upload : 0" in capsys.readouterr().out
    assert run(monkeypatch) == 0
    out = capsys.readouterr().out
    assert bucket["listings"] == 1, "listed again for meshes it had found all up"
    # What deploy.sh shows of it: its last two lines.
    assert out.splitlines()[-1].strip() == "to upload : 0  (0 MB)"
    assert "not listed again" in out.splitlines()[-2]


def test_a_new_mesh_is_listed_and_uploaded_never_taken_from_the_stamp(bucket, monkeypatch, capsys):
    assert run(monkeypatch) == 0
    (bucket["parts"] / "dd.lbm").write_bytes(b"new")
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 2
    assert bucket["uploads"] == ["dd.lbm"]
    assert "to upload : 1" in capsys.readouterr().out
    # The upload's own run writes nothing down: the next one lists, finds it up, and does.
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 3
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 3


def test_a_mesh_changed_in_size_lists_again(bucket, monkeypatch):
    assert run(monkeypatch) == 0
    (bucket["parts"] / "aa.lbm").write_bytes(b"shorter")
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 2


def test_a_listing_that_finds_one_missing_writes_nothing_down(bucket, monkeypatch, capsys):
    bucket["up"].discard("cc.lbm")
    assert run(monkeypatch, "--check") == 0
    assert "to upload : 1" in capsys.readouterr().out
    assert not storage_parts.STAMP.exists()
    assert run(monkeypatch, "--check") == 0
    assert bucket["listings"] == 2


def test_check_and_all_always_list(bucket, monkeypatch):
    assert run(monkeypatch) == 0
    assert run(monkeypatch, "--check") == 0
    assert bucket["listings"] == 2
    assert run(monkeypatch, "--all") == 0
    assert sorted(bucket["uploads"]) == ["aa.lbm", "bb.lbm", "cc.lbm"]


def test_an_old_stamp_lists_again(bucket, monkeypatch):
    assert run(monkeypatch) == 0
    said = json.loads(storage_parts.STAMP.read_text())
    said["at"] = time.time() - storage_parts.STAMP_HOURS * 3600 - 1
    storage_parts.STAMP.write_text(json.dumps(said))
    assert run(monkeypatch) == 0
    assert bucket["listings"] == 2
