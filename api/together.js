// Build together (2026-10-24): two people build one model at once, live,
// each in their own browser or desktop app (src/net/together.gd,
// supabase/together.sql, docs/TOGETHER.md).
//
// The owner of a model starts a session and is given a link with a secret
// in it; a signed-in person who opens the link joins. Every change either
// side makes is sent here and numbered, in the one order everybody puts
// them down in, and each side asks for the changes after the last number it
// has, waiting here until there are some (looked for every 100 ms): the
// relay's way (api/mcp.js), a row per message in the database and a request
// that waits on it, so it runs on Vercel, the desktop and a browser alike,
// with nothing reaching the database but this server
// (supabase/no_client_access.sql).
//
// All POST, with the person's session ("Authorization: Bearer …"):
//
//   ?op=start   {title, snapshot}  the owner begins; answered with the link
//   ?op=join    {s}                join by the link's secret: the model as it
//                                  began, who is in it, and from which number
//   ?op=send    {s, client, ops}   changes, each {cid, changes}; their numbers
//   ?op=poll    {s, after, seen}   the changes after [after], waiting up to
//                                  ~20 s for one, or for who is in it to
//                                  change from [seen]; and whether it ended
//   ?op=end     {s}                the owner ends it
//   ?op=leave   {s}                someone leaves
//   ?op=remove  {s, who}           the owner takes someone out of it: refused
//                                  from then on, by the same link too
//
// A change is {uid: state | null}: a part, by the id the session calls it,
// set to [part, colour, [12 numbers of its transform], group, unit, step],
// or taken off. Each side keeps its own changes shown until they come back
// numbered (src/net/together.gd), so a part two people move at once ends
// where the later of the two put it, on both sides. And what the model is
// besides its parts, each a key of its own with its words as the file has
// them: "~title", "~floor", "~hidden" (the colours of hidden parts),
// "~motions", "~looks" (the booklet's), "~unit_steps", "~broken" (sections
// broken out), and "~part:<id>" for a part made in the app, its LDraw files,
// so the other side can put it down.
//
// Chat: an op of "~chat" alone, a line of words, kept in the same log. The
// rule is comments' (supabase/comments.sql comments_guard): an account that
// answered the age question 13 or over and was not taken out of the
// gallery, the words a stranger may not be shown refused (api/_names.js).
// And stricter, because a chat is private and live where a comment is
// public and can be reported: an account under 13 is not shown the chat at
// all (its ops come to it with the words taken out), and is told why.
//
//   ?op=point   {s, at}            where this person is working now: a point
//                                  in the model's space, or null; shown to the
//                                  others with their name (live pointers)
//
// Who is in it is shown by the name of their profile when a visitor may be
// shown it (api/_trust.js shownPublicly: never one under 13), and otherwise
// as "Builder 2": never an email. An account under 13 builds together like
// anyone, as it shares a model by link like anyone (supabase/trust.sql);
// only its name is never shown.
import { createHash, randomBytes } from "node:crypto";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { ageOf, shownPublicly } from "./_trust.js";
import { namesTrouble } from "./_names.js";

const TOKEN = /^[A-Za-z0-9_-]{32}$/;
const CLIENT = /^[a-z0-9]{6,16}$/;
const UID = /^[a-z0-9]{1,16}\.[0-9]{1,9}$/;
const WHO = /^[0-9a-f]{8}$/;
// The model's own state besides its parts, and how long each may be.
const META = { "~title": 120, "~floor": 200, "~hidden": 50_000, "~motions": 200_000, "~looks": 200_000,
  "~unit_steps": 50_000, "~broken": 200_000 };
const MADE_PART = /^~part:[A-Za-z0-9_.-]{1,80}$/;
const MADE_PART_MOST = 1_000_000;
const CHAT_MOST = 280;
// A pointer is shown while it was sent within this long.
const POINTER_MS = 15_000;
// A model's snapshot, its text and parts, at most this much: under Vercel's
// 4.5 MB for a request's body.
const SNAPSHOT_MOST = 4_000_000;
const SEND_MOST = 500;
const CHANGES_MOST = 20_000;
const WAIT_MS = 20_000;
const POLL_MS = 100;
// Who is in it, read again this often while a poll waits.
const PEOPLE_MS = 1_000;
// Heard from within this long: here.
const HERE_MS = 45_000;

class Refusal extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const idOf = (token) => createHash("sha256").update(token).digest("hex");
// A person as the others see them in this session: never their account.
const whoOf = (id, account) => createHash("sha256").update(`${id}:${account}`).digest("hex").slice(0, 8);

function secretOf(body) {
  const token = String(body?.s || "");
  if (!TOKEN.test(token)) throw new Refusal(404, "no such session");
  return token;
}

async function sessionRow(id) {
  const [row] = await db(`together_sessions?id=eq.${id}&select=id,owner,title,last_seq,ended_at`) || [];
  return row || null;
}

async function peopleRows(id) {
  return await db(`together_people?session=eq.${id}&select=account,name,joined_at,seen_at,left_at,removed_at,`
    + "pointer,pointer_at&order=joined_at.asc") || [];
}

// Who is in it, as each side shows them; and a short signature of that, for
// a poll to come back as soon as it changes.
function peopleOut(id, session, rows, me) {
  const now = Date.now();
  let n = 0;
  const out = [];
  for (const row of rows) {
    if (row.removed_at) continue;
    n += 1;
    const here = !row.left_at && now - Date.parse(row.seen_at) < HERE_MS;
    const pointing = Array.isArray(row.pointer) && row.pointer_at && now - Date.parse(row.pointer_at) < POINTER_MS;
    out.push({
      who: whoOf(id, row.account),
      name: row.name || (row.account === session.owner ? "The owner" : `Builder ${n}`),
      owner: row.account === session.owner,
      me: row.account === me,
      here,
      at: here && pointing ? row.pointer : null,
    });
  }
  return out;
}
const signatureOf = (people) => createHash("sha256")
  .update(JSON.stringify(people.map((one) => [one.who, one.name, one.here, one.at])))
  .digest("hex").slice(0, 12);

async function shownName(account) {
  if (!(await shownPublicly(account).catch(() => false))) return "";
  const [person] = await db(`people?account=eq.${account}&select=name`) || [];
  return person?.name ? String(person.name).slice(0, 40) : "";
}

function checkState(state) {
  if (state === null) return true;
  if (!Array.isArray(state) || state.length !== 6) return false;
  const [part, colour, at, group, unit, step] = state;
  return typeof part === "string" && part.length > 0 && part.length <= 64
    && Number.isInteger(colour)
    && Array.isArray(at) && at.length === 12 && at.every((n) => typeof n === "number" && Number.isFinite(n))
    && typeof group === "string" && group.length <= 200
    && typeof unit === "string" && unit.length <= 400
    && Number.isInteger(step);
}

// Whether [key] is the model's own state besides its parts, set to [value].
function checkMeta(key, value) {
  if (META[key]) return value === null || (typeof value === "string" && value.length <= META[key]);
  if (MADE_PART.test(key)) return typeof value === "string" && value.length <= MADE_PART_MOST;
  return false;
}

// The ops' shape; whether any is a chat line.
function checkOps(ops) {
  if (!Array.isArray(ops) || ops.length < 1 || ops.length > SEND_MOST) {
    throw new Refusal(400, `send between 1 and ${SEND_MOST} changes`);
  }
  let parts = 0;
  let chat = false;
  for (const op of ops) {
    if (!op || !Number.isInteger(op.cid) || op.cid < 0 || !op.changes || typeof op.changes !== "object"
        || Array.isArray(op.changes)) {
      throw new Refusal(400, "a change is {cid, changes}");
    }
    const keys = Object.keys(op.changes);
    if (keys.includes("~chat")) {
      if (keys.length !== 1 || typeof op.changes["~chat"] !== "string") throw new Refusal(400, "a chat line goes alone");
      chat = true;
      continue;
    }
    for (const [uid, state] of Object.entries(op.changes)) {
      parts += 1;
      const ok = uid.startsWith("~") ? checkMeta(uid, state) : UID.test(uid) && checkState(state);
      if (!ok) throw new Refusal(400, `that is not a part's state: ${uid.slice(0, 20)}`);
    }
  }
  if (parts > CHANGES_MOST) throw new Refusal(413, `at most ${CHANGES_MOST} parts changed in one send`);
  return chat;
}

const CHAT_WORDS = {
  ask_first: "Brickworks asks everyone one question first. Sign in again to answer it, then chat.",
  under_13: "Chat is for people 13 and over. Building together, your models and sharing by link are all yours.",
  barred: "Brickworks took this account out of the gallery, so it cannot chat.",
};

// Why [me] may not chat, or null: comments' rule (comments_guard).
async function chatTrouble(me) {
  const age = await ageOf(me);
  if (age.ready && age.over_13 === false) return CHAT_WORDS.under_13;
  if (age.ready && age.over_13 !== true) return CHAT_WORDS.ask_first;
  if (await db("rpc/is_barred", { method: "POST", body: { account: me } }).catch(() => false) === true) {
    return CHAT_WORDS.barred;
  }
  return null;
}

// A chat line made plain: one line, printable, 1 to CHAT_MOST characters,
// and nothing a stranger may not be shown.
function chatLine(said) {
  const text = String(said).replace(/[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2066-\u2069]+/g, " ")
    .replace(/\s+/g, " ").trim();
  if (text.length === 0) throw new Refusal(400, "Say something first.");
  if ([...text].length > CHAT_MOST) throw new Refusal(400, `A chat line is at most ${CHAT_MOST} characters.`);
  const words = namesTrouble({ "Your message": [text, "words"] });
  if (words) throw new Refusal(422, words);
  return text;
}

// The session as this person may use it: there, not ended, and they are in it
// (the owner always is) and not taken out of it.
async function inSession(id, me, { joining = false } = {}) {
  const session = await sessionRow(id);
  if (!session) throw new Refusal(404, "no such session");
  if (session.ended_at) throw new Refusal(410, "the owner has ended this session");
  const [mine] = await db(`together_people?session=eq.${id}&account=eq.${me}&select=removed_at`) || [];
  if (mine?.removed_at) throw new Refusal(403, "the owner has taken you out of this session");
  if (!mine && !joining && session.owner !== me) throw new Refusal(403, "join the session by its link first");
  return session;
}

function originOf(request) {
  const host = String(request.headers?.["x-forwarded-host"] || request.headers?.host || "brickworks.diy");
  const local = /^(127\.0\.0\.1|localhost)(:\d+)?$/.test(host);
  return `${local ? "http" : "https"}://${host}`;
}

async function start(request, me) {
  const body = request.body || {};
  const snapshot = body.snapshot;
  if (!snapshot || typeof snapshot !== "object" || typeof snapshot.text !== "string"
      || !Array.isArray(snapshot.bricks)) {
    throw new Refusal(400, "start with the model: {title, snapshot: {text, lift, bricks}}");
  }
  if (JSON.stringify(snapshot).length > SNAPSHOT_MOST) {
    throw new Refusal(413, "that model is too big to build together yet");
  }
  const token = randomBytes(24).toString("base64url");
  const id = idOf(token);
  await db("together_sessions", {
    method: "POST",
    body: { id, owner: me, title: String(body.title || "").slice(0, 120), snapshot },
  });
  await db("together_people", { method: "POST", body: { session: id, account: me, name: await shownName(me) } });
  if (Math.random() < 0.1) await db("rpc/together_sweep", { method: "POST", body: {} }).catch(() => null);
  return { s: token, link: `${originOf(request)}/app?together=${token}` };
}

async function join(request, me) {
  const token = secretOf(request.body);
  const id = idOf(token);
  const session = await inSession(id, me, { joining: true });
  const [mine] = await db(`together_people?session=eq.${id}&account=eq.${me}&select=account`) || [];
  if (mine) {
    await db(`together_people?session=eq.${id}&account=eq.${me}`, {
      method: "PATCH", body: { seen_at: new Date().toISOString(), left_at: null },
    });
  } else {
    await db("together_people", { method: "POST", body: { session: id, account: me, name: await shownName(me) } });
  }
  const [whole] = await db(`together_sessions?id=eq.${id}&select=snapshot`) || [];
  const people = peopleOut(id, session, await peopleRows(id), me);
  return {
    title: session.title, owner: session.owner === me, snapshot: whole?.snapshot || null,
    after: 0, seq: session.last_seq, people, seen: signatureOf(people), chat: (await chatTrouble(me)) || "",
    link: `${originOf(request)}/app?together=${token}`,
  };
}

async function send(request, me) {
  const body = request.body || {};
  const id = idOf(secretOf(body));
  const client = String(body.client || "");
  if (!CLIENT.test(client)) throw new Refusal(400, "send from which client?");
  if (checkOps(body.ops)) {
    const trouble = await chatTrouble(me);
    if (trouble) throw new Refusal(422, trouble);
    for (const op of body.ops) {
      if (op.changes["~chat"] !== undefined) op.changes["~chat"] = chatLine(op.changes["~chat"]);
    }
  }
  // together_append itself refuses an ended session and an account not in
  // it, so a send costs one round trip to the database; the refusal is put
  // in words only when there is one.
  try {
    const seqs = await db("rpc/together_append", {
      method: "POST",
      body: { p_session: id, p_author: me, p_client: client, p_ops: body.ops.map(({ cid, changes }) => ({ cid, changes })) },
    });
    return { seqs, at: Date.now() };
  } catch (trouble) {
    // Ended, or not in it: said as such.
    await inSession(id, me);
    throw trouble;
  }
}

async function poll(request, me) {
  const body = request.body || {};
  const id = idOf(secretOf(body));
  const after = Math.max(0, Math.floor(Number(body.after) || 0));
  const seen = String(body.seen || "");
  // Two trips before it waits, not four: this person heard from (their row,
  // if they are in it and not taken out), then the session and who is in it
  // at once. A poll begins again after every change it gives, so what it
  // costs to begin is in every change.
  const [mine] = await db(`together_people?session=eq.${id}&account=eq.${me}&removed_at=is.null`, {
    method: "PATCH", body: { seen_at: new Date().toISOString(), left_at: null }, prefer: "return=representation",
  }) || [];
  const [found, all] = await Promise.all([sessionRow(id), peopleRows(id)]);
  let session = found;
  if (!mine || !session || session.ended_at) session = await inSession(id, me);
  // An account under 13 is not shown the chat (above): its words taken out.
  // Asked only of a poll that has a chat line to give, not of every poll: a
  // trip to the database each, on every side, for every change.
  let noChat = null;
  const chatHidden = async () => {
    if (noChat === null) {
      const age = await ageOf(me);
      noChat = age.ready && age.over_13 === false;
    }
    return noChat;
  };
  const until = Date.now() + WAIT_MS;
  let people = peopleOut(id, session, all, me);
  let checked = Date.now();
  for (;;) {
    const rows = await db(`together_ops?session=eq.${id}&seq=gt.${after}&order=seq.asc&limit=${SEND_MOST}`
      + "&select=seq,author,client,cid,changes") || [];
    if (Date.now() - checked > PEOPLE_MS) {
      checked = Date.now();
      session = await sessionRow(id);
      if (!session || session.ended_at) return { ended: true, ops: [], people, seen: signatureOf(people) };
      const all = await peopleRows(id);
      if (all.some((row) => row.account === me && row.removed_at)) {
        throw new Refusal(403, "the owner has taken you out of this session");
      }
      people = peopleOut(id, session, all, me);
    }
    const signature = signatureOf(people);
    if (rows.length > 0 || signature !== seen || Date.now() > until) {
      const hide = rows.some((row) => row.changes?.["~chat"] !== undefined) && await chatHidden();
      return {
        ended: false,
        ops: rows.map((row) => ({ seq: Number(row.seq), who: whoOf(id, row.author), client: row.client,
          cid: row.cid, changes: hide && row.changes?.["~chat"] !== undefined ? {} : row.changes })),
        people, seen: signature, ...(hide ? { chat: CHAT_WORDS.under_13 } : {}), at: Date.now(),
      };
    }
    await sleep(POLL_MS);
  }
}

async function end(request, me) {
  const id = idOf(secretOf(request.body));
  const session = await sessionRow(id);
  if (!session) throw new Refusal(404, "no such session");
  if (session.owner !== me) throw new Refusal(403, "only the owner ends the session");
  if (!session.ended_at) {
    await db(`together_sessions?id=eq.${id}`, { method: "PATCH", body: { ended_at: new Date().toISOString() } });
  }
  return { ended: true };
}

async function leave(request, me) {
  const id = idOf(secretOf(request.body));
  await db(`together_people?session=eq.${id}&account=eq.${me}`, {
    method: "PATCH", body: { left_at: new Date().toISOString() },
  });
  return { left: true };
}

async function remove(request, me) {
  const body = request.body || {};
  const id = idOf(secretOf(body));
  const who = String(body.who || "");
  if (!WHO.test(who)) throw new Refusal(400, "remove whom?");
  const session = await inSession(id, me);
  if (session.owner !== me) throw new Refusal(403, "only the owner takes someone out of the session");
  const rows = await peopleRows(id);
  const row = rows.find((one) => whoOf(id, one.account) === who);
  if (!row || row.account === me) throw new Refusal(404, "nobody like that is in this session");
  await db(`together_people?session=eq.${id}&account=eq.${row.account}`, {
    method: "PATCH", body: { removed_at: new Date().toISOString() },
  });
  return { people: peopleOut(id, session, await peopleRows(id), me) };
}

async function point(request, me) {
  const body = request.body || {};
  const id = idOf(secretOf(body));
  const at = body.at;
  if (at !== null && !(Array.isArray(at) && at.length === 3 && at.every((n) => typeof n === "number" && Number.isFinite(n)
      && Math.abs(n) < 1e6))) {
    throw new Refusal(400, "a pointer is [x, y, z] or null");
  }
  // One trip a few times a second: the row of someone in it, not taken out.
  const now = new Date().toISOString();
  const [mine] = await db(`together_people?session=eq.${id}&account=eq.${me}&removed_at=is.null`, {
    method: "PATCH", body: { pointer: at, pointer_at: now, seen_at: now }, prefer: "return=representation",
  }) || [];
  if (!mine) await inSession(id, me);
  return { ok: Boolean(mine) };
}

const OPS = { start, join, send, poll, end, leave, remove, point };

export default async function handler(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  response.setHeader("Access-Control-Allow-Origin", "*");
  if (request.method === "OPTIONS") {
    return response.status(204)
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "POST, OPTIONS").end();
  }
  try {
    if (!authConfigured() || !dbConfigured()) throw new Refusal(503, "building together is not configured here");
    if (request.method !== "POST") throw new Refusal(405, "POST only");
    const op = OPS[String(request.query?.op || "")];
    if (!op) throw new Refusal(400, "which op?");
    let claims;
    try {
      claims = await verify(bearer(request), request);
    } catch (error) {
      throw new Refusal(error instanceof AuthError ? error.status || 401 : 401, error.message);
    }
    const me = String(claims.sub || "");
    if (!/^[0-9a-f-]{36}$/i.test(me)) throw new Refusal(401, "that sign-in names nobody");
    return response.status(200).json(await op(request, me));
  } catch (trouble) {
    if (trouble instanceof Refusal) return response.status(trouble.status).json({ error: trouble.message });
    return response.status(502).json({ error: String(trouble?.message || trouble).slice(0, 200) });
  }
}
