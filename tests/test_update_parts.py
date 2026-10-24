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


# The knowledge made from the catalogue (refresh_catalogue.KNOWLEDGE), as
# a refresh makes it after its catalogue: by stand-ins of its two tools,
# each writing the --generated folder it was given into its list, or
# failing as told.
STAND_IN = '''
import argparse, json, sys
from pathlib import Path
ask = argparse.ArgumentParser()
ask.add_argument("--generated", type=Path)
ask.add_argument("--out", type=Path)
args = ask.parse_args()
if {fails!r}:
    print("no vendor/rebrickable/inventories.csv.gz", file=sys.stderr)
    sys.exit(1)
args.out.write_text(json.dumps({{"format": 1, {listed!r}: [str(args.generated)]}}))
'''


@pytest.fixture
def building(library, monkeypatch, tmp_path):
    """A run that builds what it names, without numpy: each part's build
    stands in for build_meshes', the refresh for the Rebrickable joins, and
    the knowledge's tools for minifig_sets and set_sizes. Returns the
    knowledge folder, each file in it as it was before, and the tools
    folder, whose set_sizes.py a test may make fail."""
    import refresh_catalogue
    ldraw, out = library
    known, tools = tmp_path / "knowledge", tmp_path / "tools"
    known.mkdir()
    tools.mkdir()
    for tool, name, listed in refresh_catalogue.KNOWLEDGE:
        (known / name).write_text(json.dumps({"format": 1, listed: ["before"]}))
        (tools / tool).write_text(STAND_IN.format(fails=False, listed=listed))
    monkeypatch.setattr(update_parts, "build", lambda _ldraw, names, _jobs: [
        (n[:-4], b"mesh", {"id": n[:-4], "mesh": f"new{n[:-4]}"}) for n in names])
    monkeypatch.setattr(refresh_catalogue, "refresh", lambda *_given: ["refreshed"])
    made = refresh_catalogue.knowledge
    monkeypatch.setattr(refresh_catalogue, "knowledge",
                        lambda generated, into: made(generated, into, tools))
    return ldraw, out, known, tools


def test_a_run_makes_the_knowledge_again_from_its_catalogue(building, capsys, tmp_path):
    import refresh_catalogue
    ldraw, out, known, _tools = building
    update = make_zip(tmp_path / "lcad2602.zip", {"ldraw/parts/b.dat": "0 Plate B\n" + TRIANGLE * 2})
    args = ["--zip", str(update), "--ldraw", str(ldraw), "--out", str(out), "--knowledge", str(known)]
    assert update_parts.main(args + ["--jobs", "2"]) == 0
    said = capsys.readouterr().out
    meshes = {e["id"]: e["mesh"] for e in json.loads((out / "catalogue.json").read_text())["parts"]}
    assert meshes["b"] == "newb" and meshes["c"] == "newc"
    for _tool, name, listed in refresh_catalogue.KNOWLEDGE:
        assert json.loads((known / name).read_text())[listed] == [str(out)], name
        assert name in said
        assert not (known / (name + ".new")).exists()


def test_knowledge_that_cannot_be_made_fails_the_run_and_keeps_the_old_file(building, capsys, tmp_path):
    import refresh_catalogue
    ldraw, out, known, tools = building
    (tools / "set_sizes.py").write_text(STAND_IN.format(fails=True, listed="models"))
    update = make_zip(tmp_path / "lcad2602.zip", {"ldraw/parts/b.dat": "0 Plate B\n" + TRIANGLE * 2})
    args = ["--zip", str(update), "--ldraw", str(ldraw), "--out", str(out), "--knowledge", str(known)]
    assert update_parts.main(args + ["--jobs", "2"]) == 1
    said = capsys.readouterr()
    # Loudly, as a refresh fails: which tool, why, and which file is behind.
    assert "update_parts FAILED: tools/set_sizes.py exited 1" in said.err
    assert "no vendor/rebrickable/inventories.csv.gz" in said.err and "set_sizes.json" in said.err
    assert json.loads((known / "set_sizes.json").read_text())["models"] == ["before"]
    # The other is still made, and the parts built are still in the
    # catalogue, with what to upload said.
    assert json.loads((known / "minifig_sets.json").read_text())["parts"] == [str(out)]
    assert {e["id"]: e["mesh"] for e in json.loads((out / "catalogue.json").read_text())["parts"]}["b"] == "newb"
    assert "To put them live" in said.out
    assert not any((known / (name + ".new")).exists() for _t, name, _l in refresh_catalogue.KNOWLEDGE)
