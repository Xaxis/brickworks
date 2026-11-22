#!/usr/bin/env python3
"""Put the site's one header and footer (web/_shell.html) into every page.

    tools/site_shell.py            write them into each page of web/
    tools/site_shell.py --check    say which pages differ, and exit 1 if any do

Every page of brickworks.diy is plain HTML with no build step, so each
carries its own copy of the header and footer. The copies drifted: on
2026-10-20 there were eight different footers and a seven-link nav, and
the owner found the site did not read as one. Now there is one, written
in web/_shell.html, and this puts it into every page that has a
`<header class="site-head">`, with aria-current="page" on the link to the
page itself. tests/test_site_shell.py runs the check.

The app (/app), the owner's admin page and the connector's sign-in
(authorize.html, which Claude opens and which has its own stricter page)
have no site header and keep their own.

Every page that uses the site's stylesheet, those two as well, also
gets the shell's <head> lines just before it: the browser bar's colour
in each theme and /theme.js, which sets the theme the person chose
before the page is drawn (2026-10-22). A page's old single theme-color
line is replaced by them.
And what installs the site (homescreen, 2026-11-22): the manifest, and
the icon and name an iPhone's Add to Home Screen takes; a page's own
copies of the first two, from before, are taken out.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
SHELL = WEB / "_shell.html"

HEADER = re.compile(r'<header class="site-head">.*?</header>', re.S)
FOOTER = re.compile(r'<footer class="site-foot">.*?</footer>', re.S)
HEAD = re.compile(r'(?:<meta name="theme-color"[^>]*>\n)+<script src="/theme\.js"></script>'
                  r'(?:\n<link rel="manifest"[^>]*>)?(?:\n<link rel="apple-touch-icon"[^>]*>)?'
                  r'(?:\n<meta name="apple-mobile-web-app-title"[^>]*>)?')
OLD_BAR = re.compile(r'<meta name="theme-color"[^>]*>\n')
# A page's own manifest and home screen icon, from before the shell's head
# carried them (homescreen, 2026-11-22): sixteen pages had them, thirteen not.
OLD_INSTALL = re.compile(r'<link rel="(?:manifest|apple-touch-icon)"[^>]*>\n')
STYLESHEET = '<link rel="stylesheet" href="/site.css">'
# Each page's own address, where it is one of the header's links (or
# Menu's: Download is there since site356). The landing page marks the
# mark; your settings are part of your account; the gallery's tabs at
# their own addresses (tools/browse_pages.py) are the gallery.
OWN = {"index.html": "/", "gallery.html": "/gallery", "builds.html": "/gallery", "library.html": "/gallery",
       "collections.html": "/gallery", "download.html": "/download", "profile.html": "/profile",
       "settings.html": "/profile", "plans.html": "/plans", "share-model.html": "/gallery"}


def shell() -> tuple[str, str, str]:
    text = SHELL.read_text(encoding="utf-8")
    head, header, footer = HEAD.search(text), HEADER.search(text), FOOTER.search(text)
    if not head or not header or not footer:
        raise SystemExit("site_shell: web/_shell.html has no theme lines, site-head header or site-foot footer")
    return head.group(0), header.group(0), footer.group(0)


def marked(header: str, page: str) -> str:
    """The header as [page] shows it: its own link marked as the page."""
    own = OWN.get(page)
    if not own:
        return header
    if own == "/":
        return header.replace('<a class="mark" href="/">', '<a class="mark" href="/" aria-current="page">', 1)
    # The account's Sign in asks for the sign-in on its page (/profile?sign-in,
    # sifix): on /profile it is the page's own link all the same.
    return re.sub(rf'(<a href="{re.escape(own)}(?:\?sign-in)?")', r'\1 aria-current="page"', header)


def pages() -> list[Path]:
    """The pages of the site: each that uses its stylesheet."""
    return [path for path in sorted(WEB.glob("*.html"))
            if not path.name.startswith("_") and STYLESHEET in path.read_text(encoding="utf-8")]


def themed(text: str, head: str) -> str:
    """[text] with the shell's <head> lines, just before the stylesheet."""
    found = HEAD.search(text)
    if found:
        return OLD_INSTALL.sub("", text[:found.start()]) + head + OLD_INSTALL.sub("", text[found.end():])
    return OLD_INSTALL.sub("", OLD_BAR.sub("", text)).replace(STYLESHEET, f"{head}\n{STYLESHEET}", 1)


def stamped(path: Path, head: str, header: str, footer: str) -> str:
    text = themed(path.read_text(encoding="utf-8"), head)
    if not HEADER.search(text):
        return text
    text = HEADER.sub(lambda _: marked(header, path.name), text, count=1)
    if not FOOTER.search(text):
        raise SystemExit(f"site_shell: {path.name} has a site header and no site-foot footer")
    return FOOTER.sub(lambda _: footer, text, count=1)


def main(argv: list[str]) -> int:
    check = "--check" in argv
    head, header, footer = shell()
    differ = []
    for path in pages():
        want = stamped(path, head, header, footer)
        if want == path.read_text(encoding="utf-8"):
            continue
        differ.append(path.name)
        if not check:
            path.write_text(want, encoding="utf-8")
    if check:
        if differ:
            print("site_shell: these pages' theme lines, header or footer are not web/_shell.html's "
                  f"(tools/site_shell.py writes it): {', '.join(differ)}")
            return 1
        print(f"site_shell: {len(pages())} pages, one theme, header and footer")
        return 0
    print(f"site_shell: wrote {len(differ)} of {len(pages())} pages" + (f": {', '.join(differ)}" if differ else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
