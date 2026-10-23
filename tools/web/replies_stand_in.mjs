// supabase/replies.sql's functions, held in the local server's own process,
// for proving the API and the pages as they will be once the file is
// applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 8830 --hold=replies
//
// The live project has comments.sql and notifications.sql, so a reply is
// written there as the comment it is (add_comment, on its comment's
// version and step, under every rule and limit of one), and only what the
// file adds is kept here: which comment each reply answers (the column
// model_comments.parent), as comments_stand_in.mjs kept reports.comment.
// Then each function the API asks is answered as the SQL answers it, over
// the live one's answer:
//
//   comments_on           the live list, each reply saying its comment, a
//                         reply only under a comment the asker is shown,
//                         and threads: true
//   add_reply             a reply to a comment its page shows everybody
//                         (to a reply: in its thread), or the refusal
//   admin_comments        the live rows, each saying its comment
//   notification_list,    the live rows, a reply in a thread the viewer is
//   notification_counts   in told as a reply ([yours] when it answers
//                         theirs), on their model or anybody's, and nothing
//                         under a comment no longer shown
//   notification_read     a model the viewer commented on read here, which
//                         the live function refuses
//
// What the SQL itself does, the trigger and the counts on cards, a
// designer's numbers and the day's email included, is proven by
// tools/replies_try.sql in a rolled-back dry run; this is for the code
// around it. Replies written here are real comments, deleted with the
// throwaway accounts that wrote them. What is held is at
// /__held/comment_parents, on this machine only.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["comments_on", "add_reply", "admin_comments", "notification_list", "notification_counts",
  "notification_read"];
const DAY = 864e5;

// Each reply's comment: reply id -> comment id.
const parents = new Map();
// A model's notifications read, of a model the viewer commented on: viewer -> model -> at.
const reads = new Map();
let inner = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const time = (iso) => (iso ? Date.parse(iso) : NaN);

async function real(path, body) {
  const answer = await inner(`${REST}${path}`, { method: body === undefined ? "GET" : "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body) });
  if (!answer.ok) throw new Error(`replies stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

/// The comments named, as admin_comments gives them: id -> row.
async function commentsNamed(ids) {
  const wanted = [...new Set(ids.filter(Boolean))];
  if (!wanted.length) return new Map();
  const rows = await real("rpc/admin_comments", { wanted });
  return new Map((rows || []).map((row) => [row.id, row]));
}

const shown = async (account) => (await real("rpc/shown_publicly", { account })) === true;

/// comment_parent_shown: the comment a reply answers, not removed, not
/// hidden, by somebody shown.
async function parentShown(row) {
  return Boolean(row) && !row.removed_at && !row.hidden_at && await shown(row.author);
}

/// The threads [viewer] is in: root id -> {joined, theirs}.
function threadsOf(viewer, rows) {
  const threads = new Map();
  for (const row of rows.values()) {
    if (row.author !== viewer || row.removed_at) continue;
    const root = parents.get(row.id) ?? row.id;
    const was = threads.get(root);
    const at = time(row.at);
    threads.set(root, { joined: was ? Math.min(was.joined, at) : at, theirs: (was?.theirs || false) || root === row.id });
  }
  return threads;
}

/// What notification_rows adds and changes, over the live list's rows.
async function noticeRows(viewer, rows) {
  // Every comment that is a reply or answered, and the viewer's own.
  const ids = [...parents.keys(), ...parents.values(), ...rows.filter((r) => r.kind === "comment").map((r) => r.comment)];
  const known = await commentsNamed(ids);
  const threads = threadsOf(viewer, known);
  const kept = [];
  for (const row of rows) {
    if (row.kind !== "comment" || !parents.has(row.comment)) {
      kept.push(row);
      continue;
    }
    const root = parents.get(row.comment);
    if (!(await parentShown(known.get(root)))) continue;
    const thread = threads.get(root);
    // Told below, as a reply.
    if (thread && time(row.at) > thread.joined) continue;
    kept.push({ ...row, parent: root });
  }
  const owners = new Map();
  for (const [id, root] of parents) {
    const one = known.get(id);
    const thread = threads.get(root);
    if (!one || !thread || one.author === viewer || one.removed_at || one.hidden_at || time(one.at) <= thread.joined) continue;
    if (!(await shown(one.author)) || !(await parentShown(known.get(root)))) continue;
    if (!owners.has(one.model)) {
      const [m] = await real(`shared_models?id=eq.${one.model}&select=owner,name,published,barred`);
      owners.set(one.model, m || null);
    }
    const m = owners.get(one.model);
    if (!m || !m.published || m.barred) continue;
    kept.push({ kind: "reply", at: one.at, on: one.model, comment: one.id, parent: root, yours: thread.theirs,
      model: one.model, name: m.name, version: one.version, step: one.step, said: String(one.body).slice(0, 240),
      by: await real("rpc/feed_who", { account: one.author }) });
  }
  return kept.filter((r) => time(r.at) > Date.now() - 90 * DAY)
    .sort((a, b) => time(b.at) - time(a.at) || String(a.kind).localeCompare(String(b.kind))).slice(0, 200);
}

const FUNCTIONS = {
  async comments_on({ model_id, asker }) {
    const on = await real("rpc/comments_on", { model_id, asker: asker ?? null });
    if (!on) return reply(200, null);
    const listed = (on.comments || []).map((one) => ({ ...one, parent: parents.get(one.id) ?? null }));
    const here = new Set(listed.filter((one) => one.parent === null).map((one) => one.id));
    return reply(200, { ...on, comments: listed.filter((one) => one.parent === null || here.has(one.parent)), threads: true });
  },
  async add_reply({ account, comment_id, said }) {
    if (!account) return reply(200, { refused: "sign_in" });
    let known = await commentsNamed([Number(comment_id)]);
    let root = known.get(Number(comment_id));
    if (root && parents.has(root.id)) {
      known = await commentsNamed([parents.get(root.id)]);
      root = known.get(parents.get(root.id));
    }
    if (!root || root.removed_at) return reply(200, { refused: "no_comment" });
    const trouble = await real("rpc/comment_trouble", { account, model_id: root.model });
    if (trouble) return reply(200, { refused: trouble });
    if (root.hidden_at || !(await shown(root.author))) return reply(200, { refused: "no_comment" });
    const made = await real("rpc/add_comment", { account, model_id: root.model, at_version: root.version,
      at_step: root.step, said });
    if (made?.refused) return reply(200, made);
    parents.set(made.comment.id, root.id);
    return reply(200, { comment: { ...made.comment, parent: root.id }, owner: made.owner, model: root.model });
  },
  async admin_comments({ wanted }) {
    const rows = await real("rpc/admin_comments", { wanted: wanted ?? null });
    return reply(200, (rows || []).map((row) => ({ ...row, parent: parents.get(row.id) ?? null })));
  },
  async notification_list({ viewer, mark }) {
    if (!viewer) return reply(200, null);
    const page = await real("rpc/notification_list", { viewer, mark: mark === true });
    const rows = await noticeRows(viewer, page.rows || []);
    const more = [...new Set(rows.map((r) => r.on))].filter((id) => !page.models[id]);
    const models = more.length ? await real(`shared_models?id=in.(${more.join(",")})&select=id,name,has_image,has_thumb,updated_at`) : [];
    return reply(200, { ...page, rows,
      models: { ...page.models, ...Object.fromEntries(models.map(({ id, ...rest }) => [id, rest])) },
      reads: { ...page.reads, ...Object.fromEntries([...(reads.get(viewer) || new Map())]) } });
  },
  async notification_counts({ viewer }) {
    if (!viewer) return reply(200, null);
    const both = await real("rpc/notification_counts", { viewer });
    const page = await real("rpc/notification_list", { viewer, mark: false });
    const seen = time(page.seen_at);
    const rows = await noticeRows(viewer, page.rows || []);
    const fresh = rows.filter((r) => !Number.isFinite(seen) || time(r.at) > seen).length;
    return reply(200, { ...both, notifications: Math.min(fresh, 99) });
  },
  async notification_read({ viewer, model }) {
    const said = await real("rpc/notification_read", { viewer, model: model ?? null });
    if (model === null || model === undefined) reads.delete(viewer);
    if (said?.refused !== "nobody") return reply(200, said);
    const on = await real("rpc/comments_on", { model_id: model, asker: viewer });
    if (!(on?.comments || []).some((one) => one.mine)) return reply(200, said);
    if (!reads.has(viewer)) reads.set(viewer, new Map());
    reads.get(viewer).set(model, new Date().toISOString());
    return reply(200, { read: true });
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
  console.log(`replies.sql held here: ${NAMES.length} functions over the project's comments and notifications`);
}

/// What is held now, for a check to read (/__held/comment_parents).
export function rowsOf(name) {
  if (name === "comment_parents") return [...parents].map(([id, parent]) => ({ id, parent }));
  return null;
}
