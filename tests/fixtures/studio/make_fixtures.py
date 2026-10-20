#!/usr/bin/env python3
"""Make the BrickLink Studio (.io) files src/dev/io_probe.gd opens.

Made here, in the shapes of two files Studio itself saved and that were
opened to learn the format (not kept: neither is ours to publish):

  bay_2025.io   as Studio 2.25.2 writes one: not locked; model.ldr with a
                byte-order mark, Windows line ends, "0 FILE <name>.io" first,
                Studio's own meta lines, a sub-model whose FILE line says
                "SubModel Group 1" and whose reference says "submodel group 1";
                model2.ldr in BrickLink's colour and part numbers carrying a
                part's geometry; modelv2.ldr in Studio's "11" lines; .info,
                errorPartList.err, a thumbnail, and a custom part under
                CustomParts/ that the model uses.
  bay_2021.io   as Studio 2.2.1 wrote one: locked with Studio's password by
                the system's own zip (not by Brickworks), model.ldr with no
                FILE line, modelv1.ldr in Studio's "10" lines, and .info's
                version with the stray carriage return Studio left in it.
  bay_aes.io    the 2021 bay locked with WinZip's AES-256 (AE-2, which states
                no CRC) under Studio's password, as another reader says some
                early-access Studio builds wrote theirs. Written here, by
                hand, so it proves the reader only alongside
                libarchive_aes256.zip, libarchive's own AES-256 test file
                (BSD-2-Clause; docs/ATTRIBUTION.md), which the probe opens
                with libarchive's password.

model2.ldr has every colour in BrickLink's numbers, which are not LDraw's
(white is 1 there and blue here), so a reader that takes the wrong member
opens the bay in the wrong colours.

    python3 tests/fixtures/studio/make_fixtures.py
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import struct
import subprocess
import tempfile
import time
import zlib
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
WHEN = (2025, 4, 8, 16, 32, 0)
CUSTOM = "m1a2b3c4_2025408_163200.dat"

# part, LDraw colour, BrickLink colour, BrickLink part, x y z, matrix, step
BAY = [
    ("3001", 4, 5, "3001", (-60, -24, -20), (1, 0, 0, 0, 1, 0, 0, 0, 1), 1),
    ("3004", 15, 1, "3004", (-60, -48, -10), (0, 0, 1, 0, 1, 0, -1, 0, 0), 1),
    ("3022", 14, 3, "3022", (-60, -56, -20), (1, 0, 0, 0, 1, 0, 0, 0, 1), 2),
    (CUSTOM[:-4], 71, 86, CUSTOM[:-4], (0, -24, 60), (1, 0, 0, 0, 1, 0, 0, 0, 1), 2),
]
GROUP = [
    ("3001", 1, 7, "3001", (40, -24, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1), 0),
    ("3068b", 0, 11, "3068", (40, -32, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1), 1),
]


def _numbers(at: tuple, turn: tuple) -> str:
    return " ".join("%f" % float(v) for v in at + turn)


def _lines(parts: list, kind: str, first_step: int = 0) -> list[str]:
    """Type-1 lines (or Studio's 10 and 11) for ``parts``, with 0 STEP between steps."""
    out: list[str] = []
    step = first_step
    for n, (part, ldraw, bricklink, bl_part, at, turn, in_step) in enumerate(parts):
        while step < in_step:
            out.append("0 STEP")
            step += 1
        if kind == "ldraw":
            out.append("1 %d %s %s.dat" % (ldraw, _numbers(at, turn), part))
        elif kind == "bricklink":
            out.append("1 %d %s %s.dat" % (bricklink, _numbers(at, turn), bl_part))
        elif kind == "v1":
            out.append("10 %d False 0 %s %s.dat" % (ldraw, _numbers(at, turn), part))
        else:
            out.append("11 %d %d False 0 %s %s.dat" % (ldraw, 806 + n, _numbers(at, turn), part))
    out.append("0 STEP")
    return out


def _header(title: str, name: str, count: int) -> list[str]:
    return ["0 %s" % title, "0 Name:  %s" % name, "0 Author:  ", "0 CustomBrick",
            "0 FlexibleBrickControlPointUnitLength -1", "0 NumOfBricks:  %d" % count]


def _studio_text(lines: list[str]) -> bytes:
    return ("﻿" + "\r\n".join(lines) + "\r\n").encode("utf-8")


def _model_2025(kind: str) -> bytes:
    """model.ldr (ldraw), model2.ldr (bricklink) or modelv2.ldr (v2)."""
    group_ref = "1 %d %s submodel group 1" % (
        16 if kind != "bricklink" else -1, _numbers((0, 0, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1)))
    if kind == "v2":
        group_ref = "11 16 805 False 0 %s submodel group 1" % _numbers(
            (0, 0, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1))
    lines = ["0 FILE bay_2025.io"] + _header("Untitled Model", "bay_2025", 6)
    lines.append(group_ref)
    lines += _lines(BAY, kind)
    lines.append("0 NOFILE")
    lines += ["0 FILE SubModel Group 1"] + _header("SubModel Group 1", "SubModel Group 1", 2) \
        + _lines(GROUP, kind) + ["0 NOFILE"]
    if kind == "bricklink":
        # The geometry of what it uses, as Studio carries it: one part's worth.
        lines += ["0 FILE 3001.dat", "0 Brick  2 x  4", "0 Name: 3001.dat",
                  "1 16 0 0 0 1 0 0 0 1 0 0 0 1 s/3001s01.dat", "0 NOFILE"]
    return _studio_text(lines)


def _model_2021(kind: str) -> bytes:
    lines = _header("Untitled Model", "bay_2021", 3)[:4]
    return _studio_text(lines + _lines(BAY[:3], kind, 1))


def _png() -> bytes:
    """A 4 x 3 picture, sandy, so the file has a thumbnail as Studio's do."""
    rows = b"".join(b"\x00" + bytes((222, 198, 156, 255)) * 4 for _ in range(3))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 3, 8, 6, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


def _custom_part() -> bytes:
    return _studio_text(["0 Studio's own part, made in its Part Designer",
                         "0 Name: %s" % CUSTOM, "0 Author: Brickworks probe",
                         "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"])


def make_2025() -> None:
    members = [
        ("model.ldr", _model_2025("ldraw")),
        ("modelv2.ldr", _model_2025("v2")),
        ("model2.ldr", _model_2025("bricklink")),
        ("thumbnail.png", _png()),
        ("errorPartList.err", b"[]"),
        (".info", json.dumps({"version": "2.25.2_1", "total_parts": 6, "parts_db_version": 151},
                             separators=(",", ":")).encode()),
        ("CustomParts/parts/" + CUSTOM, _custom_part()),
    ]
    with zipfile.ZipFile(os.path.join(HERE, "bay_2025.io"), "w", zipfile.ZIP_DEFLATED) as out:
        for name, data in members:
            out.writestr(zipfile.ZipInfo(name, WHEN), data, zipfile.ZIP_DEFLATED)


def make_2021() -> None:
    members = [
        ("model.ldr", _model_2021("ldraw")),
        ("modelv1.ldr", _model_2021("v1")),
        ("model2.ldr", _model_2021("bricklink")),
        ("thumbnail.png", _png()),
        ("errorPartList.err", b"[]"),
        (".info", b'{"version":"2.2.1_1\r","total_parts":3}'),
    ]
    target = os.path.join(HERE, "bay_2021.io")
    if os.path.exists(target):
        os.remove(target)
    with tempfile.TemporaryDirectory() as folder:
        for name, data in members:
            with open(os.path.join(folder, name), "wb") as f:
                f.write(data)
            stamp = time.mktime((2021, 2, 3, 9, 55, 0, 0, 0, -1))
            os.utime(os.path.join(folder, name), (stamp, stamp))
        subprocess.run(["zip", "-q", "-X", "-P", "soho0909", target] + [m[0] for m in members],
                       cwd=folder, check=True)


def _aes_member(name: str, data: bytes, password: bytes) -> tuple[bytes, bytes]:
    """A member locked as WinZip AE-2 with AES-256: (its data, its extra field)."""
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    salt = hashlib.sha1(name.encode() + data).digest()[:16]
    made = hashlib.pbkdf2_hmac("sha1", password, salt, 1000, 66)
    key, mac_key, check = made[:32], made[32:64], made[64:]
    deflate = zlib.compressobj(9, zlib.DEFLATED, -15)
    packed = deflate.compress(data) + deflate.flush()
    blocks = (len(packed) + 15) // 16
    counters = b"".join(struct.pack("<QQ", n + 1, 0) for n in range(blocks))
    cipher = Cipher(algorithms.AES(key), modes.ECB()).encryptor()
    stream = cipher.update(counters) + cipher.finalize()
    locked = bytes(a ^ b for a, b in zip(packed, stream))
    sealed = hmac.new(mac_key, locked, hashlib.sha1).digest()[:10]
    extra = struct.pack("<HHH2sBH", 0x9901, 7, 2, b"AE", 3, 8)
    return salt + check + locked + sealed, extra


def make_aes() -> None:
    members = [
        ("model.ldr", _model_2021("ldraw")),
        ("modelv1.ldr", _model_2021("v1")),
        ("model2.ldr", _model_2021("bricklink")),
        ("errorPartList.err", b"[]"),
        (".info", b'{"version":"2.2.1_1\r","total_parts":3}'),
    ]
    dos_time, dos_date = (9 << 11) | (55 << 5), ((2021 - 1980) << 9) | (2 << 5) | 3
    body, directory = b"", b""
    for name, data in members:
        locked, extra = _aes_member(name, data, b"soho0909")
        fields = struct.pack("<HHHHHIII", 51, 0x0001, 99, dos_time, dos_date, 0, len(locked),
                             len(data))
        header = struct.pack("<I", 0x04034B50) + fields + struct.pack("<HH", len(name), len(extra))
        directory += struct.pack("<IH", 0x02014B50, 51) + fields + struct.pack(
            "<HHHHHII", len(name), len(extra), 0, 0, 0, 0, len(body)) + name.encode() + extra
        body += header + name.encode() + extra + locked
    end = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(members), len(members), len(directory),
                      len(body), 0)
    with open(os.path.join(HERE, "bay_aes.io"), "wb") as out:
        out.write(body + directory + end)


def make_gatehouse() -> None:
    """gatehouse_2025.io: tests/fixtures/steps/gatehouse.mpd as Studio 2.25 would
    hold it — a byte-order mark, Windows line ends, its FILE line naming the
    .io — so the author's steps are opened from a Studio file too."""
    with open(os.path.join(HERE, "..", "steps", "gatehouse.mpd"), encoding="utf-8") as f:
        lines = f.read().splitlines()
    lines[0] = "0 FILE gatehouse_2025.io"
    parts = sum(1 for line in lines if line.startswith("1 ") and not line.endswith(".ldr"))
    members = [
        ("model.ldr", _studio_text(lines)),
        ("thumbnail.png", _png()),
        ("errorPartList.err", b"[]"),
        (".info", json.dumps({"version": "2.25.2_1", "total_parts": parts},
                             separators=(",", ":")).encode()),
    ]
    with zipfile.ZipFile(os.path.join(HERE, "gatehouse_2025.io"), "w",
                         zipfile.ZIP_DEFLATED) as out:
        for name, data in members:
            out.writestr(zipfile.ZipInfo(name, WHEN), data, zipfile.ZIP_DEFLATED)


def _picture(width: int, height: int, colours: list[tuple[int, int, int]]) -> bytes:
    """An RGBA PNG in bands of ``colours`` across, a clear pixel round its edge
    as Studio's prints have (a picture mapped into 0.045 to 0.955)."""
    rows = b""
    for y in range(height):
        row = b"\x00"
        for x in range(width):
            if x in (0, width - 1) or y in (0, height - 1):
                row += bytes((0, 0, 0, 0))
            else:
                band = min(len(colours) - 1, x * len(colours) // width)
                # The top quarter darker, so a picture upside down is seen.
                r, g, b = colours[band]
                if y < height // 4:
                    r, g, b = r // 2, g // 2, b // 2
                row += bytes((r, g, b, 255))
        rows += row

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6,
                                                            0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


# The decorated parts decor_2025.io carries, as Studio carries them.
PRINT = "3068pb9001"          # a catalogue print: model2.ldr, faces with coordinates
STICKERED = "2431pb9002"      # a sticker, which Studio files as the part with it on
DESIGNED = "m1a2b3c4_2025408_170000"   # Part Designer's decal: CustomParts/, a box
PRINT_PICTURE = _picture(32, 32, [(201, 26, 9), (255, 255, 255), (13, 105, 171)])
STICKER_PICTURE = _picture(64, 16, [(242, 205, 55), (27, 42, 52)])
DECAL_PICTURE = _picture(32, 32, [(75, 159, 74), (242, 205, 55)])


def _tile(half_x: float, half_z: float, colour: int, uvs: bool) -> list[str]:
    """A tile flattened as model2.ldr has a part: its top (at y 0) two
    triangles, carrying 0.045 to 0.955 when ``uvs``, as set 31213's lips do;
    its sides and bottom (at y 8) without. Wound counter-clockwise."""
    x, z = half_x, half_z

    def t(*corners: tuple[float, float, float]) -> str:
        return "3 %d %s" % (colour, " ".join("%.3f %.3f %.3f" % c for c in corners))

    top = [t((-x, 0, z), (-x, 0, -z), (x, 0, -z)), t((-x, 0, z), (x, 0, -z), (x, 0, z))]
    if uvs:
        top = [top[0] + " 0.045 0.955 0.045 0.045 0.955 0.045",
               top[1] + " 0.045 0.955 0.955 0.045 0.955 0.955"]
    sides = [
        t((-x, 0, -z), (-x, 8, -z), (x, 8, -z)), t((-x, 0, -z), (x, 8, -z), (x, 0, -z)),
        t((x, 0, z), (x, 8, z), (-x, 8, z)), t((x, 0, z), (-x, 8, z), (-x, 0, z)),
        t((-x, 0, z), (-x, 8, z), (-x, 8, -z)), t((-x, 0, z), (-x, 8, -z), (-x, 0, -z)),
        t((x, 0, -z), (x, 8, -z), (x, 8, z)), t((x, 0, -z), (x, 8, z), (x, 0, z)),
        t((-x, 8, -z), (-x, 8, z), (x, 8, z)), t((-x, 8, -z), (x, 8, z), (x, 8, -z)),
    ]
    return top + sides


def make_decor() -> None:
    """decor_2025.io: a Studio 2.25 file whose model uses a catalogue print
    (bl_3068pb9001), a stickered tile (bl_2431pb9002, a sticker as Studio has
    one), a part made in Part Designer with a decal on it, and bl_3001, a part
    LDraw has, which must stay the library's. model2.ldr carries the print and
    the stickered tile flattened with coordinates on their faces, in BrickLink's
    numbers (-1 their colour); CustomParts/ the Part Designer part, an MPD whose
    picture is cast by a projection box (PE_TEX_INFO with sixteen numbers) on
    its own tile, the box's x and z mirrored and its min and max given so the
    picture's top is the tile's back, as the lips' is."""
    import base64
    turn = (1, 0, 0, 0, 1, 0, 0, 0, 1)
    model = ["0 FILE decor_2025.io"] + _header("Untitled Model", "decor_2025", 4) + [
        "1 4 0.000000 -24.000000 0.000000 %s bl_3001.dat" % " ".join("%f" % v for v in turn),
        "1 15 20.000000 -32.000000 0.000000 %s bl_%s.dat" % (" ".join("%f" % v for v in turn), PRINT),
        "0 STEP",
        "1 0 60.000000 -8.000000 0.000000 %s bl_%s.dat" % (" ".join("%f" % v for v in turn),
                                                         STICKERED),
        "1 14 -60.000000 -8.000000 0.000000 %s %s.dat" % (" ".join("%f" % v for v in turn),
                                                       DESIGNED),
        "0 STEP", "0 NOFILE"]
    model2 = ["0 FILE decor_2025.io"] + _header("Untitled Model", "decor_2025", 4) + [
        "1 5 0.000000 -24.000000 0.000000 %s 3001.dat" % " ".join("%f" % v for v in turn),
        "1 1 20.000000 -32.000000 0.000000 %s %s.dat" % (" ".join("%f" % v for v in turn), PRINT),
        "1 11 60.000000 -8.000000 0.000000 %s %s.dat" % (" ".join("%f" % v for v in turn),
                                                       STICKERED),
        "1 3 -60.000000 -8.000000 0.000000 %s %s.dat" % (" ".join("%f" % v for v in turn), DESIGNED),
        "0 NOFILE",
        "0 FILE %s.dat" % PRINT,
        "0 Tile 2 x 2 with Red, White and Blue Bands Pattern",
        "0 Name:  %s" % PRINT, "0 Author:  ", "0 BL_Item_No %s" % PRINT,
        "0 PE_TEX_INFO " + base64.b64encode(PRINT_PICTURE).decode()] + _tile(20, 20, -1, True) + [
        "0 NOFILE",
        "0 FILE %s.dat" % STICKERED,
        "0 Tile 1 x 4 with Yellow and Black Stripes (Sticker) - Set 9999",
        "0 Name:  %s" % STICKERED, "0 Author:  ",
        "0 PE_TEX_INFO " + base64.b64encode(STICKER_PICTURE).decode()] + _tile(40, 10, -1, True) + [
        "0 NOFILE",
        "0 FILE 3001.dat", "0 Brick  2 x  4", "0 Name: 3001.dat"] + _tile(40, 20, -1, False) + [
        "0 NOFILE"]
    # Part Designer's own file: the box at the tile's top, two LDU deep, its x
    # and z mirrored as Part Designer's are, cast on the tile's faces turned up.
    box = "0.0 -0.5 0.0 -40.0 0.0 0.0 0.0 -2.0 0.0 0.0 0.0 -40.0 20.0 -20.0 -20.0 20.0"
    designed = [
        "0 FILE %s.dat" % DESIGNED,
        "0 Tile 2 x 2 with Green and Yellow Decal",
        "0 Name:  %s.dat" % DESIGNED, "0 Author:  ",
        "0 BFC CERTIFY CCW",
        "0 PE_TEX_PATH 0",
        "0 PE_TEX_INFO %s %s" % (box, base64.b64encode(DECAL_PICTURE).decode()),
        "1 16 0 0 0 1 0 0 0 1 0 0 0 1 %s-tile.dat" % DESIGNED,
        "0 NOFILE",
        "0 FILE %s-tile.dat" % DESIGNED,
        "0 BFC CERTIFY CCW"] + _tile(20, 20, 16, False) + ["0 NOFILE"]
    members = [
        ("model.ldr", _studio_text(model)),
        ("model2.ldr", _studio_text(model2)),
        ("thumbnail.png", _png()),
        ("errorPartList.err", b"[]"),
        (".info", json.dumps({"version": "2.25.2_1", "total_parts": 4, "parts_db_version": 151},
                             separators=(",", ":")).encode()),
        ("CustomParts/%s.dat" % DESIGNED, _studio_text(designed)),
    ]
    with zipfile.ZipFile(os.path.join(HERE, "decor_2025.io"), "w", zipfile.ZIP_DEFLATED) as out:
        for name, data in members:
            out.writestr(zipfile.ZipInfo(name, WHEN), data, zipfile.ZIP_DEFLATED)


def _drawing(width: int, height: int, colour_at) -> bytes:
    """An RGBA PNG whose pixel at x, y is ``colour_at(x, y)`` (r, g, b, a)."""
    rows = b"".join(b"\x00" + b"".join(bytes(colour_at(x, y)) for x in range(width))
                    for y in range(height))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6,
                                                            0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")


def _target(x: int, y: int) -> tuple[int, int, int, int]:
    """A blue disc on white with a red bar across its top: which way up it is
    drawn shows at a glance."""
    if x in (0, 63) or y in (0, 63):
        return (0, 0, 0, 0)
    if 8 <= y < 16 and 8 <= x < 56:
        return (201, 26, 9, 255)
    if (x - 32) ** 2 + (y - 38) ** 2 <= 18 ** 2:
        return (13, 105, 171, 255)
    return (255, 255, 255, 255)


def _corner(x: int, y: int) -> tuple[int, int, int, int]:
    """A green square with a yellow corner at its top left."""
    if x in (0, 31) or y in (0, 31):
        return (0, 0, 0, 0)
    if x < 14 and y < 14:
        return (242, 205, 55, 255)
    return (75, 159, 74, 255)


def _stripes(x: int, y: int) -> tuple[int, int, int, int]:
    """Black and orange stripes across, a sign's hazard band."""
    return (27, 42, 52, 255) if (x // 8) % 2 == 0 else (254, 138, 24, 255)


# The parts whole_2025.io's model uses that only the file has.
NEW_PRINT = "3068pb9101"        # a print BrickLink has and LDraw has not: bl_ in model.ldr
NEWER_LDRAW = "3070bpr9104"     # a part newer than the app's library, LDraw's number...
NEWER_BRICKLINK = "3070bpb9104"  # ...and BrickLink's, which model2.ldr carries it by
NEWER_SAME = "65999"            # one whose number is the same in both
WHOLE_DESIGNED = "m5e6f7a8_2025410_120000"   # Part Designer's: a 1 x 2 tile with a decal
TARGET_PICTURE = _drawing(64, 64, _target)
CORNER_PICTURE = _drawing(32, 32, _corner)
STRIPES_PICTURE = _drawing(64, 32, _stripes)


def _brick(half: float, height: float, top: int, rest: int) -> list[str]:
    """A brick flattened, its top (at y 0) in ``top`` and the rest in ``rest``."""
    x = z = half

    def q(colour: int, *corners: tuple[float, float, float]) -> str:
        return "4 %d %s" % (colour, " ".join("%.3f %.3f %.3f" % c for c in corners))

    return [q(top, (-x, 0, z), (-x, 0, -z), (x, 0, -z), (x, 0, z)),
            q(rest, (-x, 0, -z), (-x, height, -z), (x, height, -z), (x, 0, -z)),
            q(rest, (x, 0, z), (x, height, z), (-x, height, z), (-x, 0, z)),
            q(rest, (-x, 0, z), (-x, height, z), (-x, height, -z), (-x, 0, -z)),
            q(rest, (x, 0, -z), (x, height, -z), (x, height, z), (x, 0, z)),
            q(rest, (-x, height, -z), (-x, height, z), (x, height, z), (x, height, -z))]


def make_whole() -> None:
    """whole_2025.io: a Studio 2.25 file whose every part the file itself
    carries where the library has not got it. Six parts: 3001 and, in a
    sub-model, 3068b, which the library has; bl_3068pb9101, a print only
    BrickLink has; a Part Designer tile with a decal (CustomParts/); and, in
    the sub-model, two parts newer than the library, which model.ldr names by
    LDraw's numbers: 3070bpr9104, which model2.ldr carries as BrickLink's
    3070bpb9104, and 65999, the same in both. model2.ldr's own colours are
    BrickLink's, and they differ from LDraw's: 3070bpb9104's underside is
    BrickLink's black (11, LDraw's light turquoise) and 65999's top
    BrickLink's red (5, LDraw's dark pink)."""
    import base64
    turn = " ".join("%f" % v for v in (1, 0, 0, 0, 1, 0, 0, 0, 1))

    def line(colour: int, x: float, y: float, name: str) -> str:
        return "1 %d %f %f 0.000000 %s %s" % (colour, x, y, turn, name)

    model = ["0 FILE whole_2025.io"] + _header("Untitled Model", "whole_2025", 6) + [
        line(4, -80, -24, "3001.dat"),
        line(15, -20, -8, "bl_%s.dat" % NEW_PRINT),
        "0 STEP",
        line(14, 20, -8, "%s.dat" % WHOLE_DESIGNED),
        line(16, 0, 0, "submodel group 1"),
        "0 STEP", "0 NOFILE",
        "0 FILE SubModel Group 1"] + _header("SubModel Group 1", "SubModel Group 1", 3) + [
        line(71, 60, -8, "%s.dat" % NEWER_LDRAW),
        line(0, 100, -8, "3068b.dat"),
        "0 STEP",
        line(1, 140, -24, "%s.dat" % NEWER_SAME),
        "0 STEP", "0 NOFILE"]
    newer = _tile(10, 10, -1, True)
    # Its underside, the last two faces, in BrickLink's black.
    newer[-2:] = [face.replace("3 -1 ", "3 11 ", 1) for face in newer[-2:]]
    model2 = ["0 FILE whole_2025.io"] + _header("Untitled Model", "whole_2025", 6) + [
        line(5, -80, -24, "3001.dat"),
        line(1, -20, -8, "%s.dat" % NEW_PRINT),
        line(3, 20, -8, "%s.dat" % WHOLE_DESIGNED),
        line(-1, 0, 0, "submodel group 1"),
        "0 NOFILE",
        # The sub-model's lines in another order than model.ldr's: a part is
        # matched by where it is, not by which line it is.
        "0 FILE SubModel Group 1"] + _header("SubModel Group 1", "SubModel Group 1", 3) + [
        line(11, 100, -8, "3068.dat"),
        line(7, 140, -24, "%s.dat" % NEWER_SAME),
        line(86, 60, -8, "%s.dat" % NEWER_BRICKLINK),
        "0 NOFILE",
        "0 FILE %s.dat" % NEW_PRINT,
        "0 Tile 2 x 2 with Blue Target and Red Bar Pattern",
        "0 Name:  %s" % NEW_PRINT, "0 Author:  ", "0 BL_Item_No %s" % NEW_PRINT,
        "0 PE_TEX_INFO " + base64.b64encode(TARGET_PICTURE).decode()] + _tile(20, 20, -1, True) + [
        "0 NOFILE",
        "0 FILE %s.dat" % NEWER_BRICKLINK,
        "0 Tile 1 x 1 with Green Square Pattern",
        "0 Name:  %s" % NEWER_BRICKLINK, "0 Author:  ", "0 BL_Item_No %s" % NEWER_BRICKLINK,
        "0 PE_TEX_INFO " + base64.b64encode(CORNER_PICTURE).decode()] + newer + [
        "0 NOFILE",
        "0 FILE %s.dat" % NEWER_SAME,
        "0 Brick 1 x 1 with Red Top",
        "0 Name:  %s" % NEWER_SAME, "0 Author:  "] + _brick(10, 24, 5, -1) + [
        "0 NOFILE",
        "0 FILE 3001.dat", "0 Brick  2 x  4", "0 Name: 3001.dat"] + _tile(40, 20, -1, False) + [
        "0 NOFILE",
        "0 FILE 3068.dat", "0 Tile 2 x 2", "0 Name: 3068.dat"] + _tile(20, 20, -1, False) + [
        "0 NOFILE"]
    # Part Designer's file: its decal cast by a box at the tile's top, x and z
    # mirrored as Part Designer's are (see make_decor).
    box = "0.0 -0.5 0.0 -40.0 0.0 0.0 0.0 -2.0 0.0 0.0 0.0 -20.0 20.0 -10.0 -20.0 10.0"
    designed = [
        "0 FILE %s.dat" % WHOLE_DESIGNED,
        "0 Tile 1 x 2 with Hazard Stripes Decal",
        "0 Name:  %s.dat" % WHOLE_DESIGNED, "0 Author:  ",
        "0 BFC CERTIFY CCW",
        "0 PE_TEX_PATH 0",
        "0 PE_TEX_INFO %s %s" % (box, base64.b64encode(STRIPES_PICTURE).decode()),
        "1 16 0 0 0 1 0 0 0 1 0 0 0 1 %s-tile.dat" % WHOLE_DESIGNED,
        "0 NOFILE",
        "0 FILE %s-tile.dat" % WHOLE_DESIGNED,
        "0 BFC CERTIFY CCW"] + _tile(20, 10, 16, False) + ["0 NOFILE"]
    members = [
        ("model.ldr", _studio_text(model)),
        ("model2.ldr", _studio_text(model2)),
        ("thumbnail.png", _png()),
        ("errorPartList.err", b"[]"),
        (".info", json.dumps({"version": "2.25.2_1", "total_parts": 6, "parts_db_version": 151},
                             separators=(",", ":")).encode()),
        ("CustomParts/%s.dat" % WHOLE_DESIGNED, _studio_text(designed)),
    ]
    with zipfile.ZipFile(os.path.join(HERE, "whole_2025.io"), "w", zipfile.ZIP_DEFLATED) as out:
        for name, data in members:
            out.writestr(zipfile.ZipInfo(name, WHEN), data, zipfile.ZIP_DEFLATED)


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["decor"]:
        make_decor()
        print("wrote decor_2025.io in", HERE)
        sys.exit(0)
    if sys.argv[1:] == ["whole"]:
        make_whole()
        print("wrote whole_2025.io in", HERE)
        sys.exit(0)
    make_2025()
    make_2021()
    make_aes()
    make_gatehouse()
    make_decor()
    make_whole()
    print("wrote bay_2025.io, bay_2021.io, bay_aes.io, gatehouse_2025.io, decor_2025.io and "
          "whole_2025.io in", HERE)
