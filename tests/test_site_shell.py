"""Every page of the site has the one header and footer (web/_shell.html).

The copies in each page drifted apart (eight footers and a seven-link nav,
2026-10-20); tools/site_shell.py writes them, and this fails when a page
was edited by hand instead.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_every_page_has_the_one_header_and_footer() -> None:
    said = subprocess.run([sys.executable, str(ROOT / "tools/site_shell.py"), "--check"],
                          capture_output=True, text=True)
    assert said.returncode == 0, said.stdout + said.stderr


def test_the_header_has_four_things_at_most() -> None:
    shell = (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    nav = re.search(r'<nav class="nav" aria-label="Main">(.*?)</nav>', shell, re.S)
    assert nav is not None
    assert len(re.findall(r"<a ", nav.group(1))) <= 4


def test_the_account_is_last_after_open_the_app() -> None:
    # The owner, 2026-10-23: "the user account circle obviously is the item
    # that goes to the far right with the 'Open the app' button to the left
    # of it". web/follow.js puts the avatar where Sign in is.
    shell = (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    nav = re.search(r'<nav class="nav" aria-label="Main">(.*?)</nav>', shell, re.S)
    assert nav is not None
    links = re.findall(r"<a [^>]*>[^<]*</a>", nav.group(1))
    assert len(links) >= 2 and 'class="cta"' in links[-2] and "data-account" in links[-1], links


def test_each_page_marks_only_itself() -> None:
    for name, own in {"gallery.html": "/gallery", "download.html": "/download", "profile.html": "/profile"}.items():
        header = re.search(r'<header class="site-head">.*?</header>',
                           (ROOT / "web" / name).read_text(encoding="utf-8"), re.S).group(0)
        current = re.findall(r'<a [^>]*href="([^"]+)"[^>]*aria-current="page"', header)
        assert current and set(current) == {own}, (name, current)
