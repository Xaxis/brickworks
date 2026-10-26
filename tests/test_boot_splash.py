"""The desktop app boots on its own mark, on the app's own face.

Godot draws the boot splash project.godot names while the app loads, and
the engine's logo where it names none: desktop 0.8.0 booted on Godot's
(walk256 DS1, 2026-10-25). The splash is drawn from web/icon.svg by
tools/web/make_icons.mjs, a window's shape with the mark in its middle, so
kept to the window's aspect the mark is a fifth of its height.

The web build's page covers its canvas with a loading wall of its own
(src/boot/shell.html) until the app is up, and is left as it was: the
splash is named for the desktop ("pc") alone. That the package carries it
is the release smoke's (tools/release.py smoke --window), where Godot says
so when the file named is not there.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

try:
    from PIL import Image
except ImportError:  # pragma: no cover - the suite's Python has it
    Image = None

ROOT = Path(__file__).resolve().parent.parent

needs_pil = pytest.mark.skipif(Image is None, reason="needs Pillow to read the splash")


def application() -> dict[str, str]:
    """project.godot's [application] settings, as written."""
    out: dict[str, str] = {}
    section = ""
    for line in (ROOT / "project.godot").read_text().splitlines():
        line = line.strip()
        if line.startswith("["):
            section = line
        elif section == "[application]" and "=" in line and not line.startswith(";"):
            key, value = line.split("=", 1)
            out[key] = value
    return out


def test_the_desktop_names_a_splash_of_its_own() -> None:
    settings = application()
    image = settings.get("boot_splash/image.pc", "")
    assert image == '"res://assets/splash.png"'
    assert (ROOT / "assets" / "splash.png").is_file()
    # Kept to the window's shape: the mark in its middle, never cut off.
    assert settings.get("boot_splash/stretch_mode.pc") == "1"


def test_on_the_apps_own_face() -> None:
    """The dark face every panel of the app has (Look.FACE, opaque)."""
    colour = application().get("boot_splash/bg_color.pc", "")
    found = re.fullmatch(r"Color\(([^)]*)\)", colour)
    assert found, colour
    assert [float(n) for n in found.group(1).split(",")] == [0.1, 0.11, 0.13, 1.0]


def test_the_web_is_left_as_it_was() -> None:
    """Its page's loading wall is what a person sees; its canvas keeps Godot's."""
    settings = application()
    assert not any(key.startswith("boot_splash/") and "." not in key for key in settings)


@needs_pil
def test_the_splash_is_the_mark_in_the_middle() -> None:
    assert Image is not None
    picture = Image.open(ROOT / "assets" / "splash.png").convert("RGBA")
    width, height = picture.size
    assert (width, height) == (2560, 1440)
    # Clear round it, so it lies on the face it is drawn over.
    for x, y in [(0, 0), (width - 1, height - 1), (width // 4, height // 2),
                 (width // 2, height // 8)]:
        assert picture.getpixel((x, y))[3] == 0, (x, y)
    # The mark's three faces, yellow above, red at the left, blue at the
    # right, at points of web/icon.svg's 64 x 64, whose square is a fifth
    # of the height.
    scale = height / 5 / 64

    def at(x: float, y: float) -> tuple[int, int]:
        return (round(width / 2 + (x - 32) * scale), round(height / 2 + (y - 32) * scale))

    def near(point: tuple[int, int], wanted: str) -> bool:
        pixel = picture.getpixel(point)
        rgb = tuple(int(wanted[i:i + 2], 16) for i in (0, 2, 4))
        return pixel[3] == 255 and all(abs(a - b) <= 6 for a, b in zip(pixel, rgb))

    assert near(at(32, 10), "f2cd37")
    assert near(at(14, 35), "d0332f")
    assert near(at(50, 35), "2a6fc4")
    # Nothing of it outside the square.
    assert picture.getpixel(at(32, 1))[3] == 0
    assert picture.getpixel(at(4, 32))[3] == 0
    assert picture.getpixel(at(60, 32))[3] == 0
