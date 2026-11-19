// api/together.js's poll, its handler as Vercel calls it, against a session
// kept here: the database's REST answers, its Realtime and the sign-in's
// keys stood in for (tests/test_together_poll.py). Prints one line of JSON.
//
//   lines    a poll asked a line at a time (stream: true): a line as soon as
//            who is in it changes, the other's pointer moved while it waits
//            in a line of its own, and its last line the change that ends it
//   whole    the same asked plainly (the desktop's): answered, and ended, at
//            the first change of who is in it, as before
//   refused  taken out of the session after its first line: its last line
//            says so, its status gone with the first
//   reads    the database's reads in a second of waiting, nobody pointing,
//            asked a line at a time and asked plainly: the same
//   told     the other's pointer sent (op=point) while a poll waits: told on
//            the session's channel, it goes out at once, a line or the
//            answer, before any read of who is in it; never for somebody
//            not in it or taken out
//   pointing the database's reads in a second of the other pointing, the
//            channel listened to and not: no more than with nobody pointing
//   looked   pointat (APP_UX8 #17): a part the other points out (op=point's
//            look) goes out at once with its age, ages out of what a poll
//            says at 5 s, is taken back by a point without it, and a look
//            not of its shape is refused; with none, the signature is the
//            one it always was
//   begins   pollreads (2026-11-16): a poll's reads from the moment it
//            begins, its channel joining slower than a read on purpose, and
//            slower than PEOPLE_MS: who is in it read once as it begins
//
// Each read is logged with its time ([what, ms]), so a test bars how often
// a poll reads, not how many reads fit in a second of a busy box; and each
// time a test bars is said with what this process could not run for in it
// (stalled), so a busy box is not taken for a slow relay.
import { createHash, webcrypto } from "node:crypto";

process.env.SUPABASE_URL = "http://db.test";
process.env.SUPABASE_SECRET_KEY = "secret";
process.env.SUPABASE_PUBLISHABLE_KEY = "publishable";

const ME = "11111111-1111-4111-8111-111111111111";
const OTHER = "22222222-2222-4222-8222-222222222222";
const STRANGER = "33333333-3333-4333-8333-333333333333";
const SECRET = "a".repeat(32);
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

const pair = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
const jwk = { ...(await webcrypto.subtle.exportKey("jwk", pair.publicKey)), kid: "k1", alg: "ES256" };
const b64 = (bytes) => Buffer.from(bytes).toString("base64url");
const head = b64(JSON.stringify({ alg: "ES256", kid: "k1", typ: "JWT" }));
async function tokenOf(sub) {
  const claims = b64(JSON.stringify({ sub, aud: "authenticated", iss: "http://db.test/auth/v1",
    exp: Math.floor(Date.now() / 1000) + 3600 }));
  const signature = await webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, pair.privateKey,
    new TextEncoder().encode(`${head}.${claims}`));
  return `${head}.${claims}.${b64(signature)}`;
}
const tokens = { [ME]: await tokenOf(ME), [OTHER]: await tokenOf(OTHER), [STRANGER]: await tokenOf(STRANGER) };

// What this process could not run for, the box being busy: a timer asked for
// every millisecond, and each gap of more than 2 ms between two of them. A
// time a test bars is said beside how much of it was that (stalledIn), as
// the pointat flow's bar is less the frames the box took.
const stalls = [];
let tickAt = Date.now();
const ticker = setInterval(() => {
  const now = Date.now();
  if (now - tickAt > 2) stalls.push([tickAt + 1, now]);
  tickAt = now;
}, 1);
const stalledIn = (from, to) => stalls.reduce((sum, [a, b]) => sum + Math.max(0, Math.min(b, to) - Math.max(a, from)), 0);

// The session: the owner (OTHER) and this person (ME), and its changes.
let store;
const reset = () => {
  const now = new Date().toISOString();
  store = {
    session: { id: "", owner: OTHER, title: "t", last_seq: 0, ended_at: null },
    people: [
      { account: OTHER, name: "Ada", joined_at: now, seen_at: now, left_at: null, removed_at: null, pointer: null, pointer_at: null },
      { account: ME, name: "", joined_at: now, seen_at: now, left_at: null, removed_at: null, pointer: null, pointer_at: null },
    ],
    ops: [],
    reads: [],
    // Each request to the database as [what, when], and when a channel last
    // joined; each read held readMs, a channel's join joinMs (pollreads).
    log: [],
    joinedAt: null,
    joins: 0,
    toldAt: null,
    readMs: 0,
    // Each GET held this long besides (smalls7): a poll's reads slow, a
    // point's own PATCH not.
    getMs: 0,
    joinMs: 5,
    broadcasts: 0,
    // While unseen, a person's row is read as it was before the writes made
    // to it since (row -> its copy): a pointer then reaches a poll only on
    // the channel, so a line with it went out without a read, however a
    // busy box times the reads (pollreads, 2026-11-16).
    unseen: false,
    shown: new Map(),
  };
};

// The database's Realtime: a socket joins a topic, and a broadcast (POST
// realtime/v1/api/broadcast) reaches every socket joined to its topic.
const sockets = new Set();
class StandInSocket extends EventTarget {
  constructor(url) {
    super();
    this.url = url;
    this.topics = new Set();
    sockets.add(this);
    setTimeout(() => this.dispatchEvent(new Event("open")), 5);
  }
  said(value) { this.dispatchEvent(new MessageEvent("message", { data: JSON.stringify(value) })); }
  send(text) {
    const said = JSON.parse(text);
    if (said.event !== "phx_join") return;
    // Broadcasts reach it once it has joined, as Realtime's do: what is
    // told before is not heard (joining, below, waits longer for it).
    const join = () => {
      if (!sockets.has(this)) return;
      this.topics.add(said.topic);
      store.joinedAt = Date.now();
      store.joins += 1;
      this.said({ topic: said.topic, event: "phx_reply", ref: said.ref,
        payload: { status: "ok", response: { postgres_changes: [] } } });
    };
    // joinAfterTold: joined that long after the server told the channel, so
    // a point is told while it joins however long the send's own way in
    // took (pollreads, 2026-11-16).
    const after = store?.joinAfterTold;
    const wait = () => setTimeout(() => sockets.has(this) && (store.toldAt ? setTimeout(join, after) : wait()), 1);
    if (after) wait();
    else setTimeout(join, store?.joinMs ?? 5);
  }
  close() { sockets.delete(this); }
}
globalThis.WebSocket = StandInSocket;
const answer = (value) => new Response(value === undefined ? "" : JSON.stringify(value), { status: 200 });
globalThis.fetch = async (url, options = {}) => {
  const where = new URL(String(url));
  const method = options.method || "GET";
  if (where.pathname === "/auth/v1/.well-known/jwks.json") return answer({ keys: [jwk] });
  if (where.pathname === "/realtime/v1/api/broadcast") {
    for (const message of JSON.parse(options.body).messages) {
      store.broadcasts += 1;
      // When the server told the channel: the relay's leg from there to the
      // line is timed apart from the send's own way in, whose sign-in check
      // waits on the thread pool a busy box keeps (pollreads, 2026-11-16).
      store.toldAt = Date.now();
      const topic = `realtime:${message.topic}`;
      for (const socket of sockets) {
        if (socket.topics.has(topic)) {
          setTimeout(() => socket.said({ topic, event: "broadcast",
            payload: { type: "broadcast", event: message.event, payload: message.payload } }), 0);
        }
      }
    }
    return new Response("", { status: 202 });
  }
  const table = where.pathname.replace("/rest/v1/", "");
  const q = where.searchParams;
  store.reads.push(`${method} ${table}`);
  store.log.push([`${method} ${table}`, Date.now()]);
  if (store.readMs) await sleep(store.readMs);
  if (store.getMs && method === "GET") await sleep(store.getMs);
  if (table === "together_sessions") return answer([store.session]);
  if (table === "together_people") {
    const account = (q.get("account") || "").replace("eq.", "");
    if (method === "PATCH") {
      const body = JSON.parse(options.body);
      // A pointer at x = -1 is held until a part pointed out has landed, as a
      // database that takes two sends in the other order (ordered, below).
      if (store.holdOlder && body.pointer?.at?.[0] === -1) await until(() => store.people[0].pointer?.look, 2000);
      const row = store.people.find((one) => one.account === account && !(q.get("removed_at") && one.removed_at));
      // The point's guard (api/together.js point): kept only over an older one.
      const older = /^\(pointer_at\.is\.null,pointer_at\.lt\."(.+)"\)$/.exec(q.get("or") || "");
      const keeps = Boolean(row) && (!older || !row.pointer_at || Date.parse(row.pointer_at) < Date.parse(older[1]));
      if (keeps && store.unseen && !store.shown.has(row)) store.shown.set(row, { ...row });
      if (keeps) Object.assign(row, body);
      return answer(keeps ? [row] : []);
    }
    return answer(store.people.filter((one) => !account || one.account === account)
      .map((one) => ({ ...(store.shown.get(one) ?? one) })));
  }
  if (table === "together_ops") {
    const after = Number((q.get("seq") || "gt.0").replace("gt.", ""));
    return answer(store.ops.filter((one) => one.seq > after));
  }
  if (table === "rpc/shown_publicly") return answer(false);
  if (table === "rpc/age_of") return answer({ ask: false, over_13: true });
  return answer(null);
};

const { default: handler } = await import(process.env.TOGETHER_API || "../../../api/together.js");

// The response as Vercel's helpers make it: written a line at a time, or
// whole.
function responseOf() {
  const began = Date.now();
  return {
    statusCode: 200, headers: {}, headersSent: false, writes: [], ended: null, ms: null,
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; return this; },
    status(code) { this.statusCode = code; return this; },
    write(text) { this.headersSent = true; this.writes.push({ ms: Date.now() - began, at: Date.now(), text }); return true; },
    json(value) { this.headers["content-type"] = "application/json"; return this.end(JSON.stringify(value)); },
    end(text) { this.headersSent = true; this.ended = text; this.ms = Date.now() - began; return this; },
  };
}
const ask = (body, op = "poll", who = ME) => ({ method: "POST", query: { op },
  headers: { authorization: `Bearer ${tokens[who]}` }, body });
const point = (at) => Object.assign(store.people[0], { pointer: { at, sel: [], view: null }, pointer_at: new Date().toISOString() });

// Until [test] holds, looked at each millisecond, [ms] at most: the fixture
// acts on a poll's state, not on how long it has had. A busy box's sign-in
// check waits on the thread pool, which stalls nothing the ticker sees, and
// ran past the sleeps that stood for it: a poll not yet begun when a pointer
// moved, or not yet listening when one was told (pollreads, 2026-11-16).
async function until(test, ms = 5000) {
  for (const end = Date.now() + ms; !test() && Date.now() < end;) await sleep(1);
}
// Begun: a poll's first request, its person's row, logged since [mark].
const begun = (mark) => () => store.log.slice(mark).some(([what]) => what === "PATCH together_people");
// Listening: a channel joined since [joins] had.
const joinedSince = (joins) => () => store.joins > joins;
const writ = (response, text) => () => response.writes.some((one) => one.text.includes(text));

async function lines() {
  reset();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  // Moved while it waits: once who is in it has gone out.
  await until(() => response.writes.length >= 1);
  await sleep(100);
  point([1, 2, 3]);
  const movedAt = Date.now();
  await until(writ(response, "[1,2,3]"), 2000);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: { "a.1": null } });
  await done;
  const said = response.writes.map((one) => JSON.parse(one.text));
  const moved = response.writes.findIndex((one) => one.text.includes("[1,2,3]"));
  return {
    type: response.headers["content-type"], status: response.statusCode,
    more: said.map((one) => one.more === true), at: said.map((one) => one.people.find((p) => !p.me)?.at ?? null),
    moved_ms: moved >= 0 ? response.writes[moved].at - movedAt : null,
    stalled: moved >= 0 ? stalledIn(movedAt, response.writes[moved].at) : null,
    last: JSON.parse(response.ended), seen_last: said.at(-1)?.seen,
  };
}

async function whole() {
  reset();
  const response = responseOf();
  const began = Date.now();
  const done = handler(ask({ s: SECRET, after: 0, seen: "" }), response);
  await done;
  return { type: response.headers["content-type"], writes: response.writes.length, last: JSON.parse(response.ended),
    ms: response.ms, stalled: stalledIn(began, Date.now()) };
}

async function refused() {
  reset();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  await until(() => response.writes.length >= 1);
  store.people[1].removed_at = new Date().toISOString();
  await done;
  return { writes: response.writes.length, status: response.statusCode, last: JSON.parse(response.ended) };
}

// The database's requests logged from [from], each [what, ms after from].
// A request logged as [what, ms since from, how long this process was held
// in the 20 ms before it]: a poll's request reaches this log by code that
// never waits, so all a held process can do to its time is make it later
// than the poll asked (pollreads: two reads of the changes 96 ms apart under
// heavy, the first held 4 ms on its way).
const logged = (from) => ([what, at]) => [what, at - from, stalledIn(at - 20, at)];
const loggedSince = (from) => store.log.filter(([, at]) => at >= from).map(logged(from));

async function reads(stream, slow = false) {
  reset();
  // Seen already: nothing to say, so it waits.
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream }), first);
  await sleep(200);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  // pollreads: its channel joins slower than a read, on purpose.
  if (slow) Object.assign(store, { joinMs: 120, readMs: 20 });
  const joins = store.joins;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream }), response);
  await until(joinedSince(joins));
  await sleep(300);
  store.reads = [];
  const from = Date.now();
  await sleep(1000);
  const counted = store.reads.slice();
  const log = loggedSince(from);
  const ms = Date.now() - from;
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  Object.assign(store, { joinMs: 5, readMs: 0 });
  const count = (what) => counted.filter((one) => one === what).length;
  return { writes: response.writes.length, ops: count("GET together_ops"), people: count("GET together_people"),
    sessions: count("GET together_sessions"), log, ms };
}

// pollreads: a poll's requests to the database from the moment it is asked,
// its channel joining in [joinMs] and each read taking [readMs], for 1.5 s
// of waiting with nobody pointing; and when its channel joined.
async function begins(joinMs, readMs) {
  reset();
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  Object.assign(store, { joinMs, readMs, joinedAt: null, log: [] });
  const from = Date.now();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await until(begun(0));
  await sleep(1500);
  const log = loggedSince(from);
  const ms = Date.now() - from;
  const joined = store.joinedAt === null ? null : store.joinedAt - from;
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  Object.assign(store, { joinMs: 5, readMs: 0 });
  return { joinMs, readMs, joined, writes: response.writes.length, log, ms };
}

// The other's pointer sent as their page sends it.
async function pointAs(who, at) {
  const response = responseOf();
  await handler(ask({ s: SECRET, at, sel: [], view: null }, "point", who), response);
  return response;
}

async function told(stream) {
  reset();
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  const joins = store.joins;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream }), response);
  // Listening; then a stranger's pointer, and one of somebody taken out,
  // neither in it.
  await until(joinedSince(joins));
  await sleep(100);
  const stranger = await pointAs(STRANGER, [9, 9, 9]);
  await sleep(150);
  const quiet = response.writes.length + (response.ended ? 1 : 0);
  // Their pointer: the moment it is sent to the moment it goes out, and the
  // reads of who is in it between.
  store.toldAt = null;
  store.unseen = true;
  const sentAt = Date.now();
  const sending = pointAs(OTHER, [4, 5, 6]);
  const has = () => [...response.writes.map((one) => one.text), response.ended || ""].some((one) => one.includes("[4,5,6]"));
  for (const end = Date.now() + 2000; Date.now() < end; await sleep(1)) {
    if (response.ended || has()) break;
  }
  const outAt = Date.now();
  // Said while its reads still showed them as before: told on the channel.
  const heard = has();
  await sending;
  Object.assign(store, { unseen: false, shown: new Map() });
  const toldAt = store.toldAt ?? outAt;
  const readsBetween = store.log.filter(([what, at]) => what === "GET together_people" && at >= toldAt && at <= outAt).length;
  if (stream) {
    store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  }
  await done;
  const said = [...response.writes.map((one) => JSON.parse(one.text)), JSON.parse(response.ended)];
  const atOf = (one) => one.people?.find((p) => !p.me)?.at ?? null;
  return { stranger_status: stranger.statusCode, quiet, heard, ms: outAt - sentAt, stalled: stalledIn(sentAt, outAt),
    relay_ms: outAt - toldAt, relay_stalled: stalledIn(toldAt, outAt), reads_between: readsBetween, shown: said.map(atOf).filter(Boolean), broadcasts: store.broadcasts,
    strangers_shown: said.some((one) => (one.people || []).length !== 2) };
}

async function takenOut() {
  reset();
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  // The other taken out, and the poll's read has them so.
  store.people[0].removed_at = new Date().toISOString();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await sleep(600);
  const point = await pointAs(OTHER, [7, 7, 7]);
  await sleep(400);
  store.ops.push({ seq: 2, author: ME, client: "abcdef", cid: 1, changes: {} });
  await done;
  const said = [...response.writes.map((one) => one.text), response.ended].join("\n");
  return { point_status: point.statusCode, shown: said.includes("[7,7,7]") };
}

async function pointing(listening) {
  reset();
  globalThis.WebSocket = listening ? StandInSocket : undefined;
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  // Each read 20 ms (pollreads): every step then begins over POLL_MS after
  // the last, so a poll not listening reads who is in it at each, not at
  // those its timer's rounding lets it.
  store.readMs = 20;
  const [mark, joins] = [store.log.length, store.joins];
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await until(listening ? joinedSince(joins) : begun(mark));
  await sleep(300);
  await pointAs(OTHER, [0, 0, 0]);
  await sleep(300);
  store.reads = [];
  const from = Date.now();
  for (let n = 1; n <= 4; n++) {
    await pointAs(OTHER, [n, 0, 0]);
    await sleep(250);
  }
  const counted = store.reads.slice();
  const log = loggedSince(from);
  const ms = Date.now() - from;
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  globalThis.WebSocket = StandInSocket;
  const count = (what) => counted.filter((one) => one === what).length;
  return { ops: count("GET together_ops"), people: count("GET together_people"), sessions: count("GET together_sessions"),
    lines: response.writes.length, log, ms };
}

// pointat: the other's point with a part pointed out ([look]), as their page
// sends it.
async function lookAs(who, look) {
  const response = responseOf();
  await handler(ask({ s: SECRET, at: null, sel: [], view: null, ...(look === undefined ? {} : { look }) }, "point", who),
    response);
  return response;
}

async function looked() {
  reset();
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  // With nobody pointing anything out, the signature as it always was.
  const people = JSON.parse(first.ended).people;
  const always = createHash("sha256").update(JSON.stringify(people.map((one) => [one.who, one.name, one.here, one.at,
    one.sel, one.view]))).digest("hex").slice(0, 12);
  const joins = store.joins;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await until(joinedSince(joins));
  await sleep(100);
  store.toldAt = null;
  store.unseen = true;
  const sentAt = Date.now();
  const sent = await lookAs(OTHER, { n: 1763000000000, sel: ["ab12.3"], at: [1, 2, 3], age: 40 });
  let outAt = null;
  for (const end = Date.now() + 2000; Date.now() < end && outAt === null; await sleep(1)) {
    if (response.writes.some((one) => one.text.includes("1763000000000"))) outAt = Date.now();
  }
  Object.assign(store, { unseen: false, shown: new Map() });
  const toldAt = store.toldAt ?? outAt;
  const relay = outAt === null ? {} : { relay_ms: outAt - toldAt, relay_stalled: stalledIn(toldAt, outAt),
    reads_between: store.log.filter(([what, at]) => what === "GET together_people" && at >= toldAt && at <= outAt).length };
  // Pointed out 4.8 s ago on their side: said with that age, then gone.
  await lookAs(OTHER, { n: 1763000000001, sel: ["ab12.3", "ab12.4"], at: null, age: 4800, claude: true });
  await sleep(900);
  // A third, then taken back by a point without it.
  await lookAs(OTHER, { n: 1763000000002, sel: ["ab12.5"], at: [0, 0, 0], age: 0 });
  await sleep(300);
  await lookAs(OTHER);
  await sleep(400);
  const refused = [];
  for (const bad of [{ n: 1, sel: [], age: 0 }, { n: -1, sel: ["ab12.3"], age: 0 },
    { n: 1, sel: Array.from({ length: 51 }, (_, k) => `ab12.${k}`), age: 0 }, { n: 1, sel: ["no uid"], age: 0 },
    { n: 1, sel: ["ab12.3"], age: "0" }, { n: 1, sel: ["ab12.3"], at: [1, 2], age: 0 }, [1, 2]]) {
    refused.push((await lookAs(OTHER, bad)).statusCode);
  }
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  const said = [...response.writes.map((one) => JSON.parse(one.text)), JSON.parse(response.ended)];
  const looks = said.map((one) => one.people?.find((p) => !p.me)?.look ?? null);
  // pointfix: the first line with it says when the server had it and when,
  // and how, this poll did.
  const firstLine = said.find((one) => one.people?.find((p) => !p.me)?.look?.n === 1763000000000);
  const who = firstLine?.people?.find((p) => !p.me)?.who;
  return { always: always === seen, sent: sent.statusCode, ms: outAt === null ? null : outAt - sentAt,
    stalled: outAt === null ? null : stalledIn(sentAt, outAt), ...relay, looks,
    kept: store.people[0].pointer, refused, pointed: firstLine?.pointed?.[who] ?? null, sentAt, lineAt: firstLine?.at ?? null };
}

// pointfix: a part pointed out goes beside a send of the pointer still on its
// way (Together._point), and the database takes the pointer's second: the
// part pointed out is what is kept, and what a poll reading it later is told.
async function ordered() {
  reset();
  store.holdOlder = true;
  const send = async (at, look) => {
    const response = responseOf();
    await handler(ask({ s: SECRET, at, sel: [], view: null, ...(look ? { look } : {}) }, "point", OTHER), response);
    return response;
  };
  const pointer = send([-1, 0, 0]);
  // The pointer had by the server first: the point sent once its write has
  // reached the database, which holds it until the point's has landed. Sent
  // 30 ms after it by the clock, a busy box's sign-in check could have the
  // pointer second (pollreads).
  await until(() => store.log.some(([what]) => what === "PATCH together_people"));
  const looked = send([1, 2, 3], { n: 1763000000009, sel: ["ab12.3"], at: [1, 2, 3], age: 0 });
  const answers = await Promise.all([pointer, looked]);
  store.holdOlder = false;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: false }), response);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await done;
  return { codes: answers.map((one) => one.statusCode), kept: store.people[0].pointer,
    read: JSON.parse(response.ended).people.find((p) => !p.me)?.look?.n ?? null };
}

// pointfix: a part pointed out while a poll begun a moment before is still
// joining its channel: told before it could hear, it is read the moment the
// channel has joined, not at the next read of who is in it (PEOPLE_MS).
async function joining(tries = 1) {
  reset();
  store.joinAfterTold = 70;
  const began = Date.now();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  await until(begun(0));
  await sleep(30);
  const sentAt = Date.now();
  await lookAs(OTHER, { n: 1763000000010, sel: ["ab12.3"], at: [1, 2, 3], age: 0 });
  let outAt = null;
  for (const end = Date.now() + 1000; Date.now() < end && outAt === null; await sleep(1)) {
    if (response.writes.some((one) => one.text.includes("1763000000010"))) outAt = Date.now();
  }
  const toldAt = store.toldAt ?? outAt;
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await done;
  // When it joined, if it read the point at its last moment to wait first.
  const joinedAt = store.joinedAt;
  store.joinAfterTold = 0;
  // Told while it joins is the case: a point whose own sign-in the box held
  // past the poll's wait for its channel (PEOPLE_MS), so told after its read
  // of who is in it, is not; tried again (said in tries).
  const read = store.log.find(([what]) => what === "GET together_people")?.[1] ?? Infinity;
  if (store.toldAt !== null && store.toldAt > read && tries < 3) return joining(tries + 1);
  const line = response.writes.map((one) => JSON.parse(one.text))
    .find((one) => one.people?.find((p) => !p.me)?.look?.n === 1763000000010);
  const who = line?.people?.find((p) => !p.me)?.who;
  return { tries, sentMs: sentAt - began, toldMs: toldAt - began, joinedMs: joinedAt === null ? null : joinedAt - began,
    ms: outAt === null ? null : outAt - toldAt, stalled: outAt === null ? null : stalledIn(toldAt, outAt),
    via: line?.pointed?.[who]?.[2] ?? null };
}

// pollreads: a change made 30 ms into a poll whose channel joins at 240,
// slower than PEOPLE_MS lets it wait: the change's way to the answer, and
// the poll's requests.
async function changeWhileJoining() {
  reset();
  store.joinMs = 240;
  const from = Date.now();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  await until(begun(0));
  await sleep(30);
  const madeAt = Date.now();
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await done;
  const endedAt = Date.now();
  const joined = store.joinedAt === null ? null : store.joinedAt - from;
  store.joinMs = 5;
  return { ms: endedAt - madeAt, stalled: stalledIn(madeAt, endedAt), joined, madeMs: madeAt - from,
    ops: JSON.parse(response.ended).ops.map((op) => op.seq), log: store.log.map(logged(from)) };
}

// smalls7: a part pointed out while the poll is reading the database (each
// GET held 400 ms, so a poll is in a read four fifths of its wait) goes out
// as a line when the channel tells it, not when that read ends: three
// points, each timed from the server telling the channel to its line.
async function toldMidRead() {
  reset();
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), first);
  await sleep(100);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  const joins = store.joins;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await until(joinedSince(joins));
  await sleep(100);
  store.getMs = 400;
  store.unseen = true;
  const rounds = [];
  for (let k = 0; k < 3; k += 1) {
    await sleep(170 + 90 * k);
    store.toldAt = null;
    const n = 1763000000100 + k;
    await lookAs(OTHER, { n, sel: ["ab12.3"], at: [1, 2, 3], age: 0 });
    let outAt = null;
    for (const end = Date.now() + 2000; Date.now() < end && outAt === null; await sleep(1)) {
      if (response.writes.some((one) => one.text.includes(String(n)))) outAt = Date.now();
    }
    const toldAt = store.toldAt ?? outAt;
    rounds.push({ ms: outAt === null || toldAt === null ? null : outAt - toldAt,
      stalled: outAt === null || toldAt === null ? null : stalledIn(toldAt, outAt) });
  }
  Object.assign(store, { getMs: 0, unseen: false, shown: new Map() });
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  return { rounds };
}

const result = { changed: await changeWhileJoining(), looked: await looked(), mid_read: await toldMidRead(), ordered: await ordered(), joining: await joining(), lines: await lines(), whole: await whole(), refused: await refused(),
  reads: { lines: await reads(true), whole: await reads(false), lines_slow_join: await reads(true, true) },
  begins: [await begins(5, 0), await begins(120, 20), await begins(400, 20)],
  told: { lines: await told(true), whole: await told(false), taken_out: await takenOut() },
  pointing: { listening: await pointing(true), not: await pointing(false) } };
console.log(JSON.stringify(result));
clearInterval(ticker);
