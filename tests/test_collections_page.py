"""The collections directory, /collections (api/people.js collectionsPage,
supabase/collection_directory.sql), made by the real handler from the
design stand-in's world (tools/web/design_stand_in.mjs), with no network:
the public collections as cards with a cover, a name, whose, how many and
Follow, never a private one; what was put in last first, or the most
followed; a page past the end and a database without the directory each
said in words.

tools/web/collections_flow.mjs proves the same page live, in a browser."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def pages(*paths: str, directory: dict | None = None) -> list[dict] | None:
    """Each of [paths] as the server makes it: {status, html}. With
    [directory] {status, json}, the database answers collection_directory
    with it instead of the stand-in's own."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/collections');"
        f"const directory = {json.dumps(directory)};"
        "if (directory) { const real = globalThis.fetch;"
        "  globalThis.fetch = async (input, init) => String(input.url || input).includes('rpc/collection_directory')"
        "    ? new Response(JSON.stringify(directory.json), { status: directory.status,"
        "        headers: { 'content-type': 'application/json' } }) : real(input, init); }"
        "const out = [];"
        f"for (const path of {json.dumps(list(paths))}) {{ const r = await s.serverPage('api', path);"
        "  out.push({ status: r.status, html: r.html }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def cards(html: str) -> list[str]:
    return re.findall(r'<article class="list-card in-directory" data-id="([A-Za-z0-9]{10})"', html)


def card(html: str, id_: str) -> str:
    found = re.search(rf'<article class="list-card in-directory" data-id="{id_}">[\s\S]*?</article>', html)
    assert found, f"no card {id_}"
    return found.group(0)


def test_the_public_collections_are_cards_newest_first_and_a_private_one_never() -> None:
    said = pages("/collections")
    if said is None:
        return
    page = said[0]
    assert page["status"] == 200
    html = page["html"]
    assert "<title>Collections — the Brickworks gallery</title>" in html
    # Sam's put in last, then Robin's castles, then Robin's small one; Sam's
    # private "Ideas for later" never.
    assert cards(html) == ["SamListAa1", "ListAbcde1", "ListSmall1"]
    assert "SamListBb2" not in html and "Ideas for later" not in html
    castles = card(html, "ListAbcde1")
    assert '<a class="cover" href="/c/ListAbcde1" tabindex="-1" aria-hidden="true"><div class="mosaic n3">' in castles
    assert '<a class="name" href="/c/ListAbcde1"><b>Castles worth a weekend</b></a>' in castles
    assert '<a class="who" href="/u/design-tester">' in castles and "<span>Robin Castell</span>" in castles
    assert "<span>3 models</span>" in castles
    assert '<span data-list-followers="ListAbcde1">3 followers</span>' in castles
    # Follow is the script's to show, once it knows who is asking.
    assert '<button type="button" class="cta ghost follow" data-follow-list="ListAbcde1" hidden>Follow</button>' in castles
    # Nobody follows the small one: hidden, never "0 followers".
    assert '<span data-list-followers="ListSmall1" hidden>0 followers</span>' in card(html, "ListSmall1")
    assert '<script src="/follow.js" type="module"></script>' in html
    # The first tab is the one shown, and the page is linked back to the gallery.
    assert '<a href="/collections" data-sort="recent" aria-current="page">Recently added to</a>' in html
    assert '<a href="/collections?sort=followed" data-sort="followed">Most followed</a>' in html
    assert '<a href="/gallery">Models in the gallery</a>' in html
    # Three fit one page: no pager.
    assert 'aria-label="Pages"' not in html


def test_most_followed_puts_the_followed_one_first() -> None:
    said = pages("/collections?sort=followed")
    if said is None:
        return
    html = said[0]["html"]
    assert cards(html)[0] == "ListAbcde1" and set(cards(html)) == {"SamListAa1", "ListAbcde1", "ListSmall1"}
    assert '<a href="/collections?sort=followed" data-sort="followed" aria-current="page">Most followed</a>' in html
    assert '<meta name="robots" content="noindex">' in html


def test_pages_link_on_and_back_and_a_page_past_the_end_says_so() -> None:
    row = {"id": "ListAbcde1", "name": "Castles worth a weekend", "description": None, "count": 3, "followers": 0,
           "added": "2026-10-14T10:00:00Z", "by": {"handle": "design-tester", "name": "Robin Castell"}}
    said = pages("/collections?page=2&sort=followed",
                 directory={"status": 200, "json": {"sort": "followed", "page": 2, "size": 24, "total": 60, "rows": [row]}})
    if said is None:
        return
    pager = re.search(r'<nav class="actions center more" aria-label="Pages">[\s\S]*?</nav>', said[0]["html"])
    assert pager, "no pager"
    assert '<a class="cta ghost" rel="prev" href="/collections?sort=followed">Previous</a>' in pager.group(0)
    assert "Page 2 of 3" in pager.group(0)
    assert '<a class="cta ghost" rel="next" href="/collections?sort=followed&amp;page=3">Next</a>' in pager.group(0)
    past = pages("/collections?page=5")
    assert past and past[0]["status"] == 200
    assert 'id="collections-empty">There is no page 5.' in past[0]["html"]
    assert '<a class="link" href="/collections">Back to the first page</a>' in past[0]["html"]
    assert not cards(past[0]["html"])


def test_none_to_list_and_a_database_without_the_directory_each_say_so() -> None:
    none = pages("/collections", directory={"status": 200, "json": {"sort": "recent", "page": 1, "size": 24,
                                                                    "total": 0, "rows": []}})
    if none is None:
        return
    assert none[0]["status"] == 200
    assert 'id="collections-empty">No public collections yet. Anyone can make one' in none[0]["html"]
    missing = pages("/collections", directory={"status": 404, "json": {"code": "PGRST202"}})
    assert missing and missing[0]["status"] == 200
    assert 'id="collections-empty">Collections are not listed on Brickworks yet.' in missing[0]["html"]


def test_the_gallery_and_every_pages_footer_link_to_it() -> None:
    gallery = (ROOT / "web" / "gallery.html").read_text()
    assert '<a href="/collections" id="to-collections">Collections</a>' in gallery
    shell = (ROOT / "web" / "_shell.html").read_text()
    assert '<a href="/collections">Collections</a>' in shell
    said = pages("/collections")
    if said is None:
        return
    assert '<a href="/collections">Collections</a>' in said[0]["html"]
