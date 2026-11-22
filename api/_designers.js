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
//                               With supabase/designer_period.sql (insights2,
//                               2026-11-22), each model's `period` too: its
//                               views, builds, likes, saves, comments and
//                               remixes in the last 30 UTC days (today so
//                               far), the 30 before, each of the last 8
//                               weeks and in all, and `period` the days and
//                               every model's added up; null before the file.
//                               &handle=X answers {mine: false} and nothing
//                               else unless X is the caller's own profile,
//                               which is how /u/X asks without showing
//                               anybody else theirs. Never kept by the CDN.
//
// Nothing here takes an account from the request but the one its sign-in
// proves: there is no way to ask for anybody else's numbers.

import { bearer, verify } from "./_auth.js";
import { db } from "./_db.js";
import { photoUrls } from "./_card.js";
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
    by, ...photoUrls(origin, photo.id), page: `${origin}/m/${model}#photo-${photo.id}`,
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

/// What designer_period counts, each over the same UTC days
/// (supabase/designer_period.sql says what each is).
export const PERIOD_KINDS = ["views", "builds", "likes", "saves", "comments", "remixes"];
/// How many weeks it gives, the oldest first and the newest ending today.
export const WEEKS = 8;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const dayOf = (value) => (DAY.test(String(value ?? "")) ? String(value) : null);

/// One model's (or the sum's) counts of one kind, as numbers only.
function countsOf(said) {
  const weeks = Array.isArray(said?.weeks) ? said.weeks.slice(0, WEEKS).map(n) : [];
  while (weeks.length < WEEKS) weeks.unshift(0);
  return { now: n(said?.now), before: n(said?.before), ever: n(said?.ever), weeks };
}

/// designer_period's answer for the models designer_mine listed: each
/// model's counts by kind, and the days. Null when it said nothing.
function periodOf(said, models) {
  if (!said || typeof said !== "object" || !dayOf(said.today)) return null;
  const all = Object.fromEntries(PERIOD_KINDS.map((kind) => [kind, { now: 0, before: 0, ever: 0, weeks: Array(WEEKS).fill(0) }]));
  const each = {};
  for (const model of models) {
    const row = said.models?.[model.id];
    each[model.id] = Object.fromEntries(PERIOD_KINDS.map((kind) => [kind, countsOf(row?.[kind])]));
    for (const kind of PERIOD_KINDS) {
      const one = each[model.id][kind];
      const sum = all[kind];
      sum.now += one.now;
      sum.before += one.before;
      sum.ever += one.ever;
      one.weeks.forEach((value, at) => { sum.weeks[at] += value; });
    }
  }
  return { each, period: { today: dayOf(said.today), days: n(said.days) || DAYS, now_from: dayOf(said.now_from),
    before_from: dayOf(said.before_from), weeks_from: dayOf(said.weeks_from), views_from: dayOf(said.views_from),
    weeks: WEEKS, totals: all } };
}

/// designer_period for [account], or null before the file is applied.
async function periodRead(account) {
  try {
    return await db("rpc/designer_period", { method: "POST", body: { designer: account } });
  } catch (trouble) {
    if (missing(trouble)) return null;
    throw trouble;
  }
}

/// GET ?op=designs: the caller's own numbers, and nobody else's.
export async function designs(request, response, { origin }) {
  response.setHeader("Cache-Control", MINE_CACHE);
  const account = (await verify(bearer(request), request)).sub;
  const asked = request.query?.handle === undefined ? null : String(request.query.handle).toLowerCase();
  if (asked !== null && !HANDLE.test(asked)) throw new Unacceptable("handle is 3 to 24 letters, digits and hyphens");
  const person = (await db(`people?account=eq.${account}&select=handle,name`))[0] || null;
  // Asked from /u/X: only X's own owner is answered with anything.
  if (asked !== null && person?.handle !== asked) return response.status(200).json({ mine: false });
  // Both at once: the period's numbers beside the models and their photos.
  const [mine, period] = await Promise.allSettled([
    db("rpc/designer_mine", { method: "POST", body: { designer: account, days: DAYS } }),
    periodRead(account),
  ]);
  if (mine.status === "rejected") {
    if (!missing(mine.reason)) throw mine.reason;
    return response.status(200).json({ mine: true, ready: false, handle: person?.handle ?? null });
  }
  if (period.status === "rejected") throw period.reason;
  const said = mine.value;
  const models = (said?.models || []).filter((row) => ID.test(String(row?.id || ""))).map((row) => mineOf(origin, row));
  const totals = {};
  for (const kind of KINDS) {
    totals[kind] = models.reduce((sum, one) => sum + one[kind], 0);
    totals[`${kind}_ever`] = models.reduce((sum, one) => sum + one[`${kind}_ever`], 0);
  }
  const counted = periodOf(period.value, models);
  if (counted) for (const one of models) one.period = counted.each[one.id];
  return response.status(200).json({ mine: true, ready: true, handle: person?.handle ?? null,
    days: n(said?.days) || DAYS, since: said?.since ?? null, counted_from: said?.counted_from ?? null, totals,
    period: counted ? counted.period : null, models });
}
