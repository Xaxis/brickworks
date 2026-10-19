// Designers (2026-10-19, supabase/designers.sql): what a designer's models
// earned, on their page for anybody, and how each is doing for them alone.
//
//   designerOf(handle, tests)   /u/<handle>'s numbers: models in the
//                               gallery, builds finished of them, remixes,
//                               comments, Tested, likes, the photos other
//                               people posted of their builds, and each
//                               card's comments. {ready: false} before the
//                               file is applied; null for nobody shown.
//   GET ?op=designs             (session) the caller's own: each published
//                               model's last 30 days of opens, builds
//                               finished, remixes and comments, the same
//                               since it was shared, and who built it.
//                               &handle=X answers {mine: false} and nothing
//                               else unless X is the caller's own profile,
//                               which is how /u/X asks without showing
//                               anybody else theirs. Never kept by the CDN.
//
// Nothing here takes an account from the request but the one its sign-in
// proves: there is no way to ask for anybody else's numbers.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { Unacceptable } from "./_directory.js";

const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
/// How far back the designer's own numbers look.
export const DAYS = 30;
/// Every answer of ?op=designs: the caller's alone, so no cache keeps it.
export const MINE_CACHE = "private, no-store";

const missing = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const n = (value) => Number(value) || 0;

/// A photo as the pages are given it: where its picture is, and its page.
function photoOf(origin, photo, model) {
  if (!ID.test(String(photo?.id || "")) || !ID.test(String(model || ""))) return null;
  const by = photo.by && HANDLE.test(String(photo.by.handle || "")) ? { handle: photo.by.handle, name: photo.by.name } : null;
  return { id: photo.id, model, words: photo.words ?? null, width: n(photo.width), height: n(photo.height), at: photo.at,
    by, url: `${origin}/api/people?op=photo_file&id=${photo.id}`, page: `${origin}/m/${model}#photo-${photo.id}`,
    ...(photo.model_name ? { model_name: String(photo.model_name) } : {}) };
}

/// What a designer's page shows of their work, for anybody.
export async function designerOf(origin, handle, tests = false) {
  let said;
  try {
    said = await db("rpc/designer_page", { method: "POST", body: { wanted: handle, tests } });
  } catch (trouble) {
    if (missing(trouble)) return { ready: false };
    throw trouble;
  }
  if (!said) return null;
  const cards = {};
  for (const [id, card] of Object.entries(said.cards || {})) if (ID.test(id)) cards[id] = { comments: n(card?.comments) };
  return { ready: true, models: n(said.models), builds: n(said.builds), remixes: n(said.remixes),
    comments: n(said.comments), tested: n(said.tested), likes: n(said.likes), builders: n(said.builders), cards,
    photos: (said.photos || []).map((one) => photoOf(origin, one, one?.model)).filter(Boolean) };
}

/// One of the designer's own models, as their page draws it.
function mineOf(origin, row) {
  const url = `${origin}/m/${row.id}`;
  const version = Date.parse(row.updated_at || "") || 0;
  return { id: row.id, name: String(row.name ?? ""), listed: row.listed === true, credited: row.credited === true,
    test: row.test === true, parts: n(row.parts), tested: row.tested === true, url,
    image: row.has_image ? `${url}.png` : null, thumb: row.has_thumb ? `${url}.webp?v=${version.toString(36)}` : null,
    opens: n(row.opens), opens_ever: n(row.opens_ever), builds: n(row.builds), builds_ever: n(row.builds_ever),
    remixes: n(row.remixes), remixes_ever: n(row.remixes_ever), comments: n(row.comments),
    comments_ever: n(row.comments_ever), photos_count: n(row.photos_count), builders: n(row.builders),
    photos: (row.photos || []).map((one) => photoOf(origin, one, row.id)).filter(Boolean) };
}

const KINDS = ["opens", "builds", "remixes", "comments"];

/// GET ?op=designs: the caller's own numbers, and nobody else's.
export async function designs(request, response, { origin }) {
  response.setHeader("Cache-Control", MINE_CACHE);
  const account = (await verify(bearer(request))).sub;
  const asked = request.query?.handle === undefined ? null : String(request.query.handle).toLowerCase();
  if (asked !== null && !HANDLE.test(asked)) throw new Unacceptable("handle is 3 to 24 letters, digits and hyphens");
  const person = (await db(`people?account=eq.${account}&select=handle,name`))[0] || null;
  // Asked from /u/X: only X's own owner is answered with anything.
  if (asked !== null && person?.handle !== asked) return response.status(200).json({ mine: false });
  let said;
  try {
    said = await db("rpc/designer_mine", { method: "POST", body: { designer: account, days: DAYS } });
  } catch (trouble) {
    if (!missing(trouble)) throw trouble;
    return response.status(200).json({ mine: true, ready: false, handle: person?.handle ?? null });
  }
  const models = (said?.models || []).filter((row) => ID.test(String(row?.id || ""))).map((row) => mineOf(origin, row));
  const totals = {};
  for (const kind of KINDS) {
    totals[kind] = models.reduce((sum, one) => sum + one[kind], 0);
    totals[`${kind}_ever`] = models.reduce((sum, one) => sum + one[`${kind}_ever`], 0);
  }
  return response.status(200).json({ mine: true, ready: true, handle: person?.handle ?? null,
    days: n(said?.days) || DAYS, since: said?.since ?? null, counted_from: said?.counted_from ?? null, totals, models });
}
