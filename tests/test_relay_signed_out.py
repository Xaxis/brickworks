"""A tab's connector ends with the sign-in it was switched on with (smalls6, 2026-11-18).

Sign out everywhere (/admin, admin_sign_out) ended every token of the account
within about 5 s (smalls5), but a tab's own address (/api/mcp?t=<token>) went
on reaching the tab: its asks for work (op=next) and its answers carry no
token. On brickworks.diy a tab switched on before served every call made
through its address for as long as it stayed open
(bench/results/smalls6-2026-11-18/relay/relay_signout_live.log: 18 of 18 calls
in the 20 s after). Now the hello's session is kept with the tab's row
(supabase/relay_session.sql), and once Supabase no longer has it:

  - Claude's calls through the address are refused with words that say what
    happened and what to do, and nothing goes in the tab's queue;
  - a call already waiting, or answered after, is not passed on;
  - the tab's ask for work is told to say hello again (401) and the tab is
    closed; a hello needs a sign-in that stands, so only a new one opens it;
  - a row from before the file, with no session, is told to say hello again.

And it never fails open (s6review, 2026-11-19). L1: one failed ask whether the
column was there skipped every session check on that instance for a minute;
the column is live, so it is always read, and a sign-in Supabase cannot be
asked about refuses the call for now, in words that say so, and hands the tab
nothing. L2: an account's call picked an ended tab first and was refused
although another tab of the account was still signed in; ended tabs are set
aside before one is chosen.

Played under node through the real handler, against the stand-in database
(tests/fixtures/relay/world.mjs), with Supabase's signing key and its sessions
answered here as tests/test_signed_out.py answers them.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from loadbound import within  # noqa: E402

PREAMBLE = r"""
import { createHash, webcrypto } from 'node:crypto';
import { world } from './tests/fixtures/relay/world.mjs';
const w = world();
process.env.SUPABASE_PUBLISHABLE_KEY = 'publishable';
const { default: handle } = await import('./api/mcp.js');
const auth = await import('./api/_auth.js');
const HELD = auth.SESSION_HELD_MS + 1;
const pair = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
const jwk = { ...(await webcrypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'k1', alg: 'ES256' };
// The sessions Supabase holds: Sign out everywhere deletes the account's.
const sessions = new Set();
// Sessions orangecheck started: {bound: true, linked} by id.
const bound = new Map();
// The hellos written, Claude's calls queued, and the tab's answer to each
// (answer(row) => a result, or null while it has not answered).
const hellos = [];
const queued = [];
let answer = () => null;
// Supabase not answering oc_session_of (a slow or failing database).
let failing = false;
// The calls a waiting call took back, untaken, while the sign-in could not be checked.
const takenBack = [];
// This chat's pick (relay_picks), by channel: none unless a test sets it.
let pickedChannel = null;
w.serve = async (call, init) => {
  if (call === 'GET /auth/v1/.well-known/jwks.json') return Response.json({ keys: [jwk] });
  if (call === 'POST rpc/oc_session_of') {
    if (failing) return Response.json({ message: 'trouble' }, { status: 500 });
    const id = JSON.parse(init.body).session;
    return Response.json({ exists: sessions.has(id), ...(bound.get(id) || { bound: false, linked: false }) });
  }
  if (call.startsWith('POST relay_tabs')) {
    const row = JSON.parse(init.body);
    hellos.push(row);
    return Response.json([{ tools: row.hello.tools }]);
  }
  if (call === 'POST relay') {
    const row = { id: queued.length + 1, ...JSON.parse(init.body) };
    queued.push(row);
    return Response.json([row]);
  }
  const back = call.match(/^DELETE relay\?id=eq\.(\d+)&taken_at=is\.null/);
  if (back) {
    takenBack.push(Number(back[1]));
    return Response.json([{ id: Number(back[1]) }]);
  }
  if (call.startsWith('GET relay_picks?key=eq.') && pickedChannel) {
    return Response.json([{ key: 'connection:grant', owner: OWNER, channel: pickedChannel,
      picked_at: new Date(Date.now()).toISOString(), moved_at: null, called_at: null, did: null }]);
  }
  const asked = call.match(/^DELETE relay\?id=eq\.(\d+)&response=not\.is\.null/);
  if (asked) {
    const row = queued.find((one) => one.id === Number(asked[1]));
    const result = row && await answer(row);
    return Response.json(result ? [{ response: { jsonrpc: '2.0', id: row.request.id, result } }] : []);
  }
  return null;
};
let shift = 0; const realNow = Date.now; Date.now = () => realNow() + shift;
const later = (ms) => { shift += ms; };
const b64 = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');
const OWNER = '11111111-1111-4111-8111-111111111111';
const S = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const S2 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
// An access token Supabase would hand out for [session] (none: a token that names no session).
const signIn = async (session) => {
  const head = b64({ alg: 'ES256', kid: 'k1', typ: 'JWT' });
  const now = Math.floor(realNow() / 1000);
  const claims = b64({ sub: OWNER, aud: 'authenticated', iss: 'https://db.test/auth/v1', exp: now + 3600, iat: now,
    email: 'someone@example.com', amr: [{ method: 'otp', timestamp: now }], ...(session ? { session_id: session } : {}) });
  const signature = await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, pair.privateKey,
    new TextEncoder().encode(`${head}.${claims}`));
  return `${head}.${claims}.${Buffer.from(signature).toString('base64url')}`;
};
// One request through the handler: {status, body}.
const send = async (query, body, headers = {}) => {
  let status = 200;
  let json = null;
  const response = { setHeader: () => response, status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; }, end: () => response };
  await handle({ method: 'POST', query, headers: { host: 'brickworks.test', accept: 'application/json', ...headers },
    body }, response);
  return { status, body: json };
};
const ADDRESS = 'a-tab-address-'.padEnd(48, 'q');
const CHANNEL = createHash('sha256').update(ADDRESS).digest('hex');
const tools = [{ name: 'look_at_model', description: 'look', inputSchema: { type: 'object', properties: {} } }];
// The tab's row as its hello signed in with [session] writes it.
const switchedOn = (session) => w.tab({ channel: CHANNEL, owner: OWNER, session,
  hello: { instructions: 'the tab', tools } });
const hello = async (token) => send({ t: ADDRESS, i: 'instance-1', op: 'hello', tab: 'abcd' },
  { instructions: 'the tab', tools }, { authorization: `Bearer ${token}` });
const next = async () => send({ t: ADDRESS, op: 'next' });
// Claude's call through the address: whether it is an error, its words, and
// whether anything went in the tab's queue.
const call = async (name = 'look_at_model', method = 'tools/call') => {
  const before = queued.length;
  const got = await send({ t: ADDRESS }, { jsonrpc: '2.0', id: 9, method, params: { name, arguments: {} } });
  const result = got.body?.result || {};
  return { error: Boolean(result.isError), text: (result.content || []).map((one) => one.text).join(' '),
    tools: (result.tools || []).map((one) => one.name), queued: queued.length > before };
};
// The tab closed for that sign-in: the PATCH endTab sends.
const closedFor = () => w.calls.filter((one) => one.startsWith(`PATCH relay_tabs?channel=eq.${CHANNEL}&session=eq.`))
  .map((one) => one.split('session=eq.')[1]);
const ANSWER = { content: [{ type: 'text', text: 'the tab answered' }] };
// The same call as Claude signed in to the account makes it (OAuth): its words,
// and which tabs' queues it went in.
const ACCOUNT = w.connect(OWNER);
const askAccount = async (name = 'look_at_model', args = {}) => {
  const before = queued.length;
  const got = await send({}, { jsonrpc: '2.0', id: 9, method: 'tools/call', params: { name, arguments: args } },
    { authorization: `Bearer ${ACCOUNT}` });
  const result = got.body?.result || {};
  return { error: Boolean(result.isError), text: (result.content || []).map((one) => one.text).join(' '),
    went: queued.slice(before).filter((one) => one.request.method === 'tools/call').map((one) => one.channel) };
};
// Two tabs of the account: castle (aaaa, used last) signed in with S, car (bbbb) with S2.
const looks = [{ name: 'look_at_model', description: 'look', annotations: { readOnlyHint: true },
  inputSchema: { type: 'object', properties: {} } },
  { name: 'edit_model', description: 'edit', inputSchema: { type: 'object', properties: {} } }];
const twoTabs = () => ({
  castle: w.tab({ owner: OWNER, session: S, tab: 'aaaa', model: 'Castle', used_at: new Date(realNow()).toISOString(),
    hello: { instructions: 'the tab', tools: looks } }),
  car: w.tab({ owner: OWNER, session: S2, tab: 'bbbb', model: 'Car', used_at: new Date(realNow() - 60_000).toISOString(),
    hello: { instructions: 'the tab', tools: looks } }),
});
const closedOf = (channel) => w.calls.filter((one) => one.startsWith(`PATCH relay_tabs?channel=eq.${channel}&session=eq.`))
  .map((one) => one.split('session=eq.')[1]);
const sessionReads = () => w.calls.filter((one) => one === 'POST rpc/oc_session_of').length;
const IN = (row) => ({ content: [{ type: 'text', text: `answered in ${row.channel}` }] });
console.error = () => {};
"""


def run(body: str) -> dict | None:
    """[body] (an async function's body returning something JSON) run in a
    fresh node process after PREAMBLE."""
    if shutil.which("node") is None:
        return None
    script = PREAMBLE + f"const out = await (async () => {{ {body} }})();\nconsole.log(JSON.stringify(out));\nprocess.exit(0);\n"
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_a_hello_keeps_its_sign_in_and_a_token_naming_none_switches_nothing_on() -> None:
    got = run("""
      sessions.add(S);
      const kept = await hello(await signIn(S));
      const none = await hello(await signIn(null));
      return { kept: kept.status, session: hellos[0]?.session, none: none.status, hellos: hellos.length,
        why: none.body?.reason };
    """)
    if got is None:
        return
    assert got["kept"] == 204 and got["session"] == "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", got
    assert got["none"] == 401 and got["hellos"] == 1 and "names no session" in got["why"], got


def test_after_sign_out_everywhere_a_call_through_the_address_is_refused_and_never_queued() -> None:
    got = run("""
      sessions.add(S);
      switchedOn(S);
      answer = () => ANSWER;
      const before = await call();
      sessions.delete(S);  // Sign out everywhere: admin_sign_out deletes the account's sessions
      const held = await call();
      later(HELD);
      const after = await call();
      const listed = await call(undefined, 'tools/list');
      const tabs = await call('tabs');
      return { before, held, after, listed, tabs, closed: closedFor() };
    """)
    if got is None:
        return
    assert not got["before"]["error"] and "the tab answered" in got["before"]["text"], got
    # Within the 5 s a session's read is held (api/_auth.js SESSION_HELD_MS),
    # as every other route is: then refused, with nothing put in the queue.
    assert "the tab answered" in got["held"]["text"], got
    after = got["after"]
    assert after["error"] and not after["queued"], after
    assert after["text"].startswith("Nothing was done: the person was signed out of Brickworks"), after
    assert "switch the connector on there" in after["text"] and "Nothing needs changing in Claude" in after["text"]
    # Closed for that sign-in alone (the stand-in keeps the row open, so each
    # call after closes it again).
    assert set(got["closed"]) == {"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}, got
    # The connector stays listed in Claude; the tab is not told it was asked.
    assert got["listed"]["tools"][:1] == ["look_at_model"] and not got["listed"]["queued"], got
    assert got["tabs"]["error"] and "signed out of Brickworks" in got["tabs"]["text"], got


def test_the_tabs_ask_for_work_is_refused_once_its_sign_in_ends_and_a_new_sign_in_opens_it() -> None:
    got = run("""
      sessions.add(S);
      const row = switchedOn(S);
      // Past the check, an ask for work looks in the queue: failing here, on purpose, so it ends at once.
      w.trouble = (one) => (one.startsWith('POST rpc/relay_take') ? { status: 500 } : null);
      const standing = await next();
      sessions.delete(S);
      later(HELD);
      const ended = await next();
      const closed = closedFor();
      const oldHello = await hello(await signIn(S));
      sessions.add(S2);
      const newHello = await hello(await signIn(S2));
      row.session = S2;  // as that hello wrote it
      const again = await next();
      row.session = null;  // a row a relay from before relay_session.sql wrote
      const before = await next();
      return { standing: standing.status, ended: ended.status, endedSaid: ended.body?.error, closed,
        oldHello: oldHello.status, newHello: newHello.status, wrote: hellos.at(-1)?.session, again: again.status,
        before: before.status, beforeSaid: before.body?.error };
    """)
    if got is None:
        return
    assert got["standing"] == 502, got  # it went on to the queue
    assert got["ended"] == 401 and "signed out of Brickworks" in got["endedSaid"], got
    assert got["closed"] == ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"], got
    # ClaudeConnector says hello again on a 401: with the old sign-in it is
    # refused, and the tab switches off saying "Sign in to Brickworks again".
    assert got["oldHello"] == 401, got
    assert got["newHello"] == 204 and got["wrote"] == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", got
    assert got["again"] == 502, got
    assert got["before"] == 401 and got["beforeSaid"].startswith("say hello again"), got


def test_an_answer_given_after_the_sign_in_ended_is_not_passed_on() -> None:
    got = run("""
      sessions.add(S);
      switchedOn(S);
      answer = async () => { sessions.delete(S); later(HELD); return ANSWER; };
      return await call();
    """)
    if got is None:
        return
    assert got["error"] and "the tab answered" not in got["text"], got
    assert "signed out of Brickworks while this call was in their tab" in got["text"], got
    assert "it may have been done there" in got["text"], got


def test_a_call_waiting_on_the_tab_is_told_as_soon_as_the_sign_in_ends() -> None:
    got = run("""
      sessions.add(S);
      switchedOn(S);
      let ended = false;
      answer = () => { if (!ended) { ended = true; sessions.delete(S); later(HELD); } return null; };
      const began = realNow();
      const said = await call();
      return { ...said, waited: realNow() - began };
    """)
    if got is None:
        return
    assert got["error"] and got["text"].startswith("Nothing was done: the person was signed out"), got
    assert got["waited"] < 5_000, got


def test_one_failed_read_never_skips_the_session_check() -> None:
    """s6review L1: an ask whether the column was there (select=session&limit=0)
    failing once skipped every session check on the instance for a minute.
    No such ask is made now: the column is always read and written."""
    got = run("""
      sessions.add(S);
      switchedOn(S);
      w.trouble = (one) => (one.includes('&limit=0') ? { status: 400 } : null);
      answer = () => ANSWER;
      const before = await call();
      sessions.delete(S);
      later(HELD);
      const after = await call();
      sessions.add(S2);
      const kept = await hello(await signIn(S2));
      return { before: before.text, after, kept: kept.status, wrote: hellos.at(-1)?.session,
        asked: w.calls.filter((one) => one.includes('select=session&limit=0')).length };
    """)
    if got is None:
        return
    assert "the tab answered" in got["before"], got
    assert got["after"]["error"] and not got["after"]["queued"], got
    assert got["after"]["text"].startswith("Nothing was done: the person was signed out"), got
    assert got["kept"] == 204 and got["wrote"] == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", got
    assert got["asked"] == 0, got


def test_a_sign_in_that_cannot_be_checked_refuses_the_call_and_hands_the_tab_nothing() -> None:
    """A failed read of oc_session_of itself (a 500, or longer than
    SESSION_READ_S) let the call through until s6review. Now it is refused
    for now, in words that say so; the tab is handed nothing and told to ask
    again (503, which ClaudeConnector does in 3 s, still switched on), its
    row is not closed, and it is answered again once Supabase is."""
    got = run("""
      sessions.add(S);
      switchedOn(S);
      answer = () => ANSWER;
      failing = true;
      const refused = await call();
      const listed = await call(undefined, 'tools/list');
      const tabs = await call('tabs');
      const takes = () => w.calls.filter((one) => one.startsWith('POST rpc/relay_take')).length;
      const took = takes();
      const asked = await next();
      const greeted = await hello(await signIn(S));
      const tookAfter = takes();
      failing = false;
      const after = await call();
      return { refused, listed, tabs, asked: asked.status, askedSaid: asked.body?.error, takes: tookAfter - took,
        greeted: greeted.status, closed: closedFor(), after: after.text };
    """)
    if got is None:
        return
    refused = got["refused"]
    assert refused["error"] and not refused["queued"], refused
    assert refused["text"].startswith("Nothing was done: Brickworks could not check just now"), refused
    assert "Call again in a minute" in refused["text"], refused
    assert got["tabs"]["error"] and "could not check just now" in got["tabs"]["text"], got
    # The connector stays listed in Claude; the tab is not told it was asked.
    assert got["listed"]["tools"][:1] == ["look_at_model"] and not got["listed"]["queued"], got
    assert got["asked"] == 503 and "could not check this tab's sign-in" in got["askedSaid"], got
    assert got["takes"] == 0, got  # nothing handed to the tab
    assert got["greeted"] == 503, got  # a hello is a write: refused for now (api/_auth.js), not switched off
    assert got["closed"] == [], got
    assert "the tab answered" in got["after"], got


def test_an_answer_or_a_wait_while_the_sign_in_cannot_be_checked_is_not_let_through() -> None:
    got = run("""
      sessions.add(S);
      switchedOn(S);
      answer = async () => { failing = true; later(HELD); return ANSWER; };
      const answered = await call();
      failing = false;
      later(HELD);
      let flipped = false;
      answer = () => { if (!flipped) { flipped = true; failing = true; later(HELD); } return null; };
      const began = realNow();
      const waited = await call();
      return { answered: answered.text, waited: waited.text, ms: realNow() - began, takenBack, closed: closedFor() };
    """)
    if got is None:
        return
    assert "the tab answered" not in got["answered"], got
    assert got["answered"].startswith("The person's tab answered, but Brickworks could not check"), got
    # Not taken by the tab: taken back, only if it still was not, and refused for now.
    assert got["waited"].startswith("Nothing was done: Brickworks could not check just now"), got
    assert len(got["takenBack"]) == 1 and got["ms"] < within(5_000), got
    assert got["closed"] == [], got


def test_an_accounts_call_goes_to_its_tab_still_signed_in() -> None:
    """s6review L2: the account's castle tab, used last, was signed out on its
    device; its car tab still stands. A look picked castle and was refused, and a
    change was told to choose between both. Castle is set aside first now: both
    go to car, castle is closed, and the list of tabs names car alone."""
    got = run("""
      sessions.add(S2);
      const { castle, car } = twoTabs();
      answer = IN;
      const look = await askAccount('look_at_model');
      const change = await askAccount('edit_model');
      const tabs = await askAccount('tabs');
      return { look, change, tabs: tabs.text, castle: castle.channel, car: car.channel,
        castleClosed: closedOf(castle.channel), carClosed: closedOf(car.channel) };
    """)
    if got is None:
        return
    for said in (got["look"], got["change"]):
        assert not said["error"] and said["went"] == [got["car"]], said
        assert f"answered in {got['car']}" in said["text"] and said["text"].startswith("Tab bbbb"), said
    assert got["castleClosed"] and set(got["castleClosed"]) == {"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}, got
    assert got["carClosed"] == [], got
    assert got["tabs"].startswith("One Brickworks tab is open") and "bbbb" in got["tabs"], got
    assert "aaaa" not in got["tabs"], got


def test_a_chat_that_names_or_works_in_an_ended_tab_is_told_why() -> None:
    """A tab set aside is still the one a chat named or works in: told it was
    signed out, never sent to another tab; and an account with none left
    signed in is told so, not that none is open."""
    got = run("""
      sessions.add(S2);
      const { castle, car } = twoTabs();
      answer = IN;
      const named = await askAccount('edit_model', { target: 'aaaa' });
      const chosen = await askAccount('select_tab', { tab: 'castle' });
      pickedChannel = castle.channel;
      const home = await askAccount('edit_model');
      pickedChannel = null;
      sessions.delete(S2);
      later(HELD);
      const none = await askAccount('look_at_model');
      const listed = await askAccount('tabs');
      return { named, chosen, home, none, listed };
    """)
    if got is None:
        return
    for which in ("named", "chosen", "home", "none", "listed"):
        said = got[which]
        assert said["error"] and said["went"] == [], (which, said)
        assert said["text"].startswith("Nothing was done: the person was signed out of Brickworks"), (which, said)


def test_setting_ended_tabs_aside_reads_each_session_once_in_five_seconds() -> None:
    """The cost the review measured: about one oc_session_of a session every
    5 s an instance. Five calls at once read castle's session once (gone is
    held for good) and car's once; 5 s later one more call reads car's again."""
    got = run("""
      sessions.add(S2);
      twoTabs();
      answer = IN;
      const before = sessionReads();
      for (let i = 0; i < 5; i += 1) await askAccount('look_at_model');
      const five = sessionReads() - before;
      later(HELD);
      await askAccount('look_at_model');
      return { five, six: sessionReads() - before };
    """)
    if got is None:
        return
    assert got["five"] == 2 and got["six"] == 3, got


def test_a_session_orangecheck_started_ends_the_tab_once_orangecheck_is_unlinked() -> None:
    """As api/_oc.js judges a read of it (sessionStanding): unlinked, it is
    ended there and here; while orangecheck's list cannot be asked (no
    project keys here), a read goes on."""
    got = run("""
      sessions.add(S);
      bound.set(S, { bound: true, linked: true, rh: 'rh-1', aud: 'https://brickworks.test', iat: 1 });
      switchedOn(S);
      answer = () => ANSWER;
      const linked = await call();
      bound.set(S, { bound: true, linked: false });
      later(HELD);
      const unlinked = await call();
      return { linked: linked.text, unlinked: unlinked.text, ended: w.calls.filter((one) => one === 'POST rpc/oc_end_session').length };
    """)
    if got is None:
        return
    assert "the tab answered" in got["linked"], got
    assert got["unlinked"].startswith("Nothing was done: the person was signed out"), got
    assert got["ended"] == 1, got


def test_a_tab_waiting_for_work_as_its_sign_in_ends_is_told_within_seconds() -> None:
    """Its ask for work waits up to 25 s; the sign-in is asked after again
    once in SESSION_HELD_MS while it does, so it is not told at the end."""
    got = run("""
      sessions.add(S);
      switchedOn(S);
      const began = realNow();
      const asked = next();
      setTimeout(() => { sessions.delete(S); later(HELD); }, 300);
      const said = await asked;
      return { status: said.status, error: said.body?.error, waited: realNow() - began, closed: closedFor() };
    """)
    if got is None:
        return
    assert got["status"] == 401 and "signed out of Brickworks" in got["error"], got
    assert got["waited"] < 3_000, got
    assert set(got["closed"]) == {"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}, got
