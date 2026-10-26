"""A model's page, /m/<id> (api/share.js, docs/SOCIAL.md U4), made by the
real handler from the design stand-in's world (tools/web/design_stand_in.mjs),
with no network: its action bar says each button's name and count and never
a count of none, and it ends with more by its designer and similar models
only when there are three of each, in the order they should come, and is
still drawn, without them, when the database will not say.

tools/web/model_page_flow.mjs proves the same page in a browser."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


# A photo the watchtower's own designer, Robin, posted of it: the stand-in
# has none, so the test adds it to what the database answers.
OWNERS_PHOTO = {"id": "PhotoOwn01", "model": "DesignAbc1", "account": "11111111-1111-4111-8111-111111111111",
                "words": "The banner, in the evening light.", "width": 1200, "height": 900,
                "at": "2026-10-01T10:00:00Z", "hidden_at": None}


def pages(*paths: str, failing: str = "", owners_photo: bool = False) -> list[dict] | None:
    """Each of [paths] as the server makes it: {status, html}. With
    [failing], every database request whose address has it answers 500;
    with [owners_photo], the watchtower has a photo by its designer, the
    oldest of its photos."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/m/DesignAbc1');"
        f"const failing = {json.dumps(failing)};"
        "if (failing) { const real = globalThis.fetch;"
        "  globalThis.fetch = async (input, init) => String(input.url || input).includes(failing)"
        "    ? new Response('{}', { status: 500 }) : real(input, init); }"
        f"const owners = {json.dumps(OWNERS_PHOTO if owners_photo else None)};"
        "if (owners) { const real = globalThis.fetch;"
        "  globalThis.fetch = async (input, init) => { const url = String(input.url || input);"
        "    const answer = await real(input, init);"
        "    if (!/build_photos\\?model=eq\\.DesignAbc1&/.test(url)) return answer;"
        "    const rows = await answer.json(); return new Response(JSON.stringify([...rows, owners]),"
        "      { status: 200, headers: { 'content-type': 'application/json' } }); }; }"
        "const out = [];"
        f"for (const path of {json.dumps(list(paths))}) {{ const r = await s.serverPage('api', path);"
        "  out.push({ status: r.status, html: r.html }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def row(html: str, key: str) -> list[str] | None:
    """The ids of the cards in the page's row [key] ("more-by", "similar"),
    or None for no row."""
    found = re.search(rf'<section class="next" id="{key}"[\s\S]*?</section>', html)
    # A card is an article, its id its own (web/card.js).
    return re.findall(r'<article class="model" data-id="([A-Za-z0-9]{10})"', found.group(0)) if found else None


def labels(html: str) -> list[str]:
    bar = re.search(r'<div class="action-bar" id="marks"[\s\S]*?</details></div>', html)
    assert bar, "no action bar"
    return re.findall(r'(?:<button|<summary)[^>]*aria-label="([^"]*)"', bar.group(0))


def test_the_watchtower_leads_on_to_more_by_its_designer_and_nothing_less_than_three() -> None:
    said = pages("/m/DesignAbc1")
    if said is None:
        return
    page = said[0]
    assert page["status"] == 200
    # Robin's other three, by Top builds: the gearbox (22 built, Tested), the
    # fox (14), the bridge (4).
    assert row(page["html"], "more-by") == ["DesignGea1", "DesignFox1", "DesignBrg1"]
    assert 'More by <a href="/u/design-tester">Robin Castell</a>' in page["html"]
    # Two castles share its kind and a tag, and one of them is its own remix,
    # shown in Remixes already: one card, so no row.
    assert row(page["html"], "similar") is None


def test_its_remix_leads_on_to_similar_models_by_tags_then_kind_then_top_builds() -> None:
    said = pages("/m/DesignRmx1")
    if said is None:
        return
    page = said[0]
    # Jo has no other model in the gallery: no row.
    assert row(page["html"], "more-by") is None
    # The gatehouse and the watchtower share its kind and "castle" (the
    # gatehouse first, by Top builds); the night tram only "night".
    assert row(page["html"], "similar") == ["DesignPar1", "DesignAbc1", "MikaTram01"]


def test_the_action_bar_says_each_name_and_count_and_never_a_count_of_none() -> None:
    said = pages("/m/DesignAbc1", "/m/DesignFox1")
    if said is None:
        return
    tower, fox = (one["html"] for one in said)
    assert labels(tower) == ["Like, 96 likes", "Save", "Share", "Comment", "I built it, 37 builds", "More"]
    assert labels(fox) == ["Like, 33 likes", "Save", "Share", "Comment", "I built it, 14 builds", "More"]
    for html in (tower, fox):
        assert not re.search(r'class="n"[^>]*>0<', html)
        assert not re.search(r">0 (views|likes|remixes|built)<", html)
        # What the buttons do is in their names and the FAQ, not a paragraph.
        assert "View in 3D turns it" not in html
        assert '>Build it</a>' in html and ">Open in Brickworks</a>" in html
        # Share opens its sheet: the link and the embed code, each with Copy.
        assert 'aria-controls="share-sheet"' in html
        sheet = re.search(r'<dialog class="share-sheet" id="share-sheet"[\s\S]*?</dialog>', html).group(0)
        assert re.search(r'<input id="share-link" value="http://design\.test/m/[A-Za-z0-9]{10}" readonly', sheet)
        assert '<textarea id="share-embed" rows="4" readonly spellcheck="false">&lt;iframe src=&quot;http://design.test/m/' in sheet
        assert 'data-copy="share-link">Copy link</button>' in sheet and 'data-copy="share-embed">Copy code</button>' in sheet
        # The embed code is in the sheet, not in More.
        assert "data-embed" not in html
    # The fox has no remix and nobody has seen 0 of anything: no pill says so.
    assert "remixes</a>" not in fox


def test_the_page_is_drawn_without_what_comes_next_when_the_database_will_not_say() -> None:
    said = pages("/m/DesignAbc1", failing="rpc/directory_models")
    if said is None:
        return
    page = said[0]
    assert page["status"] == 200
    assert row(page["html"], "more-by") is None and row(page["html"], "similar") is None
    assert "<h1>Riverside Watchtower</h1>" in page["html"]


def strip(html: str) -> list[str] | None:
    """What the strip under the picture links to, in order, or None when it
    is drawn hidden."""
    found = re.search(r'<div class="media-strip" id="pictures"([^>]*)>([\s\S]*?)</div>', html)
    assert found, "no strip"
    if "hidden" in found.group(1):
        return None
    return re.findall(r'<a class="thumb" href="([^"]+)"', found.group(2))


def tabs(html: str) -> list[str]:
    nav = re.search(r'<nav class="tabs page-tabs" id="page-tabs"[\s\S]*?</nav>', html)
    assert nav, "no tabs"
    return [re.sub(r"<[^>]+>", "", one).strip() for one in re.findall(r"<a [^>]*>([\s\S]*?)</a>", nav.group(0))]


def test_the_strip_leads_with_the_published_picture_then_the_owners_photos_then_builds() -> None:
    said = pages("/m/DesignAbc1", "/m/SamModel02", owners_photo=True)
    if said is None:
        return
    tower, bakery = (one["html"] for one in said)
    # The owner's photo is the oldest, yet it comes before the builds by
    # Priya (16 October) and Jo (12 October), newest first.
    assert strip(tower) == ["/m/DesignAbc1.cutout.png", "#photo-PhotoOwn01", "#photo-PhotoBbb02", "#photo-PhotoAaa01"]
    assert 'alt="Riverside Watchtower, a photo by its designer"' in tower
    assert re.search(r'<a class="thumb" href="/m/DesignAbc1.cutout.png"[^>]*aria-current="true"', tower)
    # The picture with nothing behind the model, on the theme's own ground
    # (docs/SOCIAL.md U15); in the strip, whose frames are four to three,
    # the cards' picture, which is too.
    assert re.search(r'<a class="picture" [^>]*>.*?<img src="/m/DesignAbc1.cutout.png"', tower, flags=re.S)
    assert re.search(r'<a class="thumb" href="/m/DesignAbc1.cutout.png" '
                     r'data-picture="/m/DesignAbc1.cutout.png"[^>]*><img src="/m/DesignAbc1.webp\?v=[a-z0-9]+"', tower)
    # And in Built by people, the same order.
    assert re.findall(r'<figure class="build" id="photo-([A-Za-z0-9]{10})"', tower) == [
        "PhotoOwn01", "PhotoBbb02", "PhotoAaa01"]
    # No photo: drawn hidden, for its owner's Add a picture alone.
    assert strip(bakery) is None
    assert "data-add-picture hidden" in bakery


def test_the_tabs_say_each_part_and_its_count_never_one_of_none() -> None:
    said = pages("/m/DesignAbc1", "/m/SamModel02")
    if said is None:
        return
    tower, bakery = (one["html"] for one in said)
    # Comments are counted as they are listed, in the page (model-page.js).
    # Parts, counted from the file as the app counts it (api/_parts.js): the
    # stand-in's file is three bricks.
    assert tabs(tower) == ["About", "Parts 3", "Comments", "Builds 37", "Remixes 3", "Collections 2", "Versions 2"]
    assert tabs(bakery) == ["About", "Parts 3", "Comments", "Builds", "Remixes"]
    for html in (tower, bakery):
        for key in ("about", "comments", "builds", "remixes"):
            assert f'id="{key}"' in html, key
    assert 'id="versions"' in tower and 'id="versions"' not in bakery
    # In no collection: no tab, no part, no pill.
    assert 'id="collections"' not in bakery and 'href="#collections"' not in bakery


def test_a_model_says_how_many_collections_it_is_in_and_links_them() -> None:
    """docs/SOCIAL.md U11: "In 2 collections", a pill linked to its part of
    the page, where each public collection it is in is a card with its
    cover and whose it is; a private one is neither counted nor shown."""
    said = pages("/m/DesignAbc1", "/m/PriyaSpc01")
    if said is None:
        return
    tower, rover = (one["html"] for one in said)
    assert '<a class="pill" href="#collections" data-lists="2">In 2 collections</a>' in tower
    part = re.search(r'<section class="in-lists" id="collections"[\s\S]*?</section>', tower).group(0)
    cards = re.findall(r'<a class="list-card" href="/c/([A-Za-z0-9]{10})"', part)
    # Sam's was put in last (updated last), then Robin's.
    assert cards == ["SamListAa1", "ListAbcde1"]
    # The footbridge has no picture yet: Sam's cover is of two.
    assert re.findall(r'<div class="mosaic n(\d)">', part) == ["2", "3"]
    assert "Castles to build" in part and "3 models · Sam Okafor" in part
    # The Lunar Rover is only in Sam's private list.
    assert 'href="#collections"' not in rover and 'id="collections"' not in rover


def test_a_collection_page_leads_with_its_cover_follow_and_share() -> None:
    """/c/<id> (api/people.js listPage): its cover of its models' pictures
    beside its name, whose, its numbers (followers once there are some),
    Follow (shown by web/follow.js), Share and More with Report it."""
    said = pages("/c/ListAbcde1", "/c/ListSmall1")
    if said is None:
        return
    castles, small = (one["html"] for one in said)
    head = re.search(r'<header class="list-head">[\s\S]*?</header>', castles).group(0)
    assert '<div class="cover"><div class="mosaic n3">' in head
    assert "<h1>Castles worth a weekend</h1>" in head and 'Collected by <a href="/u/design-tester">Robin Castell</a>' in head
    assert '<li data-stat="models"><b>3</b> <span>models</span></li>' in head
    assert '<li data-stat="followers" data-list-followers="ListAbcde1"><b>3</b> <span>followers</span></li>' in head
    assert 'data-follow-list="ListAbcde1" hidden>Follow</button>' in head
    assert 'data-share="http://design.test/c/ListAbcde1" hidden' in head and 'data-report-collection="ListAbcde1"' in head
    assert '<script src="/person.js" type="module"></script>' in castles
    # Nobody follows the small one: its count is on the page for the
    # script, hidden, never "0 followers".
    assert '<li data-stat="followers" data-list-followers="ListSmall1" hidden><b>0</b>' in small
    assert not re.search(r">0 followers<", small)


def test_a_model_nobody_has_built_or_remixed_says_so_once_with_the_way_in() -> None:
    said = pages("/m/SamModel02")
    if said is None:
        return
    page = said[0]["html"]
    builds = re.search(r'<section class="builds"[\s\S]*?<div class="add-build"', page).group(0)
    assert re.findall(r"<p[^>]*>([\s\S]*?)</p>", builds) == ["Nobody has built it yet. Built it? Add a photo of yours."]
    remixes = re.search(r'<section class="tree" id="remixes"[\s\S]*?</section>', page).group(0)
    assert "Nobody has remixed it yet." in remixes and 'href="/app?copy=SamModel02"' in remixes
    assert not re.search(r">0 |\b0 (views|likes|remixes|built|builds)\b", page)


def test_with_neither_row_the_page_ends_on_the_gallerys_own() -> None:
    said = pages("/m/SamModel02", "/m/DesignAbc1")
    if said is None:
        return
    bakery, tower = (one["html"] for one in said)
    # Sam's bakery: no credit, no kind's or tags' three; the gallery's Top.
    assert row(bakery, "more-by") is None and row(bakery, "similar") is None
    shown = row(bakery, "from-gallery")
    assert shown and 1 <= len(shown) <= 6 and "SamModel02" not in shown
    # A page with a row of its own does not add the gallery's.
    assert row(tower, "from-gallery") is None
