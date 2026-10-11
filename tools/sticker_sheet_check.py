#!/usr/bin/env python3
"""Measure a sticker sheet PDF the way a printer would size it.

    tools/sticker_sheet_check.py SHEET.pdf [--expect 31.4x15.4] [--dpi 600]

A sheet from the app (src/prints/sticker_sheet.gd) draws each sticker as an
image scaled into its size by a `cm` matrix and a cut line round it as a
`re S` rectangle, in points. This reads the page size with pdfinfo, the
rectangles from the page's content, and then renders each sticker's corner
of the page with pdftoppm at --dpi and measures its blue cut line in pixels
along the lines through its middle — so the size is checked twice, once as
the document says it and once as a renderer draws it. Prints one line per
sticker in millimetres and, with --expect WxH, exits 1 unless the first
sticker is within 0.1 mm of it both ways. Needs poppler-utils.
"""
from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

POINT_MM = 25.4 / 72.0


def page_size(pdf: Path) -> tuple[float, float]:
    out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True, check=True).stdout
    found = re.search(r"Page size:\s+([\d.]+) x ([\d.]+) pts", out)
    if not found:
        raise SystemExit("pdfinfo gave no page size")
    return float(found.group(1)), float(found.group(2))


def content(pdf: Path) -> str:
    """The page's content streams, inflated where they are deflated."""
    data = pdf.read_bytes()
    text = []
    for match in re.finditer(rb"<<([^>]*?)>>\s*stream\r?\n", data):
        head = match.group(1)
        start = match.end()
        end = data.index(b"endstream", start)
        body = data[start:end].rstrip(b"\r\n")
        if b"/Subtype /Image" in head:
            continue
        if b"/FlateDecode" in head:
            body = zlib.decompress(body)
        text.append(body.decode("latin-1"))
    return "\n".join(text)


def cut_lines(stream: str) -> list[tuple[float, float, float, float]]:
    """Every rectangle stroked in the cut line's blue: x, y, w, h in points."""
    rects = []
    for match in re.finditer(
            r"0(?:\.0)? 0\.55 0\.95 RG [\d.]+ w ([\d.-]+) ([\d.-]+) ([\d.-]+) ([\d.-]+) re S", stream):
        rects.append(tuple(float(v) for v in match.groups()))
    return rects


def render(pdf: Path, dpi: int, x: int, y: int, w: int, h: int) -> tuple[int, int, bytes]:
    """A piece of the page as raw RGB, from pdftoppm's PPM."""
    with tempfile.TemporaryDirectory() as scratch:
        stem = Path(scratch) / "piece"
        subprocess.run(["pdftoppm", "-r", str(dpi), "-x", str(x), "-y", str(y), "-W", str(w),
                        "-H", str(h), "-singlefile", str(pdf), str(stem)], check=True)
        raw = (stem.with_suffix(".ppm")).read_bytes()
    header = raw.split(b"\n", 3)
    width, height = (int(v) for v in header[1].split())
    return width, height, header[3]


def is_cut(pixels: bytes, width: int, x: int, y: int) -> bool:
    o = (y * width + x) * 3
    r, g, b = pixels[o], pixels[o + 1], pixels[o + 2]
    return b > 190 and r < 90 and 90 < g < 190


def measured(pdf: Path, rect: tuple[float, float, float, float], page_h: float, dpi: int) -> tuple[float, float]:
    """The cut line's outer extent across and down the middle, less the line's
    own width (it is stroked on the sticker's edge, half outside), in mm."""
    x, y, w, h = rect
    per_point = dpi / 72.0
    margin = 20
    left = int(x * per_point) - margin
    top = int((page_h - (y + h)) * per_point) - margin
    width = int(w * per_point) + 2 * margin
    height = int(h * per_point) + 2 * margin
    px, py, pixels = render(pdf, dpi, left, top, width, height)
    row = py // 2
    column = px // 2
    across = [i for i in range(px) if is_cut(pixels, px, i, row)]
    down = [j for j in range(py) if is_cut(pixels, px, column, j)]
    if not across or not down:
        return 0.0, 0.0
    line = 0.3 * per_point
    mm = 25.4 / dpi
    return ((across[-1] - across[0] + 1 - line) * mm, (down[-1] - down[0] + 1 - line) * mm)


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    pdf = Path(args[0])
    expect = None
    dpi = 600
    for n, arg in enumerate(args):
        if arg == "--expect":
            w, h = args[n + 1].split("x")
            expect = (float(w), float(h))
        if arg == "--dpi":
            dpi = int(args[n + 1])
    page_w, page_h = page_size(pdf)
    print(f"page {page_w * POINT_MM:.2f} x {page_h * POINT_MM:.2f} mm ({page_w} x {page_h} pt)")
    rects = cut_lines(content(pdf))
    if not rects:
        print("no cut lines found")
        return 1
    failed = 0
    for n, rect in enumerate(rects):
        said = (rect[2] * POINT_MM, rect[3] * POINT_MM)
        drawn = measured(pdf, rect, page_h, dpi)
        print(f"sticker {n + 1}: the PDF says {said[0]:.2f} x {said[1]:.2f} mm; "
              f"rendered at {dpi} dpi its cut line is {drawn[0]:.2f} x {drawn[1]:.2f} mm")
        if n == 0 and expect is not None:
            for got in (said, drawn):
                if abs(got[0] - expect[0]) > 0.1 or abs(got[1] - expect[1]) > 0.1:
                    failed = 1
    if expect is not None:
        print("within 0.1 mm of %.2f x %.2f" % expect if not failed else
              "NOT within 0.1 mm of %.2f x %.2f" % expect)
    return failed


if __name__ == "__main__":
    sys.exit(main())
