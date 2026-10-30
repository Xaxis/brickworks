"""One mark, one file: web/icon.svg.

The site's header and footer show it (.chip in web/site.css), and
tools/web/make_icons.mjs draws every picture of it from it: the favicons,
the app's icon and its boot splash (tests/test_boot_splash.py). The app
cannot read web/ (its .gdignore), so its menu bar's mark (ModelBar.mark,
which opens the app's menu) draws a copy, assets/ui/mark.svg, that the same
script writes. A copy changed by hand, or a mark changed without the copy,
would show two marks.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AGAIN = "node tools/web/make_icons.mjs"


def test_the_apps_mark_is_the_sites() -> None:
    site = (ROOT / "web" / "icon.svg").read_bytes()
    app = (ROOT / "assets" / "ui" / "mark.svg").read_bytes()
    assert app == site, f"assets/ui/mark.svg is not web/icon.svg: write it again with\n  {AGAIN}"


def test_the_app_draws_it_from_source() -> None:
    """Kept as SVG, drawn at the screen's density (Icons), as the tools are."""
    kept = (ROOT / "assets" / "ui" / "mark.svg.import").read_text(encoding="utf-8")
    assert 'importer="keep"' in kept
    bar = (ROOT / "src" / "ui" / "model_bar.gd").read_text(encoding="utf-8")
    assert 'const MARK := "res://assets/ui/mark.svg"' in bar


def test_the_sites_chip_is_the_mark() -> None:
    css = (ROOT / "web" / "site.css").read_text(encoding="utf-8")
    chip = re.search(r"^\.chip \{([^}]*)\}", css, re.M)
    assert chip, "web/site.css has no .chip"
    assert "url(/icon.svg)" in chip.group(1)
