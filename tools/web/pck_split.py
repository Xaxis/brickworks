#!/usr/bin/env python3
"""Split the web export's pack, so the start waits only for the code.

    python3 tools/web/pck_split.py build/web

A first visit waited for one pack of 8.4 MB (brotli) before the engine
said a word, and most of it was not code: the parts' catalogue, the
models, LDraw's primitives and Studio's light. The scripts, compiled for
four seconds on the page's thread once the pack is in, could have been
compiling while the rest came (webload, 2026-10-30). So the pack Godot
exports is cut in four, by path:

  index.pck             the code and what it is drawn with (scripts, shaders,
                        scenes, icons), and the two tables read as their
                        classes load: what the engine waits for.
  index.data.pck        what the start reads once the scripts are made: the
                        catalogue and the rest of assets/web/, the models and
                        LDraw's tables (assets/ldraw/, not p/); and the
                        booklet's fonts. Fetched as the engine starts
                        (src/boot/shell.html) and mounted by the app before
                        its catalogue (WebPacks).
  index.primitives.bin  LDraw's primitives (assets/ldraw/p/), as a bundle of
                        files: fetched the first time a part is built from
                        LDraw's text (PartForge, CustomParts).
  index.hdri.bin        Studio's photographed light, each panorama's imported
                        texture as a bundle of files: fetched the first time
                        Studio lights a picture by one (StudioRender).

The two bundles are files, not packs, so nothing is mounted while the app
runs: a pack mounted then changes the engine's table of files while a
worker may be opening one. Their format is index.parts.bin's (web_pack.py):
"BWP1", the count, each file's name and size, then the files.

A file Godot imported (.godot/imported/) goes where its source does, as
its .import says: the .import and what it points at, together.

The packs keep Godot's own format (version 4): its header, each file at a
16-byte boundary after it, offsets from the first file, and the directory
of paths, offsets, sizes, MD5s and flags at the end. Every file the export
put in the pack is in exactly one of the four, byte for byte; the split
fails rather than drop or double one. index.html's size for index.pck,
which the engine's progress counts against, is made the code pack's.
"""

from __future__ import annotations

import json
import os
import re
import struct
import sys

MAGIC = b"GDPC"
ALIGN = 16
BUNDLE_MAGIC = b"BWP1"

DATA = "index.data.pck"
PRIMITIVES = "index.primitives.bin"
HDRI = "index.hdri.bin"


class Entry:
    def __init__(self, raw_path: bytes, offset: int, size: int, md5: bytes, flags: int):
        self.raw_path = raw_path          # as stored: zero-padded to 4 bytes
        self.path = raw_path.rstrip(b"\0").decode()
        self.offset = offset
        self.size = size
        self.md5 = md5
        self.flags = flags


def read_pack(path: str) -> tuple[bytes, bytes, list[Entry]]:
    """The pack's header (up to its first file), its bytes, and its files."""
    data = open(path, "rb").read()
    if data[:4] != MAGIC:
        sys.exit(f"pck_split: {path} is not a Godot pack")
    version, = struct.unpack_from("<I", data, 4)
    if version < 3:
        sys.exit(f"pck_split: {path} is pack format {version}; this reads 3 and later")
    flags, = struct.unpack_from("<I", data, 20)
    if flags & 1:
        sys.exit("pck_split: the pack's directory is encrypted")
    if not flags & 2:
        sys.exit("pck_split: the pack's offsets are not from its first file")
    base, directory = struct.unpack_from("<QQ", data, 24)
    at = directory
    count, = struct.unpack_from("<I", data, at)
    at += 4
    entries = []
    for _ in range(count):
        length, = struct.unpack_from("<I", data, at)
        at += 4
        raw = data[at:at + length]
        at += length
        offset, size = struct.unpack_from("<QQ", data, at)
        md5 = data[at + 16:at + 32]
        at += 32
        file_flags, = struct.unpack_from("<I", data, at)
        at += 4
        if file_flags & 1:
            sys.exit(f"pck_split: {raw.rstrip(bytes(1)).decode()} is encrypted")
        entries.append(Entry(raw, offset, size, md5, file_flags))
    if at != len(data):
        sys.exit(f"pck_split: {len(data) - at} bytes after the pack's directory")
    return data[:base], data, entries


def body(data: bytes, base: int, entry: Entry) -> bytes:
    return data[base + entry.offset:base + entry.offset + entry.size]


def write_pack(path: str, header: bytes, data: bytes, entries: list[Entry]) -> None:
    """A pack of [entries], in the order they were, with [header]'s format."""
    base = len(header)
    out = bytearray(header)
    placed = []
    for entry in sorted(entries, key=lambda e: e.offset):
        out += bytes(-len(out) % ALIGN)
        placed.append((entry, len(out) - base))
        out += body(data, base, entry)
    out += bytes(-len(out) % ALIGN)
    struct.pack_into("<Q", out, 32, len(out))
    out += struct.pack("<I", len(placed))
    for entry, offset in placed:
        out += struct.pack("<I", len(entry.raw_path)) + entry.raw_path
        out += struct.pack("<QQ", offset, entry.size) + entry.md5 + struct.pack("<I", entry.flags)
    with open(path, "wb") as f:
        f.write(out)


def write_bundle(path: str, files: list[tuple[str, bytes]]) -> None:
    """index.parts.bin's format: "BWP1", the count, names and sizes, files."""
    with open(path, "wb") as f:
        f.write(BUNDLE_MAGIC + struct.pack("<I", len(files)))
        for name, content in files:
            encoded = name.encode("ascii")
            f.write(struct.pack("<H", len(encoded)) + encoded + struct.pack("<I", len(content)))
        for _, content in files:
            f.write(content)


# Tables read as their classes load, which is while the scripts are made,
# before the data pack is mounted (Mechanism._table, KnownFits._table): in
# the data pack they would read as nothing, for good. 15 KB over the wire,
# so they stay with the code.
AT_CLASS_LOAD = {"assets/ldraw/gears.json", "assets/ldraw/known_fits.json"}


def where(path: str) -> str:
    """Which of the four a file of the pack goes in, by its own path or, for
    what Godot imported, its source's (imported_from)."""
    if path in AT_CLASS_LOAD:
        return "index.pck"
    if path.startswith("assets/ldraw/p/"):
        return PRIMITIVES
    if path.startswith("assets/hdri/"):
        return HDRI
    # The booklet's type is read when a PDF is made, long after the start
    # (BookletPdf): 0.5 MB of fonts that do not compress, which the start
    # waited for.
    if path.startswith(("assets/web/", "assets/ldraw/", "models/", "assets/fonts/")):
        return DATA
    return "index.pck"


def imported_from(data: bytes, base: int, entries: list[Entry]) -> dict[str, str]:
    """Each imported file under .godot/imported/ -> the path of its source,
    from the .import beside the source that points res:// at it."""
    sources = {}
    for e in entries:
        if e.path.endswith(".import"):
            text = body(data, base, e).decode("utf-8", "replace")
            for found in re.finditer(r'^path(?:\.[a-z0-9_]+)?="res://(\.godot/imported/[^"]+)"', text, re.M):
                sources[found.group(1)] = e.path.removesuffix(".import")
    return sources


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__.split("\n\n")[1])
    build = sys.argv[1]
    pack = os.path.join(build, "index.pck")
    header, data, entries = read_pack(pack)
    base = len(header)
    groups: dict[str, list[Entry]] = {"index.pck": [], DATA: [], PRIMITIVES: [], HDRI: []}
    sources = imported_from(data, base, entries)
    for entry in entries:
        groups[where(sources.get(entry.path, entry.path))].append(entry)
    for name in (DATA, PRIMITIVES, HDRI):
        if not groups[name]:
            sys.exit(f"pck_split: nothing in the export for {name}")
    for kept in ["project.binary"] + sorted(AT_CLASS_LOAD):
        if not any(e.path == kept for e in groups["index.pck"]):
            sys.exit(f"pck_split: no {kept} in the code pack")

    primitives = [(e.path.removeprefix("assets/ldraw/p/"), body(data, base, e))
                  for e in sorted(groups[PRIMITIVES], key=lambda e: e.path)]
    # Each panorama's imported texture under its source's name
    # (studio_small_09.hdr.ctex): what StudioRender asks for. The .import
    # files that point res:// at them are not needed by a texture read
    # from its own path.
    hdri = []
    for e in sorted(groups[HDRI], key=lambda e: e.path):
        if e.path.startswith(".godot/imported/"):
            name = os.path.basename(e.path)
            source, _, rest = name.partition(".hdr-")
            hdri.append((source + ".hdr" + os.path.splitext(rest)[1], body(data, base, e)))
    if len(hdri) != sum(1 for e in groups[HDRI] if e.path.endswith(".hdr.import")):
        sys.exit("pck_split: a panorama without its imported texture, or one twice")

    write_pack(os.path.join(build, DATA), header, data, groups[DATA])
    write_bundle(os.path.join(build, PRIMITIVES), primitives)
    write_bundle(os.path.join(build, HDRI), hdri)
    write_pack(pack, header, data, groups["index.pck"])

    # Read back: every file once, byte for byte.
    seen: dict[str, bytes] = {}
    for name in ("index.pck", DATA):
        h, d, es = read_pack(os.path.join(build, name))
        for e in es:
            if e.path in seen:
                sys.exit(f"pck_split: {e.path} is in two packs")
            seen[e.path] = body(d, len(h), e)
    for e in groups[PRIMITIVES] + groups[HDRI]:
        seen[e.path] = body(data, base, e)
    for e in entries:
        if seen.get(e.path) != body(data, base, e):
            sys.exit(f"pck_split: {e.path} did not come through whole")

    # The engine's own config, not the shell's comment that names its
    # placeholders, which Godot fills in too: progress counted against the
    # whole pack's size never reached it, and what the start fetches once
    # the engine's files are here waited for the app to ask.
    page = os.path.join(build, "index.html")
    text = open(page, encoding="utf-8").read()
    found = re.search(r"const GODOT_CONFIG = ", text)
    if not found:
        sys.exit("pck_split: no GODOT_CONFIG in index.html")
    config, end = json.JSONDecoder().raw_decode(text, found.end())
    if "index.pck" not in config.get("fileSizes", {}):
        sys.exit("pck_split: no size for index.pck in index.html's GODOT_CONFIG")
    config["fileSizes"]["index.pck"] = os.path.getsize(pack)
    text = text[:found.end()] + json.dumps(config, separators=(",", ":")) + text[end:]
    open(page, "w", encoding="utf-8").write(text)

    for name in ("index.pck", DATA, PRIMITIVES, HDRI):
        count = len(groups[name])
        print(f"pck_split: {name:<21} {os.path.getsize(os.path.join(build, name)) / 1e6:6.1f} MB, {count} files")


if __name__ == "__main__":
    main()
