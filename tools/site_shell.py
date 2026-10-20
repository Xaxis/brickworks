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
have no site header and are left alone.
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
# Each page's own address, where it is one of the header's links. The
# landing page marks the mark.
OWN = {"index.html": "/", "gallery.html": "/gallery", "download.html": "/download",
       "profile.html": "/profile"}


def shell() -> tuple[str, str]:
    text = SHELL.read_text(encoding="utf-8")
    header, footer = HEADER.search(text), FOOTER.search(text)
    if not header or not footer:
        raise SystemExit("site_shell: web/_shell.html has no site-head header or site-foot footer")
    return header.group(0), footer.group(0)


def marked(header: str, page: str) -> str:
    """The header as [page] shows it: its own link marked as the page."""
    own = OWN.get(page)
    if not own:
        return header
    if own == "/":
        return header.replace('<a class="mark" href="/">', '<a class="mark" href="/" aria-current="page">', 1)
    return re.sub(rf'(<a href="{re.escape(own)}")', r'\1 aria-current="page"', header)


def pages() -> list[Path]:
    return [path for path in sorted(WEB.glob("*.html"))
            if not path.name.startswith("_") and HEADER.search(path.read_text(encoding="utf-8"))]


def stamped(path: Path, header: str, footer: str) -> str:
    text = path.read_text(encoding="utf-8")
    text = HEADER.sub(lambda _: marked(header, path.name), text, count=1)
    if not FOOTER.search(text):
        raise SystemExit(f"site_shell: {path.name} has a site header and no site-foot footer")
    return FOOTER.sub(lambda _: footer, text, count=1)


def main(argv: list[str]) -> int:
    check = "--check" in argv
    header, footer = shell()
    differ = []
    for path in pages():
        want = stamped(path, header, footer)
        if want == path.read_text(encoding="utf-8"):
            continue
        differ.append(path.name)
        if not check:
            path.write_text(want, encoding="utf-8")
    if check:
        if differ:
            print("site_shell: these pages' header or footer is not web/_shell.html's "
                  f"(tools/site_shell.py writes it): {', '.join(differ)}")
            return 1
        print(f"site_shell: {len(pages())} pages, one header and one footer")
        return 0
    print(f"site_shell: wrote {len(differ)} of {len(pages())} pages" + (f": {', '.join(differ)}" if differ else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
