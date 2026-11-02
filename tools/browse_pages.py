#!/usr/bin/env python3
"""The gallery's tabs at their own addresses: /library, /builds, /collections.

    tools/browse_pages.py           write web/library.html, web/builds.html and web/collections.html
    tools/browse_pages.py --check   say which differ from what this writes, and exit 1 if any do

The gallery is one page to browse (web/gallery.html, web/gallery.js;
browse, 2026-11-02): Top, New, Following, Builds, Collections and Sets are
its tabs, switched in place. Each tab is at the address its own page had,
so every link anyone kept, every sitemap's line and every search engine's
entry still lands on it: /builds, /collections and /library. A static site
serves a file at each, so each is a copy of web/gallery.html, written here:
the same page, with its own head (its title, its description, its canonical
link and its languages' alternates, its share card's words), the tab it
opens on marked, on <html data-tab> from the first frame, and the search's
words for that tab. Then tools/site_lang.py writes each in German, French
and Spanish (PAGES), as it does the gallery.

tests/test_browse_pages.py runs the check. Change web/gallery.html and run
this, then tools/site_lang.py; never a copy.
"""

from __future__ import annotations

import re
import sys
from collections.abc import Callable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
SITE = "https://brickworks.diy"
GALLERY = WEB / "gallery.html"

# Each copy: its file, its address, its tab (gallery.html's data-tab), its
# head's words, and its search's (each list's own in web/*.js says the same
# once the page has switched to it).
COPIES = {
    "library.html": {
        "path": "/library", "tab": "sets",
        "title": "Sets · Every LEGO® set and its parts, in Brickworks",
        "description": "Every LEGO® set there is, each with its whole parts list drawn by Brickworks: see what you own of it, "
                       "open its parts in Brickworks, and build the ones LDraw's Official Model Repository has in 3D.",
        "card": "Every LEGO® set, in Brickworks",
        "card_said": "Every LEGO® set there is, with its parts list: the ones LDraw has modelled in 3D to turn and build in Brickworks.",
        "label": "Search every set", "placeholder": "Search sets by name, number or theme",
    },
    "builds.html": {
        "path": "/builds", "tab": "builds",
        "title": "Builds · Real models built from the Brickworks gallery",
        "description": "Photos of real builds: models from the Brickworks gallery that people built in bricks, each linked to "
                       "the model it was built from and to its builder.",
        "card": "Builds in the Brickworks gallery",
        "card_said": "Photos of real builds of models from the Brickworks gallery, each linked to its model and its builder.",
        "label": "Search the builds", "placeholder": "Search builds by the model built",
    },
    "collections.html": {
        "path": "/collections", "tab": "collections",
        "title": "Collections — the Brickworks gallery",
        "description": "Collections of models built in Brickworks, made by the people who build them: follow one to see what "
                       "is put in it.",
        "card": "Collections in the Brickworks gallery",
        "card_said": "Collections of models built in Brickworks, made by the people who build them: follow one to see what "
                     "is put in it.",
        "label": "Search the collections", "placeholder": "Search collections by name or builder",
    },
}


def attribute(value: str) -> str:
    return value.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;")


def replaced(text: str, pattern: str, new: str | Callable[[re.Match[str]], str], what: str, count: int = 1) -> str:
    """[text] with [pattern] put as [new] (words, or what a match is to be
    made: a function of it): exactly [count] times, or this stops."""
    out, n = re.subn(pattern, new if callable(new) else lambda _: str(new), text, flags=re.S)
    if n != count:
        raise SystemExit(f"browse_pages: web/gallery.html's {what} was found {n} times, not {count}")
    return out


def copy(name: str, gallery: str) -> str:
    """web/[name] as it is written from [gallery]."""
    one = COPIES[name]
    at = f"{SITE}{one['path']}"
    out = replaced(gallery, r"<!--.*?-->(?=<html)", f"<!--\n  {one['path']}: the gallery (web/gallery.html) on its {one['tab'].capitalize()} "
                   f"tab, written by tools/browse_pages.py\n  from it: change that and run it, never this.\n-->", "opening comment")
    out = replaced(out, r'--><html lang="en">', f'--><html lang="en" data-tab="{one["tab"]}">', "<html>")
    out = replaced(out, r"<title>[^<]*</title>", f"<title>{one['title']}</title>", "<title>")
    out = replaced(out, r'<meta name="description" content="[^"]*">', f'<meta name="description" content="{attribute(one["description"])}">',
                   "description")
    out = replaced(out, r'<link rel="canonical" href="[^"]*">', f'<link rel="canonical" href="{at}">', "canonical link")
    for code in ("en", "de", "fr", "es", "x-default"):
        where = f"{SITE}{'' if code in ('en', 'x-default') else '/' + code}{one['path']}"
        out = replaced(out, rf'<link rel="alternate" hreflang="{code}" href="[^"]*">',
                       f'<link rel="alternate" hreflang="{code}" href="{where}">', f"{code} alternate")
    for prop, said in (("og:title", one["card"]), ("og:description", one["card_said"])):
        out = replaced(out, rf'<meta property="{prop}" content="[^"]*">', f'<meta property="{prop}" content="{attribute(said)}">', prop)
    out = replaced(out, r'<meta property="og:url" content="[^"]*">', f'<meta property="og:url" content="{at}">', "og:url")
    for prop, said in (("twitter:title", one["card"]), ("twitter:description", one["card_said"])):
        out = replaced(out, rf'<meta name="{prop}" content="[^"]*">', f'<meta name="{prop}" content="{attribute(said)}">', prop)
    out = replaced(out, r'(<form class="finder" id="finder" role="search" action=")/gallery(")',
                   lambda found: f"{found.group(1)}{one['path']}{found.group(2)}", "search form")
    out = replaced(out, r'<span class="visually-hidden" id="q-said">[^<]*</span>',
                   f'<span class="visually-hidden" id="q-said">{one["label"]}</span>', "search's name")
    out = replaced(out, r'placeholder="Search models, builders, tags"', f'placeholder="{attribute(one["placeholder"])}"', "search's placeholder")
    # The tab it opens on marked, Top no longer.
    out = replaced(out, r'(<a href="/gallery" data-tab="top") aria-current="page"', lambda found: found.group(1), "Top's mark")
    out = replaced(out, rf'(<a href="[^"]*" data-tab="{one["tab"]}")', lambda found: f'{found.group(1)} aria-current="page"',
                   f"{one['tab']} tab")
    return out


def written() -> dict[Path, str]:
    gallery = GALLERY.read_text(encoding="utf-8")
    return {WEB / name: copy(name, gallery) for name in COPIES}


def main(argv: list[str]) -> int:
    check = "--check" in argv
    stale = []
    for path, text in written().items():
        if path.exists() and path.read_text(encoding="utf-8") == text:
            continue
        if check:
            stale.append(path.relative_to(ROOT))
            continue
        path.write_text(text, encoding="utf-8")
        print(f"browse_pages: wrote {path.relative_to(ROOT)}")
    for path in stale:
        print(f"browse_pages: {path} is not what tools/browse_pages.py writes from web/gallery.html: run it")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
