"""The home page's first screen as the deploy writes it (homefeed, 2026-11-23).

tools/web/home_shelf.mjs writes the feed's first posts into web/index.html's
copy at the deploy (web/home-feed.js draws each), from the live answers or
from web/_home.json. These drive its real decide() and filled() on the pages
as they are in this checkout: a deploy that could read nothing, today's
answers, Talk once talk.sql is applied, a language's copy, a test challenge
and words typed to break the page.
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


def written(given: dict, code: str = "") -> tuple[list[dict], str]:
    """What home_shelf decides from [given] (its answers by name), and the page it writes in [code]'s language."""
    script = f"""
import {{ readFileSync }} from "node:fs";
import {{ decide, filled }} from "./tools/web/home_shelf.mjs";
const page = readFileSync("web/{code + '/' if code else ''}index.html", "utf8");
const items = decide({json.dumps(given)});
console.log(JSON.stringify({{ items: items.map((one) => ({{ kind: one.kind, id: one.model?.id || one.thread?.id || null, pick: one.pick === true }})),
  page: filled(page, {json.dumps(code)}, items, new Map()) }}));
"""
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True, timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    out = json.loads(done.stdout.strip().splitlines()[-1])
    return out["items"], out["page"]


def asks() -> dict:
    done = subprocess.run(["node", "--input-type=module", "-e",
                           'import { ASKS } from "./tools/web/home_shelf.mjs"; console.log(JSON.stringify(ASKS));'],
                          cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def kept() -> dict:
    """The answers web/_home.json keeps, by the names decide() takes."""
    answers = json.loads((ROOT / "web/_home.json").read_text(encoding="utf-8"))["answers"]
    return {name: answers.get(path) for name, path in asks().items()}


def feed(page: str) -> str:
    inside = re.search(r"<!--feed-->(.*?)<!--/feed-->", page, re.S)
    assert inside, "the page has its feed's markers"
    return inside.group(1)


TALK = {"ready": True, "threads": [
    {"id": 7, "board": "show", "title": "My lighthouse, with a light that turns", "said": "Twelve steps of it.",
     "path": "/talk/t/7/my-lighthouse", "at": "2026-11-22T10:00:00Z", "replies": 2,
     "by": {"handle": "ann-builds", "name": "Ann"},
     "reply": {"by": {"handle": "bea-bricks", "name": "Bea"}, "said": "The gears are lovely.", "at": "2026-11-22T11:00:00Z"}},
    {"id": 8, "board": "help", "title": "</script><b>bold</b>", "said": "", "path": "javascript:alert(1)",
     "at": "2026-11-22T09:00:00Z", "replies": 0, "by": {"handle": "cy-cyrus", "name": "Cy"}, "reply": None},
], "talking": []}


def test_nothing_read_keeps_the_skeletons():
    items, page = written({})
    assert items == []
    assert feed(page).count('class="post skeleton"') == 3
    assert 'data-stream="skeleton"' in page and 'data-stream="served"' not in page


def test_todays_answers_lead_with_the_pick_and_the_challenge_third():
    given = kept()
    items, page = written(given)
    assert len(items) == 6
    pick = given["shelves"]["pick"]["model"]["id"]
    assert items[0] == {"kind": "build", "id": pick, "pick": True}
    assert items[2]["kind"] == "challenge"
    assert [one["kind"] for one in items].count("try") == 1
    posts = feed(page)
    assert 'data-stream="served"' in page and "skeleton" not in posts
    # Only the first picture is asked for at once: four drawn into the
    # first frame put a laptop's first paint back (landing, 2026-11-22).
    assert len(re.findall(r'loading="eager"', posts)) == 1
    assert 'loading="eager" fetchpriority="high"' in re.search(r"<article.*?</article>", posts, re.S).group(0)
    # Each build's post carries the studio's verbs, and links a crawler follows.
    builds = [one["id"] for one in items if one["kind"] == "build"]
    assert len(builds) >= 3
    for model in builds:
        post = re.search(rf'<article class="post build" data-kind="build" data-id="{model}".*?</article>', posts, re.S).group(0)
        for href in (f"/app?view={model}", f"/app?copy={model}", f"/app?view={model}&amp;build", f"/m/{model}#parts"):
            assert f'href="{href}"' in post, (model, href)
        assert f'<a href="/m/{model}">' in post
        assert re.search(r'class="pill" href="/docs/[a-z-]+" data-made="', post), "how it was made, to its docs"
        assert f'data-like="{model}"' in post and f'data-say="{model}"' in post and 'data-follow="' in post
    # The challenge keeps the ids web/landing.js says its days left in.
    for one in ("challenge-when", "challenge-left", "challenge-h", "challenge-brief", "challenge-days", "challenge-go"):
        assert f'id="{one}"' in posts, one
    # Each id once.
    ids = re.findall(r'\sid="([^"]+)"', page)
    assert len(ids) == len(set(ids)), [one for one in ids if ids.count(one) > 1]


def test_talk_once_applied_is_in_the_first_screen_with_its_latest_reply():
    given = {**kept(), "talk": TALK}
    items, page = written(given)
    assert [one["kind"] for one in items][:6].count("talk") == 1
    posts = feed(page)
    post = re.search(r'<article class="post talk" data-kind="talk" data-thread="7".*?</article>', posts, re.S).group(0)
    assert '<a href="/talk/t/7/my-lighthouse">My lighthouse, with a light that turns</a>' in post
    assert "The gears are lovely." in post and "<b>Bea</b>" in post
    assert 'href="/talk/t/7/my-lighthouse#reply"' in post


def test_words_typed_never_become_the_page():
    given = {**kept(), "talk": {**TALK, "threads": [TALK["threads"][1]]}}
    top = given["top"]["models"]
    given["top"] = {"models": [{**top[0], "name": '<img src=x onerror="alert(1)">', "by": {"handle": "x-y", "name": "</h3><script>"}}, *top[1:]]}
    given["shelves"] = {**given["shelves"], "pick": None}
    _, page = written(given)
    posts = feed(page)
    assert "<img src=x" not in posts and "<script>" not in posts and "</script><b>" not in posts
    assert "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;" in posts
    # A thread's address from the answer that is not a thread's: its own made from its number.
    assert "javascript:" not in posts


def test_the_german_copy_says_it_in_german():
    _, page = written(kept(), "de")
    posts = feed(page)
    assert "Im Studio öffnen" in posts and "Remixen" in posts and "Bauen" in posts
    assert 'href="/de/m/' in posts
    # The studio is the same address in every language.
    assert 'href="/app?copy=' in posts


def test_a_test_challenge_is_never_written():
    given = kept()
    test = {"title": "Checks only", "state": "open", "test": True, "starts_on": "2026-11-01", "ends_on": "2026-11-30"}
    given["shelves"] = {**given["shelves"], "challenge": test}
    given["challenge"] = {"ready": True, "challenge": test}
    items, page = written(given)
    assert "challenge" not in [one["kind"] for one in items] and "Checks only" not in page


def test_an_open_challenge_is_written_with_its_days_in_french():
    given = kept()
    c = {"title": "Microscale", "brief": "Small & mighty.", "state": "open", "test": False,
         "starts_on": "2026-11-01", "ends_on": "2026-11-30", "groups": []}
    given["challenge"] = {"ready": True, "challenge": c}
    _, page = written(given, "fr")
    assert '<h3 class="post-title" id="challenge-h" lang="en">Microscale</h3>' in page
    assert '<p id="challenge-brief" lang="en">Small &amp; mighty.</p>' in page
    assert '<p class="note" id="challenge-days">1–30 novembre</p>' in page


def test_the_heros_open_goes_to_the_gallerys_copy_once_it_is_listed():
    """hero3d: Open it in the studio opens the mark as the gallery's Open does once the
    project's account lists it, in each language; anybody else's model of that name, or
    an id that is not one, leaves the app's own copy."""
    script = """
import { readFileSync } from "node:fs";
import { heroOpen, markIn } from "./tools/web/home_shelf.mjs";
const mark = { id: "AbCdE12345", name: "The Brickworks mark", by: { handle: "brickworks", name: "Brickworks" } };
const pages = ["", "de/"].map((code) => readFileSync(`web/${code}index.html`, "utf8"));
console.log(JSON.stringify({
  found: markIn({ models: [{ ...mark, id: "ZzZzZ99999", by: { handle: "someone" } }, mark] }),
  stranger: markIn({ models: [{ ...mark, by: { handle: "someone" } }] }),
  none: markIn(null),
  links: pages.map((page) => [heroOpen(page, "AbCdE12345"), heroOpen(page, '"><b>'), heroOpen(page, null)]
    .map((one) => one.match(/id="hero-open" href="([^"]*)"/)[1])),
}));
"""
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    out = json.loads(done.stdout.strip().splitlines()[-1])
    assert out["found"] == "AbCdE12345" and out["stranger"] is None and out["none"] is None
    english, german = out["links"]
    assert english == ["/app?view=AbCdE12345", "/app?model=res://models/brickworks_mark.ldr",
                       "/app?model=res://models/brickworks_mark.ldr"]
    assert german == ["/app?lang=de&amp;view=AbCdE12345"] + ["/app?lang=de&amp;model=res://models/brickworks_mark.ldr"] * 2
