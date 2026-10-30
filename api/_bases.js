// What a model is based on (2026-10-30, docs/SOCIAL.md section 7, item 5,
// supabase/model_bases.sql). api/share.js answers the requests with these.
//
//   GET  ?op=bases&id=X           what model X is based on, as its page says
//                                 it; with a session, whether it is the
//                                 caller's to change (mine), never kept
//   POST ?op=bases                (session) {model, bases}: its designer's
//                                 list, whole, at most three, [] for none:
//                                 {how, set} a LEGO set by its number, or
//                                 {how, url, title, author?, licence?} a
//                                 work elsewhere; how is alternate (built
//                                 from a set's parts), changed or inspired
//   GET  ?op=set_based&set=N      the models in the gallery based on set N,
//                                 as gallery cards, for its page
//                                 (/library/set/N); with tests=1, test
//                                 models too
//
// A remix names the model it was copied from, when that was shared here;
// this credits what a remix line cannot: a set built from or changed, and
// work found elsewhere, by its own link, author and licence. The set is
// checked against the catalogue (api/_sets.js), so its line links its page
// here; a work elsewhere is said as its designer wrote it, its link marked
// as theirs (rel="nofollow ugc"). The database says who may change a list
// (model_bases_put): the model's own designer, 13 or over, not taken out of
// the gallery.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { TESTS_CACHE, Unacceptable, cardOf, testsAsked } from "./_directory.js";
// The words of a line, drawn the same on the page and by its dialog.
import { HOWS } from "./_card.js";
import { namesTrouble } from "./_names.js";
import { SET_NUMBER, catalogSet } from "./_sets.js";

const ID = /^[A-Za-z0-9]{10}$/;
const MOST = 3;
/// What a set's list of models based on it may be kept for.
const LIST_CACHE = "public, max-age=0, s-maxage=60, stale-while-revalidate=60";

const missing = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const plain = (text, most) => String(text ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
  .slice(0, most);

// ---------------------------------------------------------------------------
// Pure: what a list says, and what a designer may send.

/// The rows of model_bases_of, as a page and the model's answer say them:
/// [{how, set, name, href}] for a set (its name from the catalogue, null
/// for one it no longer has), [{how, url, name, author, licence, href}]
/// for a work elsewhere.
export function basesSaid(rows, setOf = catalogSet) {
  return (Array.isArray(rows) ? rows : []).filter((row) => row && HOWS[row.how]).map((row) => {
    if (row.set_number) {
      const entry = setOf(String(row.set_number));
      const set = entry ? entry.set : String(row.set_number);
      return { how: row.how, set, name: entry ? entry.name : null, href: `/library/set/${encodeURIComponent(set)}` };
    }
    return { how: row.how, url: String(row.url), name: String(row.title || ""), author: row.author || null,
      licence: row.licence || null, href: String(row.url) };
  });
}

/// [given], a designer's list as sent, made what the database keeps: at
/// most three, each a set the catalogue has or an https link with a title;
/// an alternate build only of a set. Throws Unacceptable in words for the
/// person who typed it.
export function basesAsked(given, setOf = catalogSet) {
  if (!Array.isArray(given)) throw new Unacceptable("say what it is based on as a list, [] for nothing");
  if (given.length > MOST) throw new Unacceptable(`At most ${MOST}: say the ones it owes most to.`);
  return given.map((one, at) => {
    const which = given.length > 1 ? ` (the ${["first", "second", "third"][at]})` : "";
    if (!one || typeof one !== "object" || !HOWS[one.how]) {
      throw new Unacceptable(`Say how it is based on it${which}: an alternate build, changed from it, or inspired by it.`);
    }
    const set = plain(one.set, 40);
    const url = plain(one.url, 400);
    if (Boolean(set) === Boolean(url)) throw new Unacceptable(`Give a set's number or a link${which}, one of them.`);
    if (set) {
      const entry = SET_NUMBER.test(set) ? setOf(set) : null;
      if (!entry) throw new Unacceptable(`There is no set ${set} in the library${which}: give its number as on its box, like 6080-1.`);
      return { how: one.how, set: entry.set };
    }
    if (one.how === "alternate") {
      throw new Unacceptable(`An alternate build is built from a set's parts${which}: give the set, or say changed from it or inspired by it.`);
    }
    let address;
    try {
      address = new URL(url);
    } catch {
      address = null;
    }
    if (!address || address.protocol !== "https:" || !address.hostname.includes(".") || address.username || address.password
      || address.href.length > 300) {
      throw new Unacceptable(`Give the work's own address${which}, starting https://, like https://example.org/castle.`);
    }
    const title = plain(one.title, 120);
    if (!title) throw new Unacceptable(`Give the work's title${which}, as its page names it.`);
    const author = plain(one.author, 80) || null;
    const licence = plain(one.licence, 60) || null;
    const trouble = namesTrouble({ "Its title": [title, "words"], "Its author": [author, "words"], "Its licence": [licence, "words"] });
    if (trouble) throw new Unacceptable(`${trouble}${which}.`);
    return { how: one.how, url: address.href, title, author, licence };
  });
}

// ---------------------------------------------------------------------------
// The database.

/// What model [id] is based on, said; null before model_bases.sql.
export async function basesOf(id, setOf = catalogSet) {
  try {
    return basesSaid(await db("rpc/model_bases_of", { method: "POST", body: { model_ids: [id] } }), setOf);
  } catch (trouble) {
    if (missing(trouble)) return null;
    throw trouble;
  }
}

const REFUSED = {
  no_model: [404, "There is no shared model at that link."],
  not_yours: [403, "Only its designer says what it is based on."],
  under_13: [403, "What a model is based on is shown in public, which is for accounts 13 or over."],
  barred: [403, "This model is out of the gallery, so nothing more is shown of it."],
  too_many: [400, `At most ${MOST}: say the ones it owes most to.`],
  not_a_base: [400, "say what it is based on as a list, [] for nothing"],
};

// ---------------------------------------------------------------------------
// The requests.

/// GET ?op=bases&id=X.
export async function bases(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const id = String(request.query?.id || "");
  if (!ID.test(id)) throw new Unacceptable("say which model, by its id");
  const [said, own] = await Promise.all([basesOf(id),
    db(`shared_models?id=eq.${id}&published=is.true&select=owner`).then((rows) => rows[0] || null)]);
  if (!own) throw new Unacceptable("There is no shared model at that link.", 404);
  let mine = false;
  if (bearer(request)) mine = (await verify(bearer(request), request)).sub === own.owner;
  // Before the file there is nowhere to keep a list: not offered (ready).
  return response.status(200).json({ bases: said || [], mine, ready: said !== null });
}

/// POST ?op=bases {model, bases}.
export async function basesPut(request, response) {
  const claims = await verify(bearer(request), request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const model = String(body.model || "");
  if (!ID.test(model)) throw new Unacceptable("say which model, by its id");
  const kept = basesAsked(body.bases);
  let said;
  try {
    said = await db("rpc/model_bases_put", { method: "POST", body: { account: claims.sub, model_id: model, bases: kept } });
  } catch (trouble) {
    if (missing(trouble)) throw new Unacceptable("Saying what a model is based on is not open yet.", 503);
    throw trouble;
  }
  if (said?.refused) {
    const [status, words] = REFUSED[said.refused] || [400, "That could not be kept."];
    throw new Unacceptable(words, status);
  }
  return response.status(200).json({ bases: (await basesOf(model)) || [] });
}

/// GET ?op=set_based&set=N: {models}, each a gallery card with [based].
export async function setBased(request, response, origin) {
  const tests = testsAsked(request.query || {});
  const entry = catalogSet(String(request.query?.set || ""));
  if (!entry) throw new Unacceptable("There is no such set in the catalogue.", 404);
  let rows = [];
  try {
    rows = await db("rpc/set_based", { method: "POST", body: { set_number: entry.set, tests } });
  } catch (trouble) {
    if (!missing(trouble)) throw trouble;
  }
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : LIST_CACHE);
  return response.status(200).json({ set: entry.set,
    models: (Array.isArray(rows) ? rows : []).map((row) => ({ ...cardOf(origin, row), based: HOWS[row.based] ? row.based : null })) });
}
