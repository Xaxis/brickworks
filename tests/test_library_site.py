"""The LDraw library on the site (library333, 2026-10-29): /library browses
every set the app's Library opens, and /library/<id> is each one's page.

These drive the real code with a store of their own: api/_library.js holds
the index's entries at the edge and searches them as the app's Library
does (ModelLibrary.search), credits every modeller a file names and counts
the steps its file lays out; web/card.js draws a set's card; and
api/share.js answers the shelf, a set's page, its pictures and its parts
from the store, never the database. tools/web/library_site_flow.mjs drives
them in a browser on a deployment.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="no node here")

# Four sets, as tools/library_build.py writes the index, and one of each
# kind the edge must refuse.
INDEX = {"version": 1, "models": [
    {"id": "omr-10179-1", "kind": "set", "set": "10179-1", "name": "Millennium Falcon",
     "theme": "Star Wars > Ultimate Collector Series", "year": 2007, "parts": 5264, "box": 5205,
     "file": "library/omr/10179-1.mpd", "cover": "library/covers/omr-10179-1.webp", "author": "Roland Dahl",
     "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/320", "alternate_of": None},
    {"id": "omr-106-1", "kind": "set", "set": "106-1", "name": "UNICEF Van", "theme": "Town", "year": 1985,
     "parts": 65, "box": 65, "file": "library/omr/106-1.mpd", "cover": "library/covers/omr-106-1.webp",
     "author": "Tore Eriksson", "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/1", "alternate_of": None},
    {"id": "omr-4488-1", "kind": "set", "set": "4488-1", "name": "Millennium Falcon - Mini", "theme": "Star Wars",
     "year": 2003, "parts": 66, "box": 0, "file": "library/omr/4488-1.mpd", "cover": "library/covers/omr-4488-1.webp",
     "author": "Johann Eisner", "licence": "CC BY 4.0", "page": "https://library.ldraw.org/omr/sets/517", "alternate_of": None},
    {"id": "omr-6080-1", "kind": "set", "set": "6080-1", "name": "King's Castle", "theme": "Castle", "year": 1984,
     "parts": 674, "box": 674, "file": "library/omr/6080-1.mpd", "cover": "library/covers/omr-6080-1.webp",
     "author": "Stefan Frenz", "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/9", "alternate_of": None},
    # Twice: kept once.
    {"id": "omr-106-1", "set": "106-1", "name": "Again", "theme": "Town", "year": 1985, "parts": 65,
     "file": "library/omr/106-1.mpd", "cover": "library/covers/omr-106-1.webp", "author": "X", "licence": "CCAL 2.0",
     "page": "https://library.ldraw.org/omr/sets/1"},
    # A path out of library/, an id a page could not be, a licence the site cannot pass on.
    {"id": "omr-1-1", "file": "../secrets.mpd", "cover": "library/covers/omr-1-1.webp", "licence": "CCAL 2.0"},
    {"id": "omr-a.b", "file": "library/omr/a.b.mpd", "cover": "library/covers/omr-a.b.webp", "licence": "CCAL 2.0"},
    {"id": "omr-2-1", "file": "library/omr/2-1.mpd", "cover": "library/covers/omr-2-1.webp", "licence": "proprietary"},
]}

# A file with two models by two modellers, a part of its own by a third (a
# part's author, not the set's), and a program that signed what it wrote.
FALCON = """0 FILE 10179-1.ldr
0 Millennium Falcon
0 Name: 10179-1.ldr
0 Author: Roland Dahl [RolandD]
0 !LICENSE Redistributable under CCAL version 2.0 : see CAreadme.txt
1 71 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat
1 71 0 -48 0 1 0 0 0 1 0 0 0 1 dish.ldr
0 STEP
0 ROTSTEP 0 45 0 ABS
1 4 0 -72 0 1 0 0 0 1 0 0 0 1 hose.ldr
0 FILE dish.ldr
0 Author: Evert-Jan Boer (ejb@example.org)
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
0 STEP
1 15 0 -24 0 1 0 0 0 1 0 0 0 1 own.dat
0 FILE hose.ldr
0 Author: LDCad
1 0 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 FILE own.dat
0 Author: Somebody Who Made A Part
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
0 STEP
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat
"""


def node(script: str, env: dict | None = None) -> object:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, env=env)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


LIBRARY = f"""
import * as L from "./api/_library.js";
const index = async () => {json.dumps(INDEX["models"])};
const sets = await L.librarySets({{ index }});
const ids = (ask) => L.searchSets(sets, L.askOf(ask)).models.map((one) => one.id);
"""


def test_the_shelf_keeps_whole_entries_once() -> None:
    said = node(LIBRARY + """
console.log(JSON.stringify({ ids: sets.map((one) => one.id), names: sets.map((one) => one.name),
  themes: L.themes(sets), decades: L.decades(sets) }));""")
    assert said["ids"] == ["omr-10179-1", "omr-106-1", "omr-4488-1", "omr-6080-1"]
    assert said["names"][1] == "UNICEF Van"
    assert said["themes"] == [{"name": "Castle", "n": 1}, {"name": "Star Wars", "n": 2}, {"name": "Town", "n": 1}]
    assert said["decades"] == ["2000s", "1980s"]


def test_it_searches_as_the_app_does() -> None:
    said = node(LIBRARY + """
console.log(JSON.stringify({
  number: ids({ q: "10179" }), words: ids({ q: "falcon mini" }), modeller: ids({ q: "frenz" }),
  theme: ids({ theme: "Star Wars" }), decade: ids({ decade: "1980s" }), small: ids({ size: "small" }),
  newest: ids({}), oldest: ids({ sort: "oldest" }), largest: ids({ sort: "largest" }), name: ids({ sort: "name" }),
  nothing: ids({ q: "falcon castle" }), junk: L.askOf({ sort: "views", size: "huge", decade: "1890s", page: "-3" }),
}));""")
    assert said["number"] == ["omr-10179-1"]
    assert said["words"] == ["omr-4488-1"]
    assert said["modeller"] == ["omr-6080-1"]
    assert said["theme"] == ["omr-10179-1", "omr-4488-1"]
    assert said["decade"] == ["omr-106-1", "omr-6080-1"]
    assert said["small"] == ["omr-4488-1", "omr-106-1"]
    assert said["newest"] == ["omr-10179-1", "omr-4488-1", "omr-106-1", "omr-6080-1"]
    assert said["oldest"] == ["omr-6080-1", "omr-106-1", "omr-4488-1", "omr-10179-1"]
    assert said["largest"] == ["omr-10179-1", "omr-6080-1", "omr-4488-1", "omr-106-1"]
    assert said["name"] == ["omr-6080-1", "omr-10179-1", "omr-4488-1", "omr-106-1"]
    assert said["nothing"] == []
    assert said["junk"] == {"q": "", "theme": "", "decade": "", "size": "", "sort": "newest", "page": 1}


def test_it_credits_every_modeller_and_counts_the_file_s_steps() -> None:
    said = node(f"""
import {{ authorsIn, fileSteps, namesSaid }} from "./api/_library.js";
const text = {json.dumps(FALCON)};
console.log(JSON.stringify({{ authors: authorsIn(text), steps: fileSteps(text),
  none: fileSteps("0 FILE a.ldr\\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\\n"),
  said: namesSaid(["A", "B"]), many: namesSaid(["A", "B", "C", "D", "E"]) }}));""")
    # The part's own author and LDCad are not the set's modellers; the
    # login in brackets and the address are left out.
    assert said["authors"] == ["Roland Dahl", "Evert-Jan Boer"]
    # 10179-1.ldr: its two STEPs each end a step with a part, the ROTSTEP
    # after them ends none, and the hose after it is its last step (3);
    # dish.ldr's two; the hose's one; own.dat is a part, not a model.
    assert said["steps"] == 6
    assert said["none"] == 0
    assert said["said"] == "A and B"
    assert said["many"] == "A, B, C and 2 others"


def test_a_set_s_card_opens_its_page_and_says_which_set_it_is() -> None:
    said = node(LIBRARY + """
import { cardHtml } from "./web/card.js";
console.log(JSON.stringify({ card: cardHtml(L.setCard(sets[0])),
  model: cardHtml({ id: "AbCdEfGhJk", name: "A car", parts: 12, thumb: "/m/AbCdEfGhJk.webp?v=k" }) }));""")
    card = said["card"]
    assert 'href="/library/omr-10179-1"' in card
    assert 'src="/library/omr-10179-1.webp"' in card
    assert '<small class="set">10179-1 · Star Wars · 2007</small>' in card
    assert "Modelled by Roland Dahl" in card and "5,264 parts" in card
    assert "data-like" not in card
    # A shared model's card is as it was.
    assert 'href="/m/AbCdEfGhJk"' in said["model"] and 'class="set"' not in said["model"]


SITE = f"""
process.env.PARTS_URL = "https://store.test/parts/";
// A deployment's keys, which the handler asks for; anything asked of the
// database would be in [asked], and nothing is.
Object.assign(process.env, {{ SUPABASE_URL: "https://db.test", SUPABASE_SECRET_KEY: "secret", SUPABASE_PUBLISHABLE_KEY: "public" }});
delete process.env.PUBLIC_ORIGIN;
const store = {{ "library/index.json": {json.dumps(json.dumps(INDEX))}, "library/omr/10179-1.mpd": {json.dumps(FALCON)} }};
const webp = Buffer.concat([Buffer.from("RIFF"), Buffer.alloc(4), Buffer.from("WEBPVP8 "), Buffer.alloc(16)]);
const asked = [];
globalThis.fetch = async (url) => {{
  const path = String(url).replace("https://store.test/parts/", "");
  asked.push(path);
  if (path in store) return new Response(store[path]);
  if (path === "library/covers/omr-10179-1.webp" || path === "library/pages/omr-106-1.webp") return new Response(webp);
  return new Response("", {{ status: 400 }});
}};
// The LDraw shelf alone, as a deployment without the sets' catalogue
// (api/_sets.js, tests/test_sets.py) answers it.
(await import("./api/_sets.js")).useCatalog(null);
const {{ default: handler }} = await import("./api/share.js");
async function call(query) {{
  const headers = {{}};
  let status = 200, body = "";
  const response = {{
    setHeader(k, v) {{ headers[k.toLowerCase()] = v; return this; }},
    status(s) {{ status = s; return this; }},
    json(o) {{ body = o; return this; }},
    end(b) {{ body = Buffer.isBuffer(b) ? `<${{b.length}} bytes>` : String(b); return this; }},
  }};
  await handler({{ method: "GET", query, headers: {{ host: "brickworks.test", "x-forwarded-proto": "https" }} }}, response);
  return {{ status, headers, body }};
}}
"""


def test_the_shelf_answers_a_page_of_cards_from_the_store() -> None:
    said = node(SITE + """
const list = await call({ op: "library", q: "falcon", sort: "oldest" });
console.log(JSON.stringify({ list, asked }));""")
    list_ = said["list"]
    assert list_["status"] == 200
    assert [one["id"] for one in list_["body"]["models"]] == ["omr-4488-1", "omr-10179-1"]
    assert list_["body"]["total"] == 2 and list_["body"]["of"] == 4 and list_["body"]["pages"] == 1
    assert list_["body"]["models"][0]["library"] == {"set": "4488-1", "theme": "Star Wars", "year": 2003}
    assert list_["body"]["models"][0]["licence"] == "cc-by-4.0"
    assert "s-maxage" in list_["headers"]["cache-control"]
    # The store alone: nothing asked of the database.
    assert said["asked"] == ["library/index.json"]


def test_a_set_s_page_is_a_model_s_page_crediting_its_modellers() -> None:
    said = node(SITE + """
const page = await call({ op: "set", id: "omr-10179-1" });
const none = await call({ op: "set", id: "omr-9999-1" });
const junk = await call({ op: "set", id: "../index" });
console.log(JSON.stringify({ page, none: none.status, junk: junk.status }));""")
    page = said["page"]
    html = page["body"]
    assert page["status"] == 200
    assert "<h1>Millennium Falcon</h1>" in html
    assert "<title>Millennium Falcon, LEGO® set 10179-1 — from the LDraw library</title>" in html
    # Every modeller the file names, each credited, LDraw linked.
    assert re.search(r'Modelled by <b>Roland Dahl and Evert-Jan Boer</b> for <a href="https://library\.ldraw\.org/omr/sets/320">', html)
    assert "credit Roland Dahl and Evert-Jan Boer, who modelled it for" in html
    assert 'href="https://creativecommons.org/licenses/by/2.0/" rel="license"' in html
    # The app opens it as its Library does, and its picture is the way in.
    assert html.count('href="/app?new=1&amp;library=omr-10179-1"') == 2
    assert 'src="/library/omr-10179-1.cutout.webp"' in html
    assert 'content="https://brickworks.test/library/omr-10179-1.cover.webp"' in html
    assert '<li class="pill" data-steps="6">6 steps, laid out by its modeller</li>' in html
    assert '<a class="pill" href="/library?theme=Star%20Wars">Star Wars</a>' in html
    assert 'data-parts="/library/omr-10179-1/parts.json"' in html
    # Share, with its link and no embed; none of a shared model's own rows.
    assert 'id="share-link" value="https://brickworks.test/library/omr-10179-1"' in html
    for gone in ('id="share-embed"', 'id="comments"', 'id="builds"', 'id="remixes"', 'data-mark="like"', 'data-mark="save"'):
        assert gone not in html, gone
    # More of its theme only with three, and this shelf has one more.
    assert 'id="similar"' not in html
    assert said["none"] == 404 and said["junk"] == 404


def test_a_set_s_pictures_come_from_this_site_drawn_or_its_cover() -> None:
    said = node(SITE + """
const card = await call({ op: "set_cover", id: "omr-10179-1" });
const cutout = await call({ op: "set_cover", id: "omr-106-1", as: "cutout" });
const odd = await call({ op: "set_cover", id: "omr-10179-1", as: "big" });
const file = await call({ op: "set_file", id: "omr-10179-1" });
console.log(JSON.stringify({ card, cutout, odd: odd.status, file, asked }));""")
    # Its card's picture not drawn yet: the cover, kept an hour, not a week.
    assert said["card"]["status"] == 200 and said["card"]["headers"]["content-type"] == "image/webp"
    assert "s-maxage=3600" in said["card"]["headers"]["cache-control"]
    assert "library/cards/omr-10179-1.webp" in said["asked"]
    # The page's, drawn: kept a week.
    assert said["cutout"]["status"] == 200 and "s-maxage=604800" in said["cutout"]["headers"]["cache-control"]
    assert said["odd"] == 404
    # The file from the store itself, past what a function may send.
    assert said["file"]["status"] == 302
    assert said["file"]["headers"]["location"] == "https://store.test/parts/library/omr/10179-1.mpd"


def test_the_routes_send_library_addresses_to_share() -> None:
    deploy = (ROOT / "tools/deploy.sh").read_text()
    for route in ('"/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})/?", "dest": "/api/share?op=set&id=\\$1"',
                  '[.]webp", "dest": "/api/share?op=set_cover&id=\\$1"',
                  '[.](cutout|cover)[.]webp", "dest": "/api/share?op=set_cover&id=\\$1&as=\\$2"',
                  '[.]mpd", "dest": "/api/share?op=set_file&id=\\$1"',
                  '/parts[.](json|xml|csv)", "dest": "/api/share?op=set_parts&id=\\$1&as=\\$2"'):
        assert route in deploy, route
    # The id the routes take is the one api/_library.js holds an id to.
    assert "SET_ID = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/" in (ROOT / "api/_library.js").read_text()
    # Linked from the gallery's tabs and the site's footer.
    assert '<a href="/library" id="to-library">LDraw library</a>' in (ROOT / "web/gallery.html").read_text()
    assert '<a href="/library">LDraw library</a>' in (ROOT / "web/_shell.html").read_text()
