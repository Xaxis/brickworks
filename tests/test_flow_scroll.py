"""A flow never measures a page part way through a scroll.

The site scrolls smoothly (web/site.css: `html { scroll-behavior: smooth }`,
and its sideways rows), so a flow that asked for a scroll and then measured
could read the page on its way: model_page_flow measured a frame at -808 px
at 1280 dark until it scrolled "instant" (2026-11-07, arview), and 17 more
scrollTo calls in 11 flows could do the same, as could a scrollIntoView or a
jump to a #part. tools/web/browser.mjs's instantScroll makes every scroll a
page is asked for land at once, in every context launch() makes. Held here:
that launch()'s contexts and instantScroll's do so in a real browser, and
that no script under tools/ scrolls a page in a browser it opened itself
without instantScroll.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PLAYWRIGHT = ROOT / "tools/web/node_modules/playwright"

# What scrolls a page and so goes the page's scroll-behavior: the calls, a
# jump to a part of the page by its address, and setting where an element
# is scrolled to.
SCROLLS = re.compile(r"\b(?:scrollTo|scrollBy|scrollIntoView(?:IfNeeded)?)\s*\("
                     r"|\blocation\.hash\s*=(?!=)|\.scroll(?:Top|Left)\s*[-+]?=(?!=)")
# A browser opened without browser.mjs's launch().
OWN_BROWSER = re.compile(r"\b(?:chromium|firefox|webkit)\s*\.\s*"
                         r"(?:launch|launchPersistentContext|launchServer|connect|connectOverCDP)\b")


def scripts() -> list[Path]:
    found = []
    for pattern in ("*.mjs", "*.js", "*.cjs"):
        for path in (ROOT / "tools").rglob(pattern):
            if "node_modules" in path.parts or "axe-core" in path.parts:
                continue
            found.append(path)
    return sorted(found)


def unreached(text: str) -> bool:
    """Scrolls a page in a browser it opened itself, never given instantScroll."""
    return bool(SCROLLS.search(text) and OWN_BROWSER.search(text) and "instantScroll(" not in text)


def test_every_script_that_scrolls_a_page_it_opened_itself_makes_scrolls_instant() -> None:
    browser = (ROOT / "tools/web/browser.mjs").read_text()
    stray = [str(path.relative_to(ROOT)) for path in scripts()
             if path.name != "browser.mjs" and unreached(path.read_text())]
    assert not stray, (f"{', '.join(stray)}: each scrolls a page in a browser opened without launch() "
                       "(tools/web/browser.mjs) and never calls instantScroll(context) on it, so a measure "
                       "after the scroll can read the page on its way")
    assert "export async function instantScroll(" in browser


def test_the_rule_catches_a_bare_scroll_and_passes_the_shared_means() -> None:
    own = 'const context = await chromium.launchPersistentContext(dir, {});\n'
    assert unreached(own + 'await page.evaluate(() => window.scrollTo(0, 400));')
    assert unreached(own + 'await page.evaluate(() => document.querySelector("#a").scrollIntoView());')
    assert unreached(own + 'await page.evaluate(() => { location.hash = "#parts"; });')
    assert unreached(own + 'await page.evaluate(() => { list.scrollTop = 900; });')
    assert not unreached(own + 'await instantScroll(context);\nawait page.evaluate(() => scrollTo(0, 400));')
    # launch()'s browser has it already, and a script that never scrolls needs none.
    assert not unreached('const browser = await launch();\nawait page.evaluate(() => scrollTo(0, 400));')
    assert not unreached(own + 'await page.goto(url);')
    assert not unreached(own + 'if (list.scrollTop === 0) {}')


READ = """
import { chromium } from "playwright";
import { instantScroll, launch } from "./browser.mjs";

// A long page that scrolls smoothly, as the site does, under a policy as
// strict as any of the site's (no inline style), and where it is the moment
// after each way of being asked to scroll.
const PAGE = `<!doctype html><link rel="stylesheet" href="/s.css">
  <div id="row"><div class="wide"></div></div><div class="tall"></div><div id="far">far</div><div class="tall"></div>`;
const CSS = `html { scroll-behavior: smooth; } .tall { height: 12000px; }
  #row { overflow-x: auto; scroll-behavior: smooth; white-space: nowrap; width: 200px; }
  .wide { display: inline-block; width: 4000px; height: 10px; }`;
const POLICY = { "content-security-policy": "default-src 'self'" };
async function reads(page) {
  await page.route("http://scroll.test/**", (route) => route.fulfill(route.request().url().endsWith("/s.css")
    ? { contentType: "text/css", body: CSS, headers: POLICY } : { contentType: "text/html", body: PAGE, headers: POLICY }));
  await page.goto("http://scroll.test/");
  return page.evaluate(() => {
    scrollTo(0, 12000);
    const to = scrollY;
    document.getElementById("far").scrollIntoView();
    const into = Math.round(document.getElementById("far").getBoundingClientRect().top);
    scrollTo(0, 0);
    location.hash = "#far";
    const hash = Math.round(document.getElementById("far").getBoundingClientRect().top);
    const row = document.getElementById("row");
    row.scrollLeft = 1500;
    return { to, into, hash, row: row.scrollLeft };
  });
}
const said = {};
const browser = await launch({ signedOut: true });
try {
  said.newPage = await reads(await browser.newPage({ viewport: { width: 800, height: 600 } }));
  const context = await browser.newContext({ viewport: { width: 800, height: 600 } });
  said.newContext = await reads(await context.newPage());
} finally {
  await browser.close();
}
// A context made without launch(), given instantScroll, and one not given it.
const own = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
try {
  const given = await instantScroll(await own.newContext({ viewport: { width: 800, height: 600 } }));
  said.instantScroll = await reads(await given.newPage());
  said.bare = await reads(await (await own.newContext({ viewport: { width: 800, height: 600 } })).newPage());
} finally {
  await own.close();
}
console.log(JSON.stringify(said));
"""


@pytest.mark.skipif(not PLAYWRIGHT.exists(), reason="no Playwright in tools/web/node_modules")
def test_a_scroll_asked_for_lands_at_once_in_every_context_a_flow_makes() -> None:
    # From tools/web, where the flows' Playwright is.
    run = subprocess.run(["node", "--input-type=module", "-e", READ], cwd=ROOT / "tools/web", capture_output=True,
                         text=True, timeout=180)
    assert run.returncode == 0, run.stderr[-2000:]
    said = json.loads(run.stdout.strip().splitlines()[-1])
    landed = {"to": 12000, "into": 0, "hash": 0, "row": 1500}
    for way in ("newPage", "newContext", "instantScroll"):
        assert said[way] == landed, f"{way}: {said[way]}, not {landed}"
    # Without it the same page is read on its way: what the test would miss.
    assert said["bare"]["to"] < 12000 and said["bare"]["row"] < 1500, said["bare"]
