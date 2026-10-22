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


def pages(*paths: str, failing: str = "") -> list[dict] | None:
    """Each of [paths] as the server makes it: {status, html}. With
    [failing], every database request whose address has it answers 500."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/m/DesignAbc1');"
        f"const failing = {json.dumps(failing)};"
        "if (failing) { const real = globalThis.fetch;"
        "  globalThis.fetch = async (input, init) => String(input.url || input).includes(failing)"
        "    ? new Response('{}', { status: 500 }) : real(input, init); }"
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
    return re.findall(r'<a class="model" href="/m/([A-Za-z0-9]{10})"', found.group(0)) if found else None


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
        assert 'data-embed="&lt;iframe src=&quot;http://design.test/m/' in html
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
