// supabase/comment_pins.sql's functions, held in the local server's own
// process, for proving the API, the model's page and the app as they will be
// once the file is applied (partpins, 2026-11-23).
//
//   node --env-file=.env tools/web/relay_server.mjs 11400 --static=build/web --hold=pins
//
// The live project has comments.sql and replies.sql, so a pin is written
// there as the comment it is (add_comment, under every rule and limit of
// one), and only what the file adds is kept here: each pin's part (the
// column model_comments.pin) and when its model's owner resolved it
// (resolved_at), as replies_stand_in.mjs keeps model_comments.parent. Then
// each function the API asks is answered as the SQL answers it, over the
// live one's answer:
//
//   comments_on      the live list, each comment saying its pin and
//                    resolved_at, and pins: true
//   add_pin          add_comment's, the place kept as the comment's pin
//   resolve_pin      its model's owner alone, 60 an hour (may_act, live)
//   comment_pins_of  the pins among the comments named
//
// What the SQL itself does (the check, the trigger that keeps a pin as it
// was written, a reply never a pin) is proven by tools/comment_pins_try.sql
// in a rolled-back dry run; this is for the code around it. Pins written
// here are real comments, deleted with the throwaway accounts that wrote
// them. What is held is at /__held/comment_pins, on this machine only.
// Held with --hold=replies too, this answers over replies_stand_in's list
// (relay_server.mjs holds this one outermost).

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["comments_on", "add_pin", "resolve_pin", "comment_pins_of"];

// comment id -> {pin, resolved_at, model}.
const pins = new Map();
let inner = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

async function real(path, body) {
  const answer = await inner(`${REST}${path}`, { method: body === undefined ? "GET" : "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body) });
  if (!answer.ok) throw new Error(`pins stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

/// The place add_pin takes, as its SQL checks one.
function placeShape(place) {
  return Boolean(place) && typeof place === "object" && !Array.isArray(place) && typeof place.part === "string"
    && typeof place.colour === "number" && Array.isArray(place.at) && place.at.length === 3
    && place.at.every((v) => typeof v === "number")
    && JSON.stringify(place).length <= 8000;
}

const said = (c) => {
  const kept = pins.get(Number(c?.id));
  return { ...c, pin: kept ? kept.pin : null, resolved_at: kept ? kept.resolved_at : null };
};

const FUNCTIONS = {
  async comments_on(body) {
    const on = await real("rpc/comments_on", body);
    if (!on) return reply(200, on);
    return reply(200, { ...on, comments: (on.comments || []).map(said), pins: true });
  },

  async add_pin({ account, model_id, at_version, at_step, said: words, place }) {
    if (!placeShape(place)) return reply(200, { refused: "place" });
    const made = await real("rpc/add_comment", { account, model_id, at_version, at_step, said: words });
    if (made?.refused) return reply(200, made);
    pins.set(Number(made.comment.id), { pin: place, resolved_at: null, model: model_id });
    return reply(200, { comment: said(made.comment), owner: made.owner });
  },

  async resolve_pin({ account, comment_id, done }) {
    const kept = pins.get(Number(comment_id));
    if (!kept || !account || typeof done !== "boolean") return reply(200, { refused: "no_comment" });
    const rows = await real("rpc/admin_comments", { wanted: [Number(comment_id)] });
    const row = (rows || [])[0];
    if (!row || row.removed_at) return reply(200, { refused: "no_comment" });
    const model = (await real(`shared_models?id=eq.${row.model}&select=owner`))[0];
    if (!model || model.owner !== account) return reply(200, { refused: "not_owner" });
    if (!(await real("rpc/may_act", { actor: account, act: "pin_resolve", per_hour: 60, per_day: 300 }))) {
      return reply(200, { refused: "limit" });
    }
    kept.resolved_at = done ? kept.resolved_at || new Date().toISOString() : null;
    const person = (await real(`people?account=eq.${row.author}&select=name,handle`))[0] || null;
    return reply(200, { comment: said({ id: row.id, version: row.version, step: row.step, body: row.body, at: row.at,
      edited_at: row.edited_at, hidden: Boolean(row.hidden_at), mine: row.author === account, by_owner: row.author === account,
      by: person?.name ?? null, handle: person?.handle ?? null, parent: row.parent ?? null }) });
  },

  async comment_pins_of({ comment_ids }) {
    const ids = Array.isArray(comment_ids) ? comment_ids.map(Number) : [];
    return reply(200, ids.filter((id) => pins.has(id)).sort((a, b) => a - b)
      .map((id) => ({ comment: id, resolved: Boolean(pins.get(id).resolved_at) })));
  },
};

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
  console.log(`comment_pins.sql held here: ${NAMES.length} functions over the project's comments`);
}

/// What is held now, for a check to read (/__held/comment_pins).
export function rowsOf(name) {
  if (name === "comment_pins") return [...pins].map(([id, one]) => ({ id, ...one }));
  return null;
}
