// c3review: one export (a resend.dev test account's id only), its status,
// Vercel's error header, its size, and what the audit kept of it; then the
// same account's rows counted table by table from admin_export directly.
// It passes (exit 0) when the export answers 200 in under 3 s.
//
// Kept by c3fix: the review's busy account (3d2df783, a thousand connector
// tabs, each with a 110 KB tool list) timed out about half the time, 6 to
// 10 s; console3b.sql's admin_export never reads the hidden columns.
//
//   set -a; . ./.env; set +a
//   node tools/web/c3export_one.mjs <preview> <account id or its first 8>
import { mintSession } from "./session.mjs";

const site = String(process.argv[2] || "").replace(/\/+$/, "");
const prefix = String(process.argv[3] || "");
if (!/^https:\/\/brickworks-[a-z0-9-]+-xaxis-projects\.vercel\.app$/.test(site) || !/^[0-9a-f-]{8,36}$/.test(prefix)) process.exit(2);
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const secret = { apikey: process.env.SUPABASE_SECRET_KEY, authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY}` };
const everyone = [];
for (let page = 1; page < 20; page += 1) {
  const listed = (await (await fetch(`${SUPABASE}/auth/v1/admin/users?page=${page}&per_page=1000`, { headers: secret })).json()).users || [];
  everyone.push(...listed);
  if (listed.length < 1000) break;
}
const id = everyone.find((u) => u.id.startsWith(prefix))?.id || "";
console.log(`account ${id}`);
const user = await (await fetch(`${SUPABASE}/auth/v1/admin/users/${id}`, { headers: secret })).json();
if (!/@resend\.dev$/i.test(user.email || "")) { console.log("not a test account: stopped"); process.exit(2); }
const base = { "x-vercel-protection-bypass": process.env.VERCEL_BYPASS || "", "x-vercel-skip-toolbar": "1" };
const owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
const at = Date.now();
const reply = await fetch(`${site}/api/admin?op=export&account=${id}&tests=1`, { method: "POST",
  headers: { ...base, authorization: `Bearer ${owner.access_token}` } });
const text = await reply.text();
const seconds = (Date.now() - at) / 1000;
console.log(`export: ${reply.status} in ${seconds.toFixed(1)} s, ${text.length} bytes, x-vercel-error ${reply.headers.get("x-vercel-error")}, `
  + `x-vercel-id ${reply.headers.get("x-vercel-id")}; body ${text.slice(0, 200)}`);
const audit = await (await fetch(`${site}/api/admin?op=audit&tests=1&act=export`, { headers: { ...base, authorization: `Bearer ${owner.access_token}` } })).json();
const kept = (audit.rows || []).filter((r) => r.target === id).slice(0, 2);
console.log(`audit: ${JSON.stringify(kept.map((r) => ({ id: r.id, status: r.status, said: r.said, detail: r.detail })))}`);
// The function's own size, straight from the database (what the deployment would have answered).
const direct = await fetch(`${SUPABASE}/rest/v1/rpc/admin_export`, { method: "POST", headers: { ...secret, "content-type": "application/json" },
  body: JSON.stringify({ p_account: id }) });
const body = await direct.text();
let json = null;
try { json = JSON.parse(body); } catch { /* not JSON */ }
console.log(`admin_export direct: ${direct.status}, ${(body.length / 1048576).toFixed(2)} MB; more ${JSON.stringify(json?.more || {})}; tables ${Object.entries(json?.tables || {})
  .map(([name, list]) => [name, list.length, JSON.stringify(list).length]).sort((a, b) => b[2] - a[2]).slice(0, 6)
  .map(([name, n, bytes]) => `${name} ${n} rows ${(bytes / 1048576).toFixed(2)} MB`).join(", ")}`);
const passed = reply.status === 200 && seconds < 3;
console.log(`c3export_one: ${passed ? "PASS" : "FAIL"} (${reply.status} in ${seconds.toFixed(2)} s; the bar is 200 in under 3 s)`);
process.exit(passed ? 0 : 1);
