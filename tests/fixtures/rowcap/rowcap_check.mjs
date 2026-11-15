// The api's counts past PostgREST's page of 1,000 rows (tests/test_row_cap.py).
//
// A stand-in for the project's PostgREST that answers as Supabase's does
// here: at most 1,000 rows a read whatever the limit asked (max-rows), the
// whole count in Content-Range when asked with Prefer: count=exact, and
// offset honoured. Its tables hold 1,500 likes of one model on one day,
// 1,500 published models of one owner (the first of them the liked one) and
// 1,500 of that owner's tabs; then the real handlers count them. Prints one
// line of JSON.
import http from "node:http";

const N = 1500;
const MOST = 1000;
const OWNER = "11111111-1111-4111-8111-111111111111";
const LIKER = (n) => `22222222-2222-4222-8222-${String(n).padStart(12, "0")}`;
const MODEL = "M000000000";
const DAY = new Date(Date.now() - 3 * 864e5).toISOString().slice(0, 10);
const tables = {
  model_likes: Array.from({ length: N }, (_, n) => ({ model: MODEL, account: LIKER(n), at: `${DAY}T10:00:00.000Z` })),
  shared_models: Array.from({ length: N }, (_, n) => ({ id: `M${String(n).padStart(9, "0")}`, owner: OWNER, listed: true,
    name: `m${n}`, has_image: false, has_thumb: false, updated_at: `${DAY}T09:00:00.000Z` })),
  relay_tabs: Array.from({ length: N }, (_, n) => ({ channel: String(n).padStart(64, "0"), owner: OWNER, tab: `t${n}`,
    model: null, open: false, visible: false, seen_at: `${DAY}T08:00:00.000Z`, used_at: null })),
  people: [{ account: OWNER, handle: "owner", name: "Owner" }],
  barred_accounts: [],
  relay_picks: [],
  oauth_grants: [],
  relay_call_days: [],
};
const rpc = {
  feed_of: { rows: [], seen_at: null },
  beta_testers_list: { testers: [] },
};

const server = http.createServer((request, response) => {
  const url = new URL(request.url, "http://here");
  const send = (status, body, headers = {}) => {
    response.writeHead(status, { "content-type": "application/json", ...headers });
    response.end(request.method === "HEAD" ? "" : JSON.stringify(body));
  };
  if (url.pathname === "/auth/v1/admin/users") {
    return send(200, { users: [{ id: OWNER, email: "owner@example.com", created_at: `${DAY}T00:00:00Z` }] });
  }
  const [, , , name] = url.pathname.split("/");
  if (name === "rpc") return send(200, rpc[url.pathname.split("/")[4]] ?? null);
  const rows = tables[name];
  if (!rows) return send(404, { message: "no such table" });
  // Only the filters these reads use that narrow anything: the model's likes
  // by model, the owner's by owner.
  let kept = rows;
  const model = url.searchParams.get("model");
  if (model && model.startsWith("in.(")) kept = kept.filter((row) => model.slice(4, -1).split(",").includes(row.model));
  const offset = Number(url.searchParams.get("offset") || 0);
  const limit = Math.min(Number(url.searchParams.get("limit") || Infinity), MOST);
  const page = kept.slice(offset, offset + limit);
  const counted = /count=exact/.test(String(request.headers.prefer || ""));
  return send(200, page, { "content-range": `${offset}-${offset + page.length - 1}/${counted ? kept.length : "*"}` });
});
await new Promise((done) => server.listen(0, "127.0.0.1", done));
process.env.SUPABASE_URL = `http://127.0.0.1:${server.address().port}`;
process.env.SUPABASE_SECRET_KEY = "a-secret";

const out = {};
try {
  const { listBefore } = await import("../../../api/_notifications.js");
  const before = await listBefore(OWNER, false);
  out.likes = before.rows.filter((row) => row.kind === "likes").reduce((sum, row) => sum + row.likes, 0);
  const { people } = await import("../../../api/_console.js");
  const owner = (await people(false)).people.find((one) => one.id === OWNER);
  out.models = owner.models;
  out.connectors = owner.connectors;
  const { connectorRead } = await import("../../../api/_console_connector.js");
  const account = (await connectorRead(false)).accounts.find((one) => one.account === OWNER);
  out.tabs = account ? account.tabs.length : 0;
} catch (trouble) {
  out.error = String(trouble?.stack || trouble);
}
server.close();
console.log(JSON.stringify(out));
