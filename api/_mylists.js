// Your lists (lists1, 2026-11-13, docs/LISTS.md, supabase/lists.sql): the
// sets you own and want, the models you saved, and lists of your own of
// either or both, kept with one tap from any card or page that shows a set
// or a model, and shown off on your profile.
//
// One system, not three (docs/LISTS.md "What we chose"):
//
//   I own     My collection's sets (api/collection.js): the app's, its parts
//             counted wherever "you have N of its parts" is said. The
//             website changes it with that endpoint's own op, "own", held to
//             the count the person saw; it is read here only to say which
//             sets on a page are owned and to show them off.
//   I want    the person's wishlist: a list (model_collections) of kind
//             'want', made the first time they want something
//   Saved     model_favourites, as the model page's Save always kept it
//   Lists     model_collections, a person's own, now holding sets
//             (collection_sets) beside models, in their own order or the
//             last put in first
//
//   GET  ?op=keeps&sets=A,B&models=X,Y  (session) which of these the caller
//                                owns (how many), wants, saved, and which of
//                                their lists each is in; and their lists,
//                                for a card's picker (60 of each at most)
//   GET  ?op=lists               (session) the caller's lists, each with how
//                                many sets and models; how many sets they
//                                own and whether their profile shows them;
//                                how many models they saved (/lists)
//   GET  ?op=list_items&id=X     a list's items in its order as cards, a page
//                                at a time (&page=N): public, or the
//                                caller's own; id "owned", "saved" or "want"
//                                for the caller's own built-in lists
//   GET  ?op=list_csv&id=X       a list as a CSV to download: Rebrickable's
//                                set list (Set Number, Quantity, Includes
//                                Spares) for sets alone, else a row an item
//   POST ?op=keep                (session) {list, items, on, from?}: items
//                                ("set:10497-1", "model:<id>") put in a list
//                                or taken out; list an id of theirs, "want"
//                                (the wishlist, made if none) or "saved"
//                                (models alone); from: moved out of that one
//   POST ?op=list_order          (session) {id, order} the list in that order;
//                                {id, sort: "added"} back to the newest first
//   POST ?op=owned_choice        (session) {shows}: the sets they own on their
//                                profile, or not (profile_shows.owned)
//
// And for api/people.js's pages: a list's page (/c/X) draws its items with
// itemsOf, a profile its Sets tab with ownedShowcase, and the gallery's
// directory counts sets with setCounts.
//
// A set is one of the library's (api/_sets.js catalogSet), by its number
// lower-cased as My collection keeps one; a model one the gallery shows.
// Every word a person typed is theirs, checked and escaped where it is
// shown (api/people.js); nothing here makes markup.

import { randomBytes } from "node:crypto";
import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { Unacceptable, cardOf } from "./_directory.js";
import { catalogCard, catalogSet } from "./_sets.js";
import { publicTrouble } from "./_trust.js";
import { withFaces } from "./_faces.js";

const ID = /^[A-Za-z0-9]{10}$/;
/// An item of a list as the pages and the database name one.
export const KEY = /^(set:[a-z0-9][a-z0-9._]{0,24}-[0-9]{1,3}|model:[A-Za-z0-9]{10})$/;
/// How many sets one list holds; a list's models are api/people.js's
/// MOST_IN_A_LIST. A wishlist of a few hundred is a long one; caps that bite
/// are what people hate most in every tool studied (docs/LISTS.md).
export const MOST_SETS_IN_A_LIST = 2000;
export const MOST_MODELS_IN_A_LIST = 500;
export const MOST_SAVED = 2000;
/// How many of each a page asks about at once (a page of cards is 24).
const MOST_ASKED = 60;
/// How many items one change names.
export const MOST_AT_ONCE = 200;
export const ITEMS_PAGE = 24;
/// How often a person changes their lists: [an hour, a day], as collect's.
const LIMIT = [300, 3000];
/// A list's name and words when the person has not named it: the wishlist
/// is made the first time something is wanted, in their language's word.
const WISHLIST = "Wishlist";


async function signed(request) {
  if (!bearer(request)) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
  return (await verify(bearer(request), request)).sub;
}

async function maybe(request) {
  return bearer(request) ? (await verify(bearer(request), request)).sub : null;
}

/// Once more of changing lists, or 429.
async function counted(account) {
  const allowed = await db("rpc/may_act", { method: "POST",
    body: { actor: account, act: "collect", per_hour: LIMIT[0], per_day: LIMIT[1] } });
  if (allowed !== true) throw new Unacceptable("that is a lot of that in a short time: try again in an hour", 429);
}

/// A set of the library by any spelling of its number, as a list keeps it
/// ("10497-1"), or "" for none.
export function setOf(raw) {
  const entry = catalogSet(String(raw ?? "").trim());
  return entry ? entry.set.toLowerCase() : "";
}

/// "a,b,c" from a query: each through [clean], kept once, at most [most].
function listed(raw, clean, most = MOST_ASKED) {
  return [...new Set(String(raw ?? "").split(",").map((one) => clean(one.trim())).filter(Boolean))].slice(0, most);
}

/// In a PostgREST in.(...): numbers are quoted, since one holds dots.
const quoted = (values) => values.map((one) => `"${String(one).replace(/["\\]/g, "")}"`).join(",");

/// The caller's lists as a picker shows them, their wishlist first.
async function listsOf(account) {
  const rows = await db(`model_collections?owner=eq.${account}`
    + "&select=id,name,description,public,kind,sort,cover,taken_down_at,updated_at&order=updated_at.desc");
  return rows.filter((row) => ID.test(String(row.id)))
    .sort((a, b) => (a.kind === "want" ? -1 : 0) - (b.kind === "want" ? -1 : 0));
}

/// How many of each set number [account] owns, every copy from anywhere
/// (My collection's sets; a minifigure is never one): number -> count.
async function ownedCounts(account) {
  const row = (await db(`collections?owner=eq.${account}&select=sets`))[0];
  const counts = new Map();
  for (const one of Array.isArray(row?.sets) ? row.sets : []) {
    if (!one || one.fig || typeof one.set !== "string") continue;
    const key = one.set.toLowerCase();
    counts.set(key, (counts.get(key) || 0) + (Number(one.qty) || 0));
  }
  return counts;
}

/// How many sets and models are in each of [ids] (every one: its owner's
/// count): id -> {sets, models}.
export async function setCounts(ids, { models = true } = {}) {
  const wanted = ids.filter((id) => ID.test(String(id)));
  const counts = new Map(wanted.map((id) => [id, { sets: 0, models: 0 }]));
  if (!wanted.length) return counts;
  const [sets, items] = await Promise.all([
    db(`collection_sets?collection=in.(${wanted.join(",")})&select=collection`),
    models ? db(`model_collection_items?collection=in.(${wanted.join(",")})&select=collection,model`) : [],
  ]);
  for (const row of sets) if (counts.has(row.collection)) counts.get(row.collection).sets += 1;
  // A model counts while the gallery has it, as its owner sees their list.
  const ids2 = [...new Set(items.map((row) => row.model).filter((id) => ID.test(String(id))))];
  const live = ids2.length ? new Set((await db(`shared_models?id=in.(${ids2.join(",")})&published=is.true&barred=is.false&select=id`))
    .map((row) => row.id)) : new Set();
  for (const row of items) if (counts.has(row.collection) && live.has(row.model)) counts.get(row.collection).models += 1;
  return counts;
}

/// A list as the picker and /lists are given it.
function listSaid(row, counts) {
  const n = counts?.get(row.id) || { sets: 0, models: 0 };
  return { id: row.id, name: String(row.name || ""), description: row.description || null, public: row.public === true,
    kind: row.kind === "want" ? "want" : null, sort: row.sort === "manual" ? "manual" : "added", cover: row.cover || null,
    down: Boolean(row.taken_down_at), sets: n.sets, models: n.models, count: n.sets + n.models, updated_at: row.updated_at };
}

// ---------------------------------------------------------------------------
// What the caller has of what a page shows.

export async function keeps(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signed(request);
  const sets = listed(request.query?.sets, setOf);
  const models = listed(request.query?.models, (id) => (ID.test(id) ? id : ""));
  const [lists, owned, saved] = await Promise.all([
    listsOf(account),
    sets.length ? ownedCounts(account) : new Map(),
    models.length ? db(`model_favourites?account=eq.${account}&model=in.(${models.join(",")})&select=model`) : [],
  ]);
  const ids = lists.map((list) => list.id);
  const [inSets, inModels] = ids.length ? await Promise.all([
    sets.length ? db(`collection_sets?collection=in.(${ids.join(",")})&set_num=in.(${quoted(sets)})&select=collection,set_num`) : [],
    models.length ? db(`model_collection_items?collection=in.(${ids.join(",")})&model=in.(${models.join(",")})&select=collection,model`) : [],
  ]) : [[], []];
  const kept = new Set(saved.map((row) => row.model));
  const counts = await setCounts(ids, { models: false });
  return response.status(200).json({
    signed_in: true,
    lists: lists.map((row) => listSaid(row, counts)),
    want: lists.find((row) => row.kind === "want")?.id || null,
    sets: Object.fromEntries(sets.map((set) => [set, { own: owned.get(set) || 0,
      lists: inSets.filter((row) => row.set_num === set).map((row) => row.collection) }])),
    models: Object.fromEntries(models.map((id) => [id, { saved: kept.has(id),
      lists: inModels.filter((row) => row.model === id).map((row) => row.collection) }])),
  });
}

// ---------------------------------------------------------------------------
// Putting in and taking out.

/// [account]'s wishlist's id, made now when [make] and there is none.
async function wishlistOf(account, make = false, name = "") {
  const found = (await db(`model_collections?owner=eq.${account}&kind=eq.want&select=id`))[0];
  if (found || !make) return found?.id || null;
  const id = newId();
  try {
    await db("model_collections", { method: "POST", body: { id, owner: account, name: cleanName(name) || WISHLIST,
      public: false, kind: "want", updated_at: new Date().toISOString() } });
    return id;
  } catch (trouble) {
    // Made by another request a moment ago (model_collections_one_want).
    if (!/: 409$/.test(String(trouble?.message || ""))) throw trouble;
    return (await db(`model_collections?owner=eq.${account}&kind=eq.want&select=id`))[0]?.id || null;
  }
}

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
function newId() {
  let id = "";
  for (const byte of randomBytes(10)) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

/// A wishlist's name in the person's language: one printable line.
const cleanName = (given) => (typeof given === "string"
  ? given.replace(/[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 80).trim() : "");

/// The items a change names: each a KEY, a set the library has, kept once.
function keysOf(given) {
  if (!Array.isArray(given) || given.length === 0) throw new Unacceptable("name what to put in or take out: items");
  if (given.length > MOST_AT_ONCE) throw new Unacceptable(`one change is at most ${MOST_AT_ONCE} items`);
  const out = [];
  for (const raw of given) {
    const text = String(raw ?? "");
    if (text.startsWith("set:")) {
      const set = setOf(text.slice(4));
      if (!set) throw new Unacceptable(`“${text.slice(4, 40)}” is not a set in the library`);
      out.push(`set:${set}`);
    } else if (KEY.test(text)) {
      out.push(text);
    } else {
      throw new Unacceptable(`“${text.slice(0, 40)}” is not a set or a model`);
    }
  }
  return [...new Set(out)];
}

/// One of [account]'s lists, by id, or null.
async function ownList(id, account) {
  if (!ID.test(String(id || ""))) return null;
  return (await db(`model_collections?id=eq.${id}&owner=eq.${account}&select=id,name,public,kind,sort`))[0] || null;
}

export async function keep(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signed(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  if (typeof body.on !== "boolean") throw new Unacceptable("say on: true or on: false");
  const items = keysOf(body.items);
  const sets = items.filter((key) => key.startsWith("set:")).map((key) => key.slice(4));
  const models = items.filter((key) => key.startsWith("model:")).map((key) => key.slice(6));
  await counted(account);
  if (body.list === "saved") {
    if (sets.length) throw new Unacceptable("Saved keeps models; a set is owned, wanted or in a list");
    await keepSaved(account, models, body.on);
    return response.status(200).json({ list: "saved", items, on: body.on });
  }
  const list = body.list === "want"
    ? await ownList(await wishlistOf(account, body.on, body.name), account)
    : await ownList(body.list, account);
  // Nothing wanted yet and nothing to take out: so already.
  if (!list && body.list === "want" && !body.on) return response.status(200).json({ list: null, items, on: false });
  if (!list) throw new Unacceptable("there is no list of yours at that id", 404);
  if (body.on) await putIn(list, sets, models);
  else await takeOut(list.id, sets, models);
  // Moved: out of the list it came from, once it is in this one.
  if (body.on && body.from !== undefined && body.from !== null && body.from !== "") {
    const from = body.from === "want" ? await ownList(await wishlistOf(account), account) : await ownList(body.from, account);
    if (from && from.id !== list.id) await takeOut(from.id, sets, models);
  }
  await db(`model_collections?id=eq.${list.id}`, { method: "PATCH", body: { updated_at: new Date().toISOString() } });
  const counts = await setCounts([list.id]);
  return response.status(200).json({ list: listSaid(list, counts), items, on: body.on });
}

async function keepSaved(account, models, on) {
  if (!models.length) return;
  if (!on) {
    await db(`model_favourites?account=eq.${account}&model=in.(${models.join(",")})`, { method: "DELETE" });
    return;
  }
  const shown = await db(`shared_models?id=in.(${models.join(",")})&published=is.true&barred=is.false&select=id`);
  if (shown.length !== models.length) throw new Unacceptable("there is no shared model at that link", 404);
  const kept = await db(`model_favourites?account=eq.${account}&select=model&limit=${MOST_SAVED + 1}`);
  const have = new Set(kept.map((row) => row.model));
  if (have.size + models.filter((id) => !have.has(id)).length > MOST_SAVED) {
    throw new Unacceptable(`you keep ${MOST_SAVED} already: let one go first`, 409);
  }
  await db("model_favourites?on_conflict=model,account", { method: "POST",
    body: models.map((model) => ({ model, account })), prefer: "resolution=ignore-duplicates" });
}

/// [sets] and [models] into [list], each once: at the end of a list in its
/// owner's order, else as the newest.
async function putIn(list, sets, models) {
  const [heldSets, heldModels] = await Promise.all([
    sets.length ? db(`collection_sets?collection=eq.${list.id}&select=set_num,position`) : [],
    models.length ? db(`model_collection_items?collection=eq.${list.id}&select=model,position`) : [],
  ]);
  const newSets = sets.filter((set) => !heldSets.some((row) => row.set_num === set));
  const newModels = models.filter((id) => !heldModels.some((row) => row.model === id));
  if (heldSets.length + newSets.length > MOST_SETS_IN_A_LIST) throw new Unacceptable(`a list holds ${MOST_SETS_IN_A_LIST} sets at most`, 409);
  if (heldModels.length + newModels.length > MOST_MODELS_IN_A_LIST) {
    throw new Unacceptable(`a list holds ${MOST_MODELS_IN_A_LIST} models at most`, 409);
  }
  if (newModels.length) {
    const shown = await db(`shared_models?id=in.(${newModels.join(",")})&published=is.true&barred=is.false&select=id`);
    if (shown.length !== newModels.length) throw new Unacceptable("there is no shared model at that link", 404);
  }
  let next = list.sort === "manual"
    ? 1 + Math.max(-1, ...[...heldSets, ...heldModels].map((row) => (Number.isInteger(row.position) ? row.position : -1)))
    : null;
  const place = () => (next === null ? {} : { position: next++ });
  if (newSets.length) {
    await db("collection_sets?on_conflict=collection,set_num", { method: "POST",
      body: newSets.map((set_num) => ({ collection: list.id, set_num, ...place() })), prefer: "resolution=ignore-duplicates" });
  }
  if (newModels.length) {
    await db("model_collection_items?on_conflict=collection,model", { method: "POST",
      body: newModels.map((model) => ({ collection: list.id, model, ...place() })), prefer: "resolution=ignore-duplicates" });
  }
}

async function takeOut(id, sets, models) {
  await Promise.all([
    sets.length ? db(`collection_sets?collection=eq.${id}&set_num=in.(${quoted(sets)})`, { method: "DELETE" }) : null,
    models.length ? db(`model_collection_items?collection=eq.${id}&model=in.(${models.join(",")})`, { method: "DELETE" }) : null,
  ]);
}

export async function listOrder(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signed(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const list = await ownList(body.id, account);
  if (!list) throw new Unacceptable("there is no list of yours at that id", 404);
  await counted(account);
  if (body.sort === "added") {
    await db(`model_collections?id=eq.${list.id}`, { method: "PATCH", body: { sort: "added", updated_at: new Date().toISOString() } });
    return response.status(200).json({ id: list.id, sort: "added" });
  }
  if (!Array.isArray(body.order) || body.order.length > MOST_SETS_IN_A_LIST + MOST_MODELS_IN_A_LIST) {
    throw new Unacceptable("say the order: every item of the list, first first");
  }
  const order = [...new Set(body.order.map(String).filter((key) => KEY.test(key)))];
  const placed = await db("rpc/list_place", { method: "POST", body: { list: list.id, keys: order } });
  return response.status(200).json({ id: list.id, sort: "manual", placed: Number(placed) || 0 });
}

// ---------------------------------------------------------------------------
// The sets you own, on your profile.

export async function ownedChoice(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const account = await signed(request);
  const shows = request.body?.shows;
  if (typeof shows !== "boolean") throw new Unacceptable("say shows: true or shows: false");
  const person = (await db(`people?account=eq.${account}&select=handle`))[0];
  if (shows && !person) throw new Unacceptable("make your profile first: a name and a handle", 409);
  if (shows) {
    const young = await publicTrouble(account, { profile: true });
    if (young) throw new Unacceptable(young, 422);
  }
  await counted(account);
  await db("profile_shows?on_conflict=account", { method: "POST",
    body: { account, owned: shows, updated_at: new Date().toISOString() }, prefer: "resolution=merge-duplicates" });
  return response.status(200).json({ shows, url: person ? `/u/${person.handle}?tab=sets` : null });
}

/// Whether [account] chose to show the sets they own: false before
/// lists.sql (no such column) as when they did not.
export async function ownedShown(account) {
  try {
    return (await db(`profile_shows?account=eq.${account}&select=owned`))[0]?.owned === true;
  } catch (trouble) {
    if (/: 400$/.test(String(trouble?.message || ""))) return false;
    throw trouble;
  }
}

/// The sizes a showcase filters by, a set's parts.
export const OWNED_SIZES = { small: [0, 199], medium: [200, 999], large: [1000, 2999], huge: [3000, Infinity] };
export const OWNED_SORTS = ["added", "year", "pieces", "name"];

/// The sets [account] owns as their profile shows them: what they add up
/// to, and a page of them filtered as asked: {sets (copies), unique,
/// pieces, figs, themes: [[name, n]] most first, decades: [[decade, n]],
/// total (as filtered), page, more, cards}. Each card a set's, with how
/// many they own (owned_qty). A set the library does not know (a number
/// typed in the app) is counted but not shown.
export async function ownedShowcase(account, { theme = "", decade = "", size = "", q = "", sort = "added", page = 1 } = {}) {
  const row = (await db(`collections?owner=eq.${account}&select=sets`))[0];
  const kept = new Map();
  (Array.isArray(row?.sets) ? row.sets : []).forEach((one, at) => {
    if (!one || one.fig || typeof one.set !== "string") return;
    const key = one.set.toLowerCase();
    const was = kept.get(key);
    kept.set(key, { qty: (was?.qty || 0) + (Number(one.qty) || 0), at: Math.max(was?.at ?? -1, at) });
  });
  const known = [...kept].map(([key, held]) => ({ entry: catalogSet(key), ...held })).filter((one) => one.entry);
  const themes = new Map();
  const decades = new Map();
  let sets = 0;
  let pieces = 0;
  let figs = 0;
  for (const one of known) {
    sets += one.qty;
    pieces += one.entry.parts * one.qty;
    figs += one.entry.figs * one.qty;
    const top = one.entry.theme[0] || "";
    if (top) themes.set(top, (themes.get(top) || 0) + 1);
    if (one.entry.year) decades.set(Math.floor(one.entry.year / 10) * 10, (decades.get(Math.floor(one.entry.year / 10) * 10) || 0) + 1);
  }
  const words = String(q || "").toLowerCase().split(/\s+/).filter(Boolean).slice(0, 8);
  const range = OWNED_SIZES[size];
  const shown = known.filter((one) => (!theme || one.entry.theme[0] === theme)
    && (!decade || Math.floor(one.entry.year / 10) * 10 === Number(decade))
    && (!range || (one.entry.parts >= range[0] && one.entry.parts <= range[1]))
    && words.every((word) => `${one.entry.set} ${one.entry.name}`.toLowerCase().includes(word)));
  const by = {
    added: (a, b) => b.at - a.at,
    year: (a, b) => b.entry.year - a.entry.year || b.at - a.at,
    pieces: (a, b) => b.entry.parts - a.entry.parts || b.at - a.at,
    name: (a, b) => a.entry.name.localeCompare(b.entry.name),
  }[OWNED_SORTS.includes(sort) ? sort : "added"];
  shown.sort(by);
  const start = (page - 1) * ITEMS_PAGE;
  return {
    sets, unique: known.length, pieces, figs, all: kept.size,
    themes: [...themes].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])),
    decades: [...decades].sort((a, b) => b[0] - a[0]),
    total: shown.length, page, more: shown.length > start + ITEMS_PAGE,
    cards: shown.slice(start, start + ITEMS_PAGE).map((one) => ({ ...catalogCard(one.entry), owned_qty: one.qty })),
  };
}

// ---------------------------------------------------------------------------
// A list's items.

/// A list as [account] may see it: its row with whose it is, or null (a
/// private list answers anybody else as one that does not exist; so does
/// one whose owner the site's owner took out).
export async function listShown(id, account) {
  if (!ID.test(String(id || ""))) return null;
  const row = (await db(`model_collections?id=eq.${id}`
    + "&select=id,owner,name,description,public,kind,sort,cover,taken_down_at,updated_at"))[0];
  if (!row) return null;
  if (row.owner !== account) {
    if (!row.public) return null;
    const barred = await db(`barred_accounts?account=eq.${row.owner}&select=account`);
    if (barred.length) return null;
  }
  const person = (await db(`people?account=eq.${row.owner}&select=handle,name`))[0];
  return { ...row, mine: row.owner === account, by: person ? { handle: person.handle, name: person.name } : null };
}

/// Page [page] of list [list]'s items, in its order, as cards: {total,
/// page, more, items: [{key, kind, card}]}; models while the gallery shows
/// them ([mine]: as their owner sees them), sets the library knows.
export async function itemsOf(origin, list, { mine = false, tests = false, page = 1 } = {}) {
  const all = await db("rpc/list_items", { method: "POST", body: { list: list.id, private: mine, tests } });
  const items = (Array.isArray(all) ? all : []).filter((one) => one && (one.kind === "set" ? catalogSet(one.key) : ID.test(String(one.key))));
  const start = (page - 1) * ITEMS_PAGE;
  const shown = items.slice(start, start + ITEMS_PAGE);
  const ids = shown.filter((one) => one.kind === "model").map((one) => one.key);
  const rows = ids.length ? await db("rpc/list_model_cards", { method: "POST", body: { list: list.id, models: ids, private: mine, tests } }) : [];
  const cards = new Map((await withFaces((Array.isArray(rows) ? rows : []).map((row) => cardOf(origin, row)))).map((card) => [card.id, card]));
  return {
    total: items.length, sets: items.filter((one) => one.kind === "set").length,
    models: items.filter((one) => one.kind === "model").length, page, more: items.length > start + ITEMS_PAGE,
    items: shown.map((one) => (one.kind === "set"
      ? { key: `set:${one.key}`, kind: "set", card: catalogCard(catalogSet(one.key)) }
      : { key: `model:${one.key}`, kind: "model", card: cards.get(one.key) || null })).filter((one) => one.card),
  };
}

/// Page [page] of the caller's own built-in lists: the sets they own, or
/// the models they saved, as list_items gives a list's.
async function builtIn(origin, account, which, page) {
  if (which === "owned") {
    const shown = await ownedShowcase(account, { page });
    return { id: "owned", kind: "owned", mine: true, total: shown.total, sets: shown.total, models: 0, page, more: shown.more,
      items: shown.cards.map((card) => ({ key: `set:${card.library.set.toLowerCase()}`, kind: "set", card, owned: card.owned_qty })) };
  }
  const rows = await db("rpc/directory_models", { method: "POST", body: { query: { favourites: account, private: true, sort: "added",
    size: ITEMS_PAGE + 1, skip: (page - 1) * ITEMS_PAGE } } });
  const cards = await withFaces(rows.slice(0, ITEMS_PAGE).map((row) => cardOf(origin, row)));
  const total = (await db(`model_favourites?account=eq.${account}&select=model`)).length;
  return { id: "saved", kind: "saved", mine: true, total, sets: 0, models: total, page, more: rows.length > ITEMS_PAGE,
    items: cards.map((card) => ({ key: `model:${card.id}`, kind: "model", card })) };
}

export async function listItems(request, response, { origin }) {
  const asked = String(request.query?.id || "");
  const page = Math.min(400, Math.max(1, Number.parseInt(String(request.query?.page || "1"), 10) || 1));
  const tests = String(request.query?.tests || "") === "1";
  const account = await maybe(request);
  response.setHeader("Cache-Control", "private, no-store");
  if (asked === "owned" || asked === "saved") {
    if (!account) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
    return response.status(200).json(await builtIn(origin, account, asked, page));
  }
  const id = asked === "want" ? (account ? await wishlistOf(account) : null) : asked;
  if (asked === "want" && !id) {
    if (!account) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
    return response.status(200).json({ id: null, kind: "want", mine: true, total: 0, sets: 0, models: 0, page, more: false, items: [] });
  }
  const list = await listShown(id, account);
  if (!list) throw new Unacceptable("there is no list at that id", 404);
  const shown = await itemsOf(origin, list, { mine: list.mine, tests, page });
  return response.status(200).json({ id: list.id, name: list.name, description: list.description, public: list.public,
    kind: list.kind === "want" ? "want" : null, sort: list.sort, cover: list.cover, down: Boolean(list.taken_down_at),
    mine: list.mine, by: list.by, url: `${origin}/c/${list.id}`, ...shown });
}

export async function yourLists(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const account = await signed(request);
  const [lists, owned, saved, person, shows] = await Promise.all([
    listsOf(account),
    ownedCounts(account),
    db(`model_favourites?account=eq.${account}&select=model`),
    db(`people?account=eq.${account}&select=handle`),
    ownedShown(account),
  ]);
  const counts = await setCounts(lists.map((list) => list.id));
  let copies = 0;
  let pieces = 0;
  for (const [set, n] of owned) {
    copies += n;
    pieces += (catalogSet(set)?.parts || 0) * n;
  }
  return response.status(200).json({
    lists: lists.map((row) => listSaid(row, counts)),
    owned: { sets: copies, unique: owned.size, pieces, shown: shows },
    saved: { models: saved.length },
    profile: person[0] ? { handle: person[0].handle } : null,
  });
}

// ---------------------------------------------------------------------------
// A list as a file.

/// A CSV field, quoted when it must be, and never read as a formula by a
/// spreadsheet (a name beginning =, +, - or @ gets a ' first).
function field(value) {
  let text = String(value ?? "");
  if (/^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export async function listCsv(request, response, { origin }) {
  const asked = String(request.query?.id || "");
  const account = await maybe(request);
  response.setHeader("Cache-Control", "private, no-store");
  let name;
  let sets = [];
  let models = [];
  if (asked === "owned") {
    if (!account) throw new Unacceptable("Sign in first: we email you a code, no password.", 401);
    name = "brickworks-sets-i-own";
    sets = [...(await ownedCounts(account))].map(([set, qty]) => ({ set, qty }));
  } else {
    const id = asked === "want" ? (account ? await wishlistOf(account) : null) : asked;
    const list = id ? await listShown(id, account) : null;
    if (!list) throw new Unacceptable("there is no list at that id", 404);
    name = `brickworks-${list.kind === "want" ? "wishlist" : list.id}`;
    const all = await db("rpc/list_items", { method: "POST", body: { list: list.id, private: list.mine, tests: list.mine } });
    for (const one of Array.isArray(all) ? all : []) {
      if (one.kind === "set" && catalogSet(one.key)) sets.push({ set: one.key, qty: 1 });
      else if (one.kind === "model" && ID.test(String(one.key))) models.push(one.key);
    }
  }
  const lines = [];
  if (!models.length) {
    // Rebrickable's set list, which Rebrickable, Brickset and the app import.
    lines.push("Set Number,Quantity,Includes Spares");
    for (const one of sets) lines.push([field(catalogSet(one.set)?.set || one.set), one.qty, "True"].join(","));
  } else {
    const named = new Map((await db(`shared_models?id=in.(${models.join(",")})&select=id,name`)).map((row) => [row.id, row.name]));
    lines.push("Kind,Number,Name,Link");
    for (const one of sets) {
      const entry = catalogSet(one.set);
      lines.push(["set", field(entry.set), field(entry.name), field(`${origin}/library/set/${entry.set}`)].join(","));
    }
    for (const id of models) lines.push(["model", field(id), field(named.get(id) || ""), field(`${origin}/m/${id}`)].join(","));
  }
  response.setHeader("Content-Type", "text/csv; charset=utf-8");
  response.setHeader("Content-Disposition", `attachment; filename="${name}.csv"`);
  return response.status(200).end(`${lines.join("\r\n")}\r\n`);
}
