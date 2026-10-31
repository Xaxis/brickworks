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
import { webcrypto } from "node:crypto";

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
    broadcasts: 0,
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
    this.topics.add(said.topic);
    setTimeout(() => this.said({ topic: said.topic, event: "phx_reply", ref: said.ref,
      payload: { status: "ok", response: { postgres_changes: [] } } }), 5);
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
  if (table === "together_sessions") return answer([store.session]);
  if (table === "together_people") {
    const account = (q.get("account") || "").replace("eq.", "");
    if (method === "PATCH") {
      const row = store.people.find((one) => one.account === account && !(q.get("removed_at") && one.removed_at));
      if (row) Object.assign(row, JSON.parse(options.body));
      return answer(row ? [row] : []);
    }
    return answer(store.people.filter((one) => !account || one.account === account).map((one) => ({ ...one })));
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

async function lines() {
  reset();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  await sleep(400);
  point([1, 2, 3]);
  const movedAt = Date.now();
  await sleep(600);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: { "a.1": null } });
  await done;
  const said = response.writes.map((one) => JSON.parse(one.text));
  const moved = response.writes.findIndex((one) => one.text.includes("[1,2,3]"));
  return {
    type: response.headers["content-type"], status: response.statusCode,
    more: said.map((one) => one.more === true), at: said.map((one) => one.people.find((p) => !p.me)?.at ?? null),
    moved_ms: moved >= 0 ? response.writes[moved].at - movedAt : null,
    last: JSON.parse(response.ended), seen_last: said.at(-1)?.seen,
  };
}

async function whole() {
  reset();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "" }), response);
  await done;
  return { type: response.headers["content-type"], writes: response.writes.length, last: JSON.parse(response.ended),
    ms: response.ms };
}

async function refused() {
  reset();
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 0, seen: "", stream: true }), response);
  await sleep(300);
  store.people[1].removed_at = new Date().toISOString();
  await done;
  return { writes: response.writes.length, status: response.statusCode, last: JSON.parse(response.ended) };
}

async function reads(stream) {
  reset();
  // Seen already: nothing to say, so it waits.
  const first = responseOf();
  const once = handler(ask({ s: SECRET, after: 0, seen: "", stream }), first);
  await sleep(200);
  store.ops.push({ seq: 1, author: OTHER, client: "abcdef", cid: 0, changes: {} });
  await once;
  const seen = JSON.parse(first.ended).seen;
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream }), response);
  await sleep(300);
  store.reads = [];
  await sleep(1000);
  const counted = store.reads.slice();
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  const count = (what) => counted.filter((one) => one === what).length;
  return { writes: response.writes.length, ops: count("GET together_ops"), people: count("GET together_people"),
    sessions: count("GET together_sessions") };
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
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream }), response);
  // Listening by now; then a stranger's pointer, and one of somebody taken
  // out, neither in it.
  await sleep(300);
  const stranger = await pointAs(STRANGER, [9, 9, 9]);
  await sleep(150);
  const quiet = response.writes.length + (response.ended ? 1 : 0);
  // Their pointer: the moment it is sent to the moment it goes out, and the
  // reads of who is in it between.
  const readsBefore = store.reads.filter((one) => one === "GET together_people").length;
  const sentAt = Date.now();
  const sending = pointAs(OTHER, [4, 5, 6]);
  for (const end = Date.now() + 2000; Date.now() < end; await sleep(1)) {
    if (response.ended || response.writes.some((one) => one.text.includes("[4,5,6]"))) break;
  }
  const outAt = Date.now();
  const readsBetween = store.reads.filter((one) => one === "GET together_people").length - readsBefore;
  await sending;
  if (stream) {
    store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  }
  await done;
  const said = [...response.writes.map((one) => JSON.parse(one.text)), JSON.parse(response.ended)];
  const atOf = (one) => one.people?.find((p) => !p.me)?.at ?? null;
  return { stranger_status: stranger.statusCode, quiet, ms: outAt - sentAt, reads_between: readsBetween,
    shown: said.map(atOf).filter(Boolean), broadcasts: store.broadcasts,
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
  const response = responseOf();
  const done = handler(ask({ s: SECRET, after: 1, seen, stream: true }), response);
  await sleep(300);
  await pointAs(OTHER, [0, 0, 0]);
  await sleep(300);
  store.reads = [];
  for (let n = 1; n <= 4; n++) {
    await pointAs(OTHER, [n, 0, 0]);
    await sleep(250);
  }
  const counted = store.reads.slice();
  store.ops.push({ seq: 2, author: OTHER, client: "abcdef", cid: 1, changes: {} });
  await done;
  globalThis.WebSocket = StandInSocket;
  const count = (what) => counted.filter((one) => one === what).length;
  return { ops: count("GET together_ops"), people: count("GET together_people"), sessions: count("GET together_sessions"),
    lines: response.writes.length };
}

const result = { lines: await lines(), whole: await whole(), refused: await refused(),
  reads: { lines: await reads(true), whole: await reads(false) },
  told: { lines: await told(true), whole: await told(false), taken_out: await takenOut() },
  pointing: { listening: await pointing(true), not: await pointing(false) } };
console.log(JSON.stringify(result));
