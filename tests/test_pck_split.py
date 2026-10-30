"""tools/web/pck_split.py: the web export's pack cut so the start waits for
the code alone, every file in exactly one place, byte for byte.

A pack is made here in Godot's format (version 4, as 4.7 writes it: a
112-byte header, files from it at 16-byte boundaries, offsets from the
first file, the directory at the end), split, and read back.
"""

from __future__ import annotations

import importlib.util
import json
import struct
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools/web/pck_split.py"
_spec = importlib.util.spec_from_file_location("pck_split", SCRIPT)
pck_split = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pck_split)

HEADER = 112

FILES = {
    "project.binary": b"ECFG settings",
    "src/main.gdc": b"GDSC tokens of main" * 40,
    "src/ui/look.gdc": b"GDSC look",
    "assets/fonts/LiberationSans-Regular.ttf.import":
        b"[remap]\npath=\"res://.godot/imported/LiberationSans-Regular.ttf-abc.fontdata\"\n",
    ".godot/imported/LiberationSans-Regular.ttf-abc.fontdata": b"font" * 100,
    "assets/ui/tools/accept.svg.import": b"[remap]\npath=\"res://.godot/imported/accept.svg-d7c.ctex\"\n",
    ".godot/imported/accept.svg-d7c.ctex": b"GST2 icon",
    "assets/web/catalogue.json": b'{"parts": {"3001": {}}}' * 50,
    "assets/web/parts/eab5.lbm": bytes(range(256)) * 3,
    "assets/web/all_order.txt": b"1 0\n3001\n",
    "models/car.ldr": b"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n",
    "assets/ldraw/part_names.json": b'{"3001": "brick"}',
    "assets/ldraw/gears.json": b'{"gears": {"3647": {}}}',
    "assets/ldraw/known_fits.json": b'{"plain": {}}',
    "assets/ldraw/stud.dat": b"0 Stud\n",
    "assets/ldraw/p/stud.dat": b"0 Stud (p)\n",
    "assets/ldraw/p/48/1-4cyli.dat": b"0 Cylinder 0.25\n" * 9,
    "assets/hdri/studio_small_09.hdr.import": b"[remap]\npath=\"res://.godot/imported/studio_small_09.hdr-a7a3.ctex\"\n",
    ".godot/imported/studio_small_09.hdr-a7a3.ctex": b"GST2 texture bytes" * 20,
}


def make_pack(path: Path, files: dict[str, bytes]) -> None:
    header = bytearray(b"GDPC" + struct.pack("<5I", 4, 4, 7, 2, 2))
    header += struct.pack("<QQ", HEADER, 0)
    header += bytes(HEADER - len(header))
    out = bytearray(header)
    placed = []
    for name, body in files.items():
        out += bytes(-len(out) % 16)
        placed.append((name, len(out) - HEADER, len(body)))
        out += body
    out += bytes(-len(out) % 16)
    struct.pack_into("<Q", out, 32, len(out))
    out += struct.pack("<I", len(placed))
    for name, offset, size in placed:
        raw = name.encode() + bytes(-len(name.encode()) % 4)
        out += struct.pack("<I", len(raw)) + raw + struct.pack("<QQ", offset, size) + bytes(16) + struct.pack("<I", 0)
    path.write_bytes(bytes(out))


def read_bundle(path: Path) -> dict[str, bytes]:
    data = path.read_bytes()
    assert data[:4] == b"BWP1"
    count, = struct.unpack_from("<I", data, 4)
    at = 8
    named = []
    for _ in range(count):
        length, = struct.unpack_from("<H", data, at)
        name = data[at + 2:at + 2 + length].decode()
        size, = struct.unpack_from("<I", data, at + 2 + length)
        named.append((name, size))
        at += 6 + length
    out = {}
    for name, size in named:
        out[name] = data[at:at + size]
        at += size
    assert at == len(data)
    return out


def read_pack(path: Path) -> dict[str, bytes]:
    header, data, entries = pck_split.read_pack(str(path))
    assert len(header) == HEADER
    for entry in entries:
        assert (HEADER + entry.offset) % 16 == 0
    return {e.path: pck_split.body(data, len(header), e) for e in entries}


@pytest.fixture()
def split(tmp_path: Path) -> Path:
    make_pack(tmp_path / "index.pck", FILES)
    (tmp_path / "index.html").write_text(
        # As the shell is: a comment naming the placeholders, which Godot
        # fills in too, before the engine's own config.
        '<!-- {"fileSizes":{"index.pck":999999,"index.wasm":42}} -->\n'
        '<script>const GODOT_CONFIG = {"fileSizes":{"index.pck":999999,"index.wasm":42},"executable":"index"};</script>')
    done = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path)], capture_output=True, text=True)
    assert done.returncode == 0, done.stdout + done.stderr
    return tmp_path


def test_the_engine_waits_for_the_code_alone(split: Path) -> None:
    code = read_pack(split / "index.pck")
    # With the tables read as their classes load, while the scripts are
    # made and before the data pack is mounted (Mechanism, KnownFits).
    assert sorted(code) == sorted(["project.binary", "src/main.gdc", "src/ui/look.gdc",
                                   "assets/ui/tools/accept.svg.import", ".godot/imported/accept.svg-d7c.ctex",
                                   "assets/ldraw/gears.json", "assets/ldraw/known_fits.json"])


def test_what_the_start_reads_is_a_pack_beside_it(split: Path) -> None:
    data = read_pack(split / "index.data.pck")
    # And the booklet's type, read when a PDF is made: its .import and the
    # font it points at, together.
    assert sorted(data) == sorted(["assets/web/catalogue.json", "assets/web/parts/eab5.lbm",
                                   "assets/web/all_order.txt", "models/car.ldr",
                                   "assets/ldraw/part_names.json", "assets/ldraw/stud.dat",
                                   "assets/fonts/LiberationSans-Regular.ttf.import",
                                   ".godot/imported/LiberationSans-Regular.ttf-abc.fontdata"])


def test_the_primitives_and_the_light_are_files_under_their_own_names(split: Path) -> None:
    assert read_bundle(split / "index.primitives.bin") == {
        "stud.dat": FILES["assets/ldraw/p/stud.dat"],
        "48/1-4cyli.dat": FILES["assets/ldraw/p/48/1-4cyli.dat"],
    }
    # As StudioRender asks for it (WebPacks.hdri): the source's name.
    assert read_bundle(split / "index.hdri.bin") == {
        "studio_small_09.hdr.ctex": FILES[".godot/imported/studio_small_09.hdr-a7a3.ctex"],
    }


def test_every_file_is_in_one_place_byte_for_byte(split: Path) -> None:
    found: dict[str, bytes] = {}
    for name in ("index.pck", "index.data.pck"):
        for path, body in read_pack(split / name).items():
            assert path not in found
            found[path] = body
    for name, body in read_bundle(split / "index.primitives.bin").items():
        found["assets/ldraw/p/" + name] = body
    hdri = read_bundle(split / "index.hdri.bin")
    found[".godot/imported/studio_small_09.hdr-a7a3.ctex"] = hdri["studio_small_09.hdr.ctex"]
    # The .import that pointed res:// at the texture is not needed by one
    # read from its own path, and is the only file not carried.
    assert {k: v for k, v in FILES.items() if not k.endswith(".hdr.import")} == found


def test_the_page_counts_progress_against_the_code_pack(split: Path) -> None:
    page = (split / "index.html").read_text()
    size = (split / "index.pck").stat().st_size
    config = json.JSONDecoder().raw_decode(page, page.index("const GODOT_CONFIG = ") + len("const GODOT_CONFIG = "))[0]
    assert config["fileSizes"] == {"index.pck": size, "index.wasm": 42}
    assert config["executable"] == "index"
    assert size < 999999


def test_an_export_without_a_table_read_as_its_class_loads_is_refused(tmp_path: Path) -> None:
    make_pack(tmp_path / "index.pck", {k: v for k, v in FILES.items() if k != "assets/ldraw/gears.json"})
    (tmp_path / "index.html").write_text('<script>const GODOT_CONFIG = {"fileSizes":{"index.pck":1}};</script>')
    done = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path)], capture_output=True, text=True)
    assert done.returncode != 0
    assert "gears.json" in done.stdout + done.stderr


def test_an_export_without_the_primitives_is_refused(tmp_path: Path) -> None:
    make_pack(tmp_path / "index.pck", {k: v for k, v in FILES.items() if not k.startswith("assets/ldraw/p/")})
    (tmp_path / "index.html").write_text('{"fileSizes":{"index.pck":1}}')
    done = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path)], capture_output=True, text=True)
    assert done.returncode != 0
    assert "index.primitives.bin" in done.stdout + done.stderr
