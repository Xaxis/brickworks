// supabase/discovery.sql's table and functions, held in the local server's
// own process, for proving the API, the gallery and the admin page before
// the file is applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 9250 --hold=gallery_picks
//
// Its tables are reachable only through its functions, so what is held
// here is those the API asks, answered from memory as the SQL answers them:
// gallery_pick, gallery_week, gallery_choose_pick, gallery_end_pick and
// gallery_choices; what models need and people own (model_needs and
// collection_pools, through owned_keep_needs, owned_keep_pool,
// owned_forget_pool and owned_pool_of); and directory_models asked for
// Top builds, for Parts I own, for what can be built now or with a pool's
// shares, none of which the project's own function (builds.sql's) knows. Everything else is the real project: the models, their cards (the
// builds, remixes and Tested mark each says), model_builds, read with the
// secret key. What the gallery shows is asked of directory_models itself,
// at most 49 models, newest first: paged after that in memory, which the
// few models of a flow never notice; the file's own paging, its weights and
// its timings are proven by tools/discovery_try.sql in a rolled-back dry
// run. What is held is at /__held/gallery_picks, /__held/model_needs and
// /__held/collection_pools, on this machine only.
import { SCORE } from "../../api/_directory.js";

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["gallery_pick", "gallery_week", "gallery_choose_pick", "gallery_end_pick", "gallery_choices",
  "owned_keep_needs", "owned_keep_pool", "owned_forget_pool", "owned_pool_of"];
const WEEK = 7 * 864e5;

const picks = [];
let made = 0;
// model -> {pieces, at, lots: Map "part/colour" -> qty}; account -> {lots, pieces, unknown, at, held: Map}.
const needs = new Map();
const pools = new Map();
const lotKey = (part, colour) => `${part}/${colour}`;

/// How many of [model]'s pieces [account]'s pool holds: {pieces, have},
/// pieces null for a model not counted.
function ownedOf(account, model) {
  const need = needs.get(model);
  if (!need) return { pieces: null, have: null };
  const pool = pools.get(account)?.held || new Map();
  let have = 0;
  for (const [key, qty] of need.lots) have += Math.min(qty, pool.get(key) || 0);
  return { pieces: need.pieces, have: Math.min(have, need.pieces) };
}
let inner = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const time = (iso) => (iso ? Date.parse(iso) : NaN);
const score = (builds, remixes, tested) => SCORE.builds * builds + SCORE.remixes * remixes
  + (tested ? SCORE.tested : 0);

/// The project, as the server, through whatever is held inside this.
async function real(path, init = {}) {
  const answer = await inner(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`discovery stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

/// The cards a list asked with [tests] shows, newest first: gallery_shows.
const shownCards = (tests) => real("rpc/directory_models", { method: "POST",
  body: JSON.stringify({ query: { size: 49, ...(tests ? { tests: true } : {}) } }) });

/// The past seven days, model by model: id -> {builds, remixes}, the
/// remixes only those [shown] has (gallery_week_counts).
async function weekCounts(shown) {
  const since = new Date(Date.now() - WEEK).toISOString();
  const counts = new Map();
  const of = (id) => counts.get(id) || counts.set(id, { builds: 0, remixes: 0 }).get(id);
  for (const one of await real(`model_builds?at=gt.${since}&select=model`)) of(one.model).builds += 1;
  const ids = new Set(shown.map((card) => card.id));
  for (const one of await real(`shared_models?remixed_from=not.is.null&listed_at=gt.${since}&select=id,remixed_from`)) {
    if (ids.has(one.id)) of(one.remixed_from).remixes += 1;
  }
  return counts;
}

const weekOf = (card, counts) => {
  const { builds = 0, remixes = 0 } = counts.get(card.id) || {};
  return { builds, remixes, tested: card.tested === true, score: score(builds, remixes, card.tested === true) };
};

/// gallery_week: the candidates, best first.
async function week(tests, size) {
  const shown = await shownCards(tests);
  const counts = await weekCounts(shown);
  const fresh = (card) => time(card.listed_at) > Date.now() - WEEK;
  return shown.map((card, at) => ({ card, at, week: weekOf(card, counts) }))
    .filter(({ card, week: w }) => w.builds > 0 || w.remixes > 0 || (w.tested && fresh(card)))
    .sort((a, b) => b.week.score - a.week.score || b.week.builds - a.week.builds || a.at - b.at)
    .slice(0, Math.min(Math.max(Number(size) || 5, 1), 20))
    .map(({ card, week: w }) => ({ card, week: w }));
}

const open = () => picks.filter((one) => !one.ended_at && time(one.chosen_at) <= Date.now()
  && time(one.until) > Date.now()).sort((a, b) => time(b.chosen_at) - time(a.chosen_at) || b.id - a.id);

const FUNCTIONS = {
  async gallery_week({ tests = false, size = 5 }) {
    return reply(200, await week(tests === true, size));
  },

  async gallery_pick({ tests = false }) {
    const shown = await shownCards(tests === true);
    for (const one of open()) {
      const card = shown.find((c) => c.id === one.model);
      if (!card) continue;
      return reply(200, { pick: one.id, chosen: true, chosen_at: one.chosen_at, until: one.until, card,
        week: weekOf(card, await weekCounts(shown)) });
    }
    const best = (await week(tests === true, 1))[0];
    return reply(200, best ? { ...best, pick: null, chosen: false, chosen_at: null, until: null } : null);
  },

  async gallery_choose_pick({ model_id: model, days = 7 }) {
    if (!Number.isInteger(days) || days < 1 || days > 31) {
      return reply(400, { code: "22023", message: "brickworks: a pick is for 1 to 31 days" });
    }
    if (!(await shownCards(true)).some((card) => card.id === model)) return reply(200, { refused: "not_in_gallery" });
    const now = new Date();
    const one = { id: ++made, model, chosen_at: now.toISOString(),
      until: new Date(now.getTime() + days * 864e5).toISOString(), ended_at: null };
    picks.push(one);
    return reply(200, { pick: one.id, model, chosen_at: one.chosen_at, until: one.until });
  },

  async gallery_end_pick({ pick }) {
    const one = picks.find((p) => p.id === Number(pick) && !p.ended_at);
    if (!one) return reply(200, false);
    one.ended_at = new Date().toISOString();
    return reply(200, true);
  },

  async owned_keep_needs({ model_id: model, needs: given }) {
    if (!Array.isArray(given)) return reply(400, { code: "22023", message: "brickworks: needs are a list" });
    const lots = new Map();
    for (const one of given) lots.set(lotKey(one.part, one.colour), (lots.get(lotKey(one.part, one.colour)) || 0) + Number(one.qty));
    const pieces = [...lots.values()].reduce((a, b) => a + b, 0);
    needs.set(model, { model, pieces, at: new Date().toISOString(), lots });
    return reply(200, pieces);
  },

  async owned_keep_pool({ account, lots: given, unknown = [] }) {
    if (!account || !Array.isArray(given)) return reply(400, { code: "22023", message: "brickworks: a pool is an account and a list" });
    const held = new Map();
    for (const one of given) held.set(lotKey(one.part, one.colour), (held.get(lotKey(one.part, one.colour)) || 0) + Number(one.qty));
    const pieces = [...held.values()].reduce((a, b) => a + b, 0);
    pools.set(account, { owner: account, lots: held.size, pieces, unknown: [...unknown], at: new Date().toISOString(), held });
    return reply(200, { lots: held.size, pieces });
  },

  async owned_forget_pool({ account }) {
    return reply(200, pools.delete(account));
  },

  async owned_pool_of({ account }) {
    const one = pools.get(account);
    return reply(200, one ? { lots: one.lots, pieces: one.pieces, unknown: one.unknown, at: one.at } : null);
  },

  async gallery_choices() {
    const still = picks.filter((one) => !one.ended_at && time(one.until) > Date.now())
      .sort((a, b) => time(b.chosen_at) - time(a.chosen_at) || b.id - a.id).slice(0, 50);
    if (!still.length) return reply(200, []);
    const rows = await real(`shared_models?id=in.(${[...new Set(still.map((one) => one.model))].join(",")})&select=id,name,test`);
    const shown = new Set((await shownCards(false)).map((card) => card.id));
    return reply(200, still.map((one) => {
      const row = rows.find((r) => r.id === one.model) || {};
      return { pick: one.id, model: one.model, name: row.name ?? null, chosen_at: one.chosen_at, until: one.until,
        test: row.test === true, shown: shown.has(one.model) };
    }));
  },
};

/// directory_models asked what builds.sql's does not know (Top builds,
/// Parts I own, what can be built now, a pool's shares): the project's own
/// list, newest first, given each card's share, filtered and put in the
/// asked order (ties to the newest), and paged.
async function directoryModels(url, init) {
  const query = JSON.parse(String(init.body || "{}")).query || {};
  const { pool = null, buildable = false, ...plain } = query;
  const answer = await inner(url, { ...init, body: JSON.stringify({ query: { ...plain, sort: "newest", size: 49, skip: 0 } }) });
  if (!answer.ok) return answer;
  const skip = Number(query.skip) || 0;
  const size = Math.min(Math.max(Number(query.size) || 25, 1), 49);
  let cards = (await answer.json()).map((card) => (pool ? { ...card, owned: ownedOf(pool, card.id) } : card));
  if (buildable) cards = cards.filter((card) => card.owned?.pieces > 0 && card.owned.have >= card.owned.pieces);
  const keyOf = (card) => {
    if (query.sort === "top") {
      return [score(Number(card.builds) || 0, Number(card.remixes) || 0, card.tested === true), Number(card.builds) || 0];
    }
    if (query.sort === "owned") {
      const share = card.owned?.pieces ? card.owned.have / card.owned.pieces : -1;
      return [share, card.owned?.pieces ? card.owned.have : -1];
    }
    return [0, 0];
  };
  cards = cards.map((card, at) => ({ card, at, key: keyOf(card) }))
    .sort((a, b) => b.key[0] - a.key[0] || b.key[1] - a.key[1] || a.at - b.at)
    .map(({ card }) => card);
  return reply(200, cards.slice(skip, skip + size));
}

/// Put the stand-in in front of the database, for this process.
export function hold() {
  if (inner) return;
  inner = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const where = String(url);
    if (where.startsWith(`${REST}rpc/`)) {
      const name = where.slice(`${REST}rpc/`.length).split("?")[0];
      let body = {};
      try {
        body = init.body ? JSON.parse(init.body) : {};
      } catch {
        body = {};
      }
      if (NAMES.includes(name)) return FUNCTIONS[name](body);
      const query = body?.query || {};
      if (name === "directory_models" && (["top", "owned"].includes(query.sort) || query.pool || query.buildable)) {
        return directoryModels(url, init);
      }
    }
    return inner(url, init);
  };
  console.log(`discovery.sql held here: ${NAMES.length} functions, Top builds and Parts I own`);
}

/// What a held table has now, for a check to read (/__held/<table>).
export function rowsOf(name) {
  if (name === "gallery_picks") return picks.map((row) => ({ ...row }));
  if (name === "model_needs") {
    return [...needs.values()].flatMap((one) => [...one.lots].map(([key, qty]) => ({ model: one.model,
      part: key.split("/")[0], colour: Number(key.split("/")[1]), qty })));
  }
  if (name === "collection_pools") {
    return [...pools.values()].map(({ held, ...one }) => ({ ...one, held: [...held].map(([key, qty]) => [key, qty]) }));
  }
  return null;
}
