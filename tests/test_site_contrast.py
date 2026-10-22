"""The site's colours, measured: every word readable and every pressed toggle seen, in both themes.

web/site.css has a dark set of colour tokens and a light one (chosen, or the
system's), written twice because CSS cannot say "this attribute or this
media query" in one rule. In light, the yellow accent was the only mark of
a pressed toggle and stood 1.33:1 on the page (docs/SOCIAL.md, section 3);
WCAG asks 4.5:1 for words and 3:1 for what shows a control's state.

    python3 tests/test_site_contrast.py     the table, each pair's ratio
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSS = (ROOT / "web/site.css").read_text(encoding="utf-8")

# What the site's words are drawn in, and what they sit on: the page, the
# footer and every field (bg-soft), a card, a dialog or a menu (panel), and
# a row under the pointer (panel-hi).
TEXT = ["--ink", "--ink-soft", "--ink-faint", "--bad", "--green"]
SURFACES = ["--bg", "--bg-soft", "--panel", "--panel-hi", "--field"]
# What marks a state without words: a pressed toggle's edge, the keyboard's
# focus ring.
EDGES = ["--accent-edge", "--focus"]


def block(selector: str) -> dict[str, str]:
    """The custom properties declared in the first rule for [selector]."""
    found = re.search(re.escape(selector) + r"\s*\{([^}]*)\}", CSS)
    assert found, f"web/site.css has no {selector} rule"
    return dict(re.findall(r"(--[\w-]+):\s*([^;]+);", found.group(1)))


def themes() -> dict[str, dict[str, str]]:
    dark = block(":root")
    chosen = block(':root[data-theme="light"]')
    system = block(":root:not([data-theme])")
    assert chosen == system, "the light set chosen and the system's light set differ in web/site.css"
    return {"dark": dark, "light": {**dark, **chosen}}


def colour(tokens: dict[str, str], name: str) -> str:
    value = tokens[name].strip()
    while value.startswith("var("):
        value = tokens[value[4:-1].strip()].strip()
    assert re.fullmatch(r"#[0-9a-fA-F]{6}", value), f"{name} is {value}, not a colour this can measure"
    return value


def luminance(hex_colour: str) -> float:
    def channel(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def ratio(a: str, b: str) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def pairs() -> list[tuple[str, str, str, float, float]]:
    """(theme, foreground, background, ratio, the least it may be)."""
    measured = []
    for theme, tokens in themes().items():
        for ink in TEXT:
            for surface in SURFACES:
                measured.append((theme, ink, surface, ratio(colour(tokens, ink), colour(tokens, surface)), 4.5))
        measured.append((theme, "--on-accent", "--accent",
                         ratio(colour(tokens, "--on-accent"), colour(tokens, "--accent")), 4.5))
        for edge in EDGES:
            for surface in SURFACES:
                measured.append((theme, edge, surface, ratio(colour(tokens, edge), colour(tokens, surface)), 3.0))
    return measured


def test_every_word_and_edge_is_seen_in_both_themes() -> None:
    short = [f"{theme}: {fg} on {bg} is {r:.2f}:1, under {least}:1"
             for theme, fg, bg, r, least in pairs() if r < least]
    assert not short, "\n".join(short)


def test_the_browser_bar_is_the_page_in_each_theme() -> None:
    sets = themes()
    page = {theme: colour(tokens, "--bg").lower() for theme, tokens in sets.items()}
    shell = (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    for theme in ("dark", "light"):
        said = re.search(rf'<meta name="theme-color" content="(#\w+)" media="\(prefers-color-scheme: {theme}\)">', shell)
        assert said and said.group(1).lower() == page[theme], (theme, said and said.group(1), page[theme])
    script = (ROOT / "web/theme.js").read_text(encoding="utf-8")
    bar = dict(re.findall(r'(dark|light): "(#\w+)"', script))
    assert {k: v.lower() for k, v in bar.items()} == page, (bar, page)


if __name__ == "__main__":
    for theme, fg, bg, r, least in pairs():
        print(f"{theme:5} {fg:14} on {bg:10} {r:5.2f}:1  {'ok' if r >= least else f'UNDER {least}'}")
    sys.exit(0 if all(r >= least for *_, r, least in pairs()) else 1)
