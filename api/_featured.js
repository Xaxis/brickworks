// What the gallery's front leads with, chosen once a day by Vercel's cron
// (gallery362, 2026-10-29; supabase/gallery_crons.sql).
//
// The gallery changed only when somebody posted. Now /api/share/feature
// (api/share.js ?op=feature, tools/deploy.sh's crons) chooses, from what
// people did:
//
//   featured   today's featured model: the best of the past 30 days by
//              likes, builds finished, comments, remixes and the Tested
//              mark, with a little for being new, and none featured in the
//              past four weeks
//   pick       this week's pick, on the first run of a week (its Monday):
//              the same rules over the past seven days, none picked in the
//              past eight weeks, and never today's featured model. The
//              site's owner's own choice (api/admin.js) still wins.
//   library    today's set from the LDraw library: the theme featured
//              longest ago (or never), then of its sets the decade featured
//              longest ago, and never a set featured in the past 90 days
//
// Each choice is kept once (gallery_feature_keep): a second run on the
// same day finds it there and changes nothing, and the page reads what is
// kept, never a choice of its own. Ties are broken by a hash of the day and
// the model, so the same signals give the same choice all day and another
// one the next: nothing here is random. A run takes the cron's lock first
// (cron_begin) and is written down, however it ends (cron_end); a run that
// finds the lock held does nothing and is written down as locked.
//
// Pure but for [db], which a test gives its own: tests/test_gallery_crons.py.

/// What each signal weighs. A build finished counts most, as Top builds
/// (_directory.js SCORE) counts it; a like and a comment say less.
export const WEIGHTS = { likes: 2, builds: 3, comments: 1, remixes: 2, tested: 5 };
/// What being new adds, halved every FRESH_DAYS since it was listed.
export const NEW_BONUS = 4;
export const FRESH_DAYS = 14;
/// The signals' windows, and how long before a model or a set comes again.
export const FEATURED_DAYS = 30;
export const PICK_DAYS = 7;
export const FEATURED_GAP_DAYS = 28;
export const PICK_GAP_DAYS = 56;
export const LIBRARY_GAP_DAYS = 90;
/// How long a run may hold the lock before another may take it.
export const LEASE_SECONDS = 300;
export const JOB = "gallery_feature";
const ID = /^[A-Za-z0-9]{10}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 24 * 3600 * 1000;

/// The day [now] is in, in UTC, as the database keeps a day: "2026-10-29".
export const dayOf = (now = new Date()) => new Date(now).toISOString().slice(0, 10);

/// [day] moved by [n] days.
export const daysFrom = (day, n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY_MS).toISOString().slice(0, 10);

/// The Monday of [day]'s week, which a week's pick is kept under.
export function mondayOf(day) {
  const weekday = new Date(`${day}T00:00:00Z`).getUTCDay();
  return daysFrom(day, -((weekday + 6) % 7));
}

/// A number for [text] that is the same every time (FNV-1a): how ties fall.
export function stableHash(text) {
  let h = 0x811c9dc5;
  for (const byte of Buffer.from(String(text))) {
    h ^= byte;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}

const count = (n) => (Number.isFinite(Number(n)) && Number(n) > 0 ? Math.floor(Number(n)) : 0);

/// [signal]'s score on [day]: what people did, weighed, and what being new
/// adds. {score, activity, fresh}.
export function scoreOf(signal, day) {
  const activity = WEIGHTS.likes * count(signal.likes) + WEIGHTS.builds * count(signal.builds)
    + WEIGHTS.comments * count(signal.comments) + WEIGHTS.remixes * count(signal.remixes)
    + (signal.tested === true ? WEIGHTS.tested : 0);
  const listed = Date.parse(signal.listed_at || "");
  const age = Number.isFinite(listed) ? Math.max(0, (Date.parse(`${day}T00:00:00Z`) - listed) / DAY_MS) : Infinity;
  const fresh = Number.isFinite(age) ? NEW_BONUS * 0.5 ** (age / FRESH_DAYS) : 0;
  return { score: Math.round((activity + fresh) * 100) / 100, activity, fresh: Math.round(fresh * 100) / 100 };
}

/// The day each item was last featured, of [recent] ([{day, item}]).
function lastDays(recent) {
  const last = new Map();
  for (const row of recent || []) {
    if (!row || !DAY.test(String(row.day)) || typeof row.item !== "string") continue;
    if (!last.has(row.item) || last.get(row.item) < row.day) last.set(row.item, row.day);
  }
  return last;
}

/// The model to feature on [day] of [signals] (gallery_feature_signals'
/// rows): {item, why}, or null when the gallery has none with a picture.
/// None featured within [gapDays] before [day] (of [recent]) and none in
/// [avoid], while there is another; when every one was, the one featured
/// longest ago.
export function chooseModel(signals, { day, recent = [], gapDays = FEATURED_GAP_DAYS, avoid = new Set() }) {
  const last = lastDays(recent);
  const since = daysFrom(day, -gapDays);
  const pool = (signals || []).filter((one) => one && ID.test(String(one.id)) && one.has_image !== false
    && !avoid.has(one.id));
  const fresh = pool.filter((one) => !last.has(one.id) || last.get(one.id) < since);
  const scored = (fresh.length ? fresh : pool).map((one) => ({ one, ...scoreOf(one, day),
    last: last.get(one.id) || "", tie: stableHash(`${day}:${one.id}`) }));
  if (!scored.length) return null;
  scored.sort((a, b) => (fresh.length ? 0 : a.last.localeCompare(b.last)) || b.score - a.score || a.tie - b.tie
    || a.one.id.localeCompare(b.one.id));
  const best = scored[0];
  return {
    item: best.one.id,
    why: { score: best.score, likes: count(best.one.likes), builds: count(best.one.builds),
      comments: count(best.one.comments), remixes: count(best.one.remixes), tested: best.one.tested === true,
      ...(fresh.length ? {} : { again: true }) },
  };
}

/// A set's top theme and decade, as the library filters by them.
const themeOf = (set) => String(set.theme || "").split(" > ")[0].split(" / ")[0].trim();
const decadeOf = (set) => (Number(set.year) > 0 ? `${Math.floor(Number(set.year) / 10) * 10}s` : "");

/// The set to feature on [day] of [sets] (api/_library.js entries): {item,
/// why: {theme, decade, set, name}}, or null. The theme featured longest
/// ago (never, first), then of its sets the decade it was featured in
/// longest ago (of two never featured in, the decade the whole library was
/// featured in longest ago), and never a set featured within [gapDays]
/// before [day]: null once every set was. [recent] is what the slot
/// featured, with each day's theme and decade in its why.
export function chooseSet(sets, { day, recent = [], gapDays = LIBRARY_GAP_DAYS }) {
  const since = daysFrom(day, -gapDays);
  const shown = new Set((recent || []).filter((row) => row && String(row.day) >= since).map((row) => row.item));
  const themeLast = new Map();
  const decadeLast = new Map();
  const later = (map, key, day) => { if (key && !(map.get(key) >= day)) map.set(key, day); };
  for (const row of recent || []) {
    const why = row?.why || {};
    later(themeLast, why.theme, row.day);
    later(decadeLast, why.decade, row.day);
    later(decadeLast, why.theme && why.decade ? `${why.theme}|${why.decade}` : "", row.day);
  }
  const pool = (sets || []).filter((set) => set && typeof set.id === "string" && !shown.has(set.id)
    && themeOf(set) && decadeOf(set));
  if (!pool.length) return null;
  // Longest ago first: never ("") before any day; then by the day's hash.
  const order = (last, key) => [last.get(key) || "", stableHash(`${day}:${key}`)];
  const before = ([a, x], [b, y]) => a.localeCompare(b) || x - y;
  const theme = [...new Set(pool.map(themeOf))].sort((a, b) => before(order(themeLast, a), order(themeLast, b)))[0];
  const ofTheme = pool.filter((set) => themeOf(set) === theme);
  const decade = [...new Set(ofTheme.map(decadeOf))].sort((a, b) =>
    (decadeLast.get(`${theme}|${a}`) || "").localeCompare(decadeLast.get(`${theme}|${b}`) || "")
    || before(order(decadeLast, a), order(decadeLast, b)))[0];
  const set = ofTheme.filter((one) => decadeOf(one) === decade)
    .sort((a, b) => stableHash(`${day}:${a.id}`) - stableHash(`${day}:${b.id}`) || a.id.localeCompare(b.id))[0];
  return { item: set.id, why: { theme, decade, set: set.set || "", name: set.name || "" } };
}

/// One run of the daily cron, as [holder] (who ran it, for the log), on
/// the day [now] is in: the week's pick if the week has none, today's
/// featured model and today's set, each kept unless kept already. [db] is
/// api/_db.js's; [sets] the library's (api/_library.js librarySets). Returns
/// {outcome: done | unchanged | locked, run, day, pick, featured, library},
/// each slot's {item, made} or {none}. Throws, having written the run down
/// as failed, on anything the database refuses.
export async function runFeatures({ db, sets, now = new Date(), holder = "cron" }) {
  const rpc = (name, body) => db(`rpc/${name}`, { method: "POST", body });
  const begun = await rpc("cron_begin", { job: JOB, holder, seconds: LEASE_SECONDS });
  const day = dayOf(now);
  if (!begun || begun.locked !== false) return { outcome: "locked", run: begun?.run ?? null, day };
  const run = begun.run;
  try {
    const week = mondayOf(day);
    const since = (slot, days) => rpc("gallery_features_since", { slot, since: daysFrom(day, -days) });
    const [picks, featured, library] = await Promise.all([
      since("pick", PICK_GAP_DAYS + 7), since("featured", FEATURED_GAP_DAYS + 1), since("library", 365)]);
    const keep = async (slot, keptDay, choice) => {
      if (!choice) return { none: true };
      const kept = await rpc("gallery_feature_keep", { slot, day: keptDay, item: choice.item, why: choice.why });
      return kept && kept.item ? { item: kept.item, made: kept.made === true } : { none: true, refused: kept?.refused };
    };
    const already = (rows, keptDay) => (rows || []).find((row) => row && row.day === keptDay);

    const said = { day };
    const pickKept = already(picks, week);
    said.pick = pickKept ? { item: pickKept.item, made: false }
      : await keep("pick", week, chooseModel(await rpc("gallery_feature_signals", { days: PICK_DAYS }),
        { day: week, recent: picks, gapDays: PICK_GAP_DAYS }));
    const todays = already(featured, day);
    said.featured = todays ? { item: todays.item, made: false }
      : await keep("featured", day, chooseModel(await rpc("gallery_feature_signals", { days: FEATURED_DAYS }),
        { day, recent: featured, avoid: new Set(said.pick.item ? [said.pick.item] : []) }));
    const set = already(library, day);
    said.library = set ? { item: set.item, made: false }
      : await keep("library", day, chooseSet(await sets(), { day, recent: library }));
    const outcome = [said.pick, said.featured, said.library].some((slot) => slot.made) ? "done" : "unchanged";
    await rpc("cron_end", { run, holder, outcome, said });
    return { outcome, run, ...said };
  } catch (trouble) {
    await rpc("cron_end", { run, holder, outcome: "failed", said: { day, error: String(trouble?.message || trouble).slice(0, 300) } })
      .catch(() => null);
    throw trouble;
  }
}
