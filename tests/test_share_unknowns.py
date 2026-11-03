"""A shared model, a like and a build answered when a count, a mark or a
credit beside them cannot be read (shareread, 2026-11-03).

rel-m251's live share_probe failed one check when Supabase answered one
read of a model's build count with 555 (`share: database GET model_stats:
555`), and the whole GET /api/share?id= failed with it: the viewer, the
gallery tool a session reads and the model page all lost the model for a
number beside it. The real handlers run here over the design stand-in's
world (tools/web/design_stand_in.mjs), the tables named answering 555:
what was asked for still goes out, the field read from that table is null
(unknown, never 0 or false), and the failure is in the log by name.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The watchtower, its designer's, with a mark, builds, likes, photos, a
# collection and what it is based on in the stand-in.
MODEL = "DesignAbc1"


def asked(failing: list[str], body: str) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process over the stand-in, every database request whose
    path starts with one of [failing] answering 555. It has `share(query)`
    and `people(query, body)` (signed in as Sam, POST), each {status, json,
    html}, and `logged`, every console.error line so far."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "const { webcrypto } = await import('node:crypto');"
        # The first ask sets the stand-in up: its env, its fetch, the handlers.
        "await s.serverAsk('api', { name: 'share', query: { op: 'page', id: 'DesignAbc1' } });"
        f"const failing = {json.dumps(failing)};"
        "const pair = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);"
        "const jwk = { ...(await webcrypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'unknowns', alg: 'ES256' };"
        "const standIn = globalThis.fetch;"
        "globalThis.fetch = async (input, init = {}) => {"
        "  const url = new URL(String(input.url || input));"
        "  if (url.pathname === '/auth/v1/.well-known/jwks.json') return new Response(JSON.stringify({ keys: [jwk] }));"
        "  const path = url.pathname.replace(/^\\/rest\\/v1\\//, '');"
        "  if (url.origin === s.DB && failing.some((one) => path === one))"
        "    return new Response('{\"message\":\"stand-in outage\"}', { status: 555 });"
        "  return standIn(input, init); };"
        "const b64 = (v) => Buffer.from(typeof v === 'string' ? v : JSON.stringify(v)).toString('base64url');"
        "const head = b64({ alg: 'ES256', kid: 'unknowns', typ: 'JWT' });"
        "const claims = b64({ sub: '22222222-2222-4222-8222-222222222222', aud: 'authenticated',"
        "  iss: `${s.DB}/auth/v1`, exp: Math.floor(Date.now() / 1000) + 3600, amr: [{ method: 'otp' }] });"
        "const signature = await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pair.privateKey,"
        "  new TextEncoder().encode(`${head}.${claims}`));"
        "const token = `${head}.${claims}.${Buffer.from(signature).toString('base64url')}`;"
        "const logged = []; const said = console.error;"
        "console.error = (...words) => logged.push(words.join(' '));"
        "const answer = (r) => { let json = null; try { json = JSON.parse(r.html); } catch {} return { status: r.status, json, html: r.html }; };"
        "const share = async (query) => answer(await s.serverAsk('api', { name: 'share', query }));"
        "const handlers = { share: (await import('./api/share.js')).default, people: (await import('./api/people.js')).default };"
        "const post = async (name, query, body) => {"
        "  const response = { statusCode: 200, body: '', setHeader() { return this; },"
        "    status(code) { this.statusCode = code; return this; },"
        "    json(value) { this.body = JSON.stringify(value); return this; }, end(text) { this.body = text ?? ''; return this; } };"
        "  await handlers[name]({ method: 'POST', query, body, headers: { authorization: `Bearer ${token}`,"
        "    host: 'design.test', 'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) Brickworks unknowns check',"
        "    'sec-fetch-site': 'same-origin' } }, response);"
        "  return answer({ status: response.statusCode, html: response.body }); };"
        "const people = (query, body) => post('people', query, body);"
        "const built = (query, body) => post('share', query, body);"
        f"const out = await (async () => {{ {body} }})();"
        "console.error = said;"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_the_viewer_answer_goes_out_when_its_count_mark_credit_and_bases_cannot_be_read() -> None:
    got = asked(["model_stats", "share_tests", "rpc/feed_who", "rpc/model_bases_of"],
                f"const r = await share({{ op: '', id: '{MODEL}' }}); return {{ ...r, html: null, logged }};")
    if got is None:
        return
    assert got["status"] == 200, got
    body = got["json"]
    assert body["id"] == MODEL and body["name"] == "Riverside Watchtower" and body["model"].startswith("0 ")
    # Unknown, never none: not 0 builds, not "based on nothing", not untested.
    assert body["builds"] is None and body["based_on"] is None and body["tested"] is None
    # The credit as it was published, the profile's name not being read.
    assert body["author"] == "Robin Castell"
    for table in ("model_stats", "share_tests", "rpc/feed_who", "rpc/model_bases_of"):
        assert any(f"database {'POST' if table.startswith('rpc/') else 'GET'} {table}: 555" in line
                   for line in got["logged"]), (table, got["logged"])


def test_the_viewer_answer_is_as_before_when_everything_is_read() -> None:
    got = asked([], f"const r = await share({{ op: '', id: '{MODEL}' }}); return {{ ...r, html: null, logged }};")
    if got is None:
        return
    body = got["json"]
    assert got["status"] == 200 and body["builds"] == 37 and body["tested"]["tested"] is True
    assert isinstance(body["based_on"], list) and got["logged"] == []


def test_a_like_kept_says_so_when_its_new_count_cannot_be_read() -> None:
    got = asked(["model_stats"], f"""
const on = await people({{ op: 'like', id: '{MODEL}' }}, {{ on: true }});
const off = await people({{ op: 'like', id: '{MODEL}' }}, {{ on: false }});
return {{ on: on.json, off: off.json, status: [on.status, off.status], logged }};""")
    if got is None:
        return
    assert got["status"] == [200, 200], got
    assert got["on"] == {"id": MODEL, "liked": True, "likes": None}
    assert got["off"] == {"id": MODEL, "liked": False, "likes": None}
    assert sum("database GET model_stats: 555" in line for line in got["logged"]) == 2, got["logged"]


def test_a_like_says_its_new_count_when_it_can() -> None:
    got = asked([], f"return await people({{ op: 'like', id: '{MODEL}' }}, {{ on: true }});")
    if got is None:
        return
    assert got["status"] == 200 and got["json"] == {"id": MODEL, "liked": True, "likes": 96}


def test_a_build_counted_says_so_when_its_new_count_cannot_be_read() -> None:
    got = asked(["model_stats"], f"""
const r = await built({{ op: 'built', id: '{MODEL}' }}, {{ device: 'ab'.repeat(16) }});
return {{ status: r.status, json: r.json, logged }};""")
    if got is None:
        return
    assert got["status"] == 200, got
    assert got["json"]["builds"] is None and "counted" in got["json"]
    assert any("database GET model_stats: 555" in line for line in got["logged"]), got["logged"]


def test_the_page_and_the_embed_are_drawn_when_what_is_beside_the_model_cannot_be_read() -> None:
    failing = ["share_tests", "build_photos", "rpc/model_lists", "rpc/model_bases_of", "rpc/avatars_of",
               "rpc/feed_who", "rpc/directory_models"]
    got = asked(failing, f"""
const page = await share({{ op: 'page', id: '{MODEL}' }});
const embed = await share({{ op: 'embed', id: '{MODEL}' }});
return {{ page: [page.status, page.html], embed: [embed.status, embed.html], logged }};""")
    if got is None:
        return
    status, html = got["page"]
    assert status == 200, html[-1500:]
    assert "<h1>Riverside Watchtower</h1>" in html
    # Nothing said of what was not read: its 37 builds, from the page's own
    # row, but not "no photos yet", nor a collection, nor a mark.
    assert "Built to the last step 37 times" in html
    assert "No photos of a real build yet" not in html and "Nobody has built it yet" not in html
    assert 'id="collections"' not in html and 'class="tested"' not in html
    assert got["embed"][0] == 200 and "Riverside Watchtower" in got["embed"][1]
    for table in ("share_tests", "build_photos", "rpc/model_lists", "rpc/model_bases_of", "rpc/avatars_of"):
        assert any(f"database {'POST' if table.startswith('rpc/') else 'GET'} {table}: 555" in line
                   for line in got["logged"]), (table, got["logged"])
