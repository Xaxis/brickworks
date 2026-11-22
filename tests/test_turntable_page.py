"""A model's clip on its page, its embed and its own address (api/share.js,
unit turntable), made by the real handler from the design stand-in's world
(tools/web/design_stand_in.mjs), with no network. The watchtower's newest
version is 2.

- With a clip of version 2, /m/<id>'s head names it for a link preview:
  og:video with its secure_url, type, width and height, og:type
  video.other, a twitter:card player whose player is the embed with
  ?autoplay=1 (in the page's language on a copy), and its stream; og:image
  stays. With none, with one of an older version, on an older version's
  page, or with no table to ask (before supabase/model_clips.sql), the
  picture card as it always was.
- The embed with ?autoplay=1 plays it: a muted, looping, inline video with
  the picture as its poster, Pause in its corner, and media-src 'self' in
  its policy. Without ?autoplay=1, or with no clip, the picture.
- /m/<id>.webm?v=2 is the file, kept 10 minutes by the CDN; without a
  version as briefly as the pictures; the other kind, another version or an
  unpublished model 404; a range of it 206 and kept by no CDN (Safari asks
  for one before it plays); a range past its end 416.

tools/web/turntable_flow.mjs proves the same on a deployment, recorded in a
browser."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID = "DesignAbc1"
CLIP_V2 = {"version": 2, "kind": "webm", "width": 768, "height": 432, "ms": 4000, "bytes": 10201,
           "made_at": "2026-11-22T05:00:00Z"}
ORIGIN = "http://design.test"


def ask(asks: list, clip=None) -> list[dict] | None:
    """Each of [asks] as the server answers it: ["page", path] a page by its
    address, ["op", query, headers] the share handler asked [query] with
    [headers]. [clip] is what model_clips answers for the watchtower: a row,
    None for none, or "missing" for no table (PostgREST's 404). Its file is
    tests/fixtures/clip/turn.webm. {status, html, headers, size, head}."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/m/DesignAbc1');"
        "const { readFileSync } = await import('node:fs');"
        "const file = readFileSync('tests/fixtures/clip/turn.webm');"
        f"const clip = {json.dumps(clip)};"
        "const real = globalThis.fetch;"
        "globalThis.fetch = async (input, init) => { const url = String(input.url || input);"
        "  if (/\\/rest\\/v1\\/model_clips\\?/.test(url)) return clip === 'missing'"
        "    ? new Response(JSON.stringify({ code: 'PGRST205' }), { status: 404 })"
        "    : new Response(JSON.stringify(clip ? [clip] : []), { status: 200, headers: { 'content-type': 'application/json' } });"
        "  if (/\\/storage\\/v1\\/object\\/shared-clips\\/DesignAbc1\\.webm$/.test(url)) return new Response(file, { status: 200 });"
        "  if (/\\/storage\\/v1\\/object\\/shared-clips\\//.test(url)) return new Response('', { status: 400 });"
        "  return real(input, init); };"
        "const share = (await import('./api/share.js')).default;"
        "const out = [];"
        f"for (const one of {json.dumps(asks)}) {{"
        "  if (one[0] === 'page') { const r = await s.serverPage('api', one[1]);"
        "    out.push({ status: r.status, html: r.html, headers: r.headers, size: r.bytes ? r.bytes.length : null }); continue; }"
        "  const response = { statusCode: 200, headers: {}, body: '',"
        "    status(code) { this.statusCode = code; return this; },"
        "    setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; return this; },"
        "    json(value) { this.body = JSON.stringify(value); return this; }, end(body) { this.body = body ?? ''; return this; } };"
        "  await share({ method: 'GET', query: one[1], body: undefined,"
        "    headers: { host: 'design.test', 'x-forwarded-proto': 'http', ...(one[2] || {}) } }, response);"
        "  const bytes = Buffer.isBuffer(response.body) || response.body instanceof Uint8Array ? Buffer.from(response.body) : null;"
        "  out.push({ status: response.statusCode, html: bytes ? '' : String(response.body), headers: response.headers,"
        "    size: bytes ? bytes.length : null, head: bytes ? [...bytes.subarray(0, 4)] : null }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def metas(html: str) -> dict[str, str]:
    """The <meta> tags of a page, by property or name."""
    found: dict[str, str] = {}
    for tag in re.findall(r"<meta\s[^>]*>", html):
        key = re.search(r'(?:property|name)="([^"]+)"', tag)
        value = re.search(r'content="([^"]*)"', tag)
        if key and value and key.group(1) not in found:
            found[key.group(1)] = value.group(1).replace("&amp;", "&")
    return found


def test_the_head_names_a_clip_of_the_newest_version():
    out = ask([["page", f"/m/{ID}"], ["page", f"/de/m/{ID}"], ["page", f"/m/{ID}/v/1"]], clip=CLIP_V2)
    if out is None:
        return
    page, german, older = out
    assert page["status"] == 200
    tags = metas(page["html"])
    video = f"{ORIGIN}/m/{ID}.webm?v=2"
    assert tags["og:video"] == video and tags["og:video:secure_url"] == video
    assert tags["og:video:type"] == "video/webm"
    assert (tags["og:video:width"], tags["og:video:height"]) == ("768", "432")
    assert tags["og:type"] == "video.other"
    assert tags["twitter:card"] == "player"
    assert tags["twitter:player"] == f"{ORIGIN}/m/{ID}/embed?autoplay=1"
    assert (tags["twitter:player:width"], tags["twitter:player:height"]) == ("560", "420")
    assert tags["twitter:player:stream"] == video
    assert tags["twitter:player:stream:content_type"] == "video/webm"
    assert tags["og:image"] == f"{ORIGIN}/m/{ID}.png"
    # A copy in German: its player is the embed in German.
    assert metas(german["html"])["twitter:player"] == f"{ORIGIN}/de/m/{ID}/embed?autoplay=1"
    # An older version's page is not the clip's.
    old = metas(older["html"])
    assert older["status"] == 200 and "og:video" not in old and old["twitter:card"] == "summary_large_image"


def test_no_clip_is_the_picture_card():
    for clip in (None, {**CLIP_V2, "version": 1}, "missing"):
        out = ask([["page", f"/m/{ID}"], ["page", f"/m/{ID}/embed?autoplay=1"]], clip=clip)
        if out is None:
            return
        page, embed = out
        tags = metas(page["html"])
        assert page["status"] == 200, clip
        assert "og:video" not in tags and "twitter:player" not in tags, clip
        assert tags["twitter:card"] == "summary_large_image" and tags["og:type"] == "website", clip
        assert embed["status"] == 200 and "<video" not in embed["html"], clip
        assert f'<img src="/m/{ID}.png" alt="">' in embed["html"], clip


def test_the_embed_plays_it_when_asked():
    out = ask([["page", f"/m/{ID}/embed?autoplay=1"], ["page", f"/m/{ID}/embed"]], clip=CLIP_V2)
    if out is None:
        return
    playing, still = out
    assert playing["status"] == 200
    video = re.search(r"<video [^>]*></video>", playing["html"])
    assert video, playing["html"][:400]
    tag = video.group(0)
    assert f'src="/m/{ID}.webm?v=2"' in tag and f'poster="/m/{ID}.png"' in tag
    for attribute in (" muted", " loop", " playsinline", 'aria-hidden="true"'):
        assert attribute in tag, attribute
    assert " autoplay" not in tag  # web/embed.js plays it, unless less motion is asked for
    toggle = re.search(r"<button [^>]*data-clip-toggle[^>]*>", playing["html"])
    assert toggle and 'aria-label="Pause"' in toggle.group(0) and " hidden" in toggle.group(0)
    assert "/icons.svg#pause" in playing["html"]
    assert "media-src 'self'" in playing["headers"]["content-security-policy"]
    assert "<video" not in still["html"] and not re.search(r"<button [^>]*data-clip-toggle", still["html"])
    assert f'<img src="/m/{ID}.png" alt="">' in still["html"]


def test_the_clip_at_its_address():
    q = {"op": "clip", "id": ID}
    out = ask([
        ["op", {**q, "as": "webm", "v": "2"}],
        ["op", {**q, "as": "webm"}],
        ["op", {**q, "as": "mp4", "v": "2"}],
        ["op", {**q, "as": "webm", "v": "1"}],
        ["op", {**q, "as": "webm", "v": "x"}],
        ["op", {**q, "as": "mov"}],
        ["op", {**q, "as": "webm", "v": "2"}, {"range": "bytes=0-1"}],
        ["op", {**q, "as": "webm", "v": "2"}, {"range": "bytes=-100"}],
        ["op", {**q, "as": "webm", "v": "2"}, {"range": "bytes=99999999-"}],
        ["op", {"op": "clip", "id": "QQQQQQQQQQ", "as": "webm"}],
    ], clip=CLIP_V2)
    if out is None:
        return
    whole, unversioned, mp4, older, junk, mov, first, last, past, nobody = out
    size = (ROOT / "tests/fixtures/clip/turn.webm").stat().st_size
    assert whole["status"] == 200 and whole["size"] == size
    assert whole["head"] == [0x1A, 0x45, 0xDF, 0xA3]
    assert whole["headers"]["content-type"] == "video/webm"
    assert whole["headers"]["cross-origin-resource-policy"] == "cross-origin"
    assert whole["headers"]["accept-ranges"] == "bytes"
    assert "s-maxage=600" in whole["headers"]["cache-control"]
    assert unversioned["status"] == 200 and "s-maxage=30" in unversioned["headers"]["cache-control"]
    for refused in (mp4, older, junk, mov, nobody):
        assert refused["status"] == 404 and refused["headers"]["cache-control"] == "no-store"
    assert first["status"] == 206 and first["size"] == 2
    assert first["headers"]["content-range"] == f"bytes 0-1/{size}"
    assert "s-maxage=0" in first["headers"]["cache-control"]
    assert last["status"] == 206 and last["size"] == 100
    assert last["headers"]["content-range"] == f"bytes {size - 100}-{size - 1}/{size}"
    assert past["status"] == 416 and past["headers"]["content-range"] == f"bytes */{size}"
    assert past["headers"]["cache-control"] == "no-store"
