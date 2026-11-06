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


def test_a_label_is_what_was_checked_not_what_a_client_calls_itself() -> None:
    """docs/ANY_ASSISTANT.md U1: a client is labelled by its published
    document's address or by a known host its codes go back to; a name it
    chose is shown only where the codes go to the person's own machine, or
    when it names no assistant it is not."""
    got = run("""
const { clientLabel, isClaude } = await import('./api/_oauth.js');
const cases = {
  claudeAi: { client_id: CLAUDE, client_name: 'Claude', redirect_uri: 'https://claude.ai/api/mcp/auth_callback' },
  claudeCodeDocument: { client_id: 'https://claude.ai/oauth/claude-code-client-metadata', client_name: 'Claude Code',
    redirect_uri: 'http://localhost:51123/callback' },
  codex: { client_id: 'https://chatgpt.com/oauth/codex/client.json', client_name: 'codex',
    redirect_uri: 'http://127.0.0.1:1455/callback' },
  vscode: { client_id: 'https://vscode.dev/oauth/client-metadata.json', client_name: 'VS Code',
    redirect_uri: 'https://vscode.dev/redirect' },
  zed: { client_id: 'https://zed.dev/oauth/client-metadata.json', client_name: 'zed.dev',
    redirect_uri: 'http://127.0.0.1:52001/callback' },
  gemini: { client_id: 'bwc_g', client_name: 'Gemini',
    redirect_uri: 'https://oauth-redirect.googleusercontent.com/r/gemini-connected-apps' },
  geminiOtherName: { client_id: 'bwc_g2', client_name: 'Google connected apps',
    redirect_uri: 'https://oauth-redirect-sandbox.googleusercontent.com/a/gemini' },
  copilot: { client_id: 'bwc_m', client_name: 'Copilot connector',
    redirect_uri: 'https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect' },
  perplexity: { client_id: 'bwc_p', client_name: 'Perplexity',
    redirect_uri: 'https://www.perplexity.ai/rest/connections/oauth_callback' },
  grok: { client_id: 'bwc_x', client_name: 'Grok', redirect_uri: 'https://console.x.ai/connectors-oauth-exchange-code/' },
  cursorWeb: { client_id: 'bwc_c', client_name: 'Cursor', redirect_uri: 'https://www.cursor.com/agents/mcp/oauth/callback' },
  geminiCli: { client_id: 'bwc_gc', client_name: 'Gemini CLI MCP Client', redirect_uri: 'http://localhost:7777/oauth/callback' },
  someoneNew: { client_id: 'bwc_n', client_name: 'Brick Buddy', redirect_uri: 'https://buddy.example/callback' },
  nameless: { client_id: 'bwc_0', client_name: null, redirect_uri: 'https://assistant.example/oauth/callback' },
  fakeClaude: { client_id: 'bwc_f', client_name: 'Claude', redirect_uri: 'https://not-claude.example/callback' },
  fakeClaudeCode: { client_id: 'bwc_f2', client_name: 'Claude Code', redirect_uri: 'https://not-claude.example/cc' },
  fakeChatgpt: { client_id: 'bwc_f3', client_name: 'ChatGPT', redirect_uri: 'https://chatgpt.example.net/back' },
  fakeByHello: { client_id: 'bwc_f4', client_name: null, client_info: { name: 'claude-ai', version: '1' },
    redirect_uri: 'https://assistant.example/oauth/callback' },
  fakeDocument: { client_id: 'https://not-claude.example/client.json', client_name: 'Claude',
    redirect_uri: 'https://not-claude.example/callback' },
};
const labels = Object.fromEntries(Object.entries(cases).map(([k, v]) => [k, clientLabel(v)]));
return { labels, claude: Object.keys(cases).filter((k) => isClaude(labels[k])) };
""")
    if got is None:
        return
    assert got["labels"] == {
        "claudeAi": "Claude", "claudeCodeDocument": "Claude Code", "codex": "Codex",
        "vscode": "Visual Studio Code", "zed": "Zed", "gemini": "Gemini", "geminiOtherName": "Gemini",
        "copilot": "Microsoft Copilot", "perplexity": "Perplexity", "grok": "Grok", "cursorWeb": "Cursor",
        "geminiCli": "Gemini CLI MCP Client", "someoneNew": "Brick Buddy", "nameless": "An MCP client",
        "fakeClaude": "not-claude.example", "fakeClaudeCode": "not-claude.example",
        "fakeChatgpt": "chatgpt.example.net", "fakeByHello": "assistant.example",
        "fakeDocument": "not-claude.example",
    }
    assert got["claude"] == ["claudeAi", "claudeCodeDocument"]


# A connection of [client] holding one refresh token, as trading a code
# leaves it; a refresh as the client sends it; the clock moved on.
CONNECT = """
const { sha256 } = await import('./api/_oauth.js');
const { randomBytes, randomUUID } = await import('node:crypto');
const connect = (client) => {
  const grant = { id: randomUUID(), owner: randomUUID(), client_id: client, resource: `${ORIGIN}/api/mcp`,
    scope: 'build', oc_rh: null };
  w.tables.oauth_grants.push(grant);
  const refresh = `bwr_${randomBytes(32).toString('base64url')}`;
  w.tables.oauth_tokens.push({ hash: sha256(refresh), grant_id: grant.id, kind: 'refresh', replaced_at: null,
    expires_at: new Date(Date.now() + 86400e3).toISOString() });
  return { grant, refresh };
};
const refresh = async (fields, headers = {}) => {
  const got = await askOAuth({ method: 'POST', query: { op: 'token' }, headers,
    body: { grant_type: 'refresh_token', ...fields } });
  return { status: got.status, error: got.json.error || null, refresh: got.json.refresh_token || null,
    access: /^bwa_/.test(got.json.access_token || '') };
};
const later = (ms) => { const was = Date.now; Date.now = () => was() + ms; };
const alive = (grant) => w.tables.oauth_grants.some((one) => one.id === grant.id);
const register = async (more) => (await askOAuth({ method: 'POST', query: { op: 'register' },
  body: { grant_types: ['authorization_code', 'refresh_token'], response_types: ['code'], ...more } })).json;
const basic = (id, secret) => `Basic ${Buffer.from(`${id}:${secret}`).toString('base64')}`;
"""


def test_a_client_that_proves_itself_keeps_its_refresh_token() -> None:
    """docs/ANY_ASSISTANT.md U2: Gemini registers with a secret and, as
    Google tells it to, sends the first refresh token again after the
    access token's hour. A client that proves itself (a secret, either way,
    or a signed assertion) keeps one refresh token, its expiry moved on;
    the connection stays."""
    got = run(CONNECT + """
const gemini = await register({ client_name: 'Gemini', token_endpoint_auth_method: 'client_secret_post',
  redirect_uris: ['https://oauth-redirect.googleusercontent.com/r/gemini-connected-apps'] });
const copilot = await register({ client_name: 'Microsoft Copilot', token_endpoint_auth_method: 'client_secret_basic',
  redirect_uris: ['https://teams.microsoft.com/api/platform/v1.0/oAuthRedirect'] });
const ways = {
  gemini: [gemini.client_id, (r) => refresh({ refresh_token: r, client_id: gemini.client_id,
    client_secret: gemini.client_secret })],
  copilot: [copilot.client_id, (r) => refresh({ refresh_token: r },
    { authorization: basic(copilot.client_id, copilot.client_secret) })],
  chatgpt: [CHATGPT, (r) => refresh({ refresh_token: r, client_assertion_type: ASSERTION_TYPE,
    client_assertion: w.sign() })],
};
const held = Object.fromEntries(Object.entries(ways).map(([name, [id]]) => [name, connect(id)]));
const out = {};
for (const [name, [, send]] of Object.entries(ways)) {
  const { refresh: r0 } = held[name];
  const row = () => w.tables.oauth_tokens.find((one) => one.hash === sha256(r0));
  const was = row().expires_at;
  const first = await send(r0);
  out[name] = { first: [first.status, first.refresh === r0, first.access], moved: row().expires_at > was };
}
later(32_000);
for (const [name, [, send]] of Object.entries(ways)) {
  const again = await send(held[name].refresh);
  out[name].again = [again.status, again.refresh === held[name].refresh, again.access, again.error];
  out[name].stays = alive(held[name].grant);
}
// Another client's refresh token, presented by one that proves itself: no.
const other = connect(CLAUDE);
const stolen = await ways.gemini[1](other.refresh);
out.stolen = [stolen.status, stolen.error, alive(other.grant)];
return out;
""")
    if got is None:
        return
    for name in ("gemini", "copilot", "chatgpt"):
        assert got[name]["first"] == [200, True, True], (name, got[name])
        assert got[name]["moved"], (name, got[name])
        assert got[name]["again"] == [200, True, True, None], (name, got[name])
        assert got[name]["stays"], (name, got[name])
    assert got["stolen"] == [400, "invalid_grant", True]


def test_a_public_client_still_rotates_and_a_late_reuse_ends_the_connection() -> None:
    """OAuth 2.1 asks rotation of public clients: Claude's refresh token is
    replaced; sent again within the grace it is a retry, after it somebody
    else's copy, which ends the connection."""
    got = run(CONNECT + """
const cursor = await register({ client_name: 'Cursor', token_endpoint_auth_method: 'none',
  redirect_uris: ['https://www.cursor.com/agents/mcp/oauth/callback'] });
const out = {};
for (const [name, id] of [['claude', CLAUDE], ['cursor', cursor.client_id]]) {
  const { grant, refresh: r0 } = connect(id);
  const first = await refresh({ refresh_token: r0, client_id: id });
  const retry = await refresh({ refresh_token: r0, client_id: id });
  out[name] = { grant, r0, first: [first.status, first.refresh !== r0 && Boolean(first.refresh)],
    retry: retry.status, newest: first.refresh };
}
later(32_000);
for (const [name, id] of [['claude', CLAUDE], ['cursor', cursor.client_id]]) {
  const late = await refresh({ refresh_token: out[name].r0, client_id: id });
  const newest = await refresh({ refresh_token: out[name].newest, client_id: id });
  Object.assign(out[name], { late: [late.status, late.error], ended: !alive(out[name].grant),
    newestAfter: newest.status });
  delete out[name].grant; delete out[name].r0; delete out[name].newest;
}
return out;
""")
    if got is None:
        return
    for name in ("claude", "cursor"):
        assert got[name] == {"first": [200, True], "retry": 200, "late": [400, "invalid_grant"], "ended": True,
                             "newestAfter": 400}, (name, got[name])


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
    assert got["n"] == 74
    # Claude's list keeps its arrays that say no items; nobody else's has one.
    assert got["bareClaude"] > 0 and got["bareOther"] == 0
    assert got["hintsOther"] == 74 and got["hintsClaude"] < 74


def test_the_tab_is_told_who_calls_by_the_connection_not_by_the_client() -> None:
    """docs/ANY_ASSISTANT.md U1: a call's `brickworks/who` is the
    connection's label, whatever the client put in its _meta, and no
    other `brickworks/` key of the client's reaches the tab; the rest of
    its _meta does."""
    got = run("""
const { callerMeta } = await import('./api/mcp.js');
const forged = { _meta: { 'brickworks/who': 'Somebody else', 'brickworks/chat': { chat: 'forged' },
  'brickworks/views': true, progressToken: 7 } };
return {
  account: callerMeta(forged, 'ChatGPT'),
  tabAddress: callerMeta(forged, ''),
  nothingSent: callerMeta({ name: 'search_parts' }, 'Gemini'),
  notAnObject: callerMeta({ _meta: ['brickworks/who'] }, 'Grok'),
};
""")
    if got is None:
        return
    assert got["account"] == {"progressToken": 7, "brickworks/who": "ChatGPT"}
    assert got["tabAddress"] == {"progressToken": 7}
    assert got["nothingSent"] == {"brickworks/who": "Gemini"}
    assert got["notAnObject"] == {"brickworks/who": "Grok"}
