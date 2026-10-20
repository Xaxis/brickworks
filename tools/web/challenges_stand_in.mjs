// supabase/challenges.sql's functions, held in the local server's own
// process, for proving the API and the pages before the file is applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 9271 --hold=challenges
//
// The file's five tables are kept here, in memory, and its functions the API
// asks for (challenge_set, _end, _list, _shown, _enter, _withdraw,
// _for_model, _vote, _settle, _page, _mine, _wins) answered as the SQL
// answers them, over the real project's own tables: the models
// (shared_models), their counts (model_stats), remixes, the Tested mark
// (model_tested), who may go public (trust_may_go_public, trust_kept_private,
// is_barred, shown_publicly) and whose profile names a card (people). What a
// model needs is counted from its file, as api/share.js counts it when it is
// published (checkModel, keyed): discovery.sql's model_needs, which no key
// reads. What the SQL itself does, its grants, its timings and its rules
// inside the database, is proven by tools/challenges_try.sql in a
// rolled-back dry run; this is for the code around it. /__held/challenges
// answers what is held, so a flow can tell a held relay from a deployment.

import { checkModel } from "../../api/share.js";
import { keyed } from "../../api/_owned.js";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["challenge_set", "challenge_end", "challenge_list", "challenge_shown", "challenge_enter",
  "challenge_withdraw", "challenge_for_model", "challenge_vote", "challenge_settle", "challenge_page",
  "challenge_mine", "challenge_wins"];
const CARD = "id,owner,name,author,parts,published,listed,barred,test,has_image,has_thumb,listed_at,updated_at,kind,tags,"
  + "licence,steps,own_steps,technic";

let inner = null;
const challenges = [];
const setParts = new Map();
let entries = [];
let votes = [];
const winners = [];
let nextId = 1;
const needsKept = new Map();

const reply = (status, value) => new Response(value === undefined || value === null ? "null" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

async function real(path, init = {}) {
  const answer = await inner(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`challenges stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}
const rpc = (name, body) => real(`rpc/${name}`, { method: "POST", body: JSON.stringify(body) });
const yes = async (name, body) => (await rpc(name, body)) === true;

const today = () => new Date().toISOString().slice(0, 10);
const stateOf = (c) => (c.ended_at || c.ends_on < today() ? "ended" : c.starts_on > today() ? "upcoming" : "open");
const addDays = (day, n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);

async function model(id) {
  return (await real(`shared_models?id=eq.${encodeURIComponent(id)}&select=${CARD}`))[0] || null;
}
/// gallery_shows: published, listed, not taken out, its owner not taken out.
async function inGallery(m, tests) {
  return Boolean(m && m.published && m.listed && !m.barred && (!m.test || tests)
    && !(await yes("is_barred", { account: m.owner })));
}

/// What [m] needs, from its file, as publishing counts it: Map part/colour -> qty.
async function needsOf(m) {
  const kept = needsKept.get(m.id);
  if (kept && kept.at === m.updated_at) return kept.needs;
  const file = await inner(`${SUPABASE}/storage/v1/object/shared-models/${m.id}.mpd`,
    { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  let needs = null;
  if (file.ok) {
    try {
      needs = new Map(keyed(checkModel(await file.text()).needs || []).map((one) => [`${one.part}/${one.colour}`, one]));
    } catch {
      needs = null;
    }
  }
  needsKept.set(m.id, { at: m.updated_at, needs });
  return needs;
}

/// challenge_check, over the model's file.
async function check(c, m) {
  const out = {};
  if (c.most_parts !== null) out.parts = { most: c.most_parts, has: m.parts, ok: m.parts <= c.most_parts };
  if (c.set_number !== null) {
    const needs = await needsOf(m);
    const set = setParts.get(c.id) || new Map();
    const short = needs ? [...needs.values()].map((one) => ({ part: one.part, colour: one.colour, need: one.qty,
      have: set.get(`${one.part}/${one.colour}`)?.qty || 0 })).filter((one) => one.have < one.need) : [];
    short.sort((a, b) => (b.need - b.have) - (a.need - a.have) || (a.part < b.part ? -1 : a.part > b.part ? 1 : a.colour - b.colour));
    out.set = { number: c.set_number, name: c.set_name, counted: needs !== null, ok: needs !== null && short.length === 0,
      short_lots: short.length, short: short.slice(0, 12) };
  }
  if (c.tested) out.tested = { ok: await yes("model_tested", { model_id: m.id }) };
  out.ok = Object.values(out).every((one) => one.ok !== false);
  return out;
}

/// directory_card, as the SQL makes it.
async function card(m) {
  const [stats, remixes, person, tested] = await Promise.all([
    real(`model_stats?model=eq.${m.id}&select=views,likes,builds`),
    real(`shared_models?remixed_from=eq.${m.id}&published=is.true&select=id`),
    real(`people?account=eq.${m.owner}&select=handle,name`),
    yes("model_tested", { model_id: m.id }),
  ]);
  const s = stats[0] || {};
  const by = person[0] && m.author !== null && !(await yes("trust_kept_private", { account: m.owner }))
    ? { handle: person[0].handle, name: person[0].name } : null;
  return { id: m.id, name: m.name, author: m.author, parts: m.parts, has_image: m.has_image, has_thumb: m.has_thumb,
    listed_at: m.listed_at, updated_at: m.updated_at, kind: m.kind, tags: m.tags || [], licence: m.licence,
    steps: m.steps, own_steps: m.own_steps, technic: m.technic, views: Number(s.views) || 0, likes: Number(s.likes) || 0,
    builds: Number(s.builds) || 0, remixes: remixes.length, by, tested };
}

const openFor = (tests) => challenges.filter((c) => c.test === Boolean(tests) && stateOf(c) === "open")
  .sort((a, b) => (b.starts_on < a.starts_on ? -1 : 1) || b.id - a.id)[0] || null;

function shownFor(tests) {
  const rank = { open: 0, upcoming: 1, ended: 2 };
  return challenges.filter((c) => (!c.test || tests) && (stateOf(c) !== "ended" || entries.some((e) => e.challenge === c.id)))
    .sort((a, b) => rank[stateOf(a)] - rank[stateOf(b)] || Number(b.test) - Number(a.test)
      || (stateOf(a) === "upcoming" ? (a.starts_on < b.starts_on ? -1 : a.starts_on > b.starts_on ? 1 : 0) : 0)
      || (b.ends_on < a.ends_on ? -1 : b.ends_on > a.ends_on ? 1 : 0) || b.id - a.id)[0] || null;
}

const rulesOf = (c) => ({ most_parts: c.most_parts, set_number: c.set_number, set_name: c.set_name, tested: c.tested });
const counted = async (voter) => !(await yes("is_barred", { account: voter })) && !(await yes("trust_kept_private", { account: voter }));

async function votesFor(c, modelId) {
  let total = 0;
  for (const v of votes.filter((one) => one.challenge === c.id && one.model === modelId)) if (await counted(v.voter)) total += 1;
  return total;
}

const FUNCTIONS = {
  async challenge_set(a) {
    if (a.ends_on < today()) return { refused: "past" };
    const other = challenges.filter((c) => c.test === Boolean(a.test) && !c.ended_at && c.starts_on <= a.ends_on
      && c.ends_on >= a.starts_on).sort((x, y) => (x.starts_on < y.starts_on ? -1 : 1))[0];
    if (other) return { refused: "overlap", with: { id: other.id, title: other.title } };
    if (a.set_number && (!Array.isArray(a.set_parts) || !a.set_parts.length)) return { refused: "set_empty" };
    if (a.ends_on < a.starts_on || a.ends_on > addDays(a.starts_on, 62)) throw new Error("challenges_check");
    const c = { id: nextId++, title: a.title, brief: a.brief, starts_on: a.starts_on, ends_on: a.ends_on,
      most_parts: a.most_parts ?? null, set_number: a.set_number ? String(a.set_number).toLowerCase() : null,
      set_name: a.set_name ?? null, tested: a.tested === true, test: a.test === true, created_at: new Date().toISOString(),
      ended_at: null, settled_at: null };
    challenges.push(c);
    if (c.set_number) {
      const lots = new Map();
      for (const one of a.set_parts) {
        const key = `${one.part}/${one.colour}`;
        lots.set(key, { part: one.part, colour: one.colour, qty: Math.min((lots.get(key)?.qty || 0) + Number(one.qty), 200000) });
      }
      setParts.set(c.id, lots);
    }
    return { challenge: c.id, starts_on: c.starts_on, ends_on: c.ends_on };
  },

  async challenge_end({ challenge_id }) {
    const c = challenges.find((one) => one.id === Number(challenge_id) && !one.ended_at);
    if (!c) return false;
    c.ended_at = new Date().toISOString();
    return true;
  },

  async challenge_list({ tests = false }) {
    const out = [];
    for (const c of challenges.filter((one) => !one.test || tests).sort((a, b) => (b.starts_on < a.starts_on ? -1 : 1) || b.id - a.id).slice(0, 24)) {
      const of = (list, way) => list.filter((one) => one.challenge === c.id && one.way === way).length;
      const won = [];
      for (const w of winners.filter((one) => one.challenge === c.id).sort((a, b) => (a.way < b.way ? 1 : -1))) {
        won.push({ way: w.way, model: w.model, name: (await model(w.model))?.name ?? null, votes: w.votes });
      }
      out.push({ id: c.id, title: c.title, brief: c.brief, starts_on: c.starts_on, ends_on: c.ends_on, state: stateOf(c),
        test: c.test, ended_at: c.ended_at, settled: Boolean(c.settled_at), rules: rulesOf(c),
        entries: { hand: of(entries, "hand"), assistant: of(entries, "assistant") },
        votes: { hand: of(votes, "hand"), assistant: of(votes, "assistant") }, winners: won });
    }
    return out;
  },

  async challenge_shown({ tests = false }) {
    const c = shownFor(tests);
    return c ? { ...c } : { id: null };
  },

  async challenge_enter({ account, model_id, way }) {
    if (!["hand", "assistant"].includes(way)) throw new Error("brickworks: an entry is built by hand or with the assistant");
    const m = await model(model_id);
    if (!m || !m.published) return { refused: "no_model" };
    if (m.owner !== account) return { refused: "not_yours" };
    if (await yes("trust_kept_private", { account })) return { refused: "under_13" };
    if (!(await yes("trust_may_go_public", { account }))) return { refused: "not_asked" };
    if (await yes("is_barred", { account })) return { refused: "barred" };
    if (!(await inGallery(m, true)) || m.author === null) return { refused: "not_in_gallery" };
    const c = openFor(m.test);
    if (!c) return { refused: "no_challenge" };
    const was = entries.find((e) => e.challenge === c.id && e.model === m.id);
    if (was) return { refused: "entered", way: was.way, challenge: c.id };
    if (entries.filter((e) => e.challenge === c.id && e.owner === account).length >= 3) return { refused: "three", challenge: c.id };
    const checked = await check(c, m);
    if (!checked.ok) return { refused: "rules", challenge: c.id, check: checked };
    entries.push({ challenge: c.id, model: m.id, owner: account, way, at: new Date().toISOString() });
    return { entered: true, challenge: c.id, title: c.title, way, check: checked };
  },

  async challenge_withdraw({ account, model_id }) {
    const gone = entries.filter((e) => e.model === model_id && e.owner === account
      && stateOf(challenges.find((c) => c.id === e.challenge)) === "open");
    if (!gone.length) return false;
    entries = entries.filter((e) => !gone.includes(e));
    votes = votes.filter((v) => !gone.some((e) => e.challenge === v.challenge && e.model === v.model));
    return true;
  },

  async challenge_for_model({ account, model_id }) {
    const m = await model(model_id);
    const c = m && m.owner === account && m.published ? openFor(m.test) : null;
    if (!c) return { challenge: null };
    const e = entries.find((one) => one.challenge === c.id && one.model === model_id);
    return { challenge: { id: c.id, title: c.title, starts_on: c.starts_on, ends_on: c.ends_on, rules: rulesOf(c) },
      entry: e ? { way: e.way, at: e.at } : null,
      entries: entries.filter((one) => one.challenge === c.id && one.owner === account).length, check: await check(c, m) };
  },

  async challenge_vote({ account, challenge_id, model_id, tests = false }) {
    const c = challenges.find((one) => one.id === Number(challenge_id));
    if (!c || stateOf(c) !== "open" || c.test !== Boolean(tests)) return { refused: "not_open" };
    if (await yes("trust_kept_private", { account })) return { refused: "under_13" };
    if (!(await yes("trust_may_go_public", { account }))) return { refused: "not_asked" };
    if (await yes("is_barred", { account })) return { refused: "barred" };
    const e = entries.find((one) => one.challenge === c.id && one.model === model_id);
    const m = e ? await model(model_id) : null;
    if (!e || !(await inGallery(m, true)) || !(await yes("shown_publicly", { account: e.owner }))) return { refused: "no_entry" };
    if (e.owner === account) return { refused: "own" };
    if (!(await check(c, m)).ok) return { refused: "breaks" };
    const had = votes.find((v) => v.challenge === c.id && v.way === e.way && v.voter === account);
    if (had) return { refused: "voted", way: e.way, model: had.model };
    votes.push({ challenge: c.id, way: e.way, voter: account, model: e.model, at: new Date().toISOString() });
    return { voted: true, way: e.way, model: e.model };
  },

  async challenge_settle({ challenge_id }) {
    const c = challenges.find((one) => one.id === Number(challenge_id));
    if (!c || c.settled_at || stateOf(c) !== "ended") return false;
    for (const way of ["assistant", "hand"]) {
      let best = null;
      for (const e of entries.filter((one) => one.challenge === c.id && one.way === way).sort((a, b) => (a.at < b.at ? -1 : 1))) {
        const m = await model(e.model);
        if (!(await inGallery(m, true)) || !(await yes("shown_publicly", { account: e.owner })) || !(await check(c, m)).ok) continue;
        const n = await votesFor(c, e.model);
        if (n > 0 && (!best || n > best.votes)) best = { challenge: c.id, way, model: e.model, owner: e.owner, votes: n };
      }
      if (best) winners.push({ ...best, at: new Date().toISOString() });
    }
    c.settled_at = new Date().toISOString();
    return true;
  },

  async challenge_page({ tests = false }) {
    const c = shownFor(tests);
    if (!c) return null;
    const state = stateOf(c);
    const shown = [];
    for (const e of entries.filter((one) => one.challenge === c.id)) {
      const m = await model(e.model);
      if (!(await inGallery(m, tests)) || !(await yes("shown_publicly", { account: e.owner }))) continue;
      shown.push({ model: e.model, way: e.way, at: e.at, keeps: (await check(c, m)).ok,
        votes: state === "ended" ? await votesFor(c, e.model) : null, card: await card(m) });
    }
    shown.sort((a, b) => (a.way < b.way ? 1 : a.way > b.way ? -1 : 0) || (state === "ended" ? b.votes - a.votes : 0)
      || (a.at < b.at ? -1 : a.at > b.at ? 1 : 0) || (a.model < b.model ? -1 : 1));
    return { id: c.id, title: c.title, brief: c.brief, starts_on: c.starts_on, ends_on: c.ends_on, state, test: c.test,
      settled: Boolean(c.settled_at), rules: rulesOf(c), entries: shown,
      winners: winners.filter((w) => w.challenge === c.id).sort((a, b) => (a.way < b.way ? 1 : -1))
        .map((w) => ({ way: w.way, model: w.model, votes: w.votes })) };
  },

  async challenge_mine({ account, challenge_id }) {
    const id = Number(challenge_id);
    const voted = (way) => votes.find((v) => v.challenge === id && v.voter === account && v.way === way)?.model ?? null;
    return { voted: { hand: voted("hand"), assistant: voted("assistant") },
      entries: entries.filter((e) => e.challenge === id && e.owner === account).map((e) => e.model),
      may_vote: (await yes("trust_may_go_public", { account })) && !(await yes("is_barred", { account })),
      under_13: await yes("trust_kept_private", { account }) };
  },

  async challenge_wins({ owner = null, models = null, tests = false }) {
    const out = [];
    for (const w of winners) {
      const c = challenges.find((one) => one.id === w.challenge);
      if (!(w.owner === owner || (models || []).includes(w.model)) || (c.test && !tests)) continue;
      const m = await model(w.model);
      if (!m || !m.published || m.barred) continue;
      out.push({ challenge: c.id, title: c.title, ends_on: c.ends_on, way: w.way, model: w.model, name: m.name, votes: w.votes });
    }
    return out.sort((a, b) => (b.ends_on < a.ends_on ? -1 : 1) || b.challenge - a.challenge);
  },
};

/// Put the stand-in in front of the database, for this process.
export function hold() {
  if (inner) return;
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
        try {
          return reply(200, await FUNCTIONS[name](body));
        } catch (trouble) {
          return reply(400, { message: String(trouble?.message || trouble) });
        }
      }
    }
    return inner(url, init);
  };
  console.log(`challenges.sql held here: ${NAMES.length} functions, its tables in memory`);
}

/// What a check may read (/__held/<table>): the held tables, on this machine only.
export function rowsOf(name) {
  if (name === "challenges") return challenges;
  if (name === "challenge_entries") return entries;
  if (name === "challenge_votes") return votes;
  if (name === "challenge_winners") return winners;
  return null;
}
