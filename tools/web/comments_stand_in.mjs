// supabase/comments.sql's tables and functions, held in the local server's
// own process, for proving the API, the pages and the app before the file
// is applied.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9040 --static=build/web --hold=model_comments --trust-stand-in
//
// comments.sql's tables are reachable only through its functions, so what
// is held here is the functions: comment_trouble, comments_open,
// comments_on, comment_model, add_comment, change_comment, set_comments,
// admin_comments, admin_remove_comment, mail_choice, claim_comment_digest,
// finish_comment_digest and comment_digest_kept, answered from memory as
// the SQL answers them. And the one column it adds to a table the project
// has, reports.comment: a report about a comment is written to the real
// reports table without it, and which comment it names is kept here and
// put back on every read (and every filter on it) that asks.
//
// Everything else is the real project's: the accounts, the models' rows,
// their versions, is_barred and may_act (so the limits count as they will).
// The age (trust.sql) is asked of age_of and shown_publicly through the
// server's fetch, which --trust-stand-in answers. What the SQL itself
// refuses, triggers and all, is proven by tools/comments_trial.sql in a
// rolled-back dry run; this is for the code around it.
//
// An email to a model's owner is claimed here only for a test account (a
// Resend test address), so nothing real is ever sent from a local server.
//
// With follows.sql held too (tools/web/follows_stand_in.mjs), the day's
// email is supabase/follows.sql's: mail_kinds keeps a choice for each of
// the feed's kinds, and claim_comment_digest tells of the feed's rows of
// the kinds chosen since the last email that went, asked of that stand-in.
// What is held is at /__held/<table> (model_comments, comment_settings,
// mail_choices, comment_digests, report_comments), on this machine only.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["comment_trouble", "comments_open", "comments_on", "comment_model", "add_comment", "change_comment",
  "set_comments", "admin_comments", "admin_remove_comment", "mail_choice", "mail_kinds", "claim_comment_digest",
  "finish_comment_digest", "comment_digest_kept"];
const KINDS = ["comments", "models", "versions", "photos", "remixes"];
// follows.sql's feed, when its stand-in is held: (viewer, since, until) -> [{kind, at, item}].
let feedRows = null;

/// The day's email tells of the feed too (follows_stand_in.mjs).
export function useFeed(rows) {
  feedRows = rows;
}

const comments = [];
const settings = new Map();
const mail = new Map();
const digests = [];
const reported = new Map();
const tests = new Map();
let inner = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const now = () => new Date().toISOString();

/// The real project (and any table held inside this), as the server.
async function real(path, init = {}) {
  const answer = await inner(`${REST}${path}`, { ...init,
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json",
      ...(init.headers || {}) } });
  if (!answer.ok) throw new Error(`comments stand-in: ${path.split("?")[0]} ${answer.status}`);
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
    tests.set(account, { test: /@resend\.dev$/i.test(String(user.email || "")), email: user.email || null });
  }
  return tests.get(account).test;
}

/// What [account] chose to be emailed, each kind false until chosen.
const choiceOf = (account) => ({ account, ...Object.fromEntries(KINDS.map((kind) => [kind, false])),
  at: now(), ...(mail.get(account) || {}) });

const modelOf = async (id) => (await real(`shared_models?id=eq.${encodeURIComponent(id)}`
  + "&select=id,owner,name,published,barred,steps"))[0] || null;
const overThirteen = async (account) => (await outer("age_of", { account }))?.over_13 ?? null;
const barred = async (account) => (await real("rpc/is_barred", { method: "POST", body: JSON.stringify({ account }) })) === true;
const shown = async (account) => (await outer("shown_publicly", { account })) !== false;
const mayAct = async (account, act, hour, day) => (await real("rpc/may_act", { method: "POST",
  body: JSON.stringify({ actor: account, act, per_hour: hour, per_day: day }) })) === true;
const plain = (said) => typeof said === "string" && [...said].length >= 1 && [...said].length <= 1000
  && /\S/.test(said) && !/[\u0001-\u0009\u000b-\u001f\u007f]/.test(said);

async function isOpen(m) {
  if (!m || !m.published || m.barred) return false;
  if (await barred(m.owner)) return false;
  if ((await overThirteen(m.owner)) === false) return false;
  return settings.get(m.id)?.open !== false;
}

async function trouble(account, modelId) {
  if (!account) return "sign_in";
  const m = await modelOf(modelId);
  if (!m || !m.published) return "no_model";
  if (await barred(account)) return "barred";
  const age = await overThirteen(account);
  if (age === null) return "ask_first";
  if (age !== true) return "under_13";
  if (!(await isOpen(m))) return "closed";
  return null;
}

async function said(c, asker, owner) {
  const person = (await real(`people?account=eq.${c.author}&select=name,handle`))[0] || null;
  return { id: c.id, version: c.version, step: c.step, body: c.body, at: c.at, edited_at: c.edited_at,
    hidden: c.hidden_at !== null, mine: Boolean(asker) && c.author === asker, by_owner: c.author === owner,
    by: person?.name ?? null, handle: person?.handle ?? null };
}

const FUNCTIONS = {
  comment_trouble: async ({ account, model_id: modelId }) => reply(200, await trouble(account, modelId)),
  comments_open: async ({ model_id: modelId }) => reply(200, await isOpen(await modelOf(modelId))),

  async comments_on({ model_id: modelId, asker = null }) {
    const m = await modelOf(modelId);
    if (!m || !m.published) return reply(200, null);
    const first = (await real(`share_versions?model=eq.${modelId}&select=at&order=at.asc&limit=1`))[0];
    const since = first ? Date.parse(first.at) : null;
    const listed = [];
    for (const c of comments) {
      if (c.model !== modelId || c.removed_at) continue;
      if (since !== null && Date.parse(c.at) < since) continue;
      if (c.hidden_at && !(asker && (c.author === asker || m.owner === asker))) continue;
      if (!(await shown(c.author))) continue;
      listed.push(c);
    }
    const kept = listed.slice(-500);
    return reply(200, { open: await isOpen(m), owner: Boolean(asker) && asker === m.owner,
      comments: await Promise.all(kept.map((c) => said(c, asker, m.owner))) });
  },

  async comment_model({ comment_id: id }) {
    const c = comments.find((one) => one.id === Number(id) && !one.removed_at);
    if (!c) return reply(200, null);
    const m = await modelOf(c.model);
    return reply(200, m && m.published ? c.model : null);
  },

  async add_comment({ account, model_id: modelId, at_version: version, at_step: step, said: body }) {
    const why = await trouble(account, modelId);
    if (why) return reply(200, { refused: why });
    const versions = await real(`share_versions?model=eq.${modelId}&select=n,steps`);
    let steps = null;
    const one = versions.find((v) => v.n === version);
    if (one) steps = one.steps;
    else if (version === 1 && versions.length === 0) steps = (await modelOf(modelId)).steps;
    else return reply(200, { refused: "no_version" });
    if (step !== null && step !== undefined && (step < 1 || (steps && step > steps))) return reply(200, { refused: "no_step" });
    if (!plain(body)) return reply(200, { refused: "body" });
    if (!(await mayAct(account, "comment", 10, 50))) return reply(200, { refused: "limit" });
    const m = await modelOf(modelId);
    const made = { id: comments.length + 1, model: modelId, version, step: step ?? null, author: account, body,
      at: now(), edited_at: null, hidden_at: null, removed_at: null, removed_by: null, digest: null };
    comments.push(made);
    return reply(200, { comment: await said(made, account, m.owner), owner: m.owner });
  },

  async change_comment({ account, comment_id: id, what, said: body = null }) {
    const c = comments.find((one) => one.id === Number(id) && !one.removed_at);
    if (!c || !account) return reply(200, { refused: "no_comment" });
    const m = await modelOf(c.model);
    if (["edit", "remove"].includes(what) && c.author !== account) return reply(200, { refused: "not_yours" });
    if (["hide", "show"].includes(what) && m?.owner !== account) return reply(200, { refused: "not_owner" });
    if (what === "edit") {
      const why = await trouble(account, c.model);
      if (why) return reply(200, { refused: why });
      if (!plain(body)) return reply(200, { refused: "body" });
      if (!(await mayAct(account, "comment_edit", 20, 100))) return reply(200, { refused: "limit" });
      Object.assign(c, { body, edited_at: now() });
    } else if (what === "remove") {
      Object.assign(c, { removed_at: now(), removed_by: "author" });
    } else if (what === "hide" || what === "show") {
      if (!(await mayAct(account, "comment_hide", 60, 300))) return reply(200, { refused: "limit" });
      c.hidden_at = what === "hide" ? c.hidden_at || now() : null;
    } else {
      return reply(400, { message: "brickworks: edit, remove, hide or show" });
    }
    return reply(200, { comment: await said(c, account, m?.owner), removed: Boolean(c.removed_at) });
  },

  async set_comments({ account, model_id: modelId, open }) {
    if (typeof open !== "boolean") return reply(400, { message: "brickworks: say whether comments are open" });
    const m = await modelOf(modelId);
    if (!account || !m || m.owner !== account) return reply(200, { refused: "not_owner" });
    if (!(await mayAct(account, "comment_settings", 30, 100))) return reply(200, { refused: "limit" });
    settings.set(modelId, { model: modelId, open, at: now() });
    return reply(200, { open: await isOpen(m) });
  },

  async admin_comments({ wanted = null }) {
    const chosen = comments.filter((c) => wanted === null || wanted.includes(c.id))
      .slice(-200).reverse();
    const out = [];
    for (const c of chosen) {
      const m = await modelOf(c.model);
      const person = (await real(`people?account=eq.${c.author}&select=handle`))[0] || null;
      out.push({ id: c.id, model: c.model, name: m?.name ?? null, version: c.version, step: c.step, body: c.body,
        at: c.at, edited_at: c.edited_at, hidden_at: c.hidden_at, removed_at: c.removed_at,
        removed_by: c.removed_by, author: c.author, handle: person?.handle ?? null });
    }
    return reply(200, out);
  },

  async admin_remove_comment({ comment_id: id }) {
    const c = comments.find((one) => one.id === Number(id));
    if (!c) return reply(200, false);
    if (!c.removed_at) Object.assign(c, { removed_at: now(), removed_by: "admin" });
    return reply(200, true);
  },

  async mail_choice({ account, comments: wanted = null }) {
    if (typeof wanted === "boolean") mail.set(account, { ...choiceOf(account), comments: wanted, at: now() });
    return reply(200, { comments: mail.get(account)?.comments === true });
  },

  // follows.sql's: a choice for each kind, those named kept first. Only
  // while its stand-in is held, as the function is only there with it.
  async mail_kinds({ account, chosen = null }) {
    if (!feedRows) return reply(404, { message: "Could not find the function public.mail_kinds" });
    if (chosen && Object.keys(chosen).length) {
      if (Object.entries(chosen).some(([kind, on]) => !KINDS.includes(kind) || typeof on !== "boolean")) {
        return reply(400, { message: "brickworks: say comments, models, versions, photos or remixes, each true or false" });
      }
      mail.set(account, { ...choiceOf(account), ...chosen, at: now() });
    }
    const kept = choiceOf(account);
    return reply(200, Object.fromEntries(KINDS.map((kind) => [kind, kept[kind] === true])));
  },

  async claim_comment_digest({ for_owner: owner = null }) {
    const due = [];
    for (const choice of [...mail.values()].filter((one) => KINDS.some((kind) => one[kind])
        && (!owner || one.account === owner))) {
      if (due.length >= 50) break;
      // Never anybody real from a local server.
      if (!(await isTest(choice.account))) continue;
      const day = Date.now() - 864e5;
      if (digests.some((d) => d.owner === choice.account && d.state !== "failed" && Date.parse(d.at) > day)) continue;
      const waiting = [];
      for (const c of choice.comments ? comments : []) {
        if (c.removed_at || c.hidden_at || c.author === choice.account || Date.parse(c.at) < Date.parse(choice.at)) continue;
        const earlier = c.digest ? digests.find((d) => d.id === c.digest) : null;
        if (earlier && earlier.state !== "failed") continue;
        const m = await modelOf(c.model);
        if (!m || !m.published || m.owner !== choice.account || !(await shown(c.author))) continue;
        waiting.push({ c, m });
      }
      // The feed's rows of the kinds chosen, since the last email that went
      // (or since they chose), at most 90 days.
      let rows = [];
      if (feedRows && ["models", "versions", "photos", "remixes"].some((kind) => choice[kind])) {
        const told = digests.filter((d) => d.owner === choice.account && ["sent", "dry"].includes(d.state))
          .reduce((most, d) => Math.max(most, Date.parse(d.at)), -Infinity);
        const since = Math.max(told, Date.parse(choice.at), Date.now() - 90 * 864e5);
        const kindOf = { model: "models", version: "versions", photo: "photos", remix: "remixes" };
        rows = (await feedRows(choice.account, since, Date.now())).filter((one) => choice[kindOf[one.kind]])
          .sort((a, b) => Date.parse(a.at) - Date.parse(b.at));
      }
      if (waiting.length === 0 && rows.length === 0) continue;
      const taken = waiting.slice(0, 50);
      const told = rows.slice(0, 50);
      const digest = { id: digests.length + 1, owner: choice.account, at: now(), state: "sending",
        comments: taken.length, feed: told.length, subject: null, body: null, html: null };
      digests.push(digest);
      for (const { c } of taken) c.digest = digest.id;
      due.push({ digest: digest.id, owner: choice.account, email: tests.get(choice.account).email, test: true,
        more: waiting.length - taken.length,
        comments: await Promise.all(taken.map(async ({ c, m }) => ({ id: c.id, model: c.model, name: m.name,
          version: c.version, step: c.step, body: c.body, at: c.at,
          by: (await real(`people?account=eq.${c.author}&select=name`))[0]?.name ?? null }))),
        feed: told.map((one) => ({ ...one.item, kind: one.kind, at: one.at })), feed_more: rows.length - told.length });
    }
    return reply(200, due);
  },

  async finish_comment_digest({ one, outcome, said_subject: subject, said_body: body, said_html: html }) {
    const digest = digests.find((d) => d.id === one && d.state === "sending");
    if (!digest || !["sent", "failed", "dry"].includes(outcome)) return reply(200, false);
    Object.assign(digest, { state: outcome }, outcome === "dry" ? { subject, body, html } : {});
    return reply(200, true);
  },

  async comment_digest_kept({ one }) {
    const digest = digests.find((d) => d.id === Number(one));
    return reply(200, digest && (await isTest(digest.owner)) ? { id: digest.id, owner: digest.owner,
      state: digest.state, comments: digest.comments, feed: digest.feed ?? 0, subject: digest.subject,
      body: digest.body } : null);
  },
};

// ---------------------------------------------------------------------------
// reports.comment, held.

/// The select's columns at the top level, without [column].
function without(select, column) {
  const parts = [];
  let depth = 0;
  let at = 0;
  for (let n = 0; n <= select.length; n += 1) {
    const ch = select[n];
    if (ch === "(") depth += 1;
    if (ch === ")") depth -= 1;
    if ((ch === "," && depth === 0) || n === select.length) {
      parts.push(select.slice(at, n));
      at = n + 1;
    }
  }
  const kept = parts.filter((part) => part.trim() !== column);
  return { select: kept.join(","), had: kept.length !== parts.length };
}

async function reports(url, init) {
  const method = String(init.method || "GET").toUpperCase();
  const params = new URLSearchParams(url.search);
  let ask = true;
  const filter = params.get("comment");
  if (filter !== null) {
    params.delete("comment");
    const ids = (wanted) => [...reported].filter(([, comment]) => wanted(comment)).map(([report]) => report);
    const eq = /^eq\.(\d+)$/.exec(filter);
    const chosen = eq ? ids((comment) => comment === Number(eq[1]))
      : filter === "not.is.null" ? ids(() => true) : null;
    if (chosen) {
      if (chosen.length === 0) ask = false;
      else params.append("id", `in.(${chosen.join(",")})`);
    } else if (filter === "is.null") {
      const all = ids(() => true);
      if (all.length) params.append("id", `not.in.(${all.join(",")})`);
    } else {
      return reply(400, { message: `comments stand-in: no filter like comment=${filter}` });
    }
  }
  let wantsComment = method === "GET" && !params.has("select");
  if (params.has("select")) {
    const { select, had } = without(params.get("select"), "comment");
    params.set("select", select);
    wantsComment = had;
  }
  let body = init.body;
  let comment = null;
  if (method === "POST" && body) {
    const given = JSON.parse(String(body));
    if (given && !Array.isArray(given) && given.comment !== undefined && given.comment !== null) {
      comment = Number(given.comment);
      delete given.comment;
      body = JSON.stringify(given);
    }
  }
  if (!ask) return method === "GET" ? reply(200, []) : new Response(null, { status: 204 });
  const headers = { ...(init.headers || {}) };
  if (comment !== null) headers.prefer = "return=representation";
  const answer = await inner(`${REST}reports?${params}`, { ...init, headers, body });
  if (!answer.ok || (comment === null && !wantsComment)) return answer;
  const text = await answer.text();
  const rows = text ? JSON.parse(text) : [];
  for (const row of Array.isArray(rows) ? rows : []) {
    if (comment !== null && row.id) reported.set(row.id, comment);
    row.comment = reported.get(row.id) ?? null;
  }
  return reply(answer.status, rows);
}

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
    if (where.startsWith(`${REST}reports`) && /^reports(\?|$)/.test(where.slice(REST.length))) {
      return reports(new URL(where), init);
    }
    return inner(url, init);
  };
  console.log(`comments.sql held here: ${NAMES.length} functions, and reports.comment`);
}

/// What a held table has now, for a check to read (/__held/<table>).
export function rowsOf(name) {
  const copy = (rows) => rows.map((row) => ({ ...row }));
  if (name === "model_comments") return copy(comments);
  if (name === "comment_settings") return copy([...settings.values()]);
  if (name === "mail_choices") return copy([...mail.values()]);
  if (name === "comment_digests") return copy(digests);
  if (name === "report_comments") return [...reported].map(([report, comment]) => ({ report, comment }));
  return null;
}
