// supabase/follows.sql's tables and functions, held in the local server's
// own process, for proving the API, the pages and the app before the file
// is applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 9240 --static=build/web \
//     --hold=follows,model_comments,build_photos,report_photos --trust-stand-in
//
// follows.sql's two tables are reachable only through its functions, so
// what is held here is those the API asks: follow_state, follow_person,
// follow_list, follow_choice, feed_of and feed_count, answered from memory
// as the SQL answers them. The feed is read from what holds each thing:
// the real project's shared_models and share_versions, build_photos as the
// server's fetch gives it (held too with --hold=build_photos), and the
// comments comments_stand_in.mjs holds (--hold=model_comments, which this
// needs). The day's email (comments_stand_in's claim_comment_digest and
// mail_kinds) asks this for the feed's rows.
//
// The age and who is shown (trust.sql) are asked of age_of and
// shown_publicly through the server's whole fetch, which --trust-stand-in
// answers. What the SQL itself refuses, the trigger and the grants, is
// proven by tools/follows_try.sql in a rolled-back dry run; this is for
// the code around it. What is held is at /__held/follows and
// /__held/feed_marks, on this machine only.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["follow_state", "follow_person", "follow_list", "follow_choice", "feed_of", "feed_count"];
const DAY = 864e5;

const follows = [];
const marks = new Map();
const tests = new Map();
let inner = null;
let comments = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const now = () => new Date().toISOString();
const time = (iso) => (iso ? Date.parse(iso) : NaN);

/// The project, as the server, through whatever is held inside this.
async function real(path, init = {}) {
  const answer = await inner(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`follows stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

/// An rpc asked of the server's whole fetch: the trust stand-in in front.
async function outer(name, body) {
  const answer = await globalThis.fetch(`${REST}rpc/${name}`, { method: "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify(body) });
  if (!answer.ok) return null;
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

async function isTest(account) {
  if (!account) return false;
  if (!tests.has(account)) {
    const answer = await inner(`${SUPABASE}/auth/v1/admin/users/${account}`, {
      headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
    const user = answer.ok ? await answer.json() : {};
    tests.set(account, /@resend\.dev$/i.test(String(user.email || "")));
  }
  return tests.get(account);
}

const overThirteen = async (account) => (await outer("age_of", { account }))?.over_13 ?? null;
const shown = async (account) => (await outer("shown_publicly", { account })) !== false;
const barred = async (account) => (await real("rpc/is_barred", { method: "POST", body: JSON.stringify({ account }) })) === true;
const personOf = async (handle) => (await real(`people?handle=eq.${encodeURIComponent(String(handle || "").toLowerCase())}`
  + "&select=account,handle,name"))[0] || null;
const who = async (account) => {
  if (!(await shown(account))) return null;
  const person = (await real(`people?account=eq.${account}&select=handle,name`))[0];
  return person ? { handle: person.handle, name: person.name } : null;
};

async function mayBeFollowed(account) {
  if (!account) return false;
  if (!(await real(`people?account=eq.${account}&select=account`)).length) return false;
  return (await overThirteen(account)) === true && (await shown(account));
}

async function trouble(account, whom) {
  if (!account) return "sign_in";
  if (!whom || !(await mayBeFollowed(whom))) return "nobody";
  if (account === whom) return "yourself";
  if (await barred(account)) return "barred";
  const age = await overThirteen(account);
  if (age === null) return "ask_first";
  if (age !== true) return "under_13";
  return null;
}

async function state(asker, wanted) {
  const person = await personOf(wanted);
  if (!person || !(await mayBeFollowed(person.account))) return null;
  let followers = 0;
  for (const one of follows.filter((f) => f.followed === person.account)) {
    if ((await overThirteen(one.follower)) === true && (await shown(one.follower))) followers += 1;
  }
  let following = 0;
  for (const one of follows.filter((f) => f.follower === person.account)) {
    if (await mayBeFollowed(one.followed)) following += 1;
  }
  return { handle: person.handle, followers, following, shows: marks.get(person.account)?.shows_follows === true,
    you_follow: Boolean(asker) && follows.some((f) => f.follower === asker && f.followed === person.account),
    mine: Boolean(asker) && asker === person.account, trouble: await trouble(asker, person.account) };
}

/// [viewer]'s feed from after [since] up to [until] (ms), as feed_rows.
export async function feedRows(viewer, since, until) {
  if (!viewer) return [];
  const within = (iso) => time(iso) > since && time(iso) <= until;
  const followed = [];
  for (const one of follows.filter((f) => f.follower === viewer)) {
    if (await mayBeFollowed(one.followed)) followed.push(one.followed);
  }
  const test = await isTest(viewer);
  const columns = "id,owner,name,author,parts,published,listed,listed_at,barred,test,remixed_from";
  const mine = await real(`shared_models?owner=eq.${viewer}&published=is.true&barred=is.false&select=${columns}`);
  const mineIds = new Set(mine.map((m) => m.id));
  const theirs = followed.length ? await real(`shared_models?owner=in.(${followed.join(",")})&select=${columns}`) : [];
  const credited = theirs.filter((m) => m.published && m.listed && !m.barred && m.author !== null && (!m.test || test));
  const out = [];
  for (const m of credited) {
    if (within(m.listed_at) && !(m.remixed_from && mineIds.has(m.remixed_from))) {
      out.push({ kind: "model", at: m.listed_at, item: { model: m.id, name: m.name, parts: m.parts, by: await who(m.owner) } });
    }
  }
  if (credited.length) {
    const versions = await real(`share_versions?model=in.(${credited.map((m) => m.id).join(",")})&select=model,n,at,note`);
    for (const v of versions) {
      const m = credited.find((one) => one.id === v.model);
      if (v.n > 1 && time(v.at) > time(m.listed_at) && within(v.at)) {
        out.push({ kind: "version", at: v.at, item: { model: m.id, name: m.name, version: v.n, note: v.note ?? null,
          by: await who(m.owner) } });
      }
    }
  }
  // Photos: on the viewer's own models, and by people followed.
  const photoRows = [];
  if (mineIds.size) photoRows.push(...await real(`build_photos?model=in.(${[...mineIds].join(",")})&select=*`).catch(() => []));
  if (followed.length) photoRows.push(...await real(`build_photos?account=in.(${followed.join(",")})&select=*`).catch(() => []));
  const seenPhotos = new Set();
  for (const b of photoRows) {
    if (seenPhotos.has(b.id)) continue;
    seenPhotos.add(b.id);
    if (b.removed_at || b.hidden_at || b.account === viewer || !within(b.at)) continue;
    const m = (await real(`shared_models?id=eq.${b.model}&select=${columns}`))[0];
    if (!m || !m.published || m.barred || !(await shown(b.account))) continue;
    const yours = m.owner === viewer;
    if (!yours && !(followed.includes(b.account) && m.listed && (!m.test || test))) continue;
    out.push({ kind: "photo", at: b.at, item: { photo: b.id, model: b.model, name: m.name, words: b.words ?? null,
      yours, by: await who(b.account) } });
  }
  // Comments on the viewer's own models, held by the comments stand-in.
  for (const k of comments ? comments.rowsOf("model_comments") : []) {
    if (!mineIds.has(k.model) || k.removed_at || k.hidden_at || k.author === viewer || !within(k.at)) continue;
    if (!(await shown(k.author))) continue;
    const first = (await real(`share_versions?model=eq.${k.model}&select=at&order=at.asc&limit=1`))[0];
    if (first && time(k.at) < time(first.at)) continue;
    const m = mine.find((one) => one.id === k.model);
    out.push({ kind: "comment", at: k.at, item: { comment: k.id, model: k.model, name: m.name, version: k.version,
      step: k.step, said: String(k.body).slice(0, 240), by: await who(k.author) } });
  }
  // Remixes of the viewer's own models, listed.
  if (mineIds.size) {
    const remixes = await real(`shared_models?remixed_from=in.(${[...mineIds].join(",")})&select=${columns}`);
    for (const r of remixes) {
      if (!r.published || !r.listed || r.barred || r.owner === viewer || !within(r.listed_at)) continue;
      if (!(await shown(r.owner)) || (r.test && !test)) continue;
      const o = mine.find((one) => one.id === r.remixed_from);
      out.push({ kind: "remix", at: r.listed_at, item: { model: r.id, name: r.name, of: o.id, of_name: o.name,
        by: r.author !== null ? await who(r.owner) : null } });
    }
  }
  return out;
}

const newestFirst = (a, b) => time(b.at) - time(a.at) || (a.kind < b.kind ? -1 : a.kind > b.kind ? 1 : 0);

const FUNCTIONS = {
  follow_state: async ({ asker = null, wanted }) => reply(200, await state(asker, wanted)),

  async follow_person({ account = null, wanted, following }) {
    if (typeof following !== "boolean") return reply(400, { message: "brickworks: say whether to follow" });
    const person = await personOf(wanted);
    const whom = person?.account ?? null;
    if (following) {
      const why = await trouble(account, whom);
      if (why) return reply(200, { refused: why });
      if (!follows.some((f) => f.follower === account && f.followed === whom)) {
        const allowed = await real("rpc/may_act", { method: "POST",
          body: JSON.stringify({ actor: account, act: "follow", per_hour: 60, per_day: 300 }) });
        if (allowed !== true) return reply(200, { refused: "limit" });
        follows.push({ follower: account, followed: whom, at: now() });
      }
    } else {
      if (!account) return reply(200, { refused: "sign_in" });
      for (let at = follows.length - 1; at >= 0; at -= 1) {
        if (follows[at].follower === account && follows[at].followed === whom) follows.splice(at, 1);
      }
    }
    return reply(200, (await state(account, wanted)) || { refused: "nobody" });
  },

  async follow_list({ wanted }) {
    const person = await personOf(wanted);
    if (!person || !(await mayBeFollowed(person.account))) return reply(200, null);
    const shows = marks.get(person.account)?.shows_follows === true;
    const people = [];
    if (shows) {
      for (const one of follows.filter((f) => f.follower === person.account).reverse().slice(0, 200)) {
        if (!(await mayBeFollowed(one.followed))) continue;
        const them = (await real(`people?account=eq.${one.followed}&select=handle,name`))[0];
        if (them) people.push({ handle: them.handle, name: them.name });
      }
    }
    return reply(200, { shows, people });
  },

  async follow_choice({ account, shows = null }) {
    if (typeof shows === "boolean") {
      marks.set(account, { account, seen_at: marks.get(account)?.seen_at ?? null, shows_follows: shows, at: now() });
    }
    return reply(200, { shows_follows: marks.get(account)?.shows_follows === true });
  },

  async feed_of({ viewer = null, before = null, size = 30, mark = false }) {
    if (!viewer) return reply(200, null);
    const wanted = Math.min(Math.max(Number(size) || 30, 1), 50);
    const seen = marks.get(viewer)?.seen_at ?? null;
    const until = before ? time(before) : Date.now();
    const rows = (await feedRows(viewer, Date.now() - 90 * DAY, Date.now()))
      .filter((one) => time(one.at) <= Date.now() && (!before || time(one.at) < until)).sort(newestFirst);
    if (mark) marks.set(viewer, { account: viewer, shows_follows: marks.get(viewer)?.shows_follows === true,
      seen_at: now(), at: marks.get(viewer)?.at ?? now() });
    return reply(200, { rows: rows.slice(0, wanted).map((one) => ({ ...one.item, kind: one.kind, at: one.at })),
      more: rows.length > wanted, seen_at: seen });
  },

  async feed_count({ viewer = null }) {
    if (!viewer) return reply(200, 0);
    const seen = marks.get(viewer)?.seen_at;
    const since = Math.max(seen ? time(seen) : -Infinity, Date.now() - 90 * DAY);
    return reply(200, Math.min((await feedRows(viewer, since, Date.now())).length, 99));
  },
};

/// Put the stand-in in front of the database, for this process. [held] is
/// comments_stand_in.mjs, whose comments the feed reads and whose daily
/// email asks this for the feed.
export function hold(held) {
  if (inner) return;
  comments = held || null;
  inner = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const where = String(url);
    if (where.startsWith(`${REST}rpc/`)) {
      const name = where.slice(`${REST}rpc/`.length).split("?")[0];
      if (NAMES.includes(name)) {
        let body = {};
        try {
          body = init.body ? JSON.parse(init.body) : {};
        } catch {
          body = {};
        }
        return FUNCTIONS[name](body);
      }
    }
    return inner(url, init);
  };
  if (comments?.useFeed) comments.useFeed(feedRows);
  console.log(`follows.sql held here: ${NAMES.length} functions${comments ? ", the feed in the day's email" : ""}`);
}

/// What a held table has now, for a check to read (/__held/<table>).
export function rowsOf(name) {
  if (name === "follows") return follows.map((row) => ({ ...row }));
  if (name === "feed_marks") return [...marks.values()].map((row) => ({ ...row }));
  return null;
}
