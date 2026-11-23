// Suggested edits on the site (suggestedit, 2026-11-23;
// supabase/suggestions.sql): a remixer sends their change back, its
// designer hears of it at once, opens it in the studio as Compare, and
// takes all of it or part; the version they publish with it names the
// remixer. What changed and how it is taken is api/_suggest.js.
//
//   POST ?op=suggest           (session) {remix, note?}: the change of the
//                              caller's remix sent to the model it came
//                              from: {id, again, counts, to, link}
//   GET  ?op=suggestion&id=N   (session) one change, for its designer (with
//                              their model's text, to take it) or its
//                              sender: {id, status, model, remix, by, note,
//                              changes, counts, mine?, theirs, ...}
//   POST ?op=suggestion_merge  (session) {id, n, take: "all" | [ids]}: the
//                              designer's newest version [n] with the
//                              changes taken, as text, to open in the
//                              studio; nothing is kept
//   POST ?op=suggestion_close  (session) {id, status: "declined" (its
//                              designer) | "withdrawn" (its sender)}
//   GET  ?op=suggestions&id=X  model X's changes: {open (its designer
//                              alone), taken (every one its versions took)}
//
// And a publish (api/share.js publishModel) that names one, {suggestion:
// {id, taken, whole}}, marks it taken by the version it makes.
//
// Each reads both files once, as it is asked, and never as a page is
// viewed: a model's page reads only the rows (suggestion_list).

import { db } from "./_db.js";
import { Unacceptable } from "./_directory.js";
import { namesTrouble } from "./_names.js";
import { publicTrouble } from "./_trust.js";
import { KINDS, MOST_LISTED, countsOf, mergeSuggestion, suggestionChanges } from "./_suggest.js";

const ID = /^[A-Za-z0-9]{10}$/;
export const MAX_NOTE = 500;
export const NOT_YET = "Sending a change back is not set up on this deployment yet.";
const NOT_THERE = /: 404$/;

/// An rpc, or undefined where its file is not applied.
async function call(name, body) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) return undefined;
    throw trouble;
  }
}

const cleanText = (given, limit) => (typeof given === "string"
  ? given.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, limit).trim() : "");

/// Where version [n] of link [id] keeps its model (api/share.js).
const fileOf = (id, n, newest) => (n === newest ? `${id}.mpd` : `${id}.v${n}.mpd`);

/// Link [id]'s newest version's number: 1 for one shared before versions.
async function newestOf(id) {
  const [one] = await db(`share_versions?model=eq.${id}&select=n&order=n.desc&limit=1`);
  return one?.n || 1;
}

/// Version [n] of link [id] as text (its newest where [n] is past it), and
/// which it was: {text, n}, or null where the file is not there.
async function versionText(getFile, id, n = null) {
  const newest = await newestOf(id);
  const which = Number.isInteger(n) && n >= 1 && n <= newest ? n : newest;
  const file = await getFile(fileOf(id, which, newest));
  return file ? { text: file.toString("utf8"), n: which } : null;
}

/// What the refusals of suggestion_send say.
const REFUSED = {
  gone: ["That model is not shared any more, so there is nobody to send it to.", 404],
  not_yours: ["Only the remix's own builder can send its change back.", 403],
  not_a_remix: ["This model is not a remix of anybody's: there is nobody to send it back to.", 422],
  own: ["This is a remix of your own model: open it and take what you want.", 422],
  blocked: ["You cannot send a change to this builder.", 403],
  pools: ["A check's model cannot be sent to a real builder's.", 422],
  hourly: ["You have sent a lot of changes in a short time: try again in an hour.", 429],
  asked: ["Say which remix, by its link.", 400],
};

/// The change of [body.remix], the caller's remix, sent to the model it
/// came from (compared with that model's newest version), with what they
/// say of it ([body.note]). {status, answer}.
export async function sendSuggestion(claims, body, { getFile, origin }) {
  const by = claims.sub;
  const remix = String(body?.remix ?? "");
  if (!ID.test(remix)) throw new Unacceptable(REFUSED.asked[0]);
  const note = cleanText(body?.note, MAX_NOTE) || null;
  const said = namesTrouble({ "What you say of it": [note, "words"] });
  if (said) throw new Unacceptable(said, 422);
  const young = await publicTrouble(by, { account: "kept" });
  if (young) throw new Unacceptable(young, 422);
  const [row] = await db(`shared_models?id=eq.${remix}&select=id,owner,name,published,remixed_from`);
  if (!row || !row.published) throw new Unacceptable(REFUSED.gone[0], 404);
  if (row.owner !== by) throw new Unacceptable(...REFUSED.not_yours);
  if (!row.remixed_from) throw new Unacceptable(...REFUSED.not_a_remix);
  const [original] = await db(`shared_models?id=eq.${row.remixed_from}&published=is.true&select=id,name,owner`);
  if (!original) throw new Unacceptable(...REFUSED.gone);
  if (original.owner === by) throw new Unacceptable(...REFUSED.own);
  const [theirs, mine] = await Promise.all([versionText(getFile, remix), versionText(getFile, original.id)]);
  if (!theirs || !mine) throw new Unacceptable(REFUSED.gone[0], 404);
  const compared = suggestionChanges(mine.text, theirs.text);
  if (compared.total === 0) {
    throw new Unacceptable(`Your remix is the same as “${original.name}” is now: there is no change to send.`, 422);
  }
  const sent = await call("suggestion_send", { p_remix: remix, p_by: by, p_remix_n: theirs.n, p_model_n: mine.n,
    p_note: note, p_counts: compared.counts });
  if (sent === undefined) throw new Unacceptable(NOT_YET, 503);
  if (sent?.refused) throw new Unacceptable(...(REFUSED[sent.refused] || REFUSED.asked));
  return { status: sent.again ? 200 : 201, answer: { id: sent.id, again: sent.again === true, counts: compared.counts,
    to: { id: original.id, name: original.name }, remix: { id: remix, n: theirs.n }, link: `${origin}/app?suggestion=${sent.id}` } };
}

/// Suggestion [id]'s row, read at this edge: null for none.
async function rowOf(id) {
  if (!Number.isSafeInteger(id) || id < 1) return null;
  const [row] = await db(`model_suggestions?id=eq.${id}&select=*`).catch((trouble) => {
    if (NOT_THERE.test(String(trouble?.message || ""))) return [];
    throw trouble;
  });
  return row || null;
}

/// Who [account] is to suggestion [row]: "designer" (it was sent to their
/// model, and the model is still theirs), "sender", or null.
async function roleOf(row, account) {
  if (!row || !account) return null;
  if (row.designer === account) {
    const [model] = await db(`shared_models?id=eq.${row.model}&select=owner`);
    if (model?.owner === account) return "designer";
  }
  return row.by_account === account ? "sender" : null;
}

const asNumber = (given) => (typeof given === "number" ? given : /^[0-9]{1,15}$/.test(String(given ?? "")) ? Number(given) : NaN);

/// One suggestion for its designer or its sender: what it changes in the
/// designer's newest version, and both texts the studio draws it from (the
/// designer's own only to them). 404 for anybody else.
export async function suggestionAnswer(claims, query, { getFile }) {
  const row = await rowOf(asNumber(query?.id));
  const role = await roleOf(row, claims?.sub);
  if (!role) throw new Unacceptable("There is no such change for you.", 404);
  const [model] = await db(`shared_models?id=eq.${row.model}&select=id,name,published`);
  const [remix] = await db(`shared_models?id=eq.${row.remix}&select=id,name,published`);
  if (!model?.published || !remix?.published) throw new Unacceptable("That change's models are not shared any more.", 404);
  const [mine, theirs] = await Promise.all([versionText(getFile, row.model), versionText(getFile, row.remix, row.remix_n)]);
  if (!mine || !theirs) throw new Unacceptable("That change's models are not shared any more.", 404);
  const compared = suggestionChanges(mine.text, theirs.text);
  const [by, designer] = await Promise.all([call("feed_who", { account: row.by_account }),
    call("feed_who", { account: row.designer })]);
  return { id: row.id, status: row.status, you: role, note: row.note, at: row.at, closed_at: row.closed_at,
    model: { id: model.id, name: model.name, n: mine.n, sent_against: row.model_n },
    remix: { id: remix.id, name: remix.name, n: theirs.n },
    by: by || null, designer: designer || null, taken: row.taken || null, taken_n: row.taken_n || null,
    changes: compared.changes, counts: compared.counts, sections: compared.sections, listed: compared.listed,
    total: compared.total,
    theirs: theirs.text, ...(role === "designer" ? { mine: mine.text } : {}) };
}

/// [given] as what to take: "all", or a list of change ids; else throws.
function takeOf(given) {
  if (given === "all") return "all";
  if (!Array.isArray(given) || given.length === 0 || given.length > MOST_LISTED
      || !given.every((one) => typeof one === "string" && one.length <= 300)) {
    throw new Unacceptable("say what to take: \"all\", or the ids of the changes ticked");
  }
  return given;
}

/// The designer's newest version with the changes they ticked taken, for
/// the studio to open: {text, taken, whole, n}. Nothing is kept: the
/// version they publish with it is (publishModel's suggestion).
export async function mergeAnswer(claims, body, { getFile }) {
  const row = await rowOf(asNumber(body?.id));
  if ((await roleOf(row, claims?.sub)) !== "designer") throw new Unacceptable("There is no such change for you.", 404);
  if (row.status !== "open") throw new Unacceptable(`That change was ${row.status} already.`, 409);
  const take = takeOf(body?.take);
  const mine = await versionText(getFile, row.model);
  const theirs = await versionText(getFile, row.remix, row.remix_n);
  if (!mine || !theirs) throw new Unacceptable("That change's models are not shared any more.", 404);
  if (Number.isInteger(body?.n) && body.n !== mine.n) {
    throw new Unacceptable("Your model has a newer version than the one open: open the change again to take it into that one.", 409);
  }
  const merged = mergeSuggestion(mine.text, theirs.text, take);
  if (merged.missing.length) {
    throw new Unacceptable("Some of the changes ticked are not in it any more: open it again.", 409);
  }
  const all = suggestionChanges(mine.text, theirs.text).total;
  const taken = countsOf(merged.taken);
  const count = KINDS.reduce((n, kind) => n + taken[kind], 0);
  return { text: merged.text, taken, whole: take === "all" || count === all, n: mine.n, model: row.model };
}

/// Suggestion [body.id] declined by its designer or withdrawn by its sender.
export async function closeAnswer(claims, body) {
  const status = String(body?.status ?? "");
  if (status !== "declined" && status !== "withdrawn") throw new Unacceptable("say declined or withdrawn");
  const closed = await call("suggestion_close", { p_id: asNumber(body?.id), p_account: claims.sub, p_status: status });
  if (closed === undefined) throw new Unacceptable(NOT_YET, 503);
  if (closed?.refused) throw new Unacceptable("There is no such change open for you.", 404);
  return { closed: true, status };
}

/// Model [id]'s changes as [viewer] may see them (suggestion_list), or
/// {open: null, taken: []} before the file.
export async function listOf(id, viewer = null) {
  if (!ID.test(id || "")) return { open: null, taken: [] };
  const listed = await call("suggestion_list", { p_model: id, viewer }).catch(() => undefined);
  if (!listed || typeof listed !== "object") return { open: null, taken: [] };
  return { open: Array.isArray(listed.open) ? listed.open : null, taken: Array.isArray(listed.taken) ? listed.taken : [] };
}

/// A publish's [given] suggestion read at the edge: {id, taken, whole}, or
/// null for none; throws on one malformed.
export function checkSuggestion(given) {
  if (given === undefined || given === null) return null;
  if (typeof given !== "object" || !Number.isSafeInteger(given.id) || given.id < 1) {
    throw new Unacceptable("suggestion is {id, taken, whole}: the change this version takes");
  }
  const taken = {};
  for (const kind of KINDS) {
    const n = given.taken?.[kind] ?? 0;
    if (!Number.isInteger(n) || n < 0 || n > 200000) throw new Unacceptable(`suggestion.taken.${kind} is a count`);
    taken[kind] = n;
  }
  if (given.whole !== undefined && typeof given.whole !== "boolean") throw new Unacceptable("suggestion.whole is true or false");
  return { id: given.id, taken, whole: given.whole === true };
}

/// Version [n] of model [id], just published by [owner], took [suggestion]
/// (checkSuggestion's): marked taken, which names its sender in the
/// model's Versions and tells them. {taken: true} or {taken: false, why};
/// never throws, so the publish is never in its way.
export async function markTaken(owner, id, n, suggestion) {
  try {
    const row = await rowOf(suggestion.id);
    if (!row || row.model !== id) return { taken: false, why: "that change was sent to another model" };
    const closed = await call("suggestion_close", { p_id: suggestion.id, p_account: owner, p_status: "taken", p_n: n,
      p_taken: suggestion.taken, p_whole: suggestion.whole });
    if (closed === undefined) return { taken: false, why: NOT_YET };
    if (closed?.refused) return { taken: false, why: "that change is not open for you" };
    return { taken: true, id: suggestion.id };
  } catch (trouble) {
    console.error("share: a change taken:", trouble.message);
    return { taken: false, why: "Brickworks could not note the change taken just now" };
  }
}
