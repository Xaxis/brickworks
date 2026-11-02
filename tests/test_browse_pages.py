"""The gallery is one page to browse, its tabs at the addresses their own
pages had (browse, 2026-11-02): /library, /builds and /collections are
copies of web/gallery.html that tools/browse_pages.py writes, each with its
own head and the tab it opens on. This fails when one was edited by hand,
or the gallery was changed and the copies not written again."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_each_tabs_page_is_what_browse_pages_writes() -> None:
    said = subprocess.run([sys.executable, str(ROOT / "tools/browse_pages.py"), "--check"], capture_output=True, text=True)
    assert said.returncode == 0, said.stdout + said.stderr


def test_each_opens_on_its_tab_with_its_own_head() -> None:
    gallery = (ROOT / "web/gallery.html").read_text(encoding="utf-8")
    tabs = re.findall(r'<a href="([^"]+)" data-tab="([a-z]+)"', gallery[gallery.index('id="tabs"'):])
    assert [tab for _, tab in tabs[:6]] == ["top", "new", "following", "builds", "collections", "sets"]
    for name, path, tab in (("library.html", "/library", "sets"), ("builds.html", "/builds", "builds"),
                            ("collections.html", "/collections", "collections")):
        page = (ROOT / "web" / name).read_text(encoding="utf-8")
        assert f'<html lang="en" data-tab="{tab}">' in page, name
        assert f'<link rel="canonical" href="https://brickworks.diy{path}">' in page, name
        for code in ("de", "fr", "es"):
            assert f'<link rel="alternate" hreflang="{code}" href="https://brickworks.diy/{code}{path}">' in page, name
        assert f'<form class="finder" id="finder" role="search" action="{path}"' in page, name
        # Its tab marked, and only it.
        marked = re.findall(r'<a href="[^"]+" data-tab="([a-z]+)" aria-current="page"', page)
        assert marked == [tab], (name, marked)
        # The gallery's filters, grid and pager under its tabs: one page.
        assert page[page.index('id="toolbar"'):page.index("</main>")] \
            == gallery[gallery.index('id="toolbar"'):gallery.index("</main>")], name
