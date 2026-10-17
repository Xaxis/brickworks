// People in the directory (2026-10-13): profiles, likes, favourites and
// collections. supabase/people.sql has the tables and the functions.
//
//   GET  ?op=me                   (session) the caller's profile, if they
//                                 made one, and their collections
//   POST ?op=profile              (session) {handle, name, bio?}: made, or
//                                 changed
//   GET  ?op=profile&handle=X     a profile as anyone sees it, with its first
//                                 page of models (&page=N for more)
//   GET  ?op=page&handle=X        /u/X: the profile's page
//   GET  ?op=marks&id=X           (session) whether the caller likes and
//                                 keeps model X, and which of their lists
//                                 have it
//   POST ?op=like&id=X            (session) {on}: liked or not, and the count
//   POST ?op=favourite&id=X       (session) {on}: kept or not
//   GET  ?op=favourites&page=N    (session) what the caller keeps
//   POST ?op=collection           (session) {id?, name, description?,
//                                 public?}: a list made, or changed
//   POST ?op=uncollection&id=X    (session) a list deleted
//   POST ?op=collect              (session) {collection, model, on}
//   GET  ?op=collection&id=X      a list and a page of its models: public,
//                                 or the caller's own (&page=N)
//   GET  ?op=list_page&id=X       /c/X: a public list's page
//   POST ?op=report               {model | handle | collection, reason,
//                                 note?, contact?}: somebody saying it
//                                 should not be in the gallery, to the
//                                 site's owner (api/admin.js); signed in or
//                                 not
//
// Since the directory's moderation (supabase/moderation.sql): names are
// checked for abuse and for names somebody else owns (api/_names.js); each
// thing a person does is counted, so many an hour and a day (may_act); and
// an account the site's owner took out has no profile and no public list.
//
// A test account's models (api/share.js) are left out of a profile, a list
// and their counts unless asked for with tests=1, as the gallery's are; such
// an answer is never kept by the CDN (supabase/test_models.sql).
//
// A profile is by a name its owner chooses, never one made from their
// address, and lists only the models they listed and chose to be credited
// for: a model shared without a name is not tied to anybody here. Likes
// are counted on the model; favourites and private lists are their owner's
// alone, and a private list answers anybody else exactly as one that does
// not exist. Every word a person typed is checked here and escaped on every
// page that shows it.

import { randomBytes } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";
import {
  TESTS_CACHE, Unacceptable, cardOf, count, escapeHtml, siteChrome, testsAsked, visitorKey,
} from "./_directory.js";
import { handleTrouble, namesTrouble } from "./_names.js";

const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
export const PER_PAGE = 24;
const MOST_PAGES = 400;
export const MOST_LISTS = 50;
export const MOST_IN_A_LIST = 500;
export const MOST_FAVOURITES = 2000;
// How often a person may do each thing: [an hour, a day].
export const LIMITS = { profile: [20, 60], like: [300, 2000], favourite: [300, 2000],
  collection: [20, 60], collect: [300, 3000], report: [6, 20] };
const REASONS = new Set(["spam", "offensive", "sexual", "violent", "copied", "trademark", "personal", "other"]);

class Refusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

function newId() {
  let id = "";
  for (const byte of randomBytes(10)) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

/// One printable line, its runs of space made one, cut to its limit.
function cleanLine(given, limit) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .replace(/\s+/g, " ").trim().slice(0, limit).trim();
}

/// A few lines: printable, blank lines made one, at most [limit]; null for none.
function cleanLines(given, limit, what) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string") throw new Refusal(`${what} is text`);
  const text = given.replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .split("\n").map((line) => line.replace(/\s+/g, " ").trim()).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  if (text.length > limit) throw new Refusal(`${what} is at most ${limit} characters; that is ${text.length}`);
  return text || null;
}

async function signedIn(request) {
  const claims = await verify(bearer(request));
  return claims.sub;
}

/// Once more of [act] by [who] (an account, or a visitor's key), or 429.
async function counted(who, act) {
  const [hour, day] = LIMITS[act];
  const allowed = await db("rpc/may_act", { method: "POST", body: { actor: who, act, per_hour: hour, per_day: day } });
  if (allowed !== true) throw new Refusal(`that is a lot of that in a short time: try again in an hour`, 429);
}

/// Names checked for what the gallery does not show (api/_names.js).
function checkNames(said) {
  const trouble = namesTrouble(said);
  if (trouble) throw new Refusal(trouble);
}

/// A model anybody with its link may see: {id, listed}, or null.
async function publishedModel(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&published=is.true&barred=is.false&select=id,listed`);
  return rows[0] || null;
}

/// A profile anybody may see: none for an account the site's owner took
/// out of the gallery.
async function personOf(handle) {
  if (!HANDLE.test(handle || "")) return null;
  const rows = await db(`people?handle=eq.${handle}&select=account,handle,name,bio,created_at`);
  if (!rows[0]) return null;
  const barred = await db("rpc/is_barred", { method: "POST", body: { account: rows[0].account } });
  return barred === true ? null : rows[0];
}

function pageOf(query) {
  const page = Number(query.page ?? 1);
  if (!Number.isInteger(page) || page < 1 || page > MOST_PAGES) {
    throw new Refusal(`page is a whole number from 1 to ${MOST_PAGES}`);
  }
  return page;
}

/// A page of models from directory_models, as cards.
async function models(origin, asked, page) {
  const rows = await db("rpc/directory_models", { method: "POST",
    body: { query: { ...asked, size: PER_PAGE + 1, skip: (page - 1) * PER_PAGE } } });
  return { page, per_page: PER_PAGE, more: rows.length > PER_PAGE,
    models: rows.slice(0, PER_PAGE).map((row) => cardOf(origin, row)) };
}

// ---------------------------------------------------------------------------
// Profiles.

async function me(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  const [people, lists] = await Promise.all([
    db(`people?account=eq.${account}&select=handle,name,bio,created_at`),
    db(`model_collections?owner=eq.${account}&select=id,name,description,public,updated_at&order=updated_at.desc`),
  ]);
  const counts = await Promise.all(lists.map((list) =>
    db("rpc/collection_count", { method: "POST", body: { list: list.id, private: true } })));
  return response.status(200).json({
    profile: people[0] || null,
    collections: lists.map((list, at) => ({ ...list, count: Number(counts[at]) || 0 })),
  });
}

async function saveProfile(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const handle = String(body.handle ?? "").trim().toLowerCase();
  if (!HANDLE.test(handle) || handle.includes("--")) {
    throw new Refusal("a handle is 3 to 24 letters, digits and single hyphens, starting and ending "
      + "with a letter or a digit");
  }
  const handleSaid = handleTrouble(handle);
  if (handleSaid) throw new Refusal(handleSaid, 409);
  const name = cleanLine(body.name, 40);
  if (!name) throw new Refusal("give the name to show on your profile: whatever you like to be called here");
  const bio = cleanLines(body.bio, 300, "what you say about yourself");
  checkNames({ "That name": [name, "name"], "What you say about yourself": [bio, "words"] });
  await counted(account, "profile");
  const now = new Date().toISOString();
  try {
    const rows = await db("people?on_conflict=account", { method: "POST",
      body: { account, handle, name, bio, updated_at: now },
      prefer: "resolution=merge-duplicates,return=representation" });
    const saved = rows[0] || {};
    return response.status(200).json({ handle: saved.handle, name: saved.name, bio: saved.bio,
      url: `${originOf(request)}/u/${saved.handle}` });
  } catch (trouble) {
    if (/: 409$/.test(trouble.message)) throw new Refusal("somebody already has that handle: choose another", 409);
    throw trouble;
  }
}

async function profile(request, response) {
  const handle = String(request.query?.handle || "").toLowerCase();
  const tests = testsAsked(request.query);
  const person = await personOf(handle);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "no-cache");
  if (!person) return response.status(404).json({ error: "nobody has that handle" });
  const origin = originOf(request);
  const [page, about] = await Promise.all([
    models(origin, { owner: person.account, tests }, pageOf(request.query || {})),
    db("rpc/profile_page", { method: "POST", body: { wanted: handle, tests } }),
  ]);
  return response.status(200).json({ handle: person.handle, name: person.name, bio: person.bio,
    since: person.created_at, models_count: about?.models ?? 0, likes: about?.likes ?? 0,
    collections: about?.collections ?? [], url: `${origin}/u/${person.handle}`, ...page });
}

// ---------------------------------------------------------------------------
// Likes, favourites and lists.

async function marks(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Refusal("name a link: ?id=<ten characters>");
  const [liked, kept, lists, holding] = await Promise.all([
    db(`model_likes?model=eq.${id}&account=eq.${account}&select=model`),
    db(`model_favourites?model=eq.${id}&account=eq.${account}&select=model`),
    db(`model_collections?owner=eq.${account}&select=id,name,public&order=updated_at.desc`),
    db(`model_collection_items?model=eq.${id}&select=collection`),
  ]);
  const has = new Set(holding.map((row) => row.collection));
  return response.status(200).json({ liked: liked.length > 0, favourite: kept.length > 0,
    collections: lists.map((list) => ({ ...list, has: has.has(list.id) })) });
}

async function toggle(request, response, table) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  const on = request.body?.on;
  if (typeof on !== "boolean") throw new Refusal("say on: true or on: false");
  if (!(await publishedModel(id))) throw new Refusal("there is no shared model at that link", 404);
  await counted(account, table === "model_likes" ? "like" : "favourite");
  if (on) {
    if (table === "model_favourites") {
      const kept = await db(`model_favourites?account=eq.${account}&select=model&limit=${MOST_FAVOURITES + 1}`);
      if (kept.length >= MOST_FAVOURITES) throw new Refusal(`you keep ${MOST_FAVOURITES} already: let one go first`, 409);
    }
    await db(`${table}?on_conflict=model,account`, { method: "POST", body: { model: id, account },
      prefer: "resolution=ignore-duplicates" });
  } else {
    await db(`${table}?model=eq.${id}&account=eq.${account}`, { method: "DELETE" });
  }
  if (table === "model_likes") {
    const stats = await db(`model_stats?model=eq.${id}&select=likes`);
    return response.status(200).json({ id, liked: on, likes: Number(stats[0]?.likes) || 0 });
  }
  return response.status(200).json({ id, favourite: on });
}

async function favourites(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signedIn(request);
  return response.status(200).json(await models(originOf(request),
    { favourites: account, private: true, sort: "added" }, pageOf(request.query || {})));
}

/// A list, as its owner or anybody may see it: {id, name, description,
/// public, owner, by, count, all}, or null when the asker may not. Its
/// counts have test models in them only when asked for (tests).
async function listFor(id, account, tests = false) {
  if (!ID.test(id || "")) return null;
  const list = await db("rpc/collection_page", { method: "POST", body: { list: id, tests } });
  if (!list || typeof list !== "object") return null;
  if (!list.public && list.owner !== account) return null;
  return list;
}

async function ownList(id, account) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`model_collections?id=eq.${id}&owner=eq.${account}&select=id,name,public`);
  return rows[0] || null;
}

async function saveList(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const name = cleanLine(body.name, 80);
  if (!name) throw new Refusal("give the list a name");
  const description = cleanLines(body.description, 500, "a list's description");
  if (body.public !== undefined && typeof body.public !== "boolean") throw new Refusal("public is true or false");
  checkNames({ "The collection's name": [name, "name"], "Its description": [description, "words"] });
  await counted(account, "collection");
  const now = new Date().toISOString();
  let id = body.id === undefined || body.id === null || body.id === "" ? "" : String(body.id);
  if (id) {
    if (!(await ownList(id, account))) throw new Refusal("there is no list of yours at that id", 404);
    const changed = { name, description, updated_at: now };
    if (body.public !== undefined) changed.public = body.public;
    await db(`model_collections?id=eq.${id}&owner=eq.${account}`, { method: "PATCH", body: changed });
  } else {
    const lists = await db(`model_collections?owner=eq.${account}&select=id&limit=${MOST_LISTS + 1}`);
    if (lists.length >= MOST_LISTS) throw new Refusal(`you have ${MOST_LISTS} lists already: delete one first`, 409);
    id = newId();
    await db("model_collections", { method: "POST",
      body: { id, owner: account, name, description, public: body.public === true, updated_at: now } });
  }
  const saved = await listFor(id, account);
  return response.status(200).json({ id, name: saved.name, description: saved.description,
    public: saved.public, count: saved.all, url: `${originOf(request)}/c/${id}` });
}

async function dropList(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const id = String(request.query?.id || "");
  if (!(await ownList(id, account))) throw new Refusal("there is no list of yours at that id", 404);
  await db(`model_collections?id=eq.${id}&owner=eq.${account}`, { method: "DELETE" });
  return response.status(200).json({ id, deleted: true });
}

async function collect(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const list = await ownList(String(body.collection || ""), account);
  if (!list) throw new Refusal("there is no list of yours at that id", 404);
  const model = String(body.model || "");
  if (typeof body.on !== "boolean") throw new Refusal("say on: true or on: false");
  await counted(account, "collect");
  if (body.on) {
    if (!(await publishedModel(model))) throw new Refusal("there is no shared model at that link", 404);
    const held = await db(`model_collection_items?collection=eq.${list.id}&select=model&limit=${MOST_IN_A_LIST + 1}`);
    if (held.length >= MOST_IN_A_LIST) throw new Refusal(`a list holds ${MOST_IN_A_LIST} models at most`, 409);
    await db("model_collection_items?on_conflict=collection,model", { method: "POST",
      body: { collection: list.id, model }, prefer: "resolution=ignore-duplicates" });
  } else {
    if (!ID.test(model)) throw new Refusal("name a model by its link's id");
    await db(`model_collection_items?collection=eq.${list.id}&model=eq.${model}`, { method: "DELETE" });
  }
  await db(`model_collections?id=eq.${list.id}`, { method: "PATCH", body: { updated_at: new Date().toISOString() } });
  return response.status(200).json({ collection: list.id, model, has: body.on });
}

/// A list and a page of it. Its owner, signed in, sees every published
/// model in it; anybody else, if it is public, the listed ones.
async function collection(request, response) {
  let account = null;
  if (bearer(request)) account = await signedIn(request);
  const tests = testsAsked(request.query);
  response.setHeader("Cache-Control", account ? "private, no-store" : tests ? TESTS_CACHE : "no-cache");
  const id = String(request.query?.id || "");
  const list = await listFor(id, account, tests);
  if (!list) return response.status(404).json({ error: "there is no list at that id" });
  const mine = list.owner === account;
  const origin = originOf(request);
  const page = await models(origin, { collection: id, private: mine, sort: "added", tests },
    pageOf(request.query || {}));
  return response.status(200).json({ id, name: list.name, description: list.description, public: list.public,
    by: list.by, count: mine ? list.all : list.count, mine, url: `${origin}/c/${id}`, ...page });
}

// ---------------------------------------------------------------------------
// Reports.

/// What somebody says should not be in the gallery: a model, a profile or
/// a public collection, a reason, a note and a way to reach them, kept for
/// the site's owner. Signed in or not; counted by the account, or by the
/// visitor's key for the day when there is none.
async function report(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  let account = null;
  if (bearer(request)) account = await signedIn(request);
  const named = ["model", "handle", "collection"].filter((key) => body[key] !== undefined && body[key] !== "");
  if (named.length !== 1) throw new Refusal("name one thing: a model, a profile's handle or a collection");
  const target = {};
  if (named[0] === "model") {
    if (!(await publishedModel(String(body.model)))) throw new Refusal("there is no shared model at that link", 404);
    target.model = String(body.model);
  } else if (named[0] === "handle") {
    const person = await personOf(String(body.handle).toLowerCase());
    if (!person) throw new Refusal("nobody has that handle", 404);
    target.handle = person.handle;
  } else {
    const list = await listFor(String(body.collection), account);
    if (!list) throw new Refusal("there is no list at that id", 404);
    target.collection = list.id;
  }
  const reason = String(body.reason || "");
  if (!REASONS.has(reason)) throw new Refusal(`a reason is one of ${[...REASONS].join(", ")}`);
  const note = cleanLines(body.note, 1000, "a note");
  const contact = cleanLine(body.contact, 200) || null;
  const visitor = account ? null : visitorKey(request, "report");
  await counted(account || visitor, "report");
  await db("reports", { method: "POST", body: { ...target, reason, note, contact: contact && contact.length >= 3 ? contact : null,
    reporter: account, visitor } });
  return response.status(200).json({ reported: true });
}

// ---------------------------------------------------------------------------
// The pages.

/// Its policy: itself, and the sign-in service for a report made signed in
/// (web/report.js, web/account.js).
function pageCsp() {
  let signIn = "";
  try {
    signIn = new URL(process.env.SUPABASE_URL || "").origin;
  } catch {
    signIn = "";
  }
  return "default-src 'none'; script-src 'self'; img-src 'self'; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${signIn ? ` ${signIn}` : ""}; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`;
}

function html(response, status, body, { tests = false } = {}) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", pageCsp());
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  // Kept briefly by the CDN, as a model's page is (api/share.js SHARED_CACHE);
  // never a page with test models on it.
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : "public, max-age=0, s-maxage=30, stale-while-revalidate=30");
  return response.status(status).end(body);
}

function head(origin, { title, about, url, image, robots = "" }) {
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(about)}">
${robots ? `<meta name="robots" content="${robots}">\n` : ""}${url ? `<link rel="canonical" href="${escapeHtml(url)}">\n` : ""}<meta property="og:type" content="profile">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(about)}">
${url ? `<meta property="og:url" content="${escapeHtml(url)}">\n` : ""}<meta property="og:image" content="${escapeHtml(image || `${origin}/share.png`)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(about)}">
<meta name="twitter:image" content="${escapeHtml(image || `${origin}/share.png`)}">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/report.js" type="module"></script>`;
}

/// A model's card, as the gallery draws one, made here so the page needs
/// no script to show its models.
export function cardHtml(card) {
  const picture = card.thumb ? `/m/${card.id}.webp${card.thumb.includes("?v=") ? `?v=${card.thumb.split("?v=")[1]}` : ""}`
    : card.image ? `/m/${card.id}.png` : "";
  const parts = count(card.parts, "part");
  const said = card.views ? [count(card.views, "view")] : [];
  if (card.likes) said.push(count(card.likes, "like"));
  if (card.remixes) said.push(count(card.remixes, "remix", "remixes"));
  return `<a class="model" href="/m/${card.id}" data-id="${card.id}">`
    + `<div class="frame${picture ? "" : " none"}">${picture
      ? `<img src="${escapeHtml(picture)}" alt="${escapeHtml(card.name)}" width="1200" height="630" loading="lazy" decoding="async">`
      : "No picture"}</div>`
    + `<div class="words"><b title="${escapeHtml(card.name)}">${escapeHtml(card.name)}</b>`
    + `<span>${escapeHtml(card.author ? `${parts}, by ${card.author}` : parts)}</span>`
    + `<small>${escapeHtml(said.join(" · "))}</small></div></a>`;
}

function page(origin, { title, about, url, image, robots, main }) {
  const { header, footer } = siteChrome();
  return `<!doctype html>
<html lang="en">
<head>
${head(origin, { title, about, url, image, robots })}
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
${header}
<main id="main">
${main}
</main>
${footer}
</body>
</html>`;
}

function missingPage(origin, what) {
  return page(origin, { title: `${what} — Brickworks`, about: "A page of the Brickworks gallery.", robots: "noindex",
    main: `<div class="wrap gone"><h1>${escapeHtml(what)}</h1>
  <p class="lede">The address may be mistyped, or what was here has gone.</p>
  <div class="actions"><a class="cta" href="/gallery">See the gallery</a></div></div>` });
}

const SINCE = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });

/// /u/X: a person's profile. Their name, what they said, since when, the
/// models they listed and are credited for, and their public lists.
async function profilePage(request, response) {
  const origin = originOf(request);
  const handle = String(request.query?.handle || "").toLowerCase();
  const tests = testsAsked(request.query);
  const person = await personOf(handle);
  if (!person) return html(response, 404, missingPage(origin, "Nobody here has that handle"), { tests });
  const [shown, about] = await Promise.all([
    models(origin, { owner: person.account, tests }, 1),
    db("rpc/profile_page", { method: "POST", body: { wanted: handle, tests } }),
  ]);
  const url = `${origin}/u/${person.handle}`;
  const lists = (about?.collections || []).map((list) =>
    `<li><a href="/c/${list.id}">${escapeHtml(list.name)}</a> <span>${escapeHtml(count(list.count, "model"))}</span></li>`).join("");
  const since = Date.parse(person.created_at || "");
  const first = shown.models[0];
  const main = `<div class="wrap person" data-handle="${escapeHtml(person.handle)}">
  <p class="eyebrow">Builder</p>
  <h1>${escapeHtml(person.name)}</h1>
  <p class="handle">@${escapeHtml(person.handle)}${Number.isFinite(since) ? ` · building here since ${SINCE.format(since)}` : ""}</p>
  ${person.bio ? `<p class="bio">${escapeHtml(person.bio)}</p>` : ""}
  <p class="counts"><span>${escapeHtml(count(about?.models ?? 0, "model"))} in the gallery</span>
    <span>${escapeHtml(count(about?.likes ?? 0, "like"))}</span></p>
  ${lists ? `<section aria-labelledby="lists-h"><h2 id="lists-h">Collections</h2><ul class="lists">${lists}</ul></section>` : ""}
  <section aria-labelledby="models-h"><h2 id="models-h">Models</h2>
  ${shown.models.length ? `<div class="models">${shown.models.map(cardHtml).join("")}</div>`
    : `<p class="note">Nothing in the gallery yet.</p>`}
  ${shown.more ? `<p class="note"><a href="/gallery?q=${encodeURIComponent(person.name)}">More in the gallery</a></p>` : ""}
  </section>
  <p class="note report-line"><button type="button" class="link" data-report="this profile"
    data-report-handle="${escapeHtml(person.handle)}" hidden>Report it</button> <a href="/takedown">Takedown requests</a></p>
</div>`;
  return html(response, 200, page(origin, {
    title: `${person.name} (@${person.handle}) — models built in Brickworks`,
    about: person.bio ? person.bio.replace(/\s+/g, " ").slice(0, 160)
      : `${count(about?.models ?? 0, "model")} by ${person.name}, built in Brickworks and shared in its gallery.`,
    url, image: first && first.image ? first.image : "", main,
  }), { tests });
}

/// /c/X: a public list's page. A private one is not shown here to anybody;
/// its owner sees it on /profile.
async function listPage(request, response) {
  const origin = originOf(request);
  const id = String(request.query?.id || "");
  const tests = testsAsked(request.query);
  const list = await listFor(id, null, tests);
  if (!list) return html(response, 404, missingPage(origin, "There is no collection here"), { tests });
  const shown = await models(origin, { collection: id, sort: "added", tests }, 1);
  const url = `${origin}/c/${id}`;
  const by = list.by ? `<a href="/u/${escapeHtml(list.by.handle)}">${escapeHtml(list.by.name)}</a>` : "a Brickworks builder";
  const first = shown.models[0];
  const main = `<div class="wrap person list" data-id="${id}">
  <p class="eyebrow">Collection</p>
  <h1>${escapeHtml(list.name)}</h1>
  <p class="handle">${escapeHtml(count(list.count, "model"))}, collected by ${by}</p>
  ${list.description ? `<p class="bio">${escapeHtml(list.description)}</p>` : ""}
  ${shown.models.length ? `<div class="models">${shown.models.map(cardHtml).join("")}</div>`
    : `<p class="note">Nothing in it is in the gallery just now.</p>`}
  <p class="note report-line"><button type="button" class="link" data-report="this collection"
    data-report-collection="${id}" hidden>Report it</button> <a href="/takedown">Takedown requests</a></p>
</div>`;
  return html(response, 200, page(origin, {
    title: `${list.name} — a collection in the Brickworks gallery`,
    about: list.description ? list.description.replace(/\s+/g, " ").slice(0, 160)
      : `${count(list.count, "model")} built in Brickworks, collected by ${list.by ? list.by.name : "a builder"}.`,
    url, image: first && first.image ? first.image : "", main,
  }), { tests });
}

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response.status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  response.setHeader("Access-Control-Allow-Origin", "*");
  if (!dbConfigured()) return response.status(503).json({ error: "the directory is not set up on this deployment" });
  const op = String(request.query?.op || "");
  try {
    // HEAD as GET, its body left off by the server.
    if (request.method === "GET" || request.method === "HEAD") {
      if (op === "me") return await me(request, response);
      if (op === "profile") return await profile(request, response);
      if (op === "page") return await profilePage(request, response);
      if (op === "marks") return await marks(request, response);
      if (op === "favourites") return await favourites(request, response);
      if (op === "collection") return await collection(request, response);
      if (op === "list_page") return await listPage(request, response);
    } else if (request.method === "POST") {
      if (op === "profile") return await saveProfile(request, response);
      if (op === "like") return await toggle(request, response, "model_likes");
      if (op === "favourite") return await toggle(request, response, "model_favourites");
      if (op === "collection") return await saveList(request, response);
      if (op === "uncollection") return await dropList(request, response);
      if (op === "collect") return await collect(request, response);
      if (op === "report") return await report(request, response);
    } else {
      return response.status(405).json({ error: "GET or POST" });
    }
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError || trouble instanceof Refusal || trouble instanceof Unacceptable) {
      return response.status(trouble.status).json({ error: trouble.message });
    }
    console.error("people:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}
