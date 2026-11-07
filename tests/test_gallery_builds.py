"""The gallery's Builds tab (docs/SOCIAL.md section 7, item 8), held to what it promises.

Everybody's photos of real builds, newest first, a page of 24 at a time, each
linked to its model and its builder (api/_builds.js galleryBuilds,
/api/people?op=builds). A photo is there only while it may be shown anywhere
and nobody's report of it waits: never one hidden by the model's owner, taken
out, reported, of a model not listed or taken out, by an account taken out or
under 13, nor a test model's unless asked. Here the question asked of the
database and the page made of its rows, by the two pure functions the tab is
made of; tools/web/gallery_builds_flow.mjs drives it in a browser.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from urllib.parse import parse_qsl, unquote

ROOT = Path(__file__).resolve().parent.parent
PEOPLE = (ROOT / "api/people.js").read_text()
BUILDS_JS = (ROOT / "web/builds.js").read_text()
BUILDS_HTML = (ROOT / "web/builds.html").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()


def node(script: str):
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def query(**options) -> tuple[str, dict]:
    path = node(f"""
import {{ buildsQuery }} from "./api/_builds.js";
console.log(JSON.stringify(buildsQuery({json.dumps(options)})));
""")
    table, _, rest = path.partition("?")
    asked: dict[str, list[str]] = {}
    for key, value in parse_qsl(rest, keep_blank_values=True):
        asked.setdefault(key, []).append(unquote(value))
    return table, asked


BARRED = "00000000-0000-4000-8000-0000000000a1"


def test_it_asks_only_what_may_be_shown() -> None:
    table, asked = query(page=1, tests=False, barred=[BARRED], waiting=["PhotoRep01"])
    assert table == "build_photos"
    # Not hidden by the model's owner, not taken out, nobody's report waiting.
    assert asked["hidden_at"] == ["is.null"] and asked["removed_at"] == ["is.null"]
    assert asked["id"] == ["not.in.(PhotoRep01)"]
    # Its model listed, published, not taken out, not a test model, its
    # designer and its builder not taken out.
    for key, value in (("shared_models.published", "is.true"), ("shared_models.listed", "is.true"),
                       ("shared_models.barred", "is.false"), ("shared_models.test", "is.false"),
                       ("shared_models.owner", f"not.in.({BARRED})"), ("account", f"not.in.({BARRED})")):
        assert asked[key] == [value], key
    assert "shared_models!inner(" in asked["select"][0]


def test_newest_first_a_page_of_24_and_one_more_to_know() -> None:
    _, first = query(page=1, tests=False, barred=[], waiting=[])
    _, third = query(page=3, tests=True, barred=[], waiting=[])
    assert first["order"] == ["at.desc,id.desc"]
    assert first["limit"] == ["25"] and first["offset"] == ["0"]
    assert third["limit"] == ["25"] and third["offset"] == ["48"]
    # A probe's own (tests) asks test models too; nobody barred, nothing waiting: no empty lists.
    assert "shared_models.test" not in third and "id" not in third and "account" not in third


def test_a_search_asks_for_every_word_in_the_model_built() -> None:
    # The gallery's one search box asks the Builds tab too (web/gallery.js):
    # every word in the model's name, whatever its case, and nothing else of
    # what was typed.
    _, asked = query(page=1, tests=False, barred=[], waiting=[], q="Red  castle, (tower)*")
    assert asked["shared_models.name"] == ["ilike.*Red*", "ilike.*castle*", "ilike.*tower*"]
    _, unasked = query(page=1, tests=False, barred=[], waiting=[], q="  ")
    assert "shared_models.name" not in unasked


def page(rows: list, **options) -> dict:
    return node(f"""
import {{ buildsPage }} from "./api/_builds.js";
console.log(JSON.stringify(buildsPage({json.dumps(rows)}, {json.dumps(options)})));
""")


def row(n: int, account: str = "a1", words=None) -> dict:
    return {"id": f"Photo{n:05}", "model": f"Model{n:05}", "account": account, "words": words, "width": 1200,
            "height": 900, "at": f"2026-10-{30 - n % 28:02}T12:00:00Z",
            "shared_models": {"name": f"Tower <{n}>", "owner": "o1"}}


def test_each_photo_says_its_model_and_its_builder() -> None:
    said = page([row(1, "a1", "  It   stands. "), row(2, "a2")], origin="https://x.test",
                people={"a1": {"handle": "jo-builds", "name": "Jo"}}, unshown=[])
    first, second = said["photos"]
    assert first == {"id": "Photo00001", "model": "Model00001", "model_name": "Tower <1>", "words": "It stands.",
                     "width": 1200, "height": 900, "at": "2026-10-29T12:00:00Z",
                     "by": {"handle": "jo-builds", "name": "Jo"},
                     "url": "https://x.test/api/people?op=photo_file&id=Photo00001",
                     "card": "https://x.test/api/people?op=photo_file&id=Photo00001&size=card",
                     "page": "https://x.test/m/Model00001#photo-Photo00001"}
    # A builder with no profile is nobody's link.
    assert second["by"] is None and second["words"] is None
    assert said["more"] is False


def test_a_builder_not_shown_in_public_is_left_out() -> None:
    said = page([row(1, "a1"), row(2, "young"), row(3, "a1")], origin="", people={}, unshown=["young"])
    assert [one["id"] for one in said["photos"]] == ["Photo00001", "Photo00003"]


def test_the_25th_row_says_there_is_more_and_is_not_shown() -> None:
    said = page([row(n) for n in range(1, 26)], origin="", people={}, unshown=[])
    assert len(said["photos"]) == 24 and said["more"] is True
    assert page([row(n) for n in range(1, 25)], origin="", people={}, unshown=[])["more"] is False


def test_the_tab_asks_the_api_and_says_none_in_its_own_words() -> None:
    assert 'op === "builds"' in PEOPLE and "galleryBuilds(" in PEOPLE
    assert "op=builds" in BUILDS_JS and "buildCard(" in BUILDS_JS
    empty = BUILDS_HTML[BUILDS_HTML.index('id="builds-empty"'):]
    empty = empty[:empty.index("</div>")]
    assert "I built it" in empty and 'href="/gallery"' in empty


def test_it_is_a_tab_of_the_gallery_beside_top_new_and_collections() -> None:
    # Marked on its own page; a tab on the gallery's and the LDraw library's.
    tabs = BUILDS_HTML[BUILDS_HTML.index('<nav class="tabs"'):]
    tabs = tabs[:tabs.index("</nav>")]
    assert '<a href="/builds" data-tab="builds" aria-current="page">Builds</a>' in tabs
    for page in ("gallery.html", "library.html"):
        html = (ROOT / "web" / page).read_text()
        tabs = html[html.index('<nav class="tabs"'):]
        tabs = tabs[:tabs.index("</nav>")]
        links = re.findall(r'<a href="([^"]+)"', tabs)
        assert "/builds" in links, page
        assert links.index("/builds") == links.index("/collections") - 1, page


def card(photo: dict) -> str:
    return subprocess.run(["node", "--input-type=module", "-e", f"""
import {{ buildCardHtml }} from "./web/card.js";
console.log(buildCardHtml({json.dumps(photo)}));
"""], cwd=ROOT, check=True, capture_output=True, text=True).stdout


def test_a_card_links_its_model_and_builder_and_says_every_word_as_text() -> None:
    drawn = card({"id": "PhotoAbc01", "model": "ModelAbc01", "model_name": "Keep <b>", "words": 'Took "a day" <script>',
                  "at": "2026-10-30T10:00:00Z", "width": 1200, "height": 900,
                  "by": {"handle": "kim-builds", "name": "Kim & Co"}})
    assert '<article class="model build-card" data-id="PhotoAbc01" data-model="ModelAbc01">' in drawn
    assert 'href="/m/ModelAbc01#photo-PhotoAbc01"' in drawn
    # The photo's copy at most 480 px wide, not the whole kept photo.
    assert 'src="/api/people?op=photo_file&amp;id=PhotoAbc01&amp;size=card"' in drawn
    assert 'href="/u/kim-builds"' in drawn and "Built by Kim &amp; Co" in drawn
    assert "Keep &lt;b&gt;" in drawn and "&lt;script&gt;" in drawn and "<script>" not in drawn and "<b>Keep" not in drawn
    assert 'alt="A build of Keep &lt;b&gt; by Kim &amp; Co"' in drawn
    assert '<time class="when" datetime="2026-10-30T10:00:00.000Z">30 Oct 2026</time>' in drawn


def test_a_builder_with_no_profile_shown_is_named_by_no_link() -> None:
    for by in (None, {"handle": "../evil", "name": "X"}):
        drawn = card({"id": "PhotoAbc02", "model": "ModelAbc01", "model_name": "Keep", "by": by})
        assert "/u/" not in drawn and "Built by a builder" in drawn


def test_its_flow_is_a_preview_check() -> None:
    assert "gallery_builds_flow.mjs" in CHECKS


def test_a_card_loads_a_copy_that_fills_its_card() -> None:
    # The Builds tab's cards loaded the whole kept photo, up to 1,600 px, for
    # a card a quarter of a laptop's width (socialtails). Each photo is kept
    # with a copy just large enough to cover a 4:3 card at 480 px, its shape
    # kept, never made larger: a copy bounded by its width alone was short of
    # pixels in a 4:3 card for a wide photo (streview, 1.5 to 1.74 times).
    got = node("""
import { encode } from "./api/_jpeg.js";
import { cardPhoto, cleanPhoto, decodePicture } from "./api/_photo.js";
import { buildCardHtml, cardSize, photoSrc } from "./web/card.js";
const photo = (width, height) => {
  const data = Buffer.alloc(width * height * 4, 200);
  return Buffer.from(encode({ width, height, data }, 85).data);
};
const out = {};
for (const [name, w, h] of [["landscape", 4000, 3000], ["wide", 4000, 2100], ["portrait", 1200, 1600], ["small", 300, 200]]) {
  const kept = await cleanPhoto(photo(w, h), "image/jpeg");
  const card = await decodePicture(kept.card.bytes, "image/jpeg");
  const again = await cardPhoto(kept.bytes);
  const size = cardSize(kept.width, kept.height);
  out[name] = { kept: [kept.width, kept.height], card: [card.width, card.height], said: [kept.card.width, kept.card.height],
    again: [again.width, again.height], size: [size.width, size.height], smaller: kept.card.bytes.length <= kept.bytes.length };
}
out.src = [photoSrc("PhotoAaa01"), photoSrc("PhotoAaa01", { card: true })];
out.html = /<img src="([^"]+)"/.exec(buildCardHtml({ id: "PhotoAaa01", model: "ModelAaa01", model_name: "A keep", width: 1600, height: 1200 }))[1];
out.none = cardSize(0, 900);
console.log(JSON.stringify(out));
""")
    assert got["landscape"] == {"kept": [1600, 1200], "card": [480, 360], "said": [480, 360], "again": [480, 360],
                                "size": [480, 360], "smaller": True}
    # Wide: 360 high, so a 4:3 card's 480 by 360 is filled.
    assert got["wide"]["kept"] == [1600, 840] and got["wide"]["card"] == [686, 360] == got["wide"]["size"]
    assert got["wide"]["again"] == [686, 360]
    assert got["portrait"]["kept"] == [1200, 1600] and got["portrait"]["card"] == [480, 640] == got["portrait"]["size"]
    assert got["small"]["kept"] == [300, 200] and got["small"]["card"] == [300, 200] and got["small"]["again"] == [300, 200]
    assert got["src"] == ["/api/people?op=photo_file&id=PhotoAaa01", "/api/people?op=photo_file&id=PhotoAaa01&size=card"]
    assert got["html"] == "/api/people?op=photo_file&amp;id=PhotoAaa01&amp;size=card"
    assert got["none"] == {"width": 0, "height": 0}


def test_every_place_a_photo_is_drawn_offers_the_copy_and_the_whole() -> None:
    # The copy was drawn at a whole column's width on a profile and 260 by
    # 190 on a model's page, 1.5 to 2.26 times its size (streview), and the
    # feed, Latest and Designs drew the whole photo where the copy would do.
    # Every place now gives the browser both, each described by its width
    # once cut to the place's shape, and how wide the place draws it.
    got = node("""
import { PHOTO_PLACES, photoAttrs, photoPicture } from "./web/card.js";
const wide = { id: "PhotoAaa01", width: 1600, height: 840 };
const out = {};
for (const place of Object.keys(PHOTO_PLACES)) out[place] = photoPicture(wide, place);
out.square = photoPicture({ id: "PhotoAaa01", width: 1080, height: 1080 }, "card");
out.small = photoPicture({ id: "PhotoAaa01", width: 300, height: 200 }, "card");
out.sizeless = photoPicture({ id: "PhotoAaa01" }, "columns");
out.attrs = photoAttrs(wide, "card");
out.eager = photoPicture(wide, "card", { lazy: false }).sizes;
console.log(JSON.stringify(out));
""")
    card, whole = "/api/people?op=photo_file&id=PhotoAaa01&size=card", "/api/people?op=photo_file&id=PhotoAaa01"
    # A 4:3 card cuts the 686 by 360 copy to 480 across, the whole to 1120.
    assert got["card"] == {"src": card, "srcset": f"{card} 480w, {whole} 1120w",
                           "sizes": "auto, (min-width: 900px) min(25vw, 382px), (min-width: 600px) 34vw, 50vw",
                           "card": "686x360", "whole": whole}
    assert got["thumb"]["srcset"] == f"{card} 480w, {whole} 1120w" and got["thumb"]["sizes"] == "auto, 96px"
    assert got["strip"]["srcset"] == f"{card} 432w, {whole} 1008w"
    assert got["builders"]["srcset"] == f"{card} 480w, {whole} 1120w"
    # Drawn whole, in columns and in the feed: each its own width.
    assert got["columns"]["srcset"] == f"{card} 686w, {whole} 1600w"
    assert got["feed"]["srcset"] == f"{card} 686w, {whole} 1600w" and got["feed"]["sizes"] == "auto, min(600px, 100vw)"
    assert got["square"]["srcset"] == f"{card} 480w, {whole} 1080w" and got["square"]["card"] == "480x480"
    # No larger than its copy: the copy alone. Of no size: the whole alone.
    assert got["small"] == {"src": card, "srcset": "", "sizes": "", "card": "", "whole": ""}
    assert got["sizeless"]["src"] == whole and got["sizeless"]["srcset"] == ""
    # Chrome reads an eager picture's "auto" as the whole window: none there.
    assert got["eager"] == "(min-width: 900px) min(25vw, 382px), (min-width: 600px) 34vw, 50vw"
    assert got["attrs"].startswith('src="/api/people?op=photo_file&amp;id=PhotoAaa01&amp;size=card" srcset="')
    assert 'data-card="686x360" data-whole="/api/people?op=photo_file&amp;id=PhotoAaa01"' in got["attrs"]
    # Every place draws through it: no page asks for the copy alone, nor
    # draws the whole photo from an answer's url.
    drawn = {"web/card.js": 'photoAttrs(photo, "card", { lazy: !eager })', "api/people.js": 'photoAttrs(one, "columns")',
             "api/share.js": 'photoAttrs(photo, "strip")', "web/profile.js": 'setPhoto(img, photo, "columns")',
             "web/model-page.js": 'setPhoto(img, photo, "strip")', "web/designs.js": 'setPhoto(picture, one, "builders")',
             "web/feed.js": 'setPhoto(img, one.photo, "feed")'}
    for name, call in drawn.items():
        assert call in (ROOT / name).read_text(), name
    assert 'photoAttrs(photo, "thumb", { lazy })' in (ROOT / "api/share.js").read_text()
    assert 'setPhoto(small, photo, "thumb")' in (ROOT / "web/model-page.js").read_text()
    assert 'setPhoto(img, one, "columns")' in (ROOT / "web/feed.js").read_text()
    for name in ("web/feed.js", "web/profile.js", "web/model-page.js", "web/designs.js", "web/builds.js", "api/people.js", "api/share.js"):
        text = (ROOT / name).read_text()
        assert "{ card: true }" not in text and ".photo.url" not in text and "here(one.url" not in text, name
    # Chrome takes the smaller of two pictures until the screen passes their
    # geometric mean, so each page watches its photos and gives the whole
    # where the copy would be drawn larger (sharpPhotos).
    for name in ("web/builds.js", "web/profile.js", "web/model-page.js", "web/designs.js", "web/feed.js", "web/photos.js"):
        assert "sharpPhotos(" in (ROOT / name).read_text(), name
    assert '<script src="/photos.js" type="module"></script>' in PEOPLE and 'photos: tab === "builds"' in PEOPLE


def test_each_answer_says_where_the_copy_is_too() -> None:
    for name in ("api/_follows.js", "api/_designers.js", "api/_builds.js", "api/people.js"):
        text = (ROOT / name).read_text()
        assert "photoUrls(origin," in text and "/api/people?op=photo_file&id=${" not in text, name


def test_a_copy_is_made_once_and_never_outlives_its_photo() -> None:
    # A photo kept before there were copies has one made the first time a
    # card asks, kept beside it; so has one whose copy is not the size the
    # pages describe it by (one made before copies covered a 4:3 card). Made
    # while the photo is taken out, or while its account's files are deleted
    # (api/account.js deletes them by name, then the rows), the copy goes
    # too: a red run's copies outlived their accounts so (socialtails,
    # 2026-11-06). A delete that fails is said in the log, for the sweep.
    got = node(r"""
process.env.SUPABASE_URL = "http://project.test";
process.env.SUPABASE_SECRET_KEY = "k";
import { encode } from "./api/_jpeg.js";
import { decodePicture } from "./api/_photo.js";
const files = new Map();
const row = { id: "PhotoAaa01", model: "ModelAaa01", account: "a", width: 1600, height: 840, removed_at: null, hidden_at: null };
let onPut = () => {};
let deleting = true;
const logged = [];
console.error = (...words) => logged.push(words.join(" "));
globalThis.fetch = async (url, init = {}) => {
  const where = new URL(url);
  const method = init.method || "GET";
  if (where.pathname.startsWith("/rest/v1/build_photos")) return new Response(JSON.stringify(row.gone ? [] : [row]), { status: 200 });
  if (where.pathname.startsWith("/rest/v1/shared_models")) return new Response(JSON.stringify([{ id: row.model }]), { status: 200 });
  const object = /^\/storage\/v1\/object\/build-photos\/(.+)$/.exec(where.pathname);
  if (object && method === "POST") { files.set(object[1], Buffer.from(init.body)); onPut(object[1]); return new Response("{}", { status: 200 }); }
  if (object) return files.has(object[1]) ? new Response(method === "HEAD" ? null : files.get(object[1]), { status: 200 }) : new Response("{}", { status: 400 });
  if (where.pathname === "/storage/v1/object/build-photos" && method === "DELETE") {
    if (!deleting) return new Response("{}", { status: 503 });
    for (const name of JSON.parse(init.body).prefixes) files.delete(name);
    return new Response("[]", { status: 200 });
  }
  return new Response("{}", { status: 404 });
};
const { photoFile } = await import("./api/_builds.js");
const jpeg = (width, height) => Buffer.from(encode({ width, height, data: Buffer.alloc(width * height * 4, 120) }, 85).data);
const whole = jpeg(1600, 840);
const size = async (bytes) => { const one = await decodePicture(bytes, "image/jpeg"); return [one.width, one.height]; };
const shown = async () => true;
const out = {};
files.set("PhotoAaa01.jpg", whole);
const first = await photoFile("PhotoAaa01", shown, { card: true });
out.made = [await size(first), [...files.keys()].sort()];
const again = await photoFile("PhotoAaa01", shown, { card: true });
out.kept = Buffer.compare(again, first) === 0;
// A copy kept under the old rule, 480 wide whatever its height: made again.
files.set("PhotoAaa01.card.jpg", jpeg(480, 252));
const remade = await photoFile("PhotoAaa01", shown, { card: true });
out.remade = [await size(remade), await size(files.get("PhotoAaa01.card.jpg"))];
// Its account deleted as the copy is made: the files by name, then the row.
files.clear(); files.set("PhotoAaa01.jpg", whole);
onPut = (name) => { if (name.endsWith(".card.jpg")) { files.delete("PhotoAaa01.jpg"); files.delete("PhotoAaa01.card.jpg"); files.set(name, Buffer.from("late")); } };
out.deleted = [await photoFile("PhotoAaa01", shown, { card: true }), [...files.keys()]];
// Taken out as the copy is made.
files.clear(); files.set("PhotoAaa01.jpg", whole);
onPut = (name) => { if (name.endsWith(".card.jpg")) row.removed_at = "2026-11-06T00:00:00Z"; };
out.taken = [await photoFile("PhotoAaa01", shown, { card: true }), [...files.keys()]];
// And storage refusing the copy's delete: said, not swallowed.
files.clear(); files.set("PhotoAaa01.jpg", whole); row.removed_at = null; deleting = false;
out.refused = [await photoFile("PhotoAaa01", shown, { card: true }), [...files.keys()].sort(), logged];
console.log(JSON.stringify(out));
""")
    assert got["made"] == [[686, 360], ["PhotoAaa01.card.jpg", "PhotoAaa01.jpg"]]
    assert got["kept"] is True
    assert got["remade"] == [[686, 360], [686, 360]]
    assert got["deleted"] == [None, []]
    assert got["taken"] == [None, ["PhotoAaa01.jpg"]]
    assert got["refused"][0] is None and got["refused"][1] == ["PhotoAaa01.card.jpg", "PhotoAaa01.jpg"]
    assert any("the card copy of PhotoAaa01 outlived its photo and was not deleted" in line and "503" in line
               for line in got["refused"][2]), got["refused"][2]


def test_the_sweep_deletes_a_photos_files_once_it_is_gone() -> None:
    # A copy could outlive its photo: a cleanup's failure was swallowed, a
    # rollback or another deployment deleted only <id>.jpg, and the daily
    # sweep never looked at build-photos (streview). It now deletes every
    # file of a photo with no row or taken out, over an hour old, says a
    # failure, and leaves everything else.
    got = node(r"""
process.env.SUPABASE_URL = "http://project.test";
process.env.SUPABASE_SECRET_KEY = "k";
process.env.SUPABASE_PUBLISHABLE_KEY = "p";
process.env.CRON_SECRET = "cron";
const now = Date.now();
const old = new Date(now - 2 * 3600 * 1000).toISOString();
const young = new Date(now - 10 * 60 * 1000).toISOString();
const listed = (name, at) => ({ name, id: name, updated_at: at });
let photos = [listed("LiveAaaa01.jpg", old), listed("LiveAaaa01.card.jpg", old), listed("GoneAaaa02.card.jpg", old),
  listed("TakeAaaa03.jpg", old), listed("TakeAaaa03.card.jpg", old), listed("YoungAaa04.card.jpg", young),
  listed("notes.txt", old), listed("HideAaaa05.jpg", old)];
const rows = [{ id: "LiveAaaa01", removed_at: null }, { id: "TakeAaaa03", removed_at: "2026-11-01T00:00:00Z" },
  { id: "HideAaaa05", removed_at: null }];
let deleting = true;
const deleted = [];
const logged = [];
console.error = (...words) => logged.push(words.join(" "));
globalThis.fetch = async (url, init = {}) => {
  const where = new URL(url);
  const method = init.method || "GET";
  if (where.pathname === "/storage/v1/object/list/build-photos") return new Response(JSON.stringify(photos), { status: 200 });
  if (where.pathname.startsWith("/storage/v1/object/list/")) return new Response("[]", { status: 200 });
  if (where.pathname === "/storage/v1/object/build-photos" && method === "DELETE") {
    if (!deleting) return new Response("{}", { status: 503 });
    deleted.push(...JSON.parse(init.body).prefixes);
    return new Response("[]", { status: 200 });
  }
  if (where.pathname === "/rest/v1/build_photos") {
    const ids = /^in\.\((.*)\)$/.exec(where.searchParams.get("id"))[1].split(",");
    return new Response(JSON.stringify(rows.filter((row) => ids.includes(row.id))), { status: 200 });
  }
  if (method === "DELETE") return new Response(null, { status: 204 });
  return new Response("[]", { status: 200 });
};
const { photosGone } = await import("./api/_builds.js");
const share = (await import("./api/share.js")).default;
const sweep = async (query) => {
  const response = { statusCode: 200, body: "", setHeader() { return this; }, status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; return this; }, end() { return this; } };
  await share({ method: "GET", query: { op: "sweep", ...query }, headers: { authorization: "Bearer cron" } }, response);
  return [response.statusCode, response.body.photos];
};
const out = {};
out.pure = photosGone([{ name: "AaaaAaaa01.jpg", at: old }, { name: "BbbbBbbb02.card.jpg", at: young }], [], { now, age: 3600000 });
out.daily = await sweep({});
out.deleted = deleted.splice(0);
// One photo asked by name: its files whatever their age, nothing else.
out.one = await sweep({ only: "NoModel001", photos: "YoungAaa04" });
out.oneDeleted = deleted.splice(0);
// A model asked alone: no photo looked at.
out.models = await sweep({ only: "NoModel001" });
// Storage refusing: said in the log and the answer, the sweep answered.
deleting = false;
out.refused = await sweep({});
out.logged = logged;
console.log(JSON.stringify(out));
""")
    assert got["pure"] == ["AaaaAaaa01.jpg"]
    status, said = got["daily"]
    assert status == 200 and said["looked_at"] == 7
    # No row, or taken out: gone. Live, hidden, young, or no photo's name: kept.
    assert sorted(said["removed"]) == ["GoneAaaa02.card.jpg", "TakeAaaa03.card.jpg", "TakeAaaa03.jpg"]
    assert sorted(got["deleted"]) == sorted(said["removed"])
    assert got["one"] == [200, {"looked_at": 1, "removed": ["YoungAaa04.card.jpg"]}]
    assert got["oneDeleted"] == ["YoungAaa04.card.jpg"]
    assert got["models"] == [200, None]
    assert got["refused"][0] == 200 and "503" in got["refused"][1]["trouble"]
    assert any(line.startswith("sweep: build photos:") and "503" in line for line in got["logged"]), got["logged"]


def test_the_copy_is_served_kept_and_deleted_with_its_photo() -> None:
    builds = (ROOT / "api/_builds.js").read_text()
    # Asked for with size=card; kept beside the photo when it is posted, made
    # the first time for one posted before; deleted with it however it goes.
    assert '{ card: String(request.query?.size || "") === "card" }' in PEOPLE
    assert "await putFile(PHOTOS, cardName(id), made.card.bytes" in builds
    assert builds.count("deleteFiles(PHOTOS, [photoName(id), cardName(id)])") == 2
    assert "${one.id}.card.jpg" in (ROOT / "api/account.js").read_text()
