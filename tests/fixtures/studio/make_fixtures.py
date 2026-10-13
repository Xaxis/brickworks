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


if __name__ == "__main__":
    make_2025()
    make_2021()
    make_aes()
    print("wrote bay_2025.io, bay_2021.io and bay_aes.io in", HERE)
