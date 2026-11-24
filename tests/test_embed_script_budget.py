"""An embed's card stays light: its scripts under 24 KB as the site ships them.

tools/web/embed_flow.mjs holds the scripts an embed's frame runs before View
in 3D (web/theme.js from the site's head, web/embed.js, and the web/start3d.js
it imports) under 24 KB, comments and all, since the site ships them as
written. theme.js is every page's head script, so each page-wide feature adds
to an embed in somebody else's blog: it went past twice in two days
(ce8beb641; the nightly of 2026-11-24 at 26.2 KB, after the beta strip, the
languages and checkdrift), each time found only by a browser check that a
release no longer runs by default. This holds it at the commit.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUDGET = 24 * 1024
SCRIPTS = ["theme.js", "embed.js", "start3d.js"]


def test_the_embeds_scripts_are_the_three_counted() -> None:
    share = (ROOT / "api/share.js").read_text(encoding="utf-8")
    assert '<script src="/embed.js" type="module"></script>' in share
    assert "${siteChrome().head}" in share
    # The site's head, which every page the server makes has, the embed's too.
    assert '<script src="/theme.js"></script>' in (ROOT / "api/_directory.js").read_text(encoding="utf-8")
    # embed.js's only module is start3d.js; start3d.js asks for the 3D view
    # (viewer3d.js) only once View in 3D is pressed, never at load.
    embed = (ROOT / "web/embed.js").read_text(encoding="utf-8")
    assert re.findall(r'^import .* from "(/[^"]+)";', embed, re.M) == ["/start3d.js"]
    start = (ROOT / "web/start3d.js").read_text(encoding="utf-8")
    assert not re.findall(r"^import ", start, re.M)


def test_the_embeds_scripts_stay_under_24_kb() -> None:
    sizes = {name: (ROOT / "web" / name).stat().st_size for name in SCRIPTS}
    total = sum(sizes.values())
    assert total < BUDGET, (f"an embed's frame runs {total} bytes of script before View in 3D, over {BUDGET} "
                            f"({sizes}): say the same in fewer words, or keep a page-wide feature out of theme.js")
