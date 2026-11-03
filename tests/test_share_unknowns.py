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
    `people(query, body)` and `built(query, body)` (signed in as Sam, POST),
    `signed(handler, method, query, body)`, `visit(query)` (api/people.js as
    a visitor), each {status, json, html}, and `logged`, every console.error
    line so far."""
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
        "const signed = async (name, method, query, body) => {"
        "  const response = { statusCode: 200, body: '', setHeader() { return this; },"
        "    status(code) { this.statusCode = code; return this; },"
        "    json(value) { this.body = JSON.stringify(value); return this; }, end(text) { this.body = text ?? ''; return this; } };"
        "  await handlers[name]({ method, query, body, headers: { authorization: `Bearer ${token}`,"
        "    host: 'design.test', 'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) Brickworks unknowns check',"
        "    'sec-fetch-site': 'same-origin' } }, response);"
        "  return answer({ status: response.statusCode, html: response.body }); };"
        "const people = (query, body) => signed('people', 'POST', query, body);"
        "const built = (query, body) => signed('share', 'POST', query, body);"
        "const visit = async (query) => answer(await s.serverAsk('api', { name: 'people', query }));"
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


def logged_all(got: dict, tables: list[str]) -> None:
    for table in tables:
        said = f"database {'POST' if table.startswith('rpc/') else 'GET'} {table}: 555"
        assert any(said in line for line in got["logged"]), (table, got["logged"])


# What a profile is beside its person and their models: their numbers and
# collections, builds, follows, what their models earned, their showcase,
# what they won, their levels, whom they follow and how many they liked.
PROFILE_BESIDE = ["rpc/profile_page", "build_photos", "rpc/follow_state", "rpc/designer_page", "profile_shows",
                  "rpc/challenge_wins", "rpc/achievement_levels", "rpc/follow_list", "rpc/profile_likes_count",
                  "profile_choices"]


def test_a_profile_goes_out_when_what_is_beside_its_person_cannot_be_read() -> None:
    got = asked(PROFILE_BESIDE, """
const json = await visit({ op: 'profile', handle: 'design-tester' });
const page = await visit({ op: 'page', handle: 'design-tester' });
const builds = await visit({ op: 'page', handle: 'design-tester', tab: 'builds' });
return { json: [json.status, json.json], page: [page.status, page.html], builds: [builds.status, builds.html], logged };""")
    if got is None:
        return
    status, body = got["json"]
    assert status == 200, body
    assert body["handle"] == "design-tester" and body["name"] == "Robin Castell" and body["models"]
    # Unknown, never none.
    for key in ("models_count", "likes", "followers", "following", "collections", "built", "links", "banner", "pins",
                "levels", "designer", "liked_count"):
        assert body[key] is None, (key, body[key])
    status, html = got["page"]
    assert status == 200, html[-1500:]
    assert "<h1>Robin Castell</h1>" in html or ">Robin Castell<" in html
    assert "0 models by" not in html
    status, html = got["builds"]
    assert status == 200 and "No builds yet" not in html, html[-1500:]
    logged_all(got, PROFILE_BESIDE[:-2])


def test_a_collection_page_goes_out_when_its_cover_and_follows_cannot_be_read() -> None:
    got = asked(["model_collection_items", "rpc/list_follow_state"], """
const page = await visit({ op: 'list_page', id: 'ListAbcde1' });
return { page: [page.status, page.html], logged };""")
    if got is None:
        return
    status, html = got["page"]
    assert status == 200, html[-1500:]
    assert 'data-id="' in html
    logged_all(got, ["rpc/list_follow_state"])


def test_a_challenge_goes_out_when_your_vote_cannot_be_read() -> None:
    got = asked(["rpc/challenge_mine"], """
const seen = await visit({ op: 'challenge', id: '3' });
const mine = await signed('people', 'GET', { op: 'challenge', id: '3' });
return { seen: [seen.status, seen.json], mine: [mine.status, mine.json], logged };""")
    if got is None:
        return
    status, body = got["seen"]
    assert status == 200 and body["challenge"]["title"] == "Off-world October", body
    status, body = got["mine"]
    assert status == 200 and body["challenge"]["id"] == 3, body
    # Signed in, and nothing said of their vote: not "you may not".
    assert body["you"] == {"signed_in": True}
    logged_all(got, ["rpc/challenge_mine"])
