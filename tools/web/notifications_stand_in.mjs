// supabase/notifications.sql's functions, held in the local server's own
// process, for proving the API and the pages as they will be once the file
// is applied.
//
//   node --env-file=.env tools/web/relay_server.mjs 8820 --hold=notifications
//
// The file's two tables are reachable only through its functions, so what
// is held here is those the API asks: notification_list,
// notification_read, notification_counts and follow_page, answered as the
// SQL answers them. Their rows are read as the SQL reads them, from the
// real project: the live feed_rows split by kind, likes from model_likes a
// model a day, the models' pictures from shared_models. The marks are kept
// here, and an account with none has its feed's (read through feed_of,
// since feed_marks is the server's functions' alone); opening the feed
// marks the real feed_marks through feed_of, as follow_page does. A
// challenge's end is not read (challenge_winners is the functions' alone):
// tools/notifications_try.sql proves it in a rolled-back dry run, with the
// rest of the SQL, its grants and its cascades; this is for the code
// around it. What is held is at /__held/notification_marks and
// /__held/notification_reads, on this machine only.

const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const REST = `${SUPABASE}/rest/v1/`;
const NAMES = ["notification_list", "notification_read", "notification_counts", "follow_page"];
const DAY = 864e5;

const marks = new Map();
const reads = new Map();
let inner = null;

const reply = (status, value) => new Response(value === undefined ? "" : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });
const time = (iso) => (iso ? Date.parse(iso) : NaN);

async function real(path, body) {
  const answer = await inner(`${REST}${path}`, { method: body === undefined ? "GET" : "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body) });
  if (!answer.ok) throw new Error(`notifications stand-in: ${path.split("?")[0]} ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}

/// The feed's seen_at, as feed_of says it (not marking).
const feedSeen = async (viewer) => (await real("rpc/feed_of", { viewer, before: null, size: 1, mark: false }))?.seen_at ?? null;

/// notification_marks_of: the account's own, else its feed's.
async function marksOf(viewer) {
  if (marks.has(viewer)) return marks.get(viewer);
  const seen = await feedSeen(viewer);
  return { seen_at: seen, read_at: seen };
}

/// notification_marks_kept.
async function keep(viewer) {
  if (!marks.has(viewer)) marks.set(viewer, { account: viewer, ...(await marksOf(viewer)) });
  return marks.get(viewer);
}

const iso = (ms) => new Date(ms).toISOString();

/// notification_rows, from after [since] up to [until] (ms).
async function notificationRows(viewer, since, until) {
  const feed = await real("rpc/feed_rows", { viewer, since: iso(since), until: iso(until) });
  const rows = feed.filter((f) => f.kind === "comment" || f.kind === "remix" || (f.kind === "photo" && f.item.yours === true))
    .map((f) => ({ kind: f.kind, at: f.at, model: f.kind === "remix" ? f.item.of : f.item.model, item: f.item }));
  const mine = await real(`shared_models?owner=eq.${viewer}&published=is.true&barred=is.false&select=id,name`);
  if (mine.length) {
    const names = Object.fromEntries(mine.map((one) => [one.id, one.name]));
    const likes = await real(`model_likes?model=in.(${mine.map((one) => one.id).join(",")})&account=neq.${viewer}`
      + `&at=gt.${iso(since)}&at=lte.${iso(until)}&select=model,at`);
    const days = new Map();
    for (const like of likes) {
      const day = new Date(like.at).toISOString().slice(0, 10);
      const key = `${like.model} ${day}`;
      const row = days.get(key) || { kind: "likes", at: like.at, model: like.model,
        item: { model: like.model, name: names[like.model], likes: 0, day } };
      row.item.likes += 1;
      if (time(like.at) > time(row.at)) row.at = like.at;
      days.set(key, row);
    }
    rows.push(...days.values());
  }
  return rows;
}

/// follow_rows.
async function followRows(viewer, since, until) {
  const feed = await real("rpc/feed_rows", { viewer, since: iso(since), until: iso(until) });
  return feed.filter((f) => ["model", "version", "challenge"].includes(f.kind) || (f.kind === "photo" && f.item.yours !== true));
}

const newest = (a, b) => time(b.at) - time(a.at) || String(a.kind).localeCompare(String(b.kind));

const FUNCTIONS = {
  async notification_list({ viewer, mark }) {
    if (!viewer) return reply(200, null);
    const { seen_at, read_at } = await marksOf(viewer);
    const rows = (await notificationRows(viewer, Date.now() - 90 * DAY, Date.now())).sort(newest).slice(0, 200)
      .map((r) => ({ kind: r.kind, at: r.at, on: r.model, ...r.item }));
    const ids = [...new Set(rows.map((r) => r.on))];
    const models = ids.length ? await real(`shared_models?id=in.(${ids.join(",")})&select=id,name,has_image,has_thumb,updated_at`) : [];
    if (mark) (await keep(viewer)).seen_at = iso(Date.now());
    return reply(200, { rows, models: Object.fromEntries(models.map(({ id, ...rest }) => [id, rest])), seen_at, read_at,
      reads: Object.fromEntries([...(reads.get(viewer) || new Map())]) });
  },
  async notification_read({ viewer, model }) {
    if (!viewer) return reply(200, { refused: "sign_in" });
    const kept = await keep(viewer);
    if (model === null || model === undefined) {
      kept.read_at = kept.seen_at = iso(Date.now());
      reads.delete(viewer);
      return reply(200, { read: true });
    }
    const theirs = await real(`shared_models?id=eq.${encodeURIComponent(model)}&owner=eq.${viewer}&select=id`);
    if (!theirs.length) return reply(200, { refused: "nobody" });
    if (!reads.has(viewer)) reads.set(viewer, new Map());
    reads.get(viewer).set(model, iso(Date.now()));
    return reply(200, { read: true });
  },
  async notification_counts({ viewer }) {
    if (!viewer) return reply(200, null);
    const floor = Date.now() - 90 * DAY;
    const seen = time((await marksOf(viewer)).seen_at);
    const fed = time(await feedSeen(viewer));
    const notices = await notificationRows(viewer, Math.max(Number.isFinite(seen) ? seen : -Infinity, floor), Date.now());
    const feed = await followRows(viewer, Math.max(Number.isFinite(fed) ? fed : -Infinity, floor), Date.now());
    return reply(200, { notifications: Math.min(notices.length, 99), feed: Math.min(feed.length, 99) });
  },
  async follow_page({ viewer, before, size, mark }) {
    if (!viewer) return reply(200, null);
    const wanted = Math.min(Math.max(Number(size) || 30, 1), 50);
    const seen = await feedSeen(viewer);
    const until = before ? time(before) : Date.now();
    const rows = (await followRows(viewer, Date.now() - 90 * DAY, until)).filter((r) => !before || time(r.at) < until)
      .sort(newest);
    if (mark) {
      await keep(viewer);
      await real("rpc/feed_of", { viewer, before: null, size: 1, mark: true });
    }
    return reply(200, { rows: rows.slice(0, wanted).map((r) => ({ ...r.item, kind: r.kind, at: r.at })),
      more: rows.length > wanted, seen_at: seen });
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
  console.log(`notifications.sql held here: ${NAMES.length} functions over the project's feed_rows and likes`);
}

/// What a held table has now, for a check to read (/__held/<table>).
export function rowsOf(name) {
  if (name === "notification_marks") return [...marks.values()].map((row) => ({ ...row }));
  if (name === "notification_reads") {
    return [...reads].flatMap(([account, models]) => [...models].map(([model, at]) => ({ account, model, at })));
  }
  return null;
}
