"""The app's header is the site's: the same height, ground, mark and controls.

src/ui/app_header.gd draws the header every mode of the app has (appchrome,
2026-11-23: the owner found Build it's view with no Brickworks mark in its
header). It copies web/site.css's numbers, since the app reads nothing under
web/; this fails when one side changes and the other does not.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = (ROOT / "src/ui/app_header.gd").read_text()
CSS = (ROOT / "web/site.css").read_text()


def _const(name: str) -> float:
    found = re.search(rf"^const {name} := ([0-9.]+)", GD, re.M)
    assert found, f"app_header.gd has no const {name}"
    return float(found.group(1))


def _css_px(token: str) -> float:
    found = re.search(rf"{re.escape(token)}:\s*([0-9.]+)px", CSS)
    assert found, f"site.css has no {token}"
    return float(found.group(1))


def _css_colour(token: str) -> tuple[float, float, float]:
    found = re.search(rf"{re.escape(token)}:\s*#([0-9a-fA-F]{{6}})", CSS)
    assert found, f"site.css has no {token}"
    hex_ = found.group(1)
    return tuple(int(hex_[n:n + 2], 16) / 255.0 for n in (0, 2, 4))  # type: ignore[return-value]


def test_height_is_the_sites_header() -> None:
    assert _const("TALL") + _const("LINE") == _css_px("--head-h")
    assert re.search(r"\.bar \{[^}]*min-height: 60px", CSS)
    assert _const("TALL") == 60.0


def test_controls_and_mark_are_the_sites() -> None:
    assert _const("TARGET") == _css_px("--control-h")
    chip = re.search(r"\.chip \{[^}]*width: ([0-9]+)px", CSS)
    assert chip and _const("MARK") == float(chip.group(1))


def test_ground_is_the_sites_bg() -> None:
    found = re.search(r"^const GROUND := Color\(([0-9.]+), ([0-9.]+), ([0-9.]+)", GD, re.M)
    assert found
    ground = tuple(float(v) for v in found.groups())
    bg = _css_colour("--bg")
    assert all(abs(a - b) < 0.003 for a, b in zip(ground, bg)), (ground, bg)


def test_every_mode_keeps_it() -> None:
    """The viewer no longer hides the menu bar, and the full-window modes sit under it."""
    main = (ROOT / "src/main.gd").read_text()
    hidden = re.search(r"for hidden: Control in \[(.*?)\]:", main, re.S)
    assert hidden and "_bar," not in hidden.group(1).replace("_bar_", "")
    assert "_under_header(_build_mode)" in main
    assert "_under_header(editor)" in main
    assert "_bar.set_plain(true)" in main
