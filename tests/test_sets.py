"""Every set in the catalogue a page (sets364, 2026-10-29): /library lists
every set Rebrickable's catalogue has, beside LDraw's 3D models of a few
hundred, and /library/set/<number> is each one's page.

These drive the real code with a catalogue of their own: tools/set_catalog.py
chooses the parts a set's picture is drawn from; api/_sets.js reads the
catalogue at the edge, searches and filters it, says what a person owns of a
set, and writes its page; web/card.js draws a set's card; api/share.js
answers the list, the pages and the sitemaps. tools/web/sets_flow.mjs drives
them in a browser on a deployment.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

needs_node = pytest.mark.skipif(shutil.which("node") is None, reason="no node here")

# Six sets as tools/set_catalog.py writes them: a theme inside a theme, a
# set with an LDraw model, one with sets packed in it, one with no parts.
CATALOG = {
    "format": 1,
    "themes": {"1": ["Technic", None], "158": ["Star Wars", None], "171": ["Ultimate Collector Series", 158],
               "721": ["Icons", None], "501": ["Gear", None]},
    "sets": [
        ["10179-1", "Millennium Falcon", 2007, 171, 5205, 5, 295],
        ["10497-1", "Galaxy Explorer", 2022, 721, 1278, 4, 302],
        ["42115-1", "Lamborghini Sián FKP 37", 2020, 1, 3696, 0, 380],
        ["4488-1", "Millennium Falcon - Mini", 2003, 158, 87, 0, 40],
        ["853900-1", "Key Chain Falcon", 2019, 501, 0, 0, 0],
        ["214.1-1", "Bricks and Plates", 2026, 1, 12, 0, 3],
    ],
    "inside": {"10179-1": [["4488-1", 2]]},
    "picks": {"10497-1": ["3068bp58/15", "3009p50/1"], "42115-1": ["68577/82"]},
}
# LDraw's models: one of 10179-1, and another build of it.
MODELS = [
    {"id": "omr-10179-1", "set": "10179-1", "name": "Millennium Falcon", "author": "Roland Dahl",
     "page": "https://library.ldraw.org/omr/sets/320", "alternate_of": ""},
    {"id": "omr-10179-1_B", "set": "10179-1", "name": "Millennium Falcon — B model", "author": "Somebody",
     "page": "https://library.ldraw.org/omr/sets/321", "alternate_of": "10179-1"},
]


def node(script: str) -> Any:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


SETS = f"""
import * as S from "./api/_sets.js";
const catalog = S.useCatalog({json.dumps(CATALOG)});
const models = S.modelsBySet({json.dumps(MODELS)});
const ids = (ask) => S.searchCatalog(catalog.sets, S.askSets(ask), models).sets.map((one) => one.set);
"""


def test_picks_are_a_set_s_rarest_parts_that_can_be_drawn() -> None:
    import set_catalog
    records = {
        "a-1": {"p": [["3001", 4, 10], ["rare", 1, 1], ["sticker", 1, 1], ["tiny", 1, 1], ["torso1", 1, 1],
                      ["torso2", 1, 1], ["torso3", 1, 1]]},
        "b-1": {"p": [["3001", 4, 2]]},
        "c-1": {"p": [["3001", 1, 1], ["rare", 1, 1]]},
    }
    parts = {
        "3001": {"mesh": "m1", "category": "Brick", "size_ldu": [80, 24, 40], "triangles": 500},
        "rare": {"mesh": "m2", "category": "Slope", "size_ldu": [40, 24, 40], "triangles": 500},
        "sticker": {"mesh": "m3", "category": "Sticker", "size_ldu": [40, 1, 40], "triangles": 10},
        "tiny": {"mesh": "m4", "category": "Plate", "size_ldu": [8, 8, 8], "triangles": 10},
        "torso1": {"mesh": "m5", "category": "Minifig", "size_ldu": [40, 32, 20], "triangles": 900},
        "torso2": {"mesh": "m6", "category": "Minifig", "size_ldu": [40, 32, 20], "triangles": 900},
        "torso3": {"mesh": "m7", "category": "Minifig", "size_ldu": [40, 32, 20], "triangles": 900},
    }
    picked = set_catalog.picks(records, parts)
    # Each torso is in one set, rarer than "rare" (two) and 3001 (three),
    # but only two of a figure's; no sticker, nothing too small to see.
    assert picked["a-1"] == ["torso1/1", "torso2/1", "rare/1", "3001/4"]
    assert picked["b-1"] == ["3001/4"]
    assert "sticker/1" not in picked["a-1"] and "tiny/1" not in picked["a-1"]


@pytest.mark.skipif(not (ROOT / "vendor" / "rebrickable" / "sets.csv.gz").exists()
                    or not (ROOT / "assets" / "generated" / "sets" / "000.json").exists(),
                    reason="no vendored catalogue or set shards here")
def test_the_whole_catalogue_is_written() -> None:
    import set_catalog
    made = set_catalog.build()
    by = {row[0]: row for row in made["sets"]}
    assert len(made["sets"]) > 25000
    # 10497-1 Galaxy Explorer, 2022, Icons: its list's parts and lots, and its figures.
    assert by["10497-1"][1:4] == ["Galaxy Explorer", 2022, 721] and by["10497-1"][4] > 1000 and by["10497-1"][5] == 4
    assert made["themes"]["171"][1] == 158
    assert len(made["picks"]["10497-1"]) == set_catalog.PICKS
    assert all(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,29}", row[0]) for row in made["sets"])


@needs_node
def test_it_reads_a_set_by_its_number_and_its_theme_s_path() -> None:
    said = node(SETS + """
const one = S.catalogSet("10179-1");
console.log(JSON.stringify({ n: catalog.sets.length, theme: one.theme, plain: S.catalogSet("10497").set,
  upper: S.catalogSet("10497-1".toUpperCase())?.set ?? null, dot: S.catalogSet("214.1-1")?.name ?? null,
  none: S.catalogSet("nosuch-1"), bad: S.catalogSet("../etc"), inside: one.inside, tree: S.themeTree(catalog.sets),
  years: S.yearsOf(catalog.sets) }));""")
    assert said["n"] == 6
    assert said["theme"] == ["Star Wars", "Ultimate Collector Series"]
    assert said["plain"] == "10497-1" and said["upper"] == "10497-1" and said["dot"] == "Bricks and Plates"
    assert said["none"] is None and said["bad"] is None
    assert said["inside"] == [["4488-1", 2]]
    # Gear has no set with parts, so no pill.
    assert [one["name"] for one in said["tree"]] == ["Icons", "Star Wars", "Technic"]
    assert said["tree"][1] == {"name": "Star Wars", "n": 2, "sub": [{"name": "Ultimate Collector Series", "n": 1}]}
    # The key chain's 2019 has no set with parts in it.
    assert said["years"] == {"decades": ["2020s", "2000s"], "years": [2026, 2022, 2020, 2007, 2003]}


@needs_node
def test_it_searches_and_filters_every_set() -> None:
    said = node(SETS + """
console.log(JSON.stringify({
  browse: ids({}), newest: ids({ sort: "newest" }), number: ids({ q: "4488" }), words: ids({ q: "falcon" }), gear: ids({ q: "key chain" }),
  theme: ids({ theme: "Star Wars" }), inner: ids({ theme: "Star Wars > Ultimate Collector Series" }),
  decade: ids({ decade: "2020s" }), year: ids({ year: "2022" }), large: ids({ size: "large" }),
  model: ids({ model: "3d" }), figs: ids({ figs: "with" }), none: ids({ figs: "none", theme: "Technic" }),
  oldest: ids({ sort: "oldest" }), name: ids({ sort: "name" }),
  junk: S.askSets({ sort: "price", size: "huge", decade: "1890s", year: "12", model: "yes", figs: "x", page: "-3" }),
}));""")
    # Browsed, the sets built in 3D first, since only their picture is the set:
    # a library opened on 24 sets drawn from their parts showed no set at all.
    assert said["browse"] == ["10179-1", "214.1-1", "10497-1", "42115-1", "4488-1"]
    # Newest first when asked, and a year's biggest first; a key chain with no parts left out.
    assert said["newest"] == ["214.1-1", "10497-1", "42115-1", "10179-1", "4488-1"]
    # A number is its set first; words find the key chain too.
    assert said["number"] == ["4488-1"]
    assert said["words"] == ["10179-1", "853900-1", "4488-1"]
    assert said["gear"] == ["853900-1"]
    assert said["theme"] == ["10179-1", "4488-1"] and said["inner"] == ["10179-1"]
    assert said["decade"] == ["214.1-1", "10497-1", "42115-1"] and said["year"] == ["10497-1"]
    assert said["large"] == ["10179-1", "10497-1", "42115-1"]
    assert said["model"] == ["10179-1"]
    assert said["figs"] == ["10179-1", "10497-1"] and said["none"] == ["214.1-1", "42115-1"]
    assert said["oldest"][0] == "4488-1" and said["name"][0] == "214.1-1"
    assert said["junk"] == {"q": "", "theme": "", "decade": "", "year": 0, "size": "", "model": "", "figs": "",
                            "sort": "built", "page": 1}


@needs_node
def test_a_set_s_card_names_its_page_its_picture_and_its_3d_model() -> None:
    said = node(SETS + """
import { cardHtml } from "./web/card.js";
const card = (n) => S.catalogCard(S.catalogSet(n), models);
console.log(JSON.stringify({ falcon: card("10179-1"), explorer: card("10497-1"), chain: card("853900-1"),
  falconHtml: cardHtml(card("10179-1")), explorerHtml: cardHtml(card("10497-1")), chainHtml: cardHtml(card("853900-1")) }));""")
    assert said["falcon"]["id"] == "set-10179-1"
    assert said["falcon"]["library"]["picture"] == "/library/omr-10179-1.webp" and said["falcon"]["library"]["model3d"]
    assert said["falcon"]["modelled_by"] == {"name": "Roland Dahl", "page": "https://library.ldraw.org/omr/sets/320"}
    assert said["explorer"]["library"]["picture"] == "/library/set/10497-1.jpg"
    assert said["chain"]["library"]["picture"] == ""
    falcon = said["falconHtml"]
    assert 'href="/library/set/10179-1"' in falcon and 'src="/library/omr-10179-1.webp"' in falcon
    assert 'class="pill good model3d"' in falcon and 'data-model3d="yes"' in falcon
    assert '<small class="set">10179-1 · Star Wars · 2007</small>' in falcon
    explorer = said["explorerHtml"]
    assert 'href="/library/set/10497-1"' in explorer and 'src="/library/set/10497-1.jpg"' in explorer
    assert "model3d" not in explorer and "Modelled by" not in explorer
    assert "No picture" in said["chainHtml"]


@needs_node
def test_what_a_person_owns_is_taken_lot_by_lot() -> None:
    said = node("""
import { ownedOf } from "./api/_sets.js";
// A key as api/_owned.js keyed makes one: a mould's letter off, a part nobody knows left out.
const keyOf = ([part, colour, qty]) => (part === "unknown" ? null : { part: part.replace(/a$/, ""), colour, qty });
const rows = [["3001", 4, 10], ["3794a", 0, 3], ["3794", 0, 2], ["unknown", 1, 5], ["3003", 1, 2]];
const pool = [{ part: "3001", colour: 4, qty: 6 }, { part: "3794", colour: 0, qty: 4 }, { part: "3003", colour: 1, qty: 9 }];
console.log(JSON.stringify(ownedOf(rows, pool, keyOf)));""")
    # 3794a and 3794 share the four owned: three to the first, one to the next.
    assert said == {"pieces": 17, "have": 12, "missing": [["3001", 4, 4], ["3794", 0, 1]]}


@needs_node
def test_a_set_s_page_says_what_it_is_credits_its_data_and_sells_nothing() -> None:
    said = node(SETS + """
import { cardHtml } from "./web/card.js";
const chrome = { head: "", header: "<header></header>", footer: "<footer></footer>" };
const page = (n, extra = {}) => S.setPage({ origin: "https://brickworks.test", entry: S.catalogSet(n), chrome,
  held: models.get(n.toLowerCase()) || null, cardHtml, ...extra });
const lots = [{ count: 48, name: "Slope Brick 31 1 x 2 x 0.667", colour_name: "Light Bluish Grey" },
  { count: 12, name: "Plate 1 x 2", colour_name: "Blue" }];
console.log(JSON.stringify({ falcon: page("10179-1", { inside: [[S.catalogSet("4488-1"), 2]] }),
  explorer: page("10497-1", { lots }), chain: page("853900-1"),
  brief: S.starterBrief(S.catalogSet("10497-1"), lots), files: S.sitemapSets(catalog.sets, "https://b.test") }));""")
    falcon, explorer, chain = said["falcon"], said["explorer"], said["chain"]
    for page in (falcon, explorer, chain):
        assert 'Set and inventory data: <a href="https://rebrickable.com/">Rebrickable</a>' in page
        data = re.findall(r'<script type="application/ld\+json">(.*?)</script>', page)
        assert data and '"@type":"CreativeWork"' in data[0] and '"@type":"BreadcrumbList"' in data[0]
        # Never a product: no offer, no price, and nobody's photograph.
        assert not re.search(r"Product|offers|price|cdn\.rebrickable|lego\.com", data[0] + page, re.I)
        assert "LEGO® set" in page
    assert '<link rel="canonical" href="https://brickworks.test/library/set/10179-1">' in falcon
    # Its LDraw model: Build it in 3D in the app, its page, and both models listed.
    assert 'href="/app?new=1&amp;library=omr-10179-1" data-build3d' in falcon
    assert 'href="/library/omr-10179-1">a page of its own' in falcon and "/library/omr-10179-1_B" in falcon
    assert 'src="/library/omr-10179-1.cutout.webp"' in falcon
    assert 'href="/library/set/4488-1">2 × 4488-1 Millennium Falcon - Mini' in falcon
    assert '<a href="/library?theme=Star%20Wars%20%3E%20Ultimate%20Collector%20Series">Ultimate Collector Series</a>' in falcon
    # No model: its picture drawn from its parts, its parts into the app, and a brief to design with them.
    assert 'src="/library/set/10497-1.jpg"' in explorer and "data-build3d" not in explorer
    assert 'href="/app?new=1&amp;parts=10497-1" data-bin' in explorer
    assert "/app?new=1&amp;assistant=on&amp;parts=10497-1&amp;brief=Design%20something%20new" in explorer
    assert 'data-parts="/library/set/10497-1/parts.json"' in explorer and 'id="owned" data-set="10497-1"' in explorer
    assert said["brief"].startswith("Design something new of your own with the parts of LEGO® set 10497-1 Galaxy Explorer")
    assert "48 × Slope Brick 31 1 x 2 x 0.667 in Light Bluish Grey" in said["brief"]
    # Nothing to build: not for a search engine, and nothing to open.
    assert '<meta name="robots" content="noindex">' in chain and "data-bin" not in chain and 'id="owned"' not in chain
    assert '<meta name="robots"' not in explorer
    # Every set with parts in the sitemaps, the key chain not.
    assert said["files"] == [[f"https://b.test/library/set/{n}" for n in ["10179-1", "10497-1", "42115-1", "4488-1", "214.1-1"]]]


SITE = f"""
Object.assign(process.env, {{ SUPABASE_URL: "https://db.test", SUPABASE_SECRET_KEY: "secret",
  SUPABASE_PUBLISHABLE_KEY: "public", PARTS_URL: "https://store.test/parts/" }});
delete process.env.PUBLIC_ORIGIN;
const S = await import("./api/_sets.js");
S.useCatalog({json.dumps(CATALOG)});
const shelf = JSON.stringify({{ models: [] }});
const asked = [];
globalThis.fetch = async (url) => {{
  asked.push(String(url));
  if (String(url).endsWith("library/index.json")) return new Response(shelf);
  return new Response("", {{ status: 404 }});
}};
const {{ default: handler }} = await import("./api/share.js");
async function call(query, headers = {{}}) {{
  const said = {{}};
  let status = 200, body = "";
  const response = {{
    setHeader(k, v) {{ said[k.toLowerCase()] = v; return this; }},
    status(s) {{ status = s; return this; }},
    json(o) {{ body = o; return this; }},
    end(b) {{ body = String(b); return this; }},
  }};
  await handler({{ method: "GET", query, headers: {{ host: "brickworks.test", "x-forwarded-proto": "https", ...headers }} }}, response);
  return {{ status, headers: said, body }};
}}
"""


@needs_node
def test_the_site_answers_the_list_the_pages_and_the_sitemaps() -> None:
    said = node(SITE + """
const list = await call({ op: "library", q: "falcon" });
const page = await call({ op: "catalog_set", set: "853900-1" });
const none = await call({ op: "catalog_set", set: "nosuch-1" });
const index = await call({ op: "sitemap_index" });
const first = await call({ op: "sitemap_sets", n: "1" });
const past = await call({ op: "sitemap_sets", n: "2" });
const owned = await call({ op: "catalog_owned", set: "10497-1" });
console.log(JSON.stringify({ list: { status: list.status, total: list.body.total, of: list.body.of,
  ids: list.body.models.map((one) => one.id), years: list.body.years.length, credit: list.body.credit },
  page: [page.status, page.headers["cache-control"], page.body.includes("Key Chain Falcon")], none: none.status,
  index: index.body, first: (first.body.match(/<loc>/g) || []).length, past: past.status, owned: owned.status,
  db: asked.filter((one) => one.startsWith("https://db.test/rest")).length }));""")
    assert said["list"] == {"status": 200, "total": 3, "of": 6, "ids": ["set-853900-1", "set-10179-1", "set-4488-1"],
                            "years": 5, "credit": {"name": "Rebrickable", "url": "https://rebrickable.com/"}}
    assert said["page"] == [200, "public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800", True]
    assert said["none"] == 404
    assert "<loc>https://brickworks.test/sitemap.xml</loc>" in said["index"]
    assert "<loc>https://brickworks.test/sitemaps/sets-1.xml</loc>" in said["index"] and "sets-2.xml" not in said["index"]
    assert said["first"] == 5 and said["past"] == 404
    # What somebody owns is theirs: nobody signed in is refused, and nothing asked of the database.
    assert said["owned"] == 401 and said["db"] == 0


@needs_node
def test_the_flat_lay_is_laid_out_in_cells() -> None:
    said = node("""
import { cells, drawFlatLay } from "./api/_flatlay.js";
const empty = drawFlatLay([], {}, { width: 40, height: 20 });
console.log(JSON.stringify({ six: cells(6, 1200, 630).map((c) => [Math.round(c.x), Math.round(c.y)]),
  four: cells(4, 1200, 630).length, one: cells(1, 1200, 630)[0].w, ground: [...empty.data.slice(0, 4)],
  foot: [...empty.data.slice(-4)] }));""")
    assert said["six"] == [[38, 38], [413, 38], [787, 38], [38, 315], [413, 315], [787, 315]]
    assert said["four"] == 4 and round(said["one"]) == 1124
    # On the renders' own ground, top to foot (site.css --render-top, --render-foot).
    assert said["ground"] == [237, 239, 244, 255]
    assert said["foot"] == [204, 211, 221, 255]
