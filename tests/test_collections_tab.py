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
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def asked(query: dict, directory: dict | None = None, lists_sql: bool = False) -> dict | None:
    """What the API answers [query] with: {status, cache, json}. With
    [directory] {status, json}, the database answers collection_directory
    with it instead of the stand-in's own. Without [lists_sql], a database
    before supabase/lists.sql: list_directory is not there, so the
    directory is collection_directory's (and its search's) as before."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverAsk('api', { name: 'people', query: { op: 'collections' } });"
        f"const directory = {json.dumps(directory)};"
        f"const listsSql = {json.dumps(lists_sql)};"
        "const real = globalThis.fetch;"
        "const answer = (json, status) => new Response(JSON.stringify(json), { status,"
        "  headers: { 'content-type': 'application/json' } });"
        "globalThis.fetch = async (input, init) => {"
        "  const url = String(input.url || input);"
        "  if (!listsSql && /rpc\\/list_directory$/.test(url)) return answer({ code: 'PGRST202' }, 404);"
        "  if (directory && /rpc\\/collection_directory$/.test(url)) return answer(directory.json, directory.status);"
        "  return real(input, init); };"
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
    assert "searched !== false" in js and 'say("Lists cannot be searched just yet: here are all of them.")' in js


def test_a_database_without_the_directory_lists_none() -> None:
    said = asked({"op": "collections"}, directory={"status": 404, "json": {"code": "PGRST202"}})
    if said is None:
        return
    assert said["status"] == 200
    assert said["json"]["ready"] is False and said["json"]["collections"] == []


def test_with_lists_sql_the_directory_counts_sets_and_models() -> None:
    # supabase/lists.sql's list_directory (docs/LISTS.md): lists of sets
    # beside lists of models, each card saying how many of each; never a
    # wishlist or a list taken down (its SQL, tools/lists_try.sql).
    said = asked({"op": "collections"}, lists_sql=True)
    if said is None:
        return
    answer = said["json"]
    assert said["status"] == 200 and answer["ready"] is True and answer["searched"] is True
    assert ids(said) == ["SamListAa1", "ListAbcde1", "ListSmall1"]
    castles = answer["collections"][1]
    assert castles["models"] == 3 and castles["sets"] == 0 and castles["count"] == 3
    assert "SamListBb2" not in json.dumps(answer)


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
    # Lists since lists2a (docs/LISTS.md section 5 item 2), at /gallery-lists:
    # /lists is Your lists. The tab's id stays "collections" inside the page.
    gallery = (ROOT / "web/gallery.html").read_text(encoding="utf-8")
    assert '<a href="/gallery-lists" data-tab="collections">Lists</a>' in gallery
    page = (ROOT / "web/gallery-lists.html").read_text(encoding="utf-8")
    assert '<html lang="en" data-tab="collections">' in page
    assert '<link rel="canonical" href="https://brickworks.diy/gallery-lists">' in page
    assert '<a href="/gallery-lists" data-tab="collections" aria-current="page">Lists</a>' in page
    assert '<a href="/gallery-lists">Lists</a>' in (ROOT / "web/_shell.html").read_text(encoding="utf-8")
    assert not (ROOT / "web/collections.html").exists()
    # No page links to the old address: each one goes straight to Lists.
    for one in sorted((ROOT / "web").rglob("*.html")):
        assert 'href="/collections' not in one.read_text(encoding="utf-8"), one
    # No server page any more: a static file of the gallery, which the
    # deployment serves at /gallery-lists as it does /builds.
    assert "collections_page" not in (ROOT / "tools/deploy.sh").read_text(encoding="utf-8")
    assert "collections_page" not in (ROOT / "api/people.js").read_text(encoding="utf-8")


def test_the_old_address_answers_301_to_lists_keeping_its_query() -> None:
    # Every /collections link people kept, with its search, lands on Lists:
    # the route sends it to op=moved, which answers a 301 with the query.
    deploy = (ROOT / "tools/deploy.sh").read_text(encoding="utf-8")
    assert '{ "src": "/collections([.]html)?/?", "dest": "/api/people?op=moved&to=gallery-lists" }' in deploy
    assert '"dest": "/api/people?op=moved&to=gallery-lists&lang=\\$1" }' in deploy
    script = """
      import handler from "./api/people.js";
      const said = [];
      for (const query of [{ op: "moved", to: "gallery-lists", q: "castle", sort: "followed", tests: "1" },
                           { op: "moved", to: "gallery-lists", lang: "de" },
                           { op: "moved", to: "gallery-lists", q: "a b" },
                           { op: "moved", to: "gallery-lists", lang: "xx" },
                           { op: "moved", to: "../evil" }]) {
        const response = { statusCode: 0, headers: {}, setHeader(k, v) { this.headers[k.toLowerCase()] = v; },
          status(code) { this.statusCode = code; return this; }, json(b) { this.body = b; return this; },
          send(b) { this.body = b; return this; }, end(b) { this.body = b; return this; } };
        await handler({ method: "GET", query, headers: {} }, response);
        said.push({ status: response.statusCode, location: response.headers.location || "", cache: response.headers["cache-control"] || "" });
      }
      console.log(JSON.stringify(said));
    """
    out = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                         timeout=60, env={**os.environ, "SUPABASE_URL": "", "SUPABASE_SECRET_KEY": ""})
    assert out.returncode == 0, out.stderr
    said = json.loads(out.stdout.strip().splitlines()[-1])
    assert said[0] == {"status": 301, "location": "/gallery-lists?q=castle&sort=followed&tests=1",
                       "cache": "public, max-age=3600, s-maxage=86400"}, said[0]
    assert said[1]["status"] == 301 and said[1]["location"] == "/de/gallery-lists", said[1]
    assert said[2]["status"] == 301 and said[2]["location"] == "/gallery-lists?q=a+b", said[2]
    for refused in said[3:]:
        assert refused["status"] == 404 and not refused["location"], refused
