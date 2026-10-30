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
    assert 'src="/api/people?op=photo_file&amp;id=PhotoAbc01"' in drawn
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
