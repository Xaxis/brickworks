"""ChatGPT signing in to Brickworks beside Claude (docs/PROVIDERS.md, P1).

api/oauth.js and api/_assertion.js run here under node against an
in-memory database and the clients' published documents
(tests/fixtures/oauth/world.mjs), ChatGPT's keys being a test key that
stands in for its own:

- private_key_jwt (RFC 7523): ChatGPT's assertion taken; refused when the
  signature is another key's, aud is another server's, it has expired or
  lasts too long, iss or sub is not the client, alg is not RS256, or its
  jti was spent before; a key rotated is read again;
- a client whose document prefers private_key_jwt must sign; one that
  lists "none" with no preference may go without, and an assertion it
  sends is still checked;
- "none": Claude's documents are taken as before, with nothing sent, and
  their rows never name the new columns;
- registration with public keys, and the metadata that makes ChatGPT sign;
- the relay's tool list: Claude's word for word as before, any other
  client's with every array's items said and all three hints.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORLD = "./tests/fixtures/oauth/world.mjs"


def run(body: str) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process, with the world `w`, api/oauth.js as `oauth`, and
    the world's names (ORIGIN, CHATGPT, CLAUDE, ASSERTION_TYPE, ...)."""
    if shutil.which("node") is None:
        return None
    script = (
        f"import * as names from '{WORLD}';"
        "const { ORIGIN, CHATGPT, CHATGPT_KEYS, CLAUDE, ASSERTION_TYPE, askOAuth, keyPair, publicJwk } = names;"
        "const w = await names.world();"
        "const oauth = await import('./api/oauth.js');"
        "const asserted = (jwt, more = {}) => oauth.callingClient(w.request(),"
        " { client_assertion_type: ASSERTION_TYPE, client_assertion: jwt, ...more }, ORIGIN);"
        "const named = (got) => ({ client: got.client ? got.client.client_id : null, why: got.why || null });"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_chatgpt_signed_assertion_is_taken() -> None:
    got = run("""
const first = named(await asserted(w.sign()));
return { first, row: w.clients.get(CHATGPT) };
""")
    if got is None:
        return
    assert got["first"] == {"client": "https://chatgpt.com/oauth/client.json", "why": None}
    row = got["row"]
    assert row["auth_method"] == "private_key_jwt" and row["jwks_uri"] == "https://chatgpt.com/oauth/jwks.json"
    assert row["client_name"] == "ChatGPT" and row["secret_hash"] is None
    assert row["redirect_uris"] == ["https://chatgpt.com/connector_platform_oauth_redirect"]


def test_a_signature_by_another_key_is_refused() -> None:
    got = run("return named(await asserted(w.sign({}, { pair: keyPair() })));")
    if got is None:
        return
    assert got == {"client": None, "why": "client_assertion is not signed by a key of this client"}


def test_aud_must_name_this_server() -> None:
    got = run("""
return {
  elsewhere: named(await asserted(w.sign({ aud: 'https://elsewhere.test/oauth/token' }))),
  missing: named(await asserted(w.sign({ aud: undefined }))),
  issuer: named(await asserted(w.sign({ aud: ORIGIN + '/' }))),
  listed: named(await asserted(w.sign({ aud: ['https://elsewhere.test', ORIGIN + '/oauth/token'] }))),
};
""")
    if got is None:
        return
    assert got["elsewhere"]["why"] == got["missing"]["why"] == "client_assertion's aud must name this server"
    assert got["issuer"]["client"] == got["listed"]["client"] == "https://chatgpt.com/oauth/client.json"


def test_expired_and_overlong_assertions_are_refused() -> None:
    got = run("""
const now = Math.floor(Date.now() / 1000);
return {
  expired: named(await asserted(w.sign({ iat: now - 900, exp: now - 120 }))),
  overlong: named(await asserted(w.sign({ exp: now + 7200 }))),
  early: named(await asserted(w.sign({ nbf: now + 600 }))),
  noExp: named(await asserted(w.sign({ exp: undefined }))),
  spent: w.spent.size,
};
""")
    if got is None:
        return
    assert got["expired"]["why"] == "client_assertion has expired"
    assert got["overlong"]["why"] == "client_assertion lasts longer than an hour"
    assert got["early"]["why"] == "client_assertion is not valid yet"
    assert got["noExp"]["why"] == "client_assertion has no exp"
    # Nothing that failed spent its jti.
    assert got["spent"] == 0


def test_a_replayed_jti_is_refused() -> None:
    got = run("""
const jwt = w.sign();
const first = named(await asserted(jwt));
const again = named(await asserted(jwt));
const sameJti = named(await asserted(w.sign({ jti: JSON.parse(Buffer.from(jwt.split('.')[1], 'base64url')).jti })));
return { first, again, sameJti, keys: [...w.spent.keys()] };
""")
    if got is None:
        return
    assert got["first"]["client"] == "https://chatgpt.com/oauth/client.json"
    assert got["again"]["why"] == got["sameJti"]["why"] == "client_assertion was used before"
    # Kept under a key of the client and the jti, never the raw jti.
    assert len(got["keys"]) == 1 and got["keys"][0].startswith("oauth:") and len(got["keys"][0]) == 70


def test_iss_sub_and_client_id_must_be_the_client() -> None:
    got = run("""
return {
  sub: named(await asserted(w.sign({ sub: 'someone-else' }))),
  iss: named(await asserted(w.sign({ iss: CLAUDE }))),
  clientId: named(await asserted(w.sign(), { client_id: CLAUDE })),
  secretToo: named(await asserted(w.sign(), { client_secret: 'x' })),
  wrongType: named(await oauth.callingClient(w.request(), { client_assertion_type: 'urn:other', client_assertion: w.sign() }, ORIGIN)),
};
""")
    if got is None:
        return
    assert got["sub"]["why"] == "client_assertion's iss and sub must be the client_id"
    # Claude's document has no keys: an assertion naming it checks nothing.
    assert got["iss"]["why"] == "this client has no keys to check a client_assertion by"
    assert got["clientId"]["why"] == "client_assertion must name the client_id as its iss"
    assert got["secretToo"]["why"] == "one way of authenticating a request, not two"
    assert got["wrongType"]["why"].startswith("client_assertion_type must be")


def test_only_rs256() -> None:
    got = run("""
const [h, b] = w.sign().split('.');
const header = (alg) => Buffer.from(JSON.stringify({ alg, kid: 'cimd-test' })).toString('base64url');
return {
  none: named(await asserted(`${header('none')}.${b}.`)),
  hs256: named(await asserted(`${header('HS256')}.${b}.c2lnbmF0dXJl`)),
  junk: named(await asserted('not.a-jwt')),
};
""")
    if got is None:
        return
    assert got["none"]["why"] == got["hs256"]["why"] == "client_assertion must be signed RS256"
    assert got["junk"]["client"] is None


def test_chatgpt_must_sign() -> None:
    got = run("return named(await oauth.callingClient(w.request(), { client_id: CHATGPT }, ORIGIN));")
    if got is None:
        return
    assert got == {"client": None, "why": "this client signs its token requests: send a client_assertion"}


def test_claude_is_a_public_client_as_before() -> None:
    got = run("""
const claude = named(await oauth.callingClient(w.request(), { client_id: CLAUDE }, ORIGIN));
return { claude, row: w.clients.get(CLAUDE) };
""")
    if got is None:
        return
    assert got["claude"] == {"client": "https://claude.ai/oauth/mcp-oauth-client-metadata", "why": None}
    # Its row is what it always was: the new columns are never named, so it
    # is kept whether or not supabase/oauth_keys.sql has been applied.
    assert set(got["row"]) == {"client_id", "client_name", "redirect_uris", "auth_method", "secret_hash", "fetched_at"}
    assert got["row"]["auth_method"] == "none"


def test_a_document_listing_none_with_no_preference() -> None:
    got = run("""
const doc = { ...w.documents.get(CHATGPT) };
delete doc.token_endpoint_auth_method;
w.documents.set(CHATGPT, doc);
return {
  bare: named(await oauth.callingClient(w.request(), { client_id: CHATGPT }, ORIGIN)),
  signed: named(await asserted(w.sign())),
  forged: named(await asserted(w.sign({}, { pair: keyPair() }))),
  row: w.clients.get(CHATGPT),
};
""")
    if got is None:
        return
    assert got["bare"]["client"] == got["signed"]["client"] == "https://chatgpt.com/oauth/client.json"
    assert got["forged"]["why"] == "client_assertion is not signed by a key of this client"
    assert got["row"]["auth_method"] == "none" and got["row"]["jwks_uri"] == "https://chatgpt.com/oauth/jwks.json"


def test_documents_that_cannot_be_honoured_are_refused() -> None:
    got = run("""
const out = {};
for (const [name, change] of [
  ['keysElsewhere', { jwks_uri: 'https://keys.example/jwks.json' }],
  ['keysPlainHttp', { jwks_uri: 'http://chatgpt.com/oauth/jwks.json' }],
  ['notRs256', { token_endpoint_auth_signing_alg: 'ES256' }],
  ['aSecret', { token_endpoint_auth_method: 'client_secret_basic' }],
]) {
  w.clients.clear();
  w.documents.set(CHATGPT, { ...w.documents.get(CHATGPT), ...change });
  out[name] = named(await asserted(w.sign()));
  w.documents.set(CHATGPT, { ...w.documents.get(CHATGPT), jwks_uri: CHATGPT_KEYS,
    token_endpoint_auth_signing_alg: 'RS256', token_endpoint_auth_method: 'private_key_jwt' });
}
return out;
""")
    if got is None:
        return
    for name, said in got.items():
        assert said == {"client": None, "why": "unknown client, or a wrong secret"}, name


def test_a_rotated_key_is_read_again() -> None:
    got = run("""
const first = named(await asserted(w.sign()));
const next = keyPair();
w.keys.set(CHATGPT_KEYS, { keys: [publicJwk(next, 'cimd-next')] });
const before = w.calls.filter((c) => c.endsWith('/oauth/jwks.json')).length;
const rotated = named(await asserted(w.sign({}, { pair: next, kid: 'cimd-next' })));
const after = w.calls.filter((c) => c.endsWith('/oauth/jwks.json')).length;
// A kid nobody published, straight after: not read again within the minute.
const unknown = named(await asserted(w.sign({}, { pair: next, kid: 'cimd-never' })));
const last = w.calls.filter((c) => c.endsWith('/oauth/jwks.json')).length;
return { first, rotated, unknown, reads: [before, after, last] };
""")
    if got is None:
        return
    assert got["first"]["client"] == got["rotated"]["client"] == "https://chatgpt.com/oauth/client.json"
    assert got["unknown"]["why"] == "client_assertion is not signed by a key of this client"
    assert got["reads"] == [1, 2, 2]


def test_metadata_makes_chatgpt_sign_and_claude_stay_public() -> None:
    got = run("return await askOAuth({ query: { op: 'metadata' } });")
    if got is None:
        return
    meta = got["json"]
    assert got["status"] == 200 and meta["client_id_metadata_document_supported"] is True
    assert meta["token_endpoint_auth_methods_supported"][0] == "none"
    assert "private_key_jwt" in meta["token_endpoint_auth_methods_supported"]
    assert meta["token_endpoint_auth_signing_alg_values_supported"] == ["RS256"]
    assert meta["code_challenge_methods_supported"] == ["S256"]
    assert meta["authorization_response_iss_parameter_supported"] is True


def test_a_registered_client_signs_with_the_keys_it_gave() -> None:
    got = run("""
const pair = keyPair();
const base = { client_name: 'stand-in', redirect_uris: ['http://127.0.0.1:9641/callback'],
  token_endpoint_auth_method: 'private_key_jwt' };
const made = await askOAuth({ method: 'POST', query: { op: 'register' },
  body: { ...base, jwks: { keys: [publicJwk(pair, 'k1')] } } });
const id = made.json.client_id;
const signed = named(await asserted(w.sign({}, { pair, kid: 'k1', client: id })));
const bare = named(await oauth.callingClient(w.request(), { client_id: id }, ORIGIN));
const weak = (await import('node:crypto')).generateKeyPairSync('rsa', { modulusLength: 1024 });
return {
  status: made.status, method: made.json.token_endpoint_auth_method, secret: made.json.client_secret || null,
  kept: Object.keys(w.clients.get(id).jwks.keys[0]).sort(), signed, bare,
  byAddress: (await askOAuth({ method: 'POST', query: { op: 'register' },
    body: { ...base, jwks_uri: 'https://keys.example/jwks.json' } })).status,
  weakKey: (await askOAuth({ method: 'POST', query: { op: 'register' },
    body: { ...base, jwks: { keys: [publicJwk(weak, 'k1')] } } })).status,
  noKeys: (await askOAuth({ method: 'POST', query: { op: 'register' }, body: base })).status,
};
""")
    if got is None:
        return
    assert got["status"] == 201 and got["method"] == "private_key_jwt" and got["secret"] is None
    assert got["kept"] == ["alg", "e", "kid", "kty", "n", "use"]
    assert got["signed"]["client"] and got["signed"]["why"] is None
    assert got["bare"]["why"] == "this client signs its token requests: send a client_assertion"
    assert got["byAddress"] == got["weakKey"] == got["noKeys"] == 400


def test_client_labels() -> None:
    got = run("""
const { clientLabel, isClaude } = await import('./api/_oauth.js');
const labels = [
  { client_name: 'ChatGPT', redirect_uri: 'https://chatgpt.com/connector_platform_oauth_redirect' },
  { client_name: 'ChatGPT', redirect_uri: 'https://chatgpt.com/connector/oauth/abc123' },
  { client_name: 'Claude', redirect_uri: 'https://claude.ai/api/mcp/auth_callback' },
  { client_name: 'Claude Code', redirect_uri: 'http://localhost:41234/callback' },
  { client_name: 'Cursor', redirect_uri: 'cursor://anysphere.cursor-mcp/oauth/callback' },
].map(clientLabel);
return { labels, claude: labels.map(isClaude) };
""")
    if got is None:
        return
    assert got["labels"] == ["ChatGPT", "ChatGPT", "Claude", "Claude Code", "Cursor"]
    assert got["claude"] == [False, False, True, True, False]


def test_the_relay_gives_claude_its_list_as_before_and_others_a_portable_one() -> None:
    got = run("""
const { toolsWithTabs } = await import('./api/mcp.js');
const app = JSON.parse((await import('node:fs')).readFileSync('tools/mcp_tools.json', 'utf8'))
  .map((t) => ({ name: t.name, description: t.description, inputSchema: t.input_schema, annotations: t.annotations }));
const claude = toolsWithTabs(app, false, true);
const asBefore = toolsWithTabs(app, false);
const other = toolsWithTabs(app, false, false);
const bare = [];
const walk = (schema, where) => {
  if (!schema || typeof schema !== 'object') return;
  if (schema.type === 'array' && schema.items === undefined) bare.push(where);
  for (const [k, v] of Object.entries(schema.properties || {})) walk(v, `${where}.${k}`);
  if (schema.items && typeof schema.items === 'object') walk(schema.items, `${where}[]`);
};
const count = (list) => { bare.length = 0; for (const t of list) walk(t.inputSchema, t.name); return bare.length; };
const hints = (list) => list.filter((t) => ['readOnlyHint', 'destructiveHint', 'openWorldHint']
  .every((h) => typeof t.annotations?.[h] === 'boolean')).length;
const strip = (list) => JSON.stringify(list.map((t) => t.name));
return {
  same: JSON.stringify(claude) === JSON.stringify(asBefore), n: claude.length, names: strip(claude) === strip(other),
  bareClaude: count(claude), bareOther: count(other), hintsClaude: hints(claude), hintsOther: hints(other),
  descriptions: JSON.stringify(claude.map((t) => t.description)) === JSON.stringify(other.map((t) => t.description)),
  readOnly: other.filter((t) => t.annotations.readOnlyHint).every((t) => t.annotations.destructiveHint === false),
};
""")
    if got is None:
        return
    assert got["same"] and got["names"] and got["descriptions"] and got["readOnly"]
    assert got["n"] == 69
    # Claude's list keeps its arrays that say no items; nobody else's has one.
    assert got["bareClaude"] > 0 and got["bareOther"] == 0
    assert got["hintsOther"] == 69 and got["hintsClaude"] < 69
