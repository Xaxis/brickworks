"""Every page is one width: the header's, the gallery's (web/site.css .wrap).

The owner, 2026-11-23: Talk "does not have the same page width as the other
pages". A page of words had kept a narrower width (1,140 px) than a page of
pictures and the header (1,600 px), so at 1280 its edges sat 54 px inside
the header's; plans and beta set their own 980 px. tools/web/design_flow.mjs
measures each page it visits; this holds what it cannot visit (Talk's and
every server-made page) and every page to come: no stylesheet, page or
server-made page sets a page's width but site.css's .wrap.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# A page's width, as site.css writes it: the window less its gutters, up to
# a width.
OWN_WIDTH = re.compile(r"width:\s*min\(\s*100%\s*-\s*\d+px")


def sources() -> list[Path]:
    web = [p for p in (ROOT / "web").glob("*") if p.suffix in {".css", ".html", ".js"}]
    return sorted(web + list((ROOT / "api").glob("*.js")))


def test_only_site_css_wrap_sets_a_page_width() -> None:
    found = []
    for path in sources():
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if not OWN_WIDTH.search(line):
                continue
            if path.name == "site.css" and line.lstrip().startswith(".wrap {"):
                continue
            found.append(f"{path.relative_to(ROOT)}:{n}: {line.strip()[:120]}")
    assert not found, "a page width other than site.css's .wrap:\n" + "\n".join(found)


def test_the_one_width_is_the_widest() -> None:
    css = (ROOT / "web/site.css").read_text(encoding="utf-8")
    rule = re.search(r"^\.wrap \{([^}]*)\}", css, re.M)
    assert rule and "var(--page-wide)" in rule.group(1), "site.css .wrap is not the page's one width (--page-wide)"
    assert "var(--page)" not in css and not re.search(r"--page:\s", css), "a second, narrower page width is back in site.css"


def test_talk_pages_use_the_one_container() -> None:
    talk = (ROOT / "api/_talk.js").read_text(encoding="utf-8")
    pages = re.findall(r'<div class="(wrap[^"]*talk-page[^"]*)"', talk)
    assert pages, "api/_talk.js makes no .talk-page"
    assert all(re.match(r"wrap( |$)", cls) for cls in pages), pages
