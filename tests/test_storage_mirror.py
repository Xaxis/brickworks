"""Our own browsers read the parts bucket from this machine's copy.

Every check starts a browser with a fresh profile, so each one downloaded
every part, cover and model it showed from Supabase's storage again, which is
billed as cached egress; on 2026-11-12 the owner's organisation went over its
quota and every Supabase API answered 402. tools/web/storage_mirror.mjs keeps
each object it fetches and serves it again from disk, and browser.mjs imports
it, so every browser a script there starts is routed through it. Held here:
an object is fetched from the bucket once and then served from the copy; a
mutable one is asked again with its ETag; the bucket's "no such object" passes
through and is not kept; a bucket that refuses is asked once, not once an
object, and the copy or this checkout's build outputs answer instead; a name
cannot reach outside the copy; each way a script opens a browser serves a kept
object without the network; and no script opens a browser without browser.mjs.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PLAYWRIGHT = ROOT / "tools/web/node_modules/playwright"
OWN_BROWSER = re.compile(r"\b(?:chromium|firefox|webkit)\s*\.\s*"
                         r"(?:launch|launchPersistentContext|launchServer|connect|connectOverCDP)\b")
BROWSER_MJS = re.compile(r"""from\s+["']\./browser\.mjs["']""")


def own_browsers() -> list[Path]:
    found = []
    for pattern in ("*.mjs", "*.js", "*.cjs"):
        for path in (ROOT / "tools").rglob(pattern):
            if "node_modules" in path.parts or "axe-core" in path.parts or path.name in ("browser.mjs", "storage_mirror.mjs"):
                continue
            if OWN_BROWSER.search(path.read_text(errors="replace")):
                found.append(path)
    return sorted(found)


def test_every_script_that_opens_a_browser_brings_the_mirror_in() -> None:
    stray = [str(path.relative_to(ROOT)) for path in own_browsers()
             if not BROWSER_MJS.search(path.read_text(errors="replace"))]
    assert not stray, (f"{', '.join(stray)}: each opens a browser and never imports ./browser.mjs, which brings "
                       "in storage_mirror.mjs, so its pages draw every part from Supabase's storage again")
    assert 'import "./storage_mirror.mjs";' in (ROOT / "tools/web/browser.mjs").read_text()


OBJECTS = r"""
import http from "node:http";
import { object } from "./storage_mirror.mjs";

// argv: "healthy" or "refusing" (the bucket answers 402 from the start), and
// a name this checkout's build outputs have.
const [refusing, localName] = [process.argv[1] === "refusing", process.argv[2]];
const asked = [];
const bucket = http.createServer((request, response) => {
  const name = request.url.slice(1);
  asked.push(`${name}${request.headers["if-none-match"] ? " if-none-match" : ""}`);
  if (refusing) {
    response.writeHead(402, { "content-type": "application/json" });
    return response.end('{"message":"exceed_cached_egress_quota"}');
  }
  if (name === "missing.lbm") {
    response.writeHead(400, { "content-type": "application/json" });
    return response.end('{"statusCode":"404","error":"not_found"}');
  }
  const etag = `"${name}-1"`;
  if (request.headers["if-none-match"] === etag) {
    response.writeHead(304, { etag });
    return response.end();
  }
  response.writeHead(200, { "content-type": name.endsWith(".json") ? "application/json" : "application/octet-stream",
    "cache-control": `public, max-age=${name.endsWith(".json") ? 0 : 31536000}`, etag });
  return response.end(`the bytes of ${name}`);
});
await new Promise((ready) => bucket.listen(0, "127.0.0.1", ready));
const base = `http://127.0.0.1:${bucket.address().port}/`;
const get = async (name) => {
  const got = await object(name, base + name);
  return [got.status, got.headers["x-brickworks-mirror"], got.body.toString(), got.headers["content-type"] || ""];
};
const said = {};
if (refusing) {
  said.burst = await Promise.all(Array.from({ length: 20 }, (_, n) => get(`burst${n}.lbm`)));
  said.kept = await get("0a1b2c.lbm");
  if (localName) said.local = await get(localName);
} else {
  said.first = await get("0a1b2c.lbm");
  said.again = await get("0a1b2c.lbm");
  said.index = await get("library/index.json");
  said.indexAgain = await get("library/index.json");
  said.missing = await get("missing.lbm");
  said.missingAgain = await get("missing.lbm");
  said.outside = await get("../../outside.lbm");
}
said.asked = asked;
bucket.close();
console.log(JSON.stringify(said));
"""


def node(script: str, *args: str, mirror: Path, timeout: int = 120) -> dict:
    """[script] run from tools/web with the copy at [mirror]: the JSON it printed."""
    run = subprocess.run(["node", "--input-type=module", "-e", script, *args], cwd=ROOT / "tools/web",
                         capture_output=True, text=True, timeout=timeout,
                         env={**os.environ, "BW_STORAGE_MIRROR": str(mirror)})
    assert run.returncode == 0, run.stderr[-2000:]
    return json.loads(next(line for line in reversed(run.stdout.splitlines()) if line.startswith("{")))


@pytest.mark.skipif(not PLAYWRIGHT.exists(), reason="no Playwright in tools/web/node_modules")
def test_an_object_comes_from_the_bucket_once_then_from_the_copy(tmp_path: Path) -> None:
    mirror = tmp_path / "mirror"
    said = node(OBJECTS, "healthy", mirror=mirror)
    assert said["first"] == [200, "bucket", "the bytes of 0a1b2c.lbm", "application/octet-stream"]
    assert said["again"] == [200, "cache", "the bytes of 0a1b2c.lbm", "application/octet-stream"]
    # Past its max-age, asked again with its ETag: a 304, and the copy.
    assert said["index"][:3] == [200, "bucket", "the bytes of library/index.json"]
    assert said["indexAgain"][:3] == [200, "cache", "the bytes of library/index.json"]
    assert said["missing"][:2] == said["missingAgain"][:2] == [400, "passed"]
    assert said["outside"][:2] == [400, "passed"]
    assert said["asked"] == ["0a1b2c.lbm", "library/index.json", "library/index.json if-none-match",
                             "missing.lbm", "missing.lbm"]
    kept = sorted(p.relative_to(mirror).as_posix() for p in mirror.rglob("*") if p.is_file())
    assert kept == ["0a1b2c.lbm", "library/index.json"], kept


@pytest.mark.skipif(not PLAYWRIGHT.exists(), reason="no Playwright in tools/web/node_modules")
def test_a_bucket_that_refuses_is_asked_once_and_the_copy_answers(tmp_path: Path) -> None:
    mirror = tmp_path / "mirror"
    node(OBJECTS, "healthy", mirror=mirror)
    parts = ROOT / "assets/generated/parts"
    mesh = next(iter(sorted(parts.glob("*.lbm"))), None) if parts.is_dir() else None
    said = node(OBJECTS, "refusing", mesh.name if mesh else "", mirror=mirror)
    # Twenty objects at once, one ask: its refusal passed on for each.
    assert len(said["asked"]) == 1, said["asked"]
    assert {(status, source) for status, source, *_ in said["burst"]} == {(402, "passed")}
    assert said["kept"][:3] == [200, "cache", "the bytes of 0a1b2c.lbm"]
    if mesh:
        assert said["local"][:2] == [200, "local"]


BROWSERS = r"""
import http from "node:http";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";
import { launch, SOFTWARE } from "./browser.mjs";
import { object } from "./storage_mirror.mjs";

// Kept from a stand-in bucket, then asked for at the real bucket's address,
// which no request reaches: the copy answers it.
const bucket = http.createServer((request, response) => {
  response.writeHead(200, { "content-type": "application/octet-stream", "cache-control": "public, max-age=31536000" });
  response.end("kept bytes");
});
await new Promise((ready) => bucket.listen(0, "127.0.0.1", ready));
await object("feedc0de.lbm", `http://127.0.0.1:${bucket.address().port}/feedc0de.lbm`);
bucket.close();
const AT = "https://mirror-test.supabase.co/storage/v1/object/public/parts/feedc0de.lbm";
async function read(context) {
  const page = await context.newPage();
  await page.route("http://page.test/", (route) => route.fulfill({ contentType: "text/html", body: "<p>page</p>" }));
  await page.goto("http://page.test/");
  const heard = page.waitForResponse(AT);
  const body = await page.evaluate((at) => fetch(at).then((r) => r.text(), (e) => `failed: ${e}`), AT);
  const response = await heard;
  return [body, response.headers()["x-brickworks-mirror"] || "", await response.serverAddr()];
}
const said = {};
const shared = await launch({ signedOut: true });
said.launch = await read(await shared.newContext());
await shared.close();
const own = await chromium.launch({ args: SOFTWARE });
said.chromiumLaunch = await read(await own.newContext());
await own.close();
const dir = mkdtempSync(join(tmpdir(), "mirror-test-"));
const persistent = await chromium.launchPersistentContext(dir, { args: SOFTWARE });
said.persistent = await read(persistent);
await persistent.close();
rmSync(dir, { recursive: true, force: true });
console.log(JSON.stringify(said));
"""


@pytest.mark.skipif(not PLAYWRIGHT.exists(), reason="no Playwright in tools/web/node_modules")
def test_every_way_a_script_opens_a_browser_reads_the_copy(tmp_path: Path) -> None:
    said = node(BROWSERS, mirror=tmp_path / "mirror", timeout=240)
    for way in ("launch", "chromiumLaunch", "persistent"):
        assert said[way] == ["kept bytes", "cache", None], f"{way}: {said[way]}"
