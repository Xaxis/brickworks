"""The home page's first screen as the deploy writes it (landing, 2026-11-22).

tools/web/home_shelf.mjs writes the shelf's cards and the month's challenge
into web/index.html's copy at the deploy, from the live gallery or from
web/_home.json. These drive its real decide() and filled() on the page as it
is in this checkout: a deploy that could read nothing, today's gallery, a
busy week, a language's copy, and a test challenge.
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

ASKS = {
    "trending": "/api/share?op=list&page=1&sort=top&window=week",
    "top": "/api/share?op=list&page=1&sort=top",
    "new": "/api/share?op=list&page=1&sort=newest",
    "sets": "/api/share?op=library&page=1&sort=largest&model=3d",
}


def written(answers: dict, code: str = "") -> tuple[dict, str]:
    """What home_shelf decides from [answers], and the page it writes in [code]'s language."""
    script = f"""
import {{ readFileSync }} from "node:fs";
import {{ decide, filled }} from "./tools/web/home_shelf.mjs";
const page = readFileSync("web/{code + '/' if code else ''}index.html", "utf8");
const plan = decide({json.dumps(ASKS)}, {json.dumps(answers)});
console.log(JSON.stringify({{ plan: {{ ...plan, cards: Object.fromEntries(Object.entries(plan.cards).map(([k, v]) => [k, v.map((m) => m.id)])) }},
  page: filled(page, {json.dumps(code)}, plan, new Map()) }}));
"""
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    out = json.loads(done.stdout.strip().splitlines()[-1])
    return out["plan"], out["page"]


def kept() -> dict:
    answers = json.loads((ROOT / "web/_home.json").read_text(encoding="utf-8"))["answers"]
    return {**answers, "shelves": answers["/api/share?op=shelves"]}


def cards(page: str, tab: str) -> list[str]:
    inside = re.search(rf"<!--shelf:{tab}-->(.*?)<!--/shelf:{tab}-->", page, re.S)
    return re.findall(r'<article class="model" data-id="([^"]+)"', inside.group(1)) if inside else []


def test_nothing_read_keeps_the_skeletons():
    plan, page = written({"shelves": None})
    assert plan["tabs"] == [] and plan["first"] == ""
    assert page.count('class="skeleton-card skeleton"') == 6
    assert 'data-shelf="skeleton"' in page and 'data-shelf="served"' not in page


def test_todays_gallery_leads_with_the_pick():
    answers = kept()
    plan, page = written(answers)
    pick = answers["shelves"]["pick"]["model"]["id"]
    assert plan["first"] == "top" and "trending" not in plan["tabs"]
    top = cards(page, "top")
    assert len(top) == 10 and top[0] == pick and top.count(pick) == 1
    # Only the tab shown is written in: the others fill when first opened.
    assert cards(page, "new") == [] and cards(page, "sets") == []
    assert page.count('data-pick="yes"') == 1
    assert re.search(r'id="tab-trending"[^>]* hidden>', page) and re.search(r'id="tab-top" aria-selected="true"', page)
    assert "skeleton-card" not in page and 'data-shelf="served"' in page
    assert re.search(r'id="shelf-new"[^>]* hidden\s', page) and not re.search(r'id="shelf-top"[^>]* hidden\s', page)
    # Every card has its picture, and only the first is asked for at once:
    # four drawn into the first frame put a laptop's first paint back.
    assert len(re.findall(r'loading="eager"', page)) == 1
    assert 'loading="eager" fetchpriority="high"' in re.search(r"<!--shelf:top-->(.*?)</article>", page, re.S).group(1)


def test_a_busy_week_puts_trending_first_in_german():
    answers = kept()
    top = answers["/api/share?op=list&page=1&sort=top"]["models"]
    answers["/api/share?op=list&page=1&sort=top&window=week"] = {"models": top[3:7]}
    plan, page = written(answers, "de")
    assert plan["first"] == "trending" and "top" in plan["tabs"]
    assert re.search(r'id="tab-trending" aria-selected="true"[^>]*>', page) and not re.search(r'id="tab-trending"[^>]* hidden>', page)
    assert cards(page, "trending")[0] == answers["shelves"]["pick"]["model"]["id"]
    assert '<a id="shelf-all" href="/de/gallery?window=week">' in page
    # The cards in German, from the copy's own words.
    assert "Topwahl" in page


def test_a_week_short_of_four_stays_hidden():
    answers = kept()
    top = answers["/api/share?op=list&page=1&sort=top"]["models"]
    answers["/api/share?op=list&page=1&sort=top&window=week"] = {"models": top[:3]}
    plan, _ = written(answers)
    assert plan["first"] == "top" and "trending" not in plan["tabs"]


def test_a_test_challenge_is_never_written():
    answers = kept()
    answers["shelves"] = {**answers["shelves"], "challenge": {"title": "Checks only", "state": "open", "test": True,
                                                              "starts_on": "2026-11-01", "ends_on": "2026-11-30"}}
    plan, page = written(answers)
    assert plan["challenge"] is None and "Checks only" not in page


def test_an_open_challenge_is_written_with_its_days():
    answers = kept()
    answers["shelves"] = {**answers["shelves"], "challenge": {"title": "Microscale", "brief": "Small & mighty.", "state": "open",
                                                              "test": False, "starts_on": "2026-11-01", "ends_on": "2026-11-30"}}
    _, page = written(answers, "fr")
    assert '<h2 id="challenge-h" lang="en">Microscale</h2>' in page
    assert '<p id="challenge-brief" lang="en">Small &amp; mighty.</p>' in page
    assert '<p class="note" id="challenge-days">1–30 novembre</p>' in page
