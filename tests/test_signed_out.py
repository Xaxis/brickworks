"""A token refused once its session is gone (smalls5, 2026-11-18).

c3review found that /admin's Sign out everywhere left every access token the
account had working on the site's API until it ran out, up to an hour:
api/_auth.js checked the signature alone. verify now asks Supabase whether
the token's session is still there (rpc/oc_session_of), read once in
SESSION_HELD_MS an instance. api/_auth.js runs here under node against a
Supabase in memory: its signing key, and the sessions it holds, which a test
deletes as admin_sign_out does. tools/web/signed_out_check.mjs is the same on
a deployment.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(body: str) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process with `auth` (api/_auth.js), `token(session, more)`
    (a token Supabase would hand out for [session]), `sessions` (the ids
    Supabase holds), `reads` (how many times the sessions were asked
    after), `down(on)` (the database stops answering), `later(ms)` (the
    clock moved on) and `refused(promise)` ({status, error} or null)."""
    if shutil.which("node") is None:
        return None
    script = (
        "const { webcrypto } = await import('node:crypto');"
        "process.env.SUPABASE_URL = 'https://sb.test'; process.env.SUPABASE_SECRET_KEY = 'secret';"
        "process.env.SUPABASE_PUBLISHABLE_KEY = 'publishable';"
        "const pair = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);"
        "const jwk = { ...(await webcrypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'k1', alg: 'ES256' };"
        "const sessions = new Set(); let reads = 0; let isDown = false;"
        "const down = (on) => { isDown = on; };"
        "globalThis.fetch = async (input, init = {}) => {"
        "  const url = new URL(String(input.url || input));"
        "  if (url.pathname === '/auth/v1/.well-known/jwks.json') return Response.json({ keys: [jwk] });"
        "  if (url.pathname === '/rest/v1/rpc/oc_session_of') {"
        "    reads += 1;"
        "    if (isDown) return new Response('{}', { status: 503 });"
        "    const id = JSON.parse(init.body).session;"
        "    return Response.json({ exists: sessions.has(id), bound: false, linked: false });"
        "  }"
        "  return new Response('{}', { status: 404 }); };"
        "let shift = 0; const realNow = Date.now; Date.now = () => realNow() + shift;"
        "const later = (ms) => { shift += ms; };"
        "const b64 = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');"
        "const token = async (session, more = {}) => {"
        "  const head = b64({ alg: 'ES256', kid: 'k1', typ: 'JWT' });"
        "  const now = Math.floor(realNow() / 1000);"
        "  const claims = b64({ sub: '11111111-1111-4111-8111-111111111111', aud: 'authenticated',"
        "    iss: 'https://sb.test/auth/v1', exp: now + 3600, iat: now, email: 'someone@example.com',"
        "    amr: [{ method: 'otp', timestamp: now }], ...(session ? { session_id: session } : {}), ...more });"
        "  const signature = await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pair.privateKey,"
        "    new TextEncoder().encode(`${head}.${claims}`));"
        "  return `${head}.${claims}.${Buffer.from(signature).toString('base64url')}`; };"
        "const auth = await import('./api/_auth.js');"
        "const GET = { method: 'GET' }; const POST = { method: 'POST' };"
        "const refused = (promise) => promise.then(() => null, (e) => ({ status: e.status, error: e.message }));"
        "console.error = () => {};"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify({ ...out, reads }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"


def test_a_token_whose_session_is_signed_out_is_refused_and_a_new_sign_in_works() -> None:
    got = run(f"""
sessions.add('{A}');
const old = await token('{A}');
const before = await refused(auth.verify(old, GET));
later(auth.SESSION_HELD_MS + 1);
sessions.delete('{A}');  // Sign out everywhere: admin_sign_out deletes the account's sessions
const readAfter = await refused(auth.verify(old, GET));
const writeAfter = await refused(auth.verify(old, POST));
sessions.add('{B}');  // signed in again
const fresh = await refused(auth.verify(await token('{B}'), POST));
return {{ before, readAfter, writeAfter, fresh }};
""")
    if got is None:
        return
    assert got["before"] is None and got["fresh"] is None
    assert got["readAfter"] == got["writeAfter"] == {"status": 401, "error": "You were signed out. Sign in again."}


def test_a_session_is_read_once_in_its_held_time_and_a_gone_one_once_for_good() -> None:
    got = run(f"""
sessions.add('{A}');
const t = await token('{A}');
await Promise.all([auth.verify(t, GET), auth.verify(t, GET), auth.verify(t, POST)]);
await auth.verify(t, GET);
const heldReads = reads;
later(auth.SESSION_HELD_MS + 1);
await auth.verify(t, GET);
const againReads = reads;
sessions.delete('{A}');
later(auth.SESSION_HELD_MS + 1);
const first = await refused(auth.verify(t, GET));
later(3_600_000);
const still = await refused(auth.verify(t, GET));
return {{ heldReads, againReads, goneReads: reads, first: first?.status, still: still?.status }};
""")
    if got is None:
        return
    # Four calls, three of them at once, cost one read; the next after the
    # held time one more; a gone session one, and never again.
    assert got["heldReads"] == 1 and got["againReads"] == 2 and got["goneReads"] == 3
    assert got["first"] == got["still"] == 401


def test_a_session_signed_out_is_refused_at_once_by_an_instance_that_had_not_read_it() -> None:
    got = run(f"""
const t = await token('{A}');
const r = await refused(auth.verify(t, GET));
return {{ r }};
""")
    if got is None:
        return
    assert got["r"] == {"status": 401, "error": "You were signed out. Sign in again."}


def test_while_the_database_cannot_be_asked_reads_go_on_and_writes_wait() -> None:
    got = run(f"""
sessions.add('{A}');
const t = await token('{A}');
down(true);
const read = await refused(auth.verify(t, GET));
const write = await refused(auth.verify(t, POST));
const unnamed = await refused(auth.verify(t));
down(false);
const back = await refused(auth.verify(t, POST));
return {{ read, write, unnamed, back }};
""")
    if got is None:
        return
    assert got["read"] is None and got["back"] is None
    assert got["write"] == got["unnamed"] == {
        "status": 503, "error": "Brickworks could not check your sign-in just now. Try again in a minute."}


def test_a_slow_session_read_holds_a_call_3_s_not_15() -> None:
    """The session read is in the way of every signed-in call: given the 15 s
    of any other read, a database slow to answer held each one 15 s
    (s5review). It gives up after SESSION_READ_S, then the rule above."""
    got = run(f"""
sessions.add('{A}');
const t = await token('{A}');
const plain = globalThis.fetch;
globalThis.fetch = (input, init = {{}}) => {{
  const url = new URL(String(input.url || input));
  if (url.pathname !== '/rest/v1/rpc/oc_session_of') return plain(input, init);
  reads += 1;
  return new Promise((done, fail) => init.signal?.addEventListener('abort', () => fail(init.signal.reason)));
}};
const keep = setInterval(() => {{}}, 500);
let at = Date.now();
const read = await refused(auth.verify(t, GET));
const readMs = Date.now() - at;
at = Date.now();
const write = await refused(auth.verify(t, POST));
const writeMs = Date.now() - at;
clearInterval(keep);
return {{ read, readMs, write, writeMs }};
""")
    if got is None:
        return
    assert got["read"] is None and got["write"]["status"] == 503, got
    assert 2500 <= got["readMs"] < 3500 and 2500 <= got["writeMs"] < 3500, got


def test_a_token_without_a_session_id_is_not_asked_after() -> None:
    got = run("const r = await refused(auth.verify(await token(null), POST)); return { r };")
    if got is None:
        return
    assert got["r"] is None and got["reads"] == 0


def test_a_forged_session_id_does_not_get_past_the_signature() -> None:
    got = run(f"""
sessions.add('{A}');
const [h, , s] = (await token('{B}')).split('.');
const claims = Buffer.from(JSON.stringify({{ sub: 'x', aud: 'authenticated', iss: 'https://sb.test/auth/v1',
  session_id: '{A}', exp: Math.floor(Date.now() / 1000) + 60 }})).toString('base64url');
const r = await refused(auth.verify(`${{h}}.${{claims}}.${{s}}`, GET));
return {{ r }};
""")
    if got is None:
        return
    assert got["r"]["status"] == 401 and got["reads"] == 0
