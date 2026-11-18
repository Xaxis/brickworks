// Reddit for the owner's social desk (socialdesk, 2026-11-18; api/_social.js,
// docs/SOCIAL_DESK.md): one adapter behind the desk's one interface, the way
// X, Facebook and Instagram are to be added.
//
// Two routes out. By Reddit's API, once a Reddit app's id and secret are in
// the deployment (REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET) and the owner has
// connected the brand's account by OAuth (a "web app": the code flow, a
// permanent refresh token). And by hand, which needs neither: the desk opens
// Reddit's own submit page with the words, and the owner presses Post there.
// Reddit stopped accepting new API apps on 2026-10-31 and ends what remains
// of its public API in March 2027 (its help centre's changelog of 2026-10-08):
// by hand is how a post leaves when there is no app.
//
// Every request is sent by [session.transport]: fetch for Reddit itself, the
// mock (api/_social_mock.js) for the checks' pool. Nothing here decides to
// send: send() is called from one place, api/_social.js's press, and the
// due sends of a press made earlier. Tokens are only ever in a request's
// Authorization header, never in an address, an error's words or a log.
//
// The endpoints, their scopes and their shapes are Reddit's own (the archived
// reddit source and its OAuth2 wiki; docs/SOCIAL_DESK.md has the table):
//   www.reddit.com/api/v1/authorize, access_token, revoke_token
//   oauth.reddit.com /api/v1/me (identity), /message/inbox (privatemessages),
//   /search and /r/X/about/rules, /r/X/about, /api/info (read),
//   /api/submit and /api/comment on a post or comment (submit), and
//   /api/comment on a message (privatemessages)

import { MOCK_CLIENT, mockReddit } from "./_social_mock.js";

const REDDIT = "https://www.reddit.com";
const API = "https://oauth.reddit.com";
export const SCOPES = "identity history privatemessages read submit";
// What a search across Reddit looks for: links to the site, and its name.
const SEARCHES = ["site:brickworks.diy", "\"brickworks.diy\"", "brickworks lego"];

/// A refusal a person can read: Reddit said no, and why.
export class SocialRefusal extends Error {
  constructor(words, status = 502) {
    super(words);
    this.status = status;
  }
}

/// The app this deployment is: Reddit's or the mock's. {id, secret,
/// transport, mock} or null when this deployment has no Reddit app.
export function appOf(tests) {
  if (tests) return { id: MOCK_CLIENT.id, secret: MOCK_CLIENT.secret, transport: mockReddit, mock: true };
  const id = String(process.env.REDDIT_CLIENT_ID || "").trim();
  const secret = String(process.env.REDDIT_CLIENT_SECRET || "").trim();
  return id && secret ? { id, secret, transport: fetchWithin, mock: false } : null;
}

/// fetch, given up after 15 s.
function fetchWithin(url, init = {}) {
  return fetch(url, { ...init, signal: AbortSignal.timeout(15000) });
}

/// Reddit's form of a User-Agent: <platform>:<app id>:<version> (by /u/<name>).
const agentOf = (handle) => `web:diy.brickworks.desk:1.0 (by /u/${/^[A-Za-z0-9_-]{3,20}$/.test(String(handle)) ? handle : "brickworks"})`;

/// Where the owner is sent to let the desk in: Reddit's own page, or for the
/// checks the console's mock consent ([redirect] carries tests=1).
export function authorizeUrl(app, state, redirect) {
  const asked = new URLSearchParams({ client_id: app.id, response_type: "code", state, redirect_uri: redirect,
    duration: "permanent", scope: SCOPES });
  if (app.mock) {
    const page = new URL(redirect);
    return `${page.origin}/admin?tests=1&mock_authorize=reddit&${asked}`;
  }
  return `${REDDIT}/api/v1/authorize?${asked}`;
}

async function tokenCall(app, form) {
  const reply = await app.transport(`${REDDIT}/api/v1/access_token`, { method: "POST",
    headers: { authorization: `Basic ${Buffer.from(`${app.id}:${app.secret}`).toString("base64")}`,
      "content-type": "application/x-www-form-urlencoded", "user-agent": agentOf() },
    body: new URLSearchParams(form).toString() });
  const body = await reply.json().catch(() => null);
  if (!reply.ok || !body || body.error || !body.access_token) {
    throw new SocialRefusal(`Reddit did not let the desk in (${reply.status}${body?.error ? `: ${String(body.error).slice(0, 60)}` : ""}).`);
  }
  return { access_token: body.access_token, refresh_token: body.refresh_token ?? null,
    expires_at: new Date(Date.now() + Math.max(60, Number(body.expires_in) || 3600) * 1000).toISOString(),
    scopes: String(body.scope || "") };
}

/// The code Reddit gave, for the account's tokens.
export const exchange = (app, code, redirect) => tokenCall(app, { grant_type: "authorization_code", code, redirect_uri: redirect });

/// A new access token from the refresh token.
export const refresh = (app, token) => tokenCall(app, { grant_type: "refresh_token", refresh_token: token });

/// The refresh token taken back at Reddit (and every access token with it).
export async function revoke(app, token) {
  if (!token) return false;
  const reply = await app.transport(`${REDDIT}/api/v1/revoke_token`, { method: "POST",
    headers: { authorization: `Basic ${Buffer.from(`${app.id}:${app.secret}`).toString("base64")}`,
      "content-type": "application/x-www-form-urlencoded", "user-agent": agentOf() },
    body: new URLSearchParams({ token, token_type_hint: "refresh_token" }).toString() }).catch(() => null);
  return Boolean(reply && (reply.ok || reply.status === 204));
}

/// One request to Reddit's API as the connected account: its JSON.
async function ask(session, path, { method = "GET", form } = {}) {
  const reply = await session.transport(`${API}${path}`, { method,
    headers: { authorization: `bearer ${session.access_token}`, "user-agent": agentOf(session.handle),
      ...(form ? { "content-type": "application/x-www-form-urlencoded" } : {}) },
    body: form ? new URLSearchParams({ api_type: "json", raw_json: "1", ...form }).toString() : undefined });
  if (reply.status === 401) throw new SocialRefusal("Reddit no longer takes the desk's sign-in: connect Reddit again.", 401);
  if (reply.status === 429) throw new SocialRefusal("Reddit says the desk is asking too often: try again in a few minutes.", 429);
  if (reply.status === 403) throw new SocialRefusal("Reddit refused: the account may not do that there.", 403);
  if (reply.status === 404) return null;
  if (!reply.ok) throw new SocialRefusal(`Reddit said ${reply.status}.`);
  return reply.json();
}

/// Who the connected account is: {handle, external_id}.
export async function me(session) {
  const who = await ask(session, "/api/v1/me");
  if (!who?.name) throw new SocialRefusal("Reddit did not say whose account this is.");
  return { handle: String(who.name), external_id: String(who.id || "") || null };
}

const iso = (seconds) => new Date(Number(seconds) * 1000).toISOString();
const clip = (text, most) => String(text ?? "").slice(0, most);

/// One of Reddit's inbox things as the desk keeps it.
function itemOf(thing) {
  const d = thing?.data || {};
  if (!d.name || !d.created_utc) return null;
  if (thing.kind === "t4") {
    return { external_id: d.name, kind: "message", detail: "message", author: clip(d.author, 100) || null,
      subject: clip(d.subject, 300) || null, body: clip(d.body, 10000), url: `${REDDIT}/message/messages/${d.id}`,
      community: null, thread: null, made_at: iso(d.created_utc), unread: d.new === true };
  }
  const type = String(d.type || String(d.subject || "").replace(/\s+/g, "_"));
  return { external_id: d.name, kind: type === "username_mention" ? "mention" : "reply", detail: clip(type, 40),
    author: clip(d.author, 100) || null, subject: clip(d.link_title, 300) || null, body: clip(d.body, 10000),
    url: d.context ? `${REDDIT}${d.context}` : null, community: clip(d.subreddit, 100) || null,
    thread: clip(d.link_title, 300) || null, made_at: iso(d.created_utc), unread: d.new === true };
}

/// What came in: replies, mentions of the account, messages. Newest first.
export async function inbox(session) {
  const got = await ask(session, "/message/inbox?limit=100");
  return (got?.data?.children || []).map(itemOf).filter(Boolean);
}

/// Posts across Reddit that name the site, not the account's own.
export async function mentions(session) {
  const found = new Map();
  for (const q of SEARCHES) {
    const got = await ask(session, `/search?${new URLSearchParams({ q, sort: "new", t: "month", type: "link", limit: "25" })}`);
    for (const child of got?.data?.children || []) {
      const d = child?.data || {};
      if (child.kind !== "t3" || !d.name || found.has(d.name) || String(d.author) === session.handle) continue;
      found.set(d.name, { external_id: d.name, kind: "mention", detail: "search", author: clip(d.author, 100) || null,
        subject: clip(d.title, 300) || null, body: clip(d.selftext, 10000), url: `${REDDIT}${d.permalink}`,
        community: clip(d.subreddit, 100) || null, thread: clip(d.title, 300) || null, made_at: iso(d.created_utc),
        unread: true });
    }
  }
  return [...found.values()];
}

/// A community's rules and what it says above its submit box:
/// {rules: [{title, words}], about: {title, members, takes, submit_text}}, or
/// null when there is no such community (or it is private or banned).
export async function rulesOf(session, community) {
  const [rules, about] = await Promise.all([ask(session, `/r/${community}/about/rules`), ask(session, `/r/${community}/about`)]);
  if (!rules && !about) return null;
  const a = about?.data || {};
  return {
    rules: (rules?.rules || []).map((one) => ({ title: clip(one.short_name, 200), words: clip(one.description, 2000),
      applies: one.kind === "link" ? "posts" : one.kind === "comment" ? "comments" : "both" })),
    site: (rules?.site_rules || []).map((one) => clip(one, 200)),
    about: { title: clip(a.title, 300) || null, members: Number.isFinite(a.subscribers) ? a.subscribers : null,
      takes: a.submission_type || null, submit_text: clip(a.submit_text, 4000) || null },
  };
}

/// Each sent thing's score and comments now: [{external_id, score, comments, ratio}].
export async function results(session, ids) {
  const out = [];
  for (let at = 0; at < ids.length; at += 100) {
    const got = await ask(session, `/api/info?id=${ids.slice(at, at + 100).join(",")}`);
    for (const child of got?.data?.children || []) {
      const d = child?.data || {};
      if (!d.name) continue;
      out.push({ external_id: d.name, score: Number.isFinite(d.score) ? d.score : null,
        comments: Number.isFinite(d.num_comments) ? d.num_comments : null,
        ratio: Number.isFinite(d.upvote_ratio) ? d.upvote_ratio : null });
    }
  }
  return out;
}

/// Reddit's errors in a form's answer, as words.
function refusedBy(answer) {
  const errors = answer?.json?.errors;
  if (!Array.isArray(errors) || errors.length === 0) return "";
  return errors.map((one) => (Array.isArray(one) ? `${one[0]}: ${one[1]}` : String(one))).join("; ").slice(0, 300);
}

/// [words] sent as the connected account: a post to its community, or a
/// reply to the item it answers. {external_id, url}. Called only for a send
/// the owner pressed (api/_social.js).
export async function send(session, words) {
  if (words.kind === "post") {
    const form = { sr: words.community, title: words.title, resubmit: "true", sendreplies: "true",
      ...(words.link && !words.body ? { kind: "link", url: words.link } : { kind: "self", text: words.body }) };
    const answer = await ask(session, "/api/submit", { method: "POST", form });
    const refused = refusedBy(answer);
    if (refused || !answer?.json?.data?.name) throw new SocialRefusal(`Reddit did not take the post: ${refused || "no answer"}.`, 409);
    return { external_id: answer.json.data.name, url: answer.json.data.url };
  }
  const answer = await ask(session, "/api/comment", { method: "POST", form: { thing_id: words.parent, text: words.body } });
  const refused = refusedBy(answer);
  const thing = answer?.json?.data?.things?.[0]?.data;
  if (refused || !thing?.name) throw new SocialRefusal(`Reddit did not take the reply: ${refused || "no answer"}.`, 409);
  const url = thing.permalink ? `${REDDIT}${thing.permalink}` : `${REDDIT}/message/messages/${thing.id}`;
  return { external_id: thing.name, url };
}

/// Reddit's own submit page with [words] in it, for the owner to press Post:
/// how a post leaves by hand.
export function handOff(words) {
  const asked = new URLSearchParams({ title: words.title });
  if (words.link && !words.body) asked.set("url", words.link);
  else {
    asked.set("selftext", "true");
    asked.set("text", words.body);
  }
  return `${REDDIT}/r/${words.community}/submit?${asked}`;
}

/// The thing a Reddit address names (a post's /comments/<id>/, a comment
/// after it): its full name, t3_ or t1_, or null.
export function thingOf(url) {
  const at = /^https:\/\/(?:www\.|old\.|new\.)?reddit\.com\/r\/[A-Za-z0-9_]{2,21}\/comments\/([a-z0-9]{1,13})(?:\/[^/?#]*(?:\/([a-z0-9]{1,13}))?)?\/?(?:[?#].*)?$/
    .exec(String(url || ""));
  if (!at) return null;
  return at[2] ? `t1_${at[2]}` : `t3_${at[1]}`;
}

export const reddit = {
  id: "reddit",
  name: "Reddit",
  env: ["REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET"],
  // How long Reddit lets each part be (a title 300, a post or comment 40,000).
  most: { title: 300, body: 40000 },
  where: "community",
  appOf, authorizeUrl, exchange, refresh, revoke, me, inbox, mentions, rulesOf, results, send, handOff, thingOf,
};
