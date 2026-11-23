// A change sent back (suggestedit, 2026-11-23) through the real handlers,
// api/share.js and api/people.js, over a Supabase kept in memory: the two
// builders (Dee, the designer, and Ann, who remixed Dee's model), their
// shared models, each one's versions and files, and model_suggestions with
// its functions as supabase/suggestions.sql has them (suggestion_send,
// _notices, _new_count, _list, _close). Everything else the handlers ask
// answers as a database with nothing in it would: empty, null, or kept.
// tests/test_suggest.py drives it (flow.mjs), and so does the studio's
// probe, over HTTP (serve.mjs).
//
//   const w = await suggestWorld({ mine, theirs });
//   const sent = await w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
//     body: { remix: w.REMIX } });

import { world, SUPABASE_URL } from "../billing/world.mjs";

export const DEE = "00000000-0000-4000-8000-0000000000d1";
export const ANN = "00000000-0000-4000-8000-0000000000a1";
export const MODEL = "SuggestDee";
export const REMIX = "SuggestAnn";

const reply = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status,
  headers: { "content-type": "application/json" } });

/// [rows] as a PostgREST query [q] filters them: eq., neq. and in.(),
/// ordered by order=, and at most limit=.
function filtered(rows, q) {
  let out = rows;
  for (const [key, value] of q) {
    if (["select", "order", "limit", "offset", "on_conflict"].includes(key)) continue;
    const [, op, arg] = /^(eq|neq|in|lt|gt|is)\.(.*)$/.exec(value) || [];
    if (op === "eq") out = out.filter((row) => String(row[key]) === arg);
    else if (op === "neq") out = out.filter((row) => String(row[key]) !== arg);
    else if (op === "in") {
      const among = new Set(arg.replace(/^\(|\)$/g, "").split(","));
      out = out.filter((row) => among.has(String(row[key])));
    }
  }
  const order = q.get("order");
  if (order) {
    const [field, way] = order.split(".");
    out = [...out].sort((a, b) => (a[field] > b[field] ? 1 : a[field] < b[field] ? -1 : 0) * (way === "desc" ? -1 : 1));
  }
  if (q.get("limit")) out = out.slice(0, Number(q.get("limit")));
  return out;
}

export async function suggestWorld({ mine, theirs, name = "Red car", remixName = "Red car, wider" }) {
  const w = await world({});
  const now = () => new Date().toISOString();
  const at = "2026-11-20T10:00:00.000Z";
  const people = new Map([[DEE, { account: DEE, handle: "dee", name: "Dee" }],
    [ANN, { account: ANN, handle: "ann", name: "Ann" }]]);
  const row = (id, owner, named, extra = {}) => ({ id, owner, name: named, published: true, listed: true,
    barred: false, test: false, licence: "cc-by-4.0", parts: 10, bytes: 100, has_image: false, has_thumb: false,
    created_at: at, updated_at: at, listed_at: at, remixed_from: null, author: null, wip: false, ...extra });
  const models = [row(MODEL, DEE, name), row(REMIX, ANN, remixName, { remixed_from: MODEL })];
  const versions = [{ model: MODEL, n: 1, at, parts: 10, bytes: mine.length, has_image: false, note: null },
    { model: REMIX, n: 1, at, parts: 10, bytes: theirs.length, has_image: false, note: null }];
  const files = new Map([[`${MODEL}.mpd`, Buffer.from(mine)], [`${REMIX}.mpd`, Buffer.from(theirs)]]);
  const suggestions = [];
  let seenAt = new Map();
  const who = (account) => (people.has(account) ? { handle: people.get(account).handle, name: people.get(account).name } : null);
  const modelOf = (id) => models.find((one) => one.id === id) || null;

  const rpc = {
    feed_who: ({ account }) => who(account),
    suggestion_hourly: () => 20,
    suggestion_send({ p_remix, p_by, p_remix_n, p_model_n, p_note, p_counts }) {
      if (!p_remix || !p_by || !(p_remix_n >= 1) || !(p_model_n >= 1)) return { refused: "asked" };
      const remixed = modelOf(p_remix);
      if (!remixed || !remixed.published) return { refused: "gone" };
      if (remixed.owner !== p_by) return { refused: "not_yours" };
      if (!remixed.remixed_from) return { refused: "not_a_remix" };
      const original = modelOf(remixed.remixed_from);
      if (!original || !original.published) return { refused: "gone" };
      if (original.owner === p_by) return { refused: "own" };
      const note = String(p_note || "").trim().slice(0, 500) || null;
      const open = suggestions.find((s) => s.remix === p_remix && s.status === "open" && s.model === original.id);
      if (open) {
        Object.assign(open, { remix_n: p_remix_n, model_n: p_model_n, note, counts: p_counts || {}, at: now() });
        return { id: open.id, again: true };
      }
      const id = suggestions.length + 1;
      suggestions.push({ id, model: original.id, remix: p_remix, remix_n: p_remix_n, model_n: p_model_n, by_account: p_by,
        designer: original.owner, note, counts: p_counts || {}, status: "open", taken_n: null, taken: null, whole: null,
        test: false, at: now(), closed_at: null });
      return { id, again: false };
    },
    suggestion_notices({ viewer, since }) {
      if (!viewer) return [];
      const after = since ? Date.parse(since) : 0;
      const out = [];
      for (const s of suggestions) {
        const m = modelOf(s.model);
        const r = modelOf(s.remix);
        if (!m?.published || !r?.published) continue;
        if (s.designer === viewer && m.owner === viewer && s.status !== "withdrawn" && Date.parse(s.at) > after) {
          out.push({ kind: "suggestion", at: s.at, on: s.model, model: s.model, suggestion: s.id, remix: s.remix,
            name: r.name, of_name: m.name, by: who(s.by_account), counts: s.counts, note: s.note, status: s.status,
            test: s.test });
        }
        if (s.by_account === viewer && r.owner === viewer && s.status === "taken" && Date.parse(s.closed_at) > after) {
          out.push({ kind: "suggestion_taken", at: s.closed_at, on: s.remix, model: s.remix, of: s.model,
            suggestion: s.id, name: m.name, of_name: r.name, by: who(s.designer), taken: s.taken, whole: s.whole,
            n: s.taken_n, test: s.test });
        }
      }
      return out.sort((a, b) => Date.parse(b.at) - Date.parse(a.at)).slice(0, 200);
    },
    suggestion_new_count({ viewer }) {
      const since = seenAt.get(viewer) || null;
      return Math.min(rpc.suggestion_notices({ viewer, since }).length, 99);
    },
    suggestion_list({ p_model, viewer }) {
      const m = modelOf(p_model);
      if (!m) return null;
      const mineOnes = suggestions.filter((s) => s.model === m.id);
      return {
        open: m.owner === viewer ? mineOnes.filter((s) => s.status === "open").map((s) => ({ id: s.id, remix: s.remix,
          name: modelOf(s.remix)?.name, remix_n: s.remix_n, model_n: s.model_n, by: who(s.by_account), note: s.note,
          counts: s.counts, at: s.at })) : null,
        taken: mineOnes.filter((s) => s.status === "taken").sort((a, b) => b.taken_n - a.taken_n)
          .map((s) => ({ id: s.id, n: s.taken_n, remix: s.remix, name: modelOf(s.remix)?.name, by: who(s.by_account),
            taken: s.taken, whole: s.whole, at: s.closed_at })),
      };
    },
    suggestion_close({ p_id, p_account, p_status, p_n = null, p_taken = null, p_whole = null }) {
      if (!p_id || !p_account || !["taken", "declined", "withdrawn"].includes(p_status)
          || (p_status === "taken" && !(p_n >= 1))) return { refused: "asked" };
      const one = suggestions.find((s) => s.id === p_id);
      if (!one || one.status !== "open"
          || (["taken", "declined"].includes(p_status) && (one.designer !== p_account || modelOf(one.model)?.owner !== p_account))
          || (p_status === "withdrawn" && one.by_account !== p_account)) return { refused: "none" };
      Object.assign(one, { status: p_status, closed_at: now(), taken_n: p_status === "taken" ? p_n : null,
        taken: p_status === "taken" ? p_taken || {} : null, whole: p_status === "taken" ? Boolean(p_whole) : null });
      return { closed: true, by: one.by_account, remix: one.remix, model: one.model };
    },
    // The bell: notification_counts' own rows are none here; the changes
    // sent back are added by api/_notifications.js newCounts.
    notification_counts: () => ({ notifications: 0, feed: 0 }),
    feed_new_count: () => 0,
    notification_list: ({ viewer }) => {
      const page = { rows: [], models: {}, reads: {}, seen_at: seenAt.get(viewer) || null };
      seenAt.set(viewer, now());
      return page;
    },
    // A model's page (api/share.js modelPage), as supabase/directory.sql
    // makes it: its card, the line it came from, its listed remixes.
    directory_model({ model_id }) {
      const m = modelOf(model_id);
      if (!m || !m.published) return null;
      const card = (one) => ({ id: one.id, name: one.name, author: one.author, parts: one.parts, has_image: one.has_image,
        has_thumb: one.has_thumb, listed_at: one.listed_at, updated_at: one.updated_at, kind: null, tags: [],
        licence: one.licence, views: 0, likes: 0, builds: 0,
        remixes: models.filter((r) => r.remixed_from === one.id).length, by: who(one.owner) });
      const from = [];
      for (let up = modelOf(m.remixed_from); up && from.length < 8; up = modelOf(up.remixed_from)) {
        from.push({ id: up.id, name: up.name, author: who(up.owner)?.name || null });
      }
      return { ...card(m), description: null, listed: m.listed, from,
        remixes_listed: models.filter((r) => r.remixed_from === m.id).map(card) };
    },
    may_publish: () => true,
    may_list: () => true,
    is_barred: () => false,
  };

  const calls = [];
  const worldFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input.url || input));
    if (url.origin !== SUPABASE_URL) return worldFetch(input, init);
    const method = String(init.method || "GET").toUpperCase();
    const p = url.pathname;
    const q = url.searchParams;
    calls.push(`${method} ${p}`);
    if (p === "/auth/v1/.well-known/jwks.json" || p.startsWith("/auth/")) return worldFetch(input, init);
    const json = () => (typeof init.body === "string" && init.body ? JSON.parse(init.body) : init.body);
    if (p.startsWith("/rest/v1/rpc/")) {
      const body = json();
      const fn = p.slice("/rest/v1/rpc/".length);
      return rpc[fn] ? reply(200, rpc[fn](body || {})) : reply(200, null);
    }
    const storage = /^\/storage\/v1\/object\/[^/]+\/(.+)$/.exec(p);
    if (storage) {
      const named = decodeURIComponent(storage[1]);
      if (method === "GET") {
        return files.has(named) ? new Response(files.get(named), { status: 200 }) : reply(404, { error: "not found" });
      }
      if (method === "POST" || method === "PUT") {
        files.set(named, Buffer.from(init.body instanceof Uint8Array || Buffer.isBuffer(init.body) ? init.body : String(init.body ?? "")));
        return reply(200, { Key: named });
      }
      return reply(200, {});
    }
    const body = json();
    const table = p.slice("/rest/v1/".length);
    const tables = { shared_models: models, share_versions: versions, model_suggestions: suggestions,
      people: [...people.values()] };
    const rows = tables[table];
    if (!rows) return method === "GET" ? reply(200, []) : new Response(null, { status: 201 });
    if (method === "HEAD") {
      return new Response(null, { status: 200, headers: { "content-range": `*/${filtered(rows, q).length}` } });
    }
    if (method === "GET") return reply(200, filtered(rows, q));
    if (method === "PATCH") {
      const these = filtered(rows, q);
      for (const one of these) Object.assign(one, body || {});
      return reply(200, these);
    }
    if (method === "POST") {
      for (const one of Array.isArray(body) ? body : [body]) {
        const same = table === "shared_models" ? rows.find((r) => r.id === one.id)
          : table === "share_versions" ? rows.find((r) => r.model === one.model && r.n === one.n) : null;
        if (same) Object.assign(same, one);
        else rows.push({ ...one });
      }
      return reply(201, Array.isArray(body) ? body : [body]);
    }
    if (method === "DELETE") {
      for (const one of filtered(rows, q)) rows.splice(rows.indexOf(one), 1);
      return new Response(null, { status: 204 });
    }
    return new Response(null, { status: 204 });
  };

  const tokens = { dee: await w.signIn({ sub: DEE, email: "dee@example.com" }),
    ann: await w.signIn({ sub: ANN, email: "ann@example.com" }) };

  /// One request through api/<route>.js's handler, as Vercel makes it:
  /// {status, body}. [as]: "dee", "ann" or nobody.
  async function ask(route, { method = "GET", query = {}, body, as, page = false } = {}) {
    const { default: handle } = await import(`../../../api/${route}.js`);
    const response = { statusCode: 200, headers: {}, body: undefined,
      status(code) { this.statusCode = code; return this; },
      setHeader(named, value) { this.headers[String(named).toLowerCase()] = value; return this; },
      json(value) { this.body = value; return this; },
      send(value) { this.body = value; return this; },
      end(text) { if (text !== undefined) this.body = text; return this; } };
    const headers = { host: "brickworks.diy", "x-forwarded-proto": "https", ...(page ? { accept: "text/html" } : {}),
      ...(as ? { authorization: `Bearer ${tokens[as]}` } : {}) };
    await handle({ method, query, headers, body, url: `/api/${route}` }, response);
    return { status: response.statusCode, body: response.body, headers: response.headers };
  }

  return { MODEL, REMIX, DEE, ANN, tokens, ask, calls, models, versions, files, suggestions, people };
}
