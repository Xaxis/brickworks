// supabase/designers.sql's functions, held in the local server's own
// process, for proving the API and the pages before the file is applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 9260 --hold=model_opens
//
// What the API asks of the file is two functions, designer_page and
// designer_mine, answered here from the real project's own tables as the
// SQL answers them: the models (shared_models), their counts (model_stats),
// builds finished (model_builds), remixes, the Tested mark (model_tested),
// the comments each page shows a visitor (comments_on, which says which are
// the owner's), photos of builds (build_photos) and who is shown in public
// (shown_publicly). The opens are model_views' rows, a visitor a day: what
// model_opens holds the moment the file is applied (it counts in what
// model_views has, today's and yesterday's, and then each new one). What
// the SQL itself does, the trigger, the grants, its paging and its timings,
// is proven by tools/designers_try.sql in a rolled-back dry run; this is
// for the code around it. /__held/model_opens answers [] so a flow can tell
// a held relay from a deployment.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["designer_page", "designer_mine"];
const DAY = 864e5;

let inner = null;

const reply = (status, value) => new Response(value === undefined || value === null ? "null" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const time = (iso) => (iso ? Date.parse(iso) : NaN);

/// The project, as the server, through whatever is held inside this.
async function real(path, init = {}) {
  const answer = await inner(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`designers stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}
const rpc = (name, body) => real(`rpc/${name}`, { method: "POST", body: JSON.stringify(body) });
const shown = async (account) => (await rpc("shown_publicly", { account })) === true;
const inList = (ids) => `in.(${ids.join(",")})`;

/// [ids]' comments as each page shows them to a visitor, less the owner's:
/// model -> [at, ...].
async function earnedComments(ids) {
  const out = new Map();
  for (const id of ids) {
    const said = await rpc("comments_on", { model_id: id }).catch(() => null);
    out.set(id, (said?.comments || []).filter((c) => !c.by_owner && !c.hidden).map((c) => time(c.at)));
  }
  return out;
}

/// Photos other people posted of [models] (rows with id and owner), shown
/// in public, newest first, each with who and its model's name.
async function photosOf(models) {
  if (!models.length) return [];
  const owners = new Map(models.map((m) => [m.id, m.owner]));
  const names = new Map(models.map((m) => [m.id, m.name]));
  const rows = await real(`build_photos?model=${inList(models.map((m) => m.id))}&removed_at=is.null&hidden_at=is.null`
    + "&select=id,model,account,words,width,height,at&order=at.desc,id.asc");
  const out = [];
  const seen = new Map();
  for (const row of rows.filter((one) => one.account !== owners.get(one.model))) {
    if (!seen.has(row.account)) seen.set(row.account, await shown(row.account));
    if (seen.get(row.account)) out.push(row);
  }
  const accounts = [...new Set(out.map((one) => one.account))];
  const people = accounts.length ? await real(`people?account=${inList(accounts)}&select=account,handle,name`) : [];
  const named = new Map(people.map((one) => [one.account, { handle: one.handle, name: one.name }]));
  return out.map((one) => ({ ...one, by: named.get(one.account) || null, model_name: names.get(one.model) }));
}

const FUNCTIONS = {
  async designer_page({ wanted, tests = false }) {
    const person = (await real(`people?handle=eq.${encodeURIComponent(String(wanted || "").toLowerCase())}&select=account`))[0];
    if (!person || !(await shown(person.account))) return reply(200, null);
    const theirs = (await real(`shared_models?owner=eq.${person.account}&published=is.true&listed=is.true`
      + "&barred=is.false&author=not.is.null&select=id,owner,name,test")).filter((m) => tests || !m.test);
    const ids = theirs.map((m) => m.id);
    const stats = ids.length ? await real(`model_stats?model=${inList(ids)}&select=model,builds,likes`) : [];
    const remixes = ids.length ? await real(`shared_models?remixed_from=${inList(ids)}&published=is.true&select=remixed_from`) : [];
    const comments = await earnedComments(ids);
    let tested = 0;
    for (const id of ids) if ((await rpc("model_tested", { model_id: id })) === true) tested += 1;
    const photos = await photosOf(theirs);
    const cards = {};
    for (const [id, list] of comments) if (list.length) cards[id] = { comments: list.length };
    return reply(200, {
      models: ids.length,
      builds: stats.reduce((sum, s) => sum + (Number(s.builds) || 0), 0),
      remixes: remixes.length,
      comments: [...comments.values()].reduce((sum, list) => sum + list.length, 0),
      tested,
      likes: stats.reduce((sum, s) => sum + (Number(s.likes) || 0), 0),
      builders: new Set(photos.map((one) => one.account)).size,
      cards,
      photos: photos.slice(0, 12).map((one) => ({ id: one.id, model: one.model, model_name: one.model_name, words: one.words,
        width: one.width, height: one.height, at: one.at, by: one.by })),
    });
  },

  async designer_mine({ designer = null, days = 30 }) {
    if (!designer) return reply(200, null);
    const span = Math.min(Math.max(Math.trunc(Number(days) || 30), 1), 90);
    const today = new Date().toISOString().slice(0, 10);
    const sinceDay = new Date(Date.parse(today) - (span - 1) * DAY).toISOString().slice(0, 10);
    const sinceAt = Date.now() - span * DAY;
    const mine = await real(`shared_models?owner=eq.${designer}&published=is.true&barred=is.false`
      + "&select=id,name,owner,listed,author,test,parts,has_image,has_thumb,updated_at,listed_at,created_at");
    const ids = mine.map((m) => m.id);
    const none = !ids.length;
    const stats = none ? [] : await real(`model_stats?model=${inList(ids)}&select=model,views,builds`);
    const views = none ? [] : await real(`model_views?model=${inList(ids)}&day=gte.${sinceDay}&select=model`);
    const builds = none ? [] : await real(`model_builds?model=${inList(ids)}&select=model,at`);
    const remixes = none ? [] : await real(`shared_models?remixed_from=${inList(ids)}&published=is.true&select=remixed_from,created_at`);
    const comments = await earnedComments(ids);
    const photos = await photosOf(mine);
    const first = await real("model_views?select=day&order=day.asc&limit=1");
    const rows = [];
    for (const m of mine) {
      const s = stats.find((one) => one.model === m.id) || {};
      const said = comments.get(m.id) || [];
      const pictured = photos.filter((one) => one.model === m.id);
      rows.push({ id: m.id, name: m.name, listed: m.listed, credited: m.author !== null, test: m.test, parts: m.parts,
        has_image: m.has_image, has_thumb: m.has_thumb, updated_at: m.updated_at, listed_at: m.listed_at,
        created_at: m.created_at, tested: (await rpc("model_tested", { model_id: m.id })) === true,
        opens: views.filter((one) => one.model === m.id).length, opens_ever: Number(s.views) || 0,
        builds: builds.filter((one) => one.model === m.id && time(one.at) >= sinceAt).length,
        builds_ever: Number(s.builds) || 0,
        remixes: remixes.filter((one) => one.remixed_from === m.id && time(one.created_at) >= sinceAt).length,
        remixes_ever: remixes.filter((one) => one.remixed_from === m.id).length,
        comments: said.filter((at) => at >= sinceAt).length, comments_ever: said.length,
        photos_count: pictured.length, builders: new Set(pictured.map((one) => one.account)).size,
        photos: pictured.slice(0, 6).map((one) => ({ id: one.id, words: one.words, width: one.width, height: one.height,
          at: one.at, by: one.by })) });
    }
    const listedAt = (row) => (row.listed_at ? time(row.listed_at) : -Infinity);
    rows.sort((a, b) => b.opens - a.opens || b.builds - a.builds || b.builds_ever - a.builds_ever
      || b.opens_ever - a.opens_ever || listedAt(b) - listedAt(a) || time(b.created_at) - time(a.created_at)
      || (a.id < b.id ? -1 : 1));
    for (const row of rows) delete row.created_at;
    return reply(200, { days: span, since: sinceDay, counted_from: first[0]?.day ?? null, models: rows });
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
        return FUNCTIONS[name](body);
      }
    }
    return inner(url, init);
  };
  console.log(`designers.sql held here: ${NAMES.join(", ")}, opens read from model_views`);
}

/// What a check may read (/__held/<table>): only that this is held.
export function rowsOf(name) {
  return name === "model_opens" ? [] : null;
}
