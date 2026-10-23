"""tools/update_parts.py builds what an LDraw update reaches, and only that.

A small library is made in a folder: a part drawn from a subpart drawn from
a primitive, a part used by another, an unofficial part and its subpart.
Zips laid out as LDraw's are applied to it with --dry-run, which works out
everything a real run builds without numpy, and the parts it names are
read back from what it prints.
"""

from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import update_parts  # noqa: E402

TRIANGLE = "3 16 0 0 0 1 0 0 0 0 1\n"


def ref(name: str) -> str:
    return f"1 16 0 0 0 1 0 0 0 1 0 0 0 1 {name}\n"


LIBRARY = {
    "parts/a.dat": "0 Brick A\n" + ref("s\\as01.dat"),
    "parts/s/as01.dat": "0 ~Brick A body\n" + ref("prim.dat"),
    "p/prim.dat": "0 Primitive\n" + TRIANGLE,
    "parts/b.dat": "0 Plate B\n" + TRIANGLE,
    "parts/c.dat": "0 Plate C with B\n" + ref("b.dat"),
    "parts/d.dat": "0 Tile D\n" + TRIANGLE,
    "unofficial/parts/u.dat": "0 Slope U\n" + ref("s\\us01.dat"),
    "unofficial/parts/s/us01.dat": "0 ~Slope U body\n" + TRIANGLE,
    "models/Note2601CA.txt": "ldraw.org Parts Update 2026-01\n",
}


@pytest.fixture
def library(tmp_path: Path) -> tuple[Path, Path]:
    ldraw, out = tmp_path / "ldraw", tmp_path / "generated"
    for rel, text in LIBRARY.items():
        (ldraw / rel).parent.mkdir(parents=True, exist_ok=True)
        (ldraw / rel).write_text(text)
    out.mkdir()
    entries = [{"id": i, "mesh": f"m{i}"} for i in ("a", "b", "c", "d", "u")]
    (out / "catalogue.json").write_text(json.dumps({"counts": {}, "parts": entries}))
    return ldraw, out


def make_zip(path: Path, files: dict[str, str]) -> Path:
    with zipfile.ZipFile(path, "w") as archive:
        for name, text in files.items():
            archive.writestr(name, text)
    return path


def run(capsys, ldraw: Path, out: Path, *zips: Path, dry: bool = True) -> dict[str, list[str]]:
    args = ["--zip", *map(str, zips), "--ldraw", str(ldraw), "--out", str(out), "--jobs", "2"]
    assert update_parts.main(args + (["--dry-run"] if dry else [])) == 0
    said: dict[str, list[str]] = {"text": [capsys.readouterr().out]}
    for line in said["text"][0].splitlines():
        head, _, rest = line.partition(": ")
        if head in ("new", "rebuilt", "through a subpart or primitive"):
            said[head] = rest.split()
    return said


def test_a_changed_primitive_rebuilds_the_part_two_files_above_it(library, capsys, tmp_path):
    ldraw, out = library
    update = make_zip(tmp_path / "lcad2602.zip", {
        "ldraw/p/prim.dat": "0 Primitive\n" + TRIANGLE + TRIANGLE,
        "ldraw/models/Note2602CA.txt": "ldraw.org Parts Update 2026-02\n"})
    said = run(capsys, ldraw, out, update)
    assert said["rebuilt"] == ["a"]
    assert said["through a subpart or primitive"] == ["a"]
    assert said["new"] == []


def test_a_changed_part_rebuilds_the_parts_that_use_it(library, capsys, tmp_path):
    ldraw, out = library
    update = make_zip(tmp_path / "lcad2602.zip", {"ldraw/parts/b.dat": "0 Plate B\n" + TRIANGLE * 2})
    said = run(capsys, ldraw, out, update)
    assert said["rebuilt"] == ["b", "c"]
    assert said["through a subpart or primitive"] == ["c"]


def test_the_unofficial_zip_adds_parts_and_reaches_through_its_subparts(library, capsys, tmp_path):
    ldraw, out = library
    unofficial = make_zip(tmp_path / "ldrawunf.zip", {
        "parts/u.dat": LIBRARY["unofficial/parts/u.dat"],          # unchanged
        "parts/s/us01.dat": "0 ~Slope U body\n" + TRIANGLE * 2,    # changed
        "parts/n.dat": "0 Brick N\n" + ref("s\\ns01.dat"),         # new
        "parts/s/ns01.dat": "0 ~Brick N body\n" + TRIANGLE,
        "CAreadme.txt": "not a part file"})
    said = run(capsys, ldraw, out, unofficial)
    assert said["new"] == ["n"]
    assert said["rebuilt"] == ["u"]


def test_an_unofficial_file_an_official_one_shadows_changes_nothing(library, capsys, tmp_path):
    ldraw, out = library
    unofficial = make_zip(tmp_path / "ldrawunf.zip", {"parts/b.dat": "0 Plate B, under review\n"})
    said = run(capsys, ldraw, out, unofficial)
    assert said["rebuilt"] == [] and said["new"] == []


def test_an_official_part_over_an_unofficial_one_rebuilds_it(library, capsys, tmp_path):
    ldraw, out = library
    update = make_zip(tmp_path / "lcad2602.zip", {
        "ldraw/parts/u.dat": LIBRARY["unofficial/parts/u.dat"]})   # made official as it was
    said = run(capsys, ldraw, out, update)
    assert said["rebuilt"] == ["u"]


def test_an_update_older_than_the_library_is_not_applied(library, capsys, tmp_path):
    ldraw, out = library
    old = make_zip(tmp_path / "lcad2512.zip", {
        "ldraw/parts/d.dat": "0 Tile D, as it was\n",
        "ldraw/models/Note2512CA.txt": "ldraw.org Parts Update 2025-12\n"})
    said = run(capsys, ldraw, out, old)
    assert "older than the library's" in said["text"][0]
    assert said["rebuilt"] == []


def test_members_that_would_land_outside_the_library_are_left_out(library, capsys, tmp_path):
    ldraw, out = library
    bad = make_zip(tmp_path / "ldrawunf.zip", {
        "../evil.dat": "0 x\n", "/abs.dat": "0 x\n", "parts/../../x.dat": "0 x\n",
        "parts\\y.dat": "0 x\n", "parts/run.sh": "rm -rf /\n", "p/ok.dat": "0 ok\n"})
    layout, release, files = update_parts.members(bad)
    assert layout == "unofficial" and release == 0
    assert list(files) == ["unofficial/p/ok.dat"]


def test_a_second_run_finds_nothing_to_do(library, capsys, tmp_path):
    ldraw, out = library
    same = make_zip(tmp_path / "ldrawunf.zip", {
        "parts/u.dat": LIBRARY["unofficial/parts/u.dat"],
        "parts/s/us01.dat": LIBRARY["unofficial/parts/s/us01.dat"]})
    before = (out / "catalogue.json").read_text()
    said = run(capsys, ldraw, out, same, dry=False)
    assert "0 new or changed" in said["text"][0]
    assert "nothing to build" in said["text"][0]
    assert (out / "catalogue.json").read_text() == before
    assert not (out / update_parts.PENDING).exists()
