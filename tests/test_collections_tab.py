"""The gallery's Collections tab, /collections (web/collections.js; browse,
2026-11-02): the public collections as the gallery's cards, from
/api/people?op=collections (api/people.js collections,
supabase/collection_directory.sql), the real handler asked over the design
stand-in's world (tools/web/design_stand_in.mjs), with no network. Never a
private one; what was put in last first, or the most followed; a search
before supabase/collection_search.sql is applied, and a database without
the directory, each said as such.

tools/web/collections_flow.mjs drives the tab live in a browser, and
tools/web/browse_flow.mjs the gallery's tabs as one page."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def asked(query: dict, directory: dict | None = None) -> dict | None:
    """What the API answers [query] with: {status, cache, json}. With
    [directory] {status, json}, the database answers collection_directory
    with it instead of the stand-in's own."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverAsk('api', { name: 'people', query: { op: 'collections' } });"
        f"const directory = {json.dumps(directory)};"
        "if (directory) { const real = globalThis.fetch;"
        "  globalThis.fetch = async (input, init) => /rpc\\/collection_directory$/.test(String(input.url || input))"
        "    ? new Response(JSON.stringify(directory.json), { status: directory.status,"
        "        headers: { 'content-type': 'application/json' } }) : real(input, init); }"
        f"const r = await s.serverAsk('api', {{ name: 'people', query: {json.dumps(query)} }});"
        "console.log(JSON.stringify({ status: r.status, cache: r.headers['cache-control'], json: JSON.parse(r.html) }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def ids(said: dict) -> list[str]:
    return [one["id"] for one in said["json"]["collections"]]


def test_the_public_collections_newest_first_and_a_private_one_never() -> None:
    said = asked({"op": "collections"})
    if said is None:
        return
    assert said["status"] == 200 and "s-maxage" in said["cache"]
    answer = said["json"]
    assert answer["ready"] is True and answer["searched"] is True
    assert answer["total"] == 3 and answer["pages"] == 1
    # Sam's put in last, then Robin's castles, then Robin's small one; Sam's
    # private "Ideas for later" never.
    assert ids(said) == ["SamListAa1", "ListAbcde1", "ListSmall1"]
    assert "SamListBb2" not in json.dumps(answer) and "Ideas for later" not in json.dumps(answer)
    castles = answer["collections"][1]
    assert castles["name"] == "Castles worth a weekend" and castles["count"] == 3 and castles["followers"] == 3
    assert castles["by"]["handle"] == "design-tester" and castles["by"]["name"] == "Robin Castell"
    # Its cover: up to four of its models' pictures, each a model's own.
    assert len(castles["covers"]) == 3
    assert all(re.fullmatch(r"/m/[A-Za-z0-9]{10}\.(webp|png)(\?v=[a-z0-9]+)?", src) for src in castles["covers"])


def test_most_followed_puts_the_followed_one_first() -> None:
    said = asked({"op": "collections", "sort": "followed"})
    if said is None:
        return
    assert said["json"]["sort"] == "followed"
    assert ids(said)[0] == "ListAbcde1" and set(ids(said)) == {"SamListAa1", "ListAbcde1", "ListSmall1"}


def test_a_search_before_its_function_is_applied_lists_them_all_and_says_so() -> None:
    # The stand-in has no collection_search.sql: the tab says it lists them
    # all (web/collections.js, "Collections cannot be searched just yet").
    said = asked({"op": "collections", "q": "castle"})
    if said is None:
        return
    assert said["json"]["searched"] is False and len(ids(said)) == 3
    js = (ROOT / "web/collections.js").read_text(encoding="utf-8")
    assert "searched !== false" in js and 'say("Collections cannot be searched just yet: here are all of them.")' in js


def test_a_database_without_the_directory_lists_none() -> None:
    said = asked({"op": "collections"}, directory={"status": 404, "json": {"code": "PGRST202"}})
    if said is None:
        return
    assert said["status"] == 200
    assert said["json"]["ready"] is False and said["json"]["collections"] == []


def card(list_: dict) -> str:
    return subprocess.run(["node", "--input-type=module", "-e", f"""
import {{ collectionCardHtml }} from "./web/card.js";
console.log(collectionCardHtml({json.dumps(list_)}));
"""], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def test_a_card_is_the_gallery_card_with_its_cover_whose_and_follow() -> None:
    if shutil.which("node") is None:
        return
    drawn = card({"id": "ListAbcde1", "name": "Castles <b>", "count": 3, "followers": 0,
                  "by": {"handle": "design-tester", "name": "Robin & Co"},
                  "covers": ["/m/DesignMod1.webp?v=abc", "https://elsewhere.test/x.png", "/m/DesignRmx1.png"]})
    # The model card's shape (web/site.css .model), so the tab reads as the gallery.
    assert drawn.startswith('<article class="model collection-card" data-id="ListAbcde1"><div class="frame">')
    # Only a model's own pictures are drawn.
    assert '<div class="mosaic n2">' in drawn and "elsewhere.test" not in drawn
    assert '<a class="open" href="/c/ListAbcde1"><b title="Castles &lt;b&gt;">Castles &lt;b&gt;</b></a>' in drawn
    assert '<a class="who" href="/u/design-tester">' in drawn and "<span>Robin &amp; Co</span>" in drawn
    assert '<span class="parts">3 models</span>' in drawn
    # Nobody follows it: hidden, never "0 followers".
    assert '<span class="parts" data-list-followers="ListAbcde1" hidden>0 followers</span>' in drawn
    # Follow is web/follow.js's to show, once it knows who is asking.
    assert '<button type="button" class="cta ghost small follow" data-follow-list="ListAbcde1" hidden>Follow</button>' in drawn
    # Somebody's handle that is not one is nobody's link.
    assert "/u/" not in card({"id": "ListAbcde1", "name": "X", "count": 1, "by": {"handle": "../evil", "name": "X"}})


def test_it_is_a_tab_of_the_gallery_and_every_pages_footer_links_to_it() -> None:
    gallery = (ROOT / "web/gallery.html").read_text(encoding="utf-8")
    assert '<a href="/collections" data-tab="collections">Collections</a>' in gallery
    page = (ROOT / "web/collections.html").read_text(encoding="utf-8")
    assert '<html lang="en" data-tab="collections">' in page
    assert '<link rel="canonical" href="https://brickworks.diy/collections">' in page
    assert '<a href="/collections" data-tab="collections" aria-current="page">Collections</a>' in page
    assert '<a href="/collections">Collections</a>' in (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    # No server page any more: a static file of the gallery, which the
    # deployment serves at /collections as it does /builds.
    assert "collections_page" not in (ROOT / "tools/deploy.sh").read_text(encoding="utf-8")
    assert "collections_page" not in (ROOT / "api/people.js").read_text(encoding="utf-8")
