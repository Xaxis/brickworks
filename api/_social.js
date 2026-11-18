// The owner's social desk (socialdesk, 2026-11-18; /admin › Social,
// docs/SOCIAL_DESK.md, supabase/social.sql): Brickworks' own accounts on the
// networks, Reddit first. What came in (replies, mentions, messages), what
// the owner writes (drafts, posts, replies, scheduled sends) and what each
// sent post brought (its score and comments over time, and the visits to
// brickworks.diy its links carried by their utm_campaign).
//
// One model for every network, each a provider behind one interface
// (api/_social_reddit.js is the first): connect by OAuth, read the inbox and
// what names the site, read a community's rules, send, read a send's
// results, and hand a send to the network's own page to be posted by hand.
// X, Facebook and Instagram are named here and shown "not connected yet",
// each with what it needs and costs (docs/SOCIAL_DESK.md).
//
// Nothing leaves without the owner's own press. A send goes out from one
// place only, deliver(), and only for a row the owner pressed Send or
// Schedule on: social_send keeps the press with a hash of the exact words
// the page showed, refuses it when the words it holds are not those, and
// the database refuses any row past a draft without a press
// (social_sends_pressed). The due sends (the cron, every quarter of an hour)
// deliver only scheduled rows whose words still hash to their press. Nothing
// here posts, replies, votes or marks anything at a network of its own
// accord; what it reads on its own is what came in and how sent posts do.
//
// Tokens are read by session() alone, used in a request's Authorization
// header and never answered, written to the audit or logged.
//
// api/admin.js asks all of this after its owner check (404 to anybody else);
// api/plans.js the public visit (op=social_visit) and the cron (op=social_due).

import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { AuthError } from "./_auth.js";
import { db, dbCount } from "./_db.js";
import { ownOrigin } from "./_console_data.js";
import { cronNoted, isCron } from "./_cron.js";
import { reddit, SocialRefusal } from "./_social_reddit.js";

const DAY = 864e5;
const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const ID = /^[a-z0-9]{10}$/;
const COMMUNITY = /^[A-Za-z0-9_]{2,21}$/;
const OURS = new Set(["brickworks.diy", "www.brickworks.diy"]);

/// The networks: Reddit's adapter, and those still to come, each with what
/// it needs and what it costs (docs/SOCIAL_DESK.md, read 2026-11-18).
export const PROVIDERS = {
  reddit,
  x: { id: "x", name: "X", later: true,
    needs: "An X developer app (console.x.com) and OAuth 2.0 with tweet.read, tweet.write, users.read, dm.read, dm.write, offline.access.",
    cost: "Pay per use: $0.015 a post, $0.20 a post with a link, $0.01 a reply when summoned, $0.005 a post read." },
  facebook: { id: "facebook", name: "Facebook", later: true,
    needs: "A Meta app with the Page's admin as its admin. Posting to the Page likely needs App Review for pages_manage_posts "
      + "(unconfirmed: Meta's Pages overview says every Page permission does), and posts reach the public only from a Live app.",
    cost: "No fee from Meta." },
  instagram: { id: "instagram", name: "Instagram", later: true,
    needs: "A professional account linked to the Facebook Page, through the same Meta app (instagram_business_* permissions).",
    cost: "No fee from Meta; at most 100 posts by API a day." },
};

const providerOf = (name) => (Object.hasOwn(PROVIDERS, name) ? PROVIDERS[name] : null);

/// The words a request carried, parsed.
function bodyOf(request) {
  if (typeof request.body !== "string") return request.body && typeof request.body === "object" ? request.body : {};
  try {
    return JSON.parse(request.body) || {};
  } catch {
    return {};
  }
}

const testsOf = (request) => String(request.query?.tests || "") === "1";

/// [b]'s [key] as words: "" when it is not there, refused (400) when it is
/// anything but a string, so a list or an object is never kept as its
/// String() ("x,y", "[object Object]").
function field(b, key) {
  const given = b?.[key];
  if (given === undefined || given === null) return "";
  if (typeof given !== "string") throw new AuthError(`${key} is to be words, not ${Array.isArray(given) ? "a list" : typeof given}.`, 400);
  return given;
}

/// How long [words] are as the networks and the database count them: in
/// characters (code points), so an emoji is one, not two.
const lengthOf = (words) => [...words].length;
const text = (given, most) => String(given ?? "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
  .slice(0, most);
const line = (given, most) => text(given, most).replace(/\s+/g, " ").trim();

/// The desk's tables not on this database yet: said once, the same way.
const NOT_YET = "The social desk's tables are not on this database yet (supabase/social.sql).";
async function tables(promise) {
  try {
    return await promise;
  } catch (trouble) {
    if (notYet(trouble)) throw new AuthError(NOT_YET, 503);
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// The words of a send, and the press on them.

/// [address] with the desk's tags, when it is the site's own (brickworks.diy,
/// or the console's own host for the checks): utm_source=<network>,
/// utm_medium=social, utm_campaign=bw-<send id>. Anything else as it was.
export function tagged(address, provider, id, hosts) {
  let url;
  try {
    url = new URL(address);
  } catch {
    return address;
  }
  if (!/^https?:$/.test(url.protocol) || !hosts.has(url.host.toLowerCase())) return address;
  for (const key of [...url.searchParams.keys()]) if (key.startsWith("utm_")) url.searchParams.delete(key);
  url.searchParams.set("utm_source", provider);
  url.searchParams.set("utm_medium", "social");
  url.searchParams.set("utm_campaign", `bw-${id}`);
  return url.toString();
}

/// Every address in [words] that is the site's own, tagged.
const taggedText = (words, provider, id, hosts) => words.replace(/https?:\/\/[^\s<>()\]]+/g, (found) => {
  const end = /[.,;:!?'"]+$/.exec(found)?.[0] || "";
  return tagged(found.slice(0, found.length - end.length), provider, id, hosts) + end;
});

/// The hash of a send's words, exactly as they leave: what a press is on.
export function hashOf(row) {
  return createHash("sha256").update(JSON.stringify([row.provider, row.kind, row.community ?? null, row.parent ?? null,
    row.title ?? "", row.body ?? "", row.link ?? null])).digest("hex");
}

const SEND_COLUMNS = "id,provider,test,kind,community,parent,title,body,link,status,route,pressed_at,pressed_by,pressed_hash,send_at,"
  + "sent_at,external_id,url,said,made_at,changed_at";

/// A send as the page shows it: its words, where, how far it went, and the
/// hash a press on these words carries.
function sendView(row) {
  const provider = providerOf(row.provider);
  const handOff = row.kind === "post" && row.community && provider?.handOff ? provider.handOff(row) : null;
  return { id: row.id, provider: row.provider, kind: row.kind, community: row.community ?? null, parent: row.parent ?? null,
    title: row.title ?? "", body: row.body ?? "", link: row.link ?? null, status: row.status, route: row.route ?? null,
    pressed_at: row.pressed_at ?? null, pressed_by: row.pressed_by ?? null, send_at: row.send_at ?? null,
    sent_at: row.sent_at ?? null, external_id: row.external_id ?? null, url: row.url ?? null, said: row.said ?? null,
    made_at: row.made_at ?? null, changed_at: row.changed_at ?? null, campaign: `bw-${row.id}`, hash: hashOf(row),
    unsure: unsure(row), hand_off_filled: handOff ? handOff.filled : false };
}

async function sendOf(id, tests) {
  if (!ID.test(String(id || ""))) throw new AuthError("name a send: id", 400);
  const rows = await tables(db(`social_sends?id=eq.${id}&test=eq.${tests}&select=${SEND_COLUMNS}`));
  if (!Array.isArray(rows) || rows.length === 0) throw new AuthError("no such send", 404);
  return rows[0];
}

/// [id]'s row moved from status [from] to what [change] says, only if it is
/// still [from]: the row after, or null when something else moved it first.
async function moved(id, from, change) {
  const rows = await db(`social_sends?id=eq.${id}&status=eq.${from}`, { method: "PATCH",
    body: { ...change, changed_at: new Date().toISOString() }, prefer: "return=representation" });
  return Array.isArray(rows) && rows.length ? rows[0] : null;
}

// ---------------------------------------------------------------------------
// Connecting: OAuth's state signed here, so a code is only taken back for a
// connect the owner started from this console, within ten minutes, and
// once. The state carries when the account was last connected (or that it
// was not), and the finish writes the account only while that still holds:
// a connect finished, or its state replayed, finds it changed and is refused.

function stateKey() {
  return createHmac("sha256", String(process.env.SUPABASE_SECRET_KEY || "")).update("socialdesk-oauth-state").digest();
}

/// The account as a connect finds it: its connected_at, or "-" with none.
const epochOf = (account) => (account ? Buffer.from(String(account.connected_at)).toString("base64url") : "-");

function stateFor(provider, tests, epoch) {
  const payload = `${provider}.${tests ? 1 : 0}.${Date.now() + 10 * 60000}.${randomBytes(9).toString("base64url")}.${epoch}`;
  return `${payload}.${createHmac("sha256", stateKey()).update(payload).digest("base64url")}`;
}

/// The epoch a state was made for, or null when it is not this console's,
/// not this network's, or over ten minutes old.
function stateEpoch(state, provider, tests) {
  const parts = String(state || "").split(".");
  if (parts.length !== 6) return null;
  const payload = parts.slice(0, 5).join(".");
  const want = Buffer.from(createHmac("sha256", stateKey()).update(payload).digest("base64url"));
  const given = Buffer.from(parts[5]);
  if (want.length !== given.length || !timingSafeEqual(want, given)) return null;
  return parts[0] === provider && parts[1] === (tests ? "1" : "0") && Number(parts[2]) > Date.now() ? parts[4] : null;
}

/// Where the network sends the owner back: one fixed address for the real
/// network, the one registered with its app (brickworks.diy, whichever host
/// the console was opened on); the checks' stand-in, this console's own.
const HOME = "https://brickworks.diy";
function redirectOf(request, provider, tests) {
  const origin = tests ? ownOrigin(request) : HOME;
  if (!origin) throw new AuthError("connect from the site's own address", 400);
  return `${origin}/admin?${tests ? "tests=1&" : ""}connected=${provider}`;
}

const accountOf = async (provider, tests) => (await tables(db(`social_accounts?provider=eq.${provider}&test=eq.${tests}`
  + "&select=connected_at")))?.[0] ?? null;

function connectable(name, tests) {
  const provider = providerOf(String(name || ""));
  if (!provider) throw new AuthError("name a network: reddit, x, facebook or instagram", 400);
  if (provider.later) throw new AuthError(`${provider.name} is not part of the desk yet.`, 409);
  const app = provider.appOf(tests);
  if (!app) {
    throw new AuthError(`This deployment has no ${provider.name} app: ${provider.env.join(" and ")} are not set in Vercel. `
      + "Reddit stopped accepting new API apps on 31 October 2026; without one, posts go by hand.", 409);
  }
  return { provider, app };
}

/// POST op=social_connect {provider}: where to send the owner to let the desk in.
export async function socialConnect(request, response) {
  const tests = testsOf(request);
  const { provider, app } = connectable(bodyOf(request).provider ?? request.query?.provider, tests);
  const epoch = epochOf(await accountOf(provider.id, tests));
  return response.status(200).json({ provider: provider.id, outcome: "asked",
    authorize: provider.authorizeUrl(app, stateFor(provider.id, tests, epoch), redirectOf(request, provider.id, tests)) });
}

/// POST op=social_connected {provider, code, state} (or {error}): the code
/// the network sent back taken for the account's tokens, kept here alone.
export async function socialConnected(request, response, claims) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const { provider, app } = connectable(b.provider, tests);
  const epoch = stateEpoch(b.state, provider.id, tests);
  if (epoch === null) {
    throw new AuthError("That connect was not started from this console, or is over ten minutes old: press Connect again.", 400);
  }
  const before = await accountOf(provider.id, tests);
  const finished = () => new AuthError("That connect is finished already, or the account changed since it began: press Connect "
    + "again.", 409);
  if (epochOf(before) !== epoch) throw finished();
  if (b.error) throw new AuthError(`${provider.name} was not let in (${line(b.error, 60)}).`, 409);
  if (!/^[A-Za-z0-9_.~-]{4,200}$/.test(String(b.code || ""))) throw new AuthError("no code came back", 400);
  const keys = await provider.exchange(app, String(b.code), redirectOf(request, provider.id, tests));
  const who = await provider.me({ transport: app.transport, access_token: keys.access_token, handle: null });
  const now = new Date().toISOString();
  const account = { provider: provider.id, test: tests, handle: line(who.handle, 100), external_id: who.external_id,
    scopes: line(keys.scopes, 1000), connected_by: line(claims?.email || "the owner", 320), connected_at: now,
    synced_at: null, sync_said: null };
  // Written only as the connect found it: a second finish of the same
  // connect (two at once, or one replayed) changes nothing, and the keys
  // it was given are handed back.
  let won;
  if (before) {
    won = await tables(db(`social_accounts?provider=eq.${provider.id}&test=eq.${tests}`
      + `&connected_at=eq.${encodeURIComponent(before.connected_at)}`, { method: "PATCH", body: account, prefer: "return=representation" }));
    won = Array.isArray(won) && won.length > 0;
  } else {
    won = await tables(db("social_accounts", { method: "POST", body: account })).then(() => true,
      (trouble) => (/: 409$/.test(String(trouble?.message || "")) ? false : Promise.reject(trouble)));
  }
  if (!won) {
    await provider.revoke(app, keys.refresh_token).catch(() => null);
    throw finished();
  }
  await db("social_tokens?on_conflict=provider,test", { method: "POST", prefer: "resolution=merge-duplicates",
    body: { provider: provider.id, test: tests, access_token: keys.access_token, refresh_token: keys.refresh_token,
      expires_at: keys.expires_at, changed_at: now } });
  return response.status(200).json({ provider: provider.id, handle: who.handle, outcome: "connected" });
}

/// POST op=social_disconnect {provider}: the tokens taken back at the network
/// and forgotten here. What was sent and what came in are kept.
export async function socialDisconnect(request, response) {
  const tests = testsOf(request);
  const provider = providerOf(String(bodyOf(request).provider ?? ""));
  if (!provider || provider.later) throw new AuthError("name a connected network", 400);
  const kept = await tables(db(`social_tokens?provider=eq.${provider.id}&test=eq.${tests}&select=refresh_token`));
  const app = provider.appOf(tests);
  const revoked = kept?.[0]?.refresh_token && app ? await provider.revoke(app, kept[0].refresh_token) : false;
  await db(`social_tokens?provider=eq.${provider.id}&test=eq.${tests}`, { method: "DELETE" });
  await db(`social_accounts?provider=eq.${provider.id}&test=eq.${tests}`, { method: "DELETE" });
  return response.status(200).json({ provider: provider.id, outcome: "disconnected", revoked });
}

/// The connected account of [provider] in this pool, ready to ask: its
/// access token refreshed when it is within a minute of running out. Null
/// when it is not connected (or this deployment has no app for it).
async function session(provider, tests) {
  if (provider.later) return null;
  const app = provider.appOf(tests);
  if (!app) return null;
  const [keys, account] = await Promise.all([
    db(`social_tokens?provider=eq.${provider.id}&test=eq.${tests}&select=access_token,refresh_token,expires_at`),
    db(`social_accounts?provider=eq.${provider.id}&test=eq.${tests}&select=handle`),
  ]);
  if (!keys?.length || !account?.length) return null;
  let { access_token: access, refresh_token: refresh, expires_at: expires } = keys[0];
  if (refresh && (!expires || Date.parse(expires) < Date.now() + 60000)) {
    const fresh = await provider.refresh(app, refresh);
    access = fresh.access_token;
    await db(`social_tokens?provider=eq.${provider.id}&test=eq.${tests}`, { method: "PATCH",
      body: { access_token: fresh.access_token, expires_at: fresh.expires_at, changed_at: new Date().toISOString(),
        ...(fresh.refresh_token ? { refresh_token: fresh.refresh_token } : {}) } });
  }
  return { transport: app.transport, access_token: access, handle: account[0].handle };
}

// ---------------------------------------------------------------------------
// Reading: what came in, and how sent posts do. Never a send.

/// New items kept, those already here left as they are (read or not).
async function keepItems(provider, tests, items) {
  // A network's ids are its own letters, digits and _ (t1_abc): anything
  // else is not kept, so none is ever quoted into a filter.
  items = items.filter((one) => /^[A-Za-z0-9_]{1,100}$/.test(String(one.external_id || "")));
  if (!items.length) return 0;
  const ids = items.map((one) => one.external_id);
  const there = new Set();
  for (let at = 0; at < ids.length; at += 50) {
    const chunk = ids.slice(at, at + 50).join(",");
    for (const row of await db(`social_items?provider=eq.${provider.id}&test=eq.${tests}&external_id=in.(${chunk})&select=external_id`)) {
      there.add(row.external_id);
    }
  }
  const now = new Date().toISOString();
  const fresh = items.filter((one) => !there.has(one.external_id) && /^https:\/\//.test(String(one.url || "")))
    .map(({ unread, ...one }) => ({ ...one, provider: provider.id, test: tests, seen_at: now, read_at: unread ? null : now }));
  if (fresh.length) await db("social_items", { method: "POST", body: fresh });
  return fresh.length;
}

/// Each sent thing's score and comments now, kept as one more point over
/// time (at most one a sixth of an hour each).
async function keepResults(provider, tests, s) {
  const sent = await db(`social_sends?provider=eq.${provider.id}&test=eq.${tests}&status=eq.sent&select=id,external_id,sent_at`
    + "&order=sent_at.desc&limit=200");
  const recent = (sent || []).filter((one) => one.external_id && Date.now() - Date.parse(one.sent_at) < 90 * DAY);
  if (!recent.length) return 0;
  const got = await provider.results(s, recent.map((one) => one.external_id));
  const byThing = new Map(got.map((one) => [one.external_id, one]));
  const at = new Date(Math.floor(Date.now() / 600000) * 600000).toISOString();
  const rows = recent.filter((one) => byThing.has(one.external_id)).map((one) => {
    const r = byThing.get(one.external_id);
    return { send: one.id, at, score: r.score, comments: r.comments, ratio: r.ratio };
  });
  if (rows.length) await db("social_results?on_conflict=send,at", { method: "POST", body: rows, prefer: "resolution=merge-duplicates" });
  return rows.length;
}

/// One network's look for what came in and how sent posts do.
async function syncOne(provider, tests) {
  const s = await session(provider, tests);
  if (!s) return null;
  let said = "";
  let fresh = 0;
  let points = 0;
  try {
    const [inboxItems, found] = await Promise.all([provider.inbox(s), provider.mentions(s)]);
    fresh = await keepItems(provider, tests, [...inboxItems, ...found]);
    points = await keepResults(provider, tests, s);
    said = `${fresh} new, ${points} sent ${points === 1 ? "post" : "posts"} read`;
  } catch (trouble) {
    said = String(trouble?.message || trouble).slice(0, 300);
  }
  await db(`social_accounts?provider=eq.${provider.id}&test=eq.${tests}`, { method: "PATCH",
    body: { synced_at: new Date().toISOString(), sync_said: said } });
  return { provider: provider.id, fresh, points, said };
}

/// POST op=social_sync: every connected network's look, now.
export async function socialSync(request, response) {
  const tests = testsOf(request);
  await tables(db(`social_accounts?test=eq.${tests}&select=provider&limit=1`));
  const looked = [];
  for (const provider of Object.values(PROVIDERS)) {
    const one = await syncOne(provider, tests).catch((trouble) => ({ provider: provider.id, said: String(trouble?.message || trouble) }));
    if (one) looked.push(one);
  }
  const fresh = looked.reduce((sum, one) => sum + (one.fresh || 0), 0);
  return response.status(200).json({ outcome: looked.length ? `${fresh} new` : "nothing connected", looked });
}

/// POST op=social_mark {provider, external_id, read} or {all: true}: read or
/// unread here. Nothing is marked at the network.
export async function socialMark(request, response) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const read = b.read === false ? null : new Date().toISOString();
  if (b.all === true) {
    await tables(db(`social_items?test=eq.${tests}&read_at=is.null`, { method: "PATCH", body: { read_at: new Date().toISOString() } }));
    return response.status(200).json({ outcome: "all read" });
  }
  const provider = providerOf(String(b.provider || ""));
  const id = String(b.external_id || "");
  if (!provider || !/^[A-Za-z0-9_:.-]{1,100}$/.test(id)) throw new AuthError("name an item: provider and external_id", 400);
  const rows = await tables(db(`social_items?provider=eq.${provider.id}&test=eq.${tests}&external_id=eq.${encodeURIComponent(id)}`,
    { method: "PATCH", body: { read_at: read }, prefer: "return=representation" }));
  if (!rows?.length) throw new AuthError("no such item", 404);
  return response.status(200).json({ outcome: read ? "read" : "unread" });
}

// ---------------------------------------------------------------------------
// Writing: a draft kept, pressed, scheduled, sent, or handed over.

/// A send that may be up at the network or may not: it went to the network
/// and no clear answer came back (a timeout, the network's own 5xx, an
/// answer that names no post), or its request was cut off mid-send and it is
/// still "sending" five minutes on. Never sent again on that press: the
/// owner looks on the network, then pastes its address (social_posted) or
/// takes it back to the drafts (social_unschedule) and presses Send afresh.
const STUCK = 5 * 60000;
const UNSURE = "Unsure: ";
const unsure = (row) => row.status === "sending"
  && (String(row.said || "").startsWith(UNSURE) || Date.now() - Date.parse(row.changed_at) > STUCK);

/// POST op=social_draft {id?, provider, kind, community?, parent?, title,
/// body, link?}: kept as a draft, its links to the site tagged. A draft that
/// was scheduled or handed over is a draft again, and says so: pressed
/// afresh to go.
export async function socialDraft(request, response) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const provider = providerOf(field(b, "provider"));
  if (!provider || provider.later) throw new AuthError("write for a network the desk has: reddit", 400);
  const asked = field(b, "kind");
  const kind = asked === "reply" ? "reply" : asked === "post" ? "post" : null;
  if (!kind) throw new AuthError("a post or a reply", 400);
  const id = field(b, "id");
  let before = null;
  if (id) {
    before = await sendOf(id, tests);
    if (["sending", "sent"].includes(before.status)) throw new AuthError("It has gone: what was sent is kept as it was.", 409);
    if (before.provider !== provider.id || before.kind !== kind) throw new AuthError("a draft keeps its network and kind", 409);
  }
  const community = field(b, "community").replace(/^\/?r\//i, "").trim();
  if (community && !COMMUNITY.test(community)) throw new AuthError("A community's name is 2 to 21 letters, digits or _.", 400);
  let parent = null;
  if (kind === "reply") {
    parent = field(b, "parent") || before?.parent || "";
    const items = /^[A-Za-z0-9_:.-]{1,100}$/.test(parent) ? await tables(db(`social_items?provider=eq.${provider.id}&test=eq.${tests}`
      + `&external_id=eq.${encodeURIComponent(parent)}&select=external_id`)) : [];
    if (!items?.length) throw new AuthError("a reply answers an item in the inbox", 400);
  }
  const hosts = new Set(OURS);
  const origin = ownOrigin(request);
  if (origin) hosts.add(new URL(origin).host.toLowerCase());
  // Cut at twice the most first (a character is at most two UTF-16 units),
  // then counted in characters, as Reddit and the database count them.
  const title = kind === "post" ? line(field(b, "title"), provider.most.title * 2 + 2) : "";
  const words = text(field(b, "body"), provider.most.body * 2 + 2).trim();
  const given = field(b, "link").trim();
  if (given && !/^https?:\/\/[^\s]+$/.test(given)) throw new AuthError("A link is an address that starts https://.", 400);
  const now = new Date();
  // The row as kept under [one]: the site's links tagged with that id.
  const rowAs = (one) => ({ id: one, provider: provider.id, test: tests, kind, community: kind === "post" ? community || null : null,
    parent, title, body: taggedText(words, provider.id, one, hosts),
    link: kind === "post" && given ? tagged(given, provider.id, one, hosts) : null, status: "draft", route: null, pressed_at: null,
    pressed_by: null, pressed_hash: null, send_at: null, said: null, changed_at: now.toISOString() });
  const twins = [tests, provider.id, kind, community || null, parent, title, words, given || null];
  const row = rowAs(id || twinId(twins, now.getTime()));
  if (lengthOf(title) > provider.most.title) throw new AuthError(`A title is at most ${provider.most.title} characters.`, 400);
  if (lengthOf(row.body) > provider.most.body) throw new AuthError(`At most ${provider.most.body} characters.`, 400);
  if (row.link && row.link.length > 2000) throw new AuthError("That link is too long.", 400);
  const wrong = provider.refuses(row);
  if (wrong) throw new AuthError(wrong, 400);
  if (before) {
    const after = await moved(id, before.status, row);
    if (!after) throw new AuthError("It changed while you wrote: look again.", 409);
    // Edited after a press, it no longer goes: said, never silently.
    const outcome = before.status === "scheduled" ? "unscheduled" : before.status === "handed" ? "redrafted" : "kept";
    return response.status(200).json({ outcome, send: sendView(after) });
  }
  const kept = await keptNew(row, rowAs, twins, now.getTime());
  return response.status(200).json({ outcome: "kept", send: sendView(kept) });
}

/// Two Keeps of one new draft (two tabs at once, presses the page did not
/// hold, or a Keep pressed again when its answer was lost) are one draft.
/// A new draft's id is made from its words and the ten seconds it is kept
/// in, so the second meets the first's id and the database's own key
/// decides, whatever order they run in; both are answered with the one
/// kept. A draft of the ten seconds before is found too. The same words
/// kept again later, or once that draft was edited or sent, take an id of
/// chance.
const TWINS = 10000;
const ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789";
const chance = () => Array.from(randomBytes(10), (byte) => ALPHABET[byte % 36]).join("");
function twinId(twins, at) {
  const digest = createHash("sha256").update(JSON.stringify([...twins, Math.floor(at / TWINS)])).digest();
  return Array.from(digest.subarray(0, 10), (byte) => ALPHABET[byte % 36]).join("");
}

async function keptNew(row, rowAs, twins, at) {
  const twinOf = async (one) => {
    const [kept] = (await tables(db(`social_sends?id=eq.${one}&status=eq.draft&select=${SEND_COLUMNS}`))) || [];
    return kept && Date.parse(kept.made_at) >= at - 2 * TWINS && hashOf(kept) === hashOf(rowAs(one)) ? kept : null;
  };
  const earlier = await twinOf(twinId(twins, at - TWINS));
  if (earlier) return earlier;
  const made = { ...row, made_at: new Date(at).toISOString() };
  const put = await tables(db("social_sends", { method: "POST", body: made })).then(() => true,
    (trouble) => (/: 409$/.test(String(trouble?.message || "")) ? false : Promise.reject(trouble)));
  if (put) return made;
  const twin = await twinOf(row.id);
  if (twin) return twin;
  const other = { ...rowAs(chance()), made_at: made.made_at };
  await tables(db("social_sends", { method: "POST", body: other }));
  return other;
}

/// POST op=social_drop {id}: a draft thrown away, or one that failed or was
/// handed to the owner and not posted. What went (or may have) is kept.
export async function socialDrop(request, response) {
  const tests = testsOf(request);
  const row = await sendOf(field(bodyOf(request), "id"), tests);
  if (!["draft", "failed", "handed"].includes(row.status)) {
    throw new AuthError("Only a draft, one that failed, or one handed to you and not posted is thrown away.", 409);
  }
  await db(`social_sends?id=eq.${row.id}&status=eq.${row.status}`, { method: "DELETE" });
  return response.status(200).json({ outcome: "dropped" });
}

function readyToGo(row, provider) {
  if (row.kind === "post") {
    if (!row.community) return "Say which community it goes to.";
    if (!row.title) return "A post needs a title.";
    if (!row.body && !row.link) return "A post needs words or a link.";
  } else if (!row.body) return "A reply needs words.";
  if (lengthOf(row.title) > provider.most.title || lengthOf(row.body) > provider.most.body) return "It is longer than the network takes.";
  return provider.refuses({ kind: row.kind, link: row.link, body: row.body });
}

/// What leaves, and how: a post or a reply at the network, [s] connected.
/// The only place anything is sent. The network's own no is "failed" (it is
/// not there, and may be pressed again); anything less clear is unsure.
async function deliver(row, s, provider) {
  let went;
  try {
    went = await provider.send(s, { kind: row.kind, community: row.community, parent: row.parent, title: row.title,
      body: row.body, link: row.link });
  } catch (trouble) {
    const said = String(trouble?.message || trouble).slice(0, 400);
    if (trouble instanceof SocialRefusal && !trouble.unsure) {
      await moved(row.id, "sending", { status: "failed", said });
      throw new AuthError(said, trouble.status === 409 ? 409 : 502);
    }
    await moved(row.id, "sending", { said: `${UNSURE}${said}` }).catch(() => null);
    throw new AuthError(`${provider.name} gave no clear answer (${said}), so it may be up. Look on ${provider.name} first: `
      + "if it is there, paste its address under Sent; if not, take it back to the drafts and press Send again.", 502);
  }
  const done = { status: "sent", sent_at: new Date().toISOString(), external_id: went.external_id, url: went.url, said: null };
  for (let tries = 0; tries < 2; tries += 1) {
    try {
      return await moved(row.id, "sending", done);
    } catch {
      // Written once more; then said, with where it went.
    }
  }
  await moved(row.id, "sending", { said: `${UNSURE}it went, as ${went.url}, but was not written down here` }).catch(() => null);
  throw new AuthError(`It went, as ${went.url}, but could not be written down here: paste that address under Sent.`, 502);
}

/// Where a send is handed to the owner: {url, filled}, the network's own
/// page for a post (filled when its words are in the address), or the item
/// a reply answers (never filled: the words are copied and pasted there).
async function handOffOf(row, provider, tests) {
  if (row.kind === "post") return provider.handOff(row);
  const items = await db(`social_items?provider=eq.${provider.id}&test=eq.${tests}&external_id=eq.${encodeURIComponent(row.parent)}`
    + "&select=url");
  return items?.[0]?.url ? { url: items[0].url, filled: false } : null;
}

/// POST op=social_send {id, hash, at?}: the owner's press of Send (or, with
/// [at], Schedule) on the exact words [hash] names. Connected, it goes by
/// the network's API (now, or at its time); else it is handed over: the
/// network's own page opened with the words, for the owner to press Post.
export async function socialSend(request, response, claims) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const row = await sendOf(field(b, "id"), tests);
  const provider = providerOf(row.provider);
  if (unsure(row)) throw new AuthError("It may be up already: look on Reddit, then paste its address or take it back to the drafts.", 409);
  if (!["draft", "failed", "scheduled", "handed"].includes(row.status)) throw new AuthError("It has gone already.", 409);
  if (field(b, "hash") !== hashOf(row)) {
    throw new AuthError("These are not the words you pressed Send on: they changed since. Look again and press Send.", 409);
  }
  const wrong = readyToGo(row, provider);
  if (wrong) throw new AuthError(wrong, 400);
  let at = null;
  const when = field(b, "at");
  if (when) {
    at = Date.parse(when);
    if (!Number.isFinite(at) || at < Date.now() + 60000 || at > Date.now() + 60 * DAY) {
      throw new AuthError("Schedule it at least a minute from now and within 60 days.", 400);
    }
  }
  const s = await session(provider, tests);
  const route = s ? "api" : "by_hand";
  const press = { pressed_at: new Date().toISOString(), pressed_by: line(claims?.email || "the owner", 320), pressed_hash: hashOf(row),
    route, said: null };
  if (at !== null) {
    const after = await moved(row.id, row.status, { ...press, status: "scheduled", send_at: new Date(at).toISOString() });
    if (!after) throw new AuthError("It changed while you pressed: look again.", 409);
    return response.status(200).json({ outcome: "scheduled", send: sendView(after) });
  }
  if (route === "by_hand") {
    const handOff = await handOffOf(row, provider, tests);
    if (!handOff) throw new AuthError("There is nowhere to hand it to.", 409);
    const after = await moved(row.id, row.status, { ...press, status: "handed", send_at: null });
    if (!after) throw new AuthError("It changed while you pressed: look again.", 409);
    return response.status(200).json({ outcome: "handed", hand_off: handOff.url, hand_off_filled: handOff.filled,
      send: sendView(after) });
  }
  const claimed = await moved(row.id, row.status, { ...press, status: "sending", send_at: null });
  if (!claimed) throw new AuthError("It is being sent already.", 409);
  const after = await deliver(claimed, s, provider);
  return response.status(200).json({ outcome: "sent", url: after?.url ?? null, send: after ? sendView(after) : null });
}

/// POST op=social_unschedule {id}: back to the drafts, its press forgotten:
/// a scheduled send, one handed to the owner and not posted, or one that is
/// unsure and that the owner found is not on the network. It goes only on a
/// fresh press.
export async function socialUnschedule(request, response) {
  const row = await sendOf(field(bodyOf(request), "id"), testsOf(request));
  const from = row.status;
  if (!(from === "scheduled" || from === "handed" || unsure(row))) throw new AuthError("It is not waiting to go.", 409);
  const after = await moved(row.id, from, { status: "draft", route: null, pressed_at: null, pressed_by: null,
    pressed_hash: null, send_at: null, said: null });
  if (!after) throw new AuthError("It went while you pressed.", 409);
  return response.status(200).json({ outcome: from === "scheduled" ? "unscheduled" : "back to drafts", send: sendView(after) });
}

/// POST op=social_posted {id, url}: a send handed over and posted by the
/// owner at the network, or an unsure one found there: its address kept, so
/// the visits it brings are counted (and, once the network is connected,
/// its score). A reply to a private message has no address of its own: its
/// conversation's is kept.
export async function socialPosted(request, response) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const row = await sendOf(field(b, "id"), tests);
  const provider = providerOf(row.provider);
  const from = row.status;
  if (!(from === "handed" || (from === "scheduled" && row.route === "by_hand") || unsure(row))) {
    throw new AuthError("Only a send handed to you, or one that may be up, is marked posted.", 409);
  }
  const url = field(b, "url").trim();
  let thing = provider.thingOf(url);
  let address = url;
  if (row.kind === "reply" && /^t4_/.test(String(row.parent))) {
    const items = await db(`social_items?provider=eq.${provider.id}&test=eq.${tests}&external_id=eq.${encodeURIComponent(row.parent)}`
      + "&select=url");
    address = items?.[0]?.url || "";
    thing = null;
    if (!/^https:\/\//.test(address)) throw new AuthError("Its message is no longer in the inbox: paste the conversation's address.", 400);
  } else if (!thing || !thing.startsWith(row.kind === "post" ? "t3_" : "t1_")) {
    throw new AuthError(provider.pasteHelp(row.kind), 400);
  }
  const after = await moved(row.id, from, { status: "sent", sent_at: new Date().toISOString(), url: address, external_id: thing,
    said: null });
  if (!after) throw new AuthError("It changed while you pressed: look again.", 409);
  return response.status(200).json({ outcome: "posted", send: sendView(after) });
}

/// POST op=social_notes {provider, community, notes}: the owner's own notes
/// on a community's rules, kept beside them.
export async function socialNotes(request, response) {
  const tests = testsOf(request);
  const b = bodyOf(request);
  const provider = providerOf(field(b, "provider"));
  const community = field(b, "community").replace(/^\/?r\//i, "");
  if (!provider || provider.later || !COMMUNITY.test(community)) throw new AuthError("name a community", 400);
  await tables(db("social_rules?on_conflict=provider,test,community", { method: "POST", prefer: "resolution=merge-duplicates",
    body: { provider: provider.id, test: tests, community: community.toLowerCase(), notes: text(field(b, "notes"), 4000).trim() || null,
      noted_at: new Date().toISOString() } }));
  return response.status(200).json({ outcome: "noted" });
}

// ---------------------------------------------------------------------------
// The section's reads.

/// GET op=social_rules&provider=&community=: a community's rules beside the
/// box, read from the network a day at most, with the owner's notes.
export async function socialRules(request) {
  const tests = testsOf(request);
  const provider = providerOf(String(request.query?.provider || "reddit"));
  const community = String(request.query?.community || "").replace(/^\/?r\//i, "");
  if (!provider || provider.later || !COMMUNITY.test(community)) throw new AuthError("name a community", 400);
  const key = community.toLowerCase();
  const kept = (await tables(db(`social_rules?provider=eq.${provider.id}&test=eq.${tests}&community=eq.${key}`
    + "&select=rules,read_at,notes,noted_at")))?.[0] || null;
  const page = `https://www.reddit.com/r/${community}/about/rules`;
  if (kept?.rules && kept.read_at && Date.now() - Date.parse(kept.read_at) < DAY) {
    return { community, ...kept.rules, read_at: kept.read_at, notes: kept.notes ?? null, from: "kept", page };
  }
  const s = await session(provider, tests);
  if (!s) {
    return { community, rules: kept?.rules?.rules ?? null, site: kept?.rules?.site ?? [], about: kept?.rules?.about ?? null,
      read_at: kept?.read_at ?? null, notes: kept?.notes ?? null, from: "none", page };
  }
  const got = await provider.rulesOf(s, community);
  if (!got) return { community, rules: null, site: [], about: null, read_at: null, notes: kept?.notes ?? null, from: "missing", page };
  const now = new Date().toISOString();
  await db("social_rules?on_conflict=provider,test,community", { method: "POST", prefer: "resolution=merge-duplicates",
    body: { provider: provider.id, test: tests, community: key, rules: got, read_at: now } });
  return { community, ...got, read_at: now, notes: kept?.notes ?? null, from: "network", page };
}

/// GET op=social: the section whole. Each network (connected, how, what it
/// needs), the inbox newest first, every send with its results over time and
/// the visits its links brought.
/// What Sent lists: the newest sends of every kind, and every one still to
/// go or waiting on the owner (OPEN_MOST: what Supabase answers a read at most).
const NEWEST = 300;
const OPEN = ["scheduled", "sending", "handed", "failed"];
const OPEN_MOST = 1000;

export async function socialRead(request) {
  const tests = testsOf(request);
  let accounts;
  let items;
  let sends;
  let open;
  let total;
  try {
    [accounts, items, sends, open, total] = await Promise.all([
      db(`social_accounts?test=eq.${tests}&select=provider,handle,connected_at,connected_by,synced_at,sync_said,scopes`),
      db(`social_items?test=eq.${tests}&select=provider,external_id,kind,detail,author,subject,body,url,community,thread,made_at,`
        + "seen_at,read_at&order=made_at.desc&limit=300"),
      db(`social_sends?test=eq.${tests}&select=${SEND_COLUMNS}&order=changed_at.desc&limit=${NEWEST}`),
      // Every send still to go or waiting on the owner, however long ago it
      // was last changed: a schedule never goes unseen.
      db(`social_sends?test=eq.${tests}&status=in.(${OPEN.join(",")})&select=${SEND_COLUMNS}&order=changed_at.desc&limit=${OPEN_MOST}`),
      dbCount(`social_sends?test=eq.${tests}`),
    ]);
  } catch (trouble) {
    if (!notYet(trouble)) throw trouble;
    return { ready: false, said: NOT_YET, networks: networks(tests, []), items: [], sends: [] };
  }
  const listed = new Set(sends.map((one) => one.id));
  sends = [...sends, ...open.filter((one) => !listed.has(one.id))];
  const ids = sends.filter((one) => ["sent", "handed"].includes(one.status)).map((one) => one.id);
  const results = new Map();
  const visits = new Map();
  for (let at = 0; at < ids.length; at += 80) {
    const chunk = ids.slice(at, at + 80).join(",");
    const [points, landed] = await Promise.all([
      db(`social_results?send=in.(${chunk})&select=send,at,score,comments,ratio&order=at.asc`),
      db(`social_visits?send=in.(${chunk})&select=send,at,path,source&order=at.asc`),
    ]);
    for (const one of points || []) (results.get(one.send) || results.set(one.send, []).get(one.send)).push(one);
    for (const one of landed || []) (visits.get(one.send) || visits.set(one.send, []).get(one.send)).push(one);
  }
  return {
    ready: true,
    // Sent, dropped back or failed long ago, past the newest: counted, not listed.
    unlisted: Math.max(0, total - sends.length),
    networks: networks(tests, accounts),
    items: items.map((one) => ({ ...one, read: Boolean(one.read_at) })),
    sends: sends.map((row) => {
      const points = results.get(row.id) || [];
      const landed = visits.get(row.id) || [];
      const days = {};
      for (const one of landed) days[one.at.slice(0, 10)] = (days[one.at.slice(0, 10)] || 0) + 1;
      // A send waiting on the owner at the network: where they post it.
      const waiting = row.status === "handed" || (row.status === "scheduled" && row.route === "by_hand");
      const provider = providerOf(row.provider);
      const handOff = !waiting || !provider || provider.later ? null : row.kind === "post" ? provider.handOff(row).url
        : items.find((one) => one.provider === row.provider && one.external_id === row.parent)?.url ?? null;
      return { ...sendView(row), hand_off: handOff,
        results: points.map(({ at, score, comments, ratio }) => ({ at, score, comments, ratio })),
        visits: { total: landed.length, by_day: days, last: landed.at(-1)?.at ?? null } };
    }),
  };
}

/// Each network as the page shows it: connected or not, by what, what is
/// missing (by name, never a value), and what one still to come costs.
function networks(tests, accounts) {
  return Object.values(PROVIDERS).map((provider) => {
    if (provider.later) return { id: provider.id, name: provider.name, later: true, needs: provider.needs, cost: provider.cost };
    const account = accounts.find((one) => one.provider === provider.id) || null;
    const app = provider.appOf(tests);
    return { id: provider.id, name: provider.name, later: false, mock: Boolean(app?.mock), api: Boolean(app),
      missing: app ? [] : provider.env.filter((name) => !String(process.env[name] || "").trim()),
      account: account && { handle: account.handle, connected_at: account.connected_at, connected_by: account.connected_by,
        synced_at: account.synced_at, sync_said: account.sync_said },
      route: account && app ? "api" : "by_hand", most: provider.most };
  });
}

/// For the Overview and the console's list: unread items, sends that wait on
/// the owner (handed over, or due by hand), and failed ones. Null before the file.
export async function socialNeeds(tests = false) {
  try {
    const [unread, waiting] = await Promise.all([
      db(`social_items?test=eq.${tests}&read_at=is.null&select=external_id&limit=500`),
      db(`social_sends?test=eq.${tests}&status=in.(handed,scheduled,failed,sending)&select=id,status,route,send_at,said,changed_at`
        + "&limit=500"),
    ]);
    const due = waiting.filter((one) => one.status === "handed"
      || (one.status === "scheduled" && one.route === "by_hand" && Date.parse(one.send_at) <= Date.now())).length;
    // Failed, or unsure whether it is up: each wants the owner's look.
    return { unread: unread.length, due, failed: waiting.filter((one) => one.status === "failed" || unsure(one)).length };
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// The cron (api/plans.js op=social_due, every quarter of an hour), and the
// visits the site's pages tell of.

/// Scheduled sends whose time has come, by the API, each only if its words
/// still hash to the owner's press; then each connected network's look.
export async function socialDue() {
  let due;
  try {
    due = await db(`social_sends?status=eq.scheduled&route=eq.api&select=${SEND_COLUMNS}&order=send_at.asc&limit=50`);
  } catch (trouble) {
    if (notYet(trouble)) return { outcome: "not_applied", sent: 0, failed: 0 };
    throw trouble;
  }
  let sent = 0;
  let failed = 0;
  for (const row of due.filter((one) => Date.parse(one.send_at) <= Date.now())) {
    const provider = providerOf(row.provider);
    if (!provider || provider.later) continue;
    if (!row.pressed_at || row.pressed_hash !== hashOf(row)) {
      await moved(row.id, "scheduled", { status: "failed", said: "Its words are not those pressed: not sent." });
      failed += 1;
      continue;
    }
    const s = await session(provider, row.test).catch(() => null);
    if (!s) {
      await moved(row.id, "scheduled", { status: "failed", said: `${provider.name} is not connected: not sent.` });
      failed += 1;
      continue;
    }
    const claimed = await moved(row.id, "scheduled", { status: "sending" });
    if (!claimed) continue;
    const went = await deliver(claimed, s, provider).then(() => true, () => false);
    if (went) sent += 1;
    else failed += 1;
  }
  const looked = [];
  for (const tests of [false, true]) {
    for (const provider of Object.values(PROVIDERS)) {
      const one = await syncOne(provider, tests).catch(() => null);
      if (one) looked.push({ ...one, tests });
    }
  }
  return { outcome: sent || failed ? `${sent} sent, ${failed} failed` : "nothing due", sent, failed,
    looked: looked.map((one) => `${one.tests ? "checks' " : ""}${one.provider}: ${one.said}`) };
}

/// GET /api/plans?op=social_due: Vercel's cron (/api/plans/social-due, every
/// quarter of an hour), with CRON_SECRET; its runs written down when it sent
/// something, failed, or at the day's first run, so Site sees it alive
/// without a row every quarter hour.
export async function socialDueRoute(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the social desk's sends are the cron's" });
  const started = new Date().toISOString();
  let out;
  try {
    out = await socialDue();
  } catch (trouble) {
    const said = String(trouble?.message || trouble).slice(0, 200);
    console.error(`social: due: ${said}`);
    await cronNoted(request, "social_due", started, "failed", { error: said });
    return response.status(500).json({ error: "the due sends stopped" });
  }
  const now = new Date();
  if (out.sent || out.failed || (now.getUTCHours() === 0 && now.getUTCMinutes() < 15)
    || !/^vercel-cron\b/.test(String(request.headers?.["user-agent"] || ""))) {
    await cronNoted(request, "social_due", started, out.failed ? "failed" : "done", { outcome: out.outcome });
  }
  return response.status(200).json(out);
}

/// The visitor [request] is, for send [id] today: a key only this server can
/// make from its address and browser, neither of them kept. A visitor counts
/// once a day a post, however many times the beacon is sent, and nobody can
/// add visits by inventing numbers of their own.
function visitorOf(request, id) {
  const headers = request.headers || {};
  const address = String(headers["x-real-ip"] || String(headers["x-forwarded-for"] || "").split(",")[0]).trim()
    || request.socket?.remoteAddress || "";
  const agent = String(headers["user-agent"] || "").slice(0, 300);
  const digest = createHmac("sha256", `social-visit:${process.env.SUPABASE_SECRET_KEY || ""}`)
    .update(`${id}|${new Date().toISOString().slice(0, 10)}|${address}|${agent}`).digest();
  return Array.from(digest.subarray(0, 20), (byte) => "abcdefghijklmnopqrstuvwxyz0123456789"[byte % 36]).join("");
}

/// At most this many visits a post are counted in any hour: the rows stay
/// bounded whoever sends the beacon (docs/SOCIAL_DESK.md).
export const VISITS_AN_HOUR = 1000;

/// POST /api/plans?op=social_visit {campaign, path, source}: a page opened
/// from a sent post's link (web/theme.js). Counted once a visitor a day, for
/// a send that went, up to VISITS_AN_HOUR; anything else let go. Always 204:
/// it tells nobody what is counted.
export async function socialVisit(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const b = bodyOf(request);
  const campaign = /^bw-([a-z0-9]{10})$/.exec(typeof b.campaign === "string" ? b.campaign : "");
  const path = (typeof b.path === "string" ? b.path : "/").split(/[?#]/)[0].slice(0, 300);
  const source = typeof b.source === "string" && /^[a-z0-9_.-]{1,40}$/.test(b.source) ? b.source : null;
  if (campaign && path.startsWith("/")) {
    const id = campaign[1];
    try {
      const went = await db(`social_sends?id=eq.${id}&status=in.(sent,handed)&select=id`);
      const hour = new Date(Date.now() - 3600000).toISOString();
      if (went?.length && await dbCount(`social_visits?send=eq.${id}&at=gte.${hour}`) < VISITS_AN_HOUR) {
        await db("social_visits?on_conflict=send,nonce", { method: "POST", prefer: "resolution=ignore-duplicates",
          body: { send: id, nonce: visitorOf(request, id), path, source } });
      }
    } catch (trouble) {
      if (!notYet(trouble)) console.error(`social: a visit not counted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
  return response.status(204).end();
}
