// c3review's attack on console3 (/admin part C), beyond the unit's attack3:
//   G. forged owner tokens (a real signature over another payload; alg none)
//   L. delete's typed address: Unicode lookalikes, a zero-width space, mailto:
//   U. unbar_model: what unlist took, given back, and audited
//   X. export: another person's rows (a follower's account id) and secret-ish columns
//   S. sign out everywhere: the refresh token, the access token, Supabase's own word
//   N. the notice: RTL, 10,000 characters, every language's page and a server page
//      load it, and how long a cleared notice is still served
//   Q. console3.sql's functions and tables refused to the publishable key and to
//      a signed-in stranger (the live database, reads and harmless writes only)
//   R. run_cron with a name from Object's prototype, and the console's ops
//      named so (GET and POST): unknown, and never audited
// Only throwaways at resend.dev are made, and deleted at the end. Never the
// owner's account; never a notice on brickworks.diy (the preview's own scope only).
//
// The review's tool (bench/results/c3review-2026-11-15), kept here by c3fix,
// which fixed what it found: X (B's follower's account in B's export: now a
// count), R (run_cron and the ops: own names only). G's forged tokens are
// refused by the site (401), or before it by Vercel's firewall: an alg-none
// token is answered 403 with x-vercel-mitigated: deny and never reaches the
// function, which counts as refused.
//
//   set -a; . ./.env; set +a
//   node tools/web/c3attack.mjs <preview> [groups, e.g. GXR] > c3attack.out
import { mintSession, deleteAccount } from "./session.mjs";
import { randomBytes, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";

const site = String(process.argv[2] || "").replace(/\/+$/, "");
if (!/^https:\/\/brickworks-[a-z0-9-]+-xaxis-projects\.vercel\.app$/.test(site)) {
  console.error("c3attack: a preview of this project only");
  process.exit(2);
}
const only = new Set(String(process.argv[3] || "GLUXSNQR").split(""));
const bypass = process.env.VERCEL_BYPASS || "";
const base = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const PUBLISHABLE = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-c3rev-${who}-${rand}@resend.dev`;
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

let n = 0;
async function api(pathname, { method = "GET", token, body, extra = {}, fresh = true } = {}) {
  const headers = { ...base, ...extra };
  if (token) headers.authorization = `Bearer ${token}`;
  let sent;
  if (body !== undefined) {
    headers["content-type"] = "application/json";
    sent = JSON.stringify(body);
  }
  const where = fresh ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${n += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers, body: sent });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: reply.status, json, text, headers: reply.headers };
}
async function rest(pathname, { method = "GET", headers = secret, body } = {}) {
  const reply = await fetch(`${SUPABASE}${pathname}`, { method, headers: { ...headers, ...(body ? { "content-type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: reply.status, json, text };
}
const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString("base64url");
const unb64 = (part) => JSON.parse(Buffer.from(part, "base64url").toString("utf8"));

const rows = [];
let failed = 0;
const row = (group, attack, expected, got, ok) => {
  rows.push({ group, attack, expected, got, ok });
  if (!ok) failed += 1;
  console.log(`${ok ? "ok  " : "FAIL"}  ${group} ${attack}: expected ${expected}, got ${got}`);
};
const note = (group, what) => console.log(`note  ${group} ${what}`);

const made = [];
const models = [];
let owner = null;
let noticeSet = false;
const mint = async (who, options = {}) => {
  const one = await mintSession(address(who), { welcome: false, ...options });
  made.push({ email: one.kept.email, id: one.kept.user_id, who });
  return one;
};
const OPS = [["data", "GET"], ["find", "GET"], ["challenge_view", "GET"], ["switches", "GET"], ["unbar_model", "POST"],
  ["notice_set", "POST", { words: { en: `c3rev forged ${rand}` } }], ["notice_clear", "POST"], ["run_cron", "POST"],
  ["export", "POST"], ["delete_account", "POST"], ["sign_out", "POST"]];

try {
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
  const x = await mint("x");
  const sha = await api("/api/admin?op=site", { token: owner.access_token });
  note("-", `preview ${site}: site op ${sha.status}, release ${JSON.stringify(sha.json?.deployment || sha.json?.release || null).slice(0, 160)}`);

  // --- G. Forged owner tokens --------------------------------------------------
  if (only.has("G")) {
    const [h, p, s] = x.access_token.split(".");
    const claims = unb64(p);
    const swapped = `${h}.${b64({ ...claims, email: process.env.MASTER_EMAIL, email_verified: true })}.${s}`;
    const none = `${b64({ alg: "none", typ: "JWT" })}.${b64({ ...claims, email: process.env.MASTER_EMAIL })}.`;
    const hs = `${b64({ alg: "HS256", typ: "JWT", kid: unb64(h).kid })}.${b64({ ...claims, email: process.env.MASTER_EMAIL })}.${"A".repeat(43)}`;
    const expired = `${h}.${b64({ ...claims, exp: 1 })}.${s}`;
    for (const [op, method, body] of OPS) {
      const q = `/api/admin?op=${op}&tests=1&account=${x.kept.user_id}&job=gallery_feature&id=AbCdEfGhIj&q=resend&challenge=1`;
      // 401 from the site, or "fw" where Vercel's firewall refused it before the function ran.
      const refusal = (one) => (one.status === 403 && one.headers.get("x-vercel-mitigated") === "deny" ? "fw" : String(one.status));
      const got = [];
      for (const token of [swapped, none, hs, expired]) got.push(refusal(await api(q, { method, body, token })));
      const cross = refusal(await api(q, { method, body, extra: { origin: "https://evil.example", cookie: "sb-access-token=x" } }));
      row("G", `${method} ${op}: X's signature over the owner's address / alg none / HS256 / exp moved / a cookie from another origin`,
        "401 401|fw 401 401 401", `${got.join(" ")} ${cross}`, [...got, cross].every((one) => one === "401" || one === "fw"));
    }
  }

  // --- L. Delete's typed address ----------------------------------------------
  if (only.has("L")) {
    const v = await mint("v");
    const addr = v.kept.email;
    const tries = [
      ["Cyrillic е for the first e", addr.replace("e", "е")],
      ["a zero-width space after +", addr.replace("+", "+​")],
      ["a fullwidth ＠", addr.replace("@", "＠")],
      ["mailto: before it", `mailto:${addr}`],
      ["two addresses, comma", `${addr},${addr}`],
      ["its account id", v.kept.user_id],
    ];
    for (const [what, confirm] of tries) {
      const out = await as(`/api/admin?op=delete_account&account=${v.kept.user_id}`, { method: "POST", body: { confirm, reason: "c3rev" } });
      row("L", `delete V typed with ${what}`, "422", `${out.status}`, out.status === 422);
    }
    const there = await rest(`/auth/v1/admin/users/${v.kept.user_id}`);
    row("L", "V still there after every refusal", "200", `${there.status}`, there.status === 200);
    const right = await as(`/api/admin?op=delete_account&account=${v.kept.user_id}`, { method: "POST",
      body: { confirm: `  ${addr.toUpperCase()}\t`, reason: "c3rev: the right one, padded" } });
    const gone = await rest(`/auth/v1/admin/users/${v.kept.user_id}`);
    row("L", "V's address upper-cased with a no-break space and a tab round it", "200, V gone", `${right.status}, ${gone.status}`,
      right.status === 200 && gone.status === 404);
    note("L", `answer: ${JSON.stringify(right.json).slice(0, 300)}`);
  }

  // --- U. unbar_model ---------------------------------------------------------
  const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
  const publish = async (who, name) => {
    const model = `0 ${name}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n`;
    const shared = await api("/api/share", { method: "POST", token: who.access_token, body: { name, author: "C3 Review", model, image: picture, listed: true } });
    if (shared.json?.id) models.push({ id: shared.json.id, token: who.access_token });
    return shared;
  };
  if (only.has("U")) {
    const u = await mint("u");
    const shared = await publish(u, `C3rev Unbar ${rand}`);
    const id = shared.json?.id;
    row("U", "U published a listed model", "an id", `${id || shared.status} ${JSON.stringify(shared.json).slice(0, 120)}`, Boolean(id));
    if (id) {
      const state = async () => (await rest(`/rest/v1/shared_models?id=eq.${id}&select=listed,listed_at,barred`)).json?.[0];
      const fileRow = async () => (await rest(`/rest/v1/barred_models?model=eq.${id}&select=hash,model`)).json || [];
      const before = await state();
      const out = await as(`/api/admin?op=unlist&id=${id}&tests=1`, { method: "POST" });
      const taken = await state();
      const filed = await fileRow();
      row("U", "unlist: listed false, barred true, its file refused", "200 false true 1",
        `${out.status} ${taken?.listed} ${taken?.barred} ${filed.length}`, out.status === 200 && taken?.listed === false && taken?.barred === true && filed.length === 1);
      const back = await as(`/api/admin?op=unbar_model&id=${id}&tests=1`, { method: "POST" });
      const after = await state();
      const filedAfter = await fileRow();
      row("U", "unbar_model: barred false, its file no longer refused, still not listed (its owner lists it)", "200 false 0 false",
        `${back.status} ${after?.barred} ${filedAfter.length} ${after?.listed}`, back.status === 200 && after?.barred === false && filedAfter.length === 0 && after?.listed === false);
      note("U", `before ${JSON.stringify(before)}, after ${JSON.stringify(after)}; answer ${JSON.stringify(back.json)}`);
      const audit = await as(`/api/admin?op=audit&tests=1&act=unbar_model`);
      const kept = (audit.json?.rows || []).find((r) => r.target === id);
      row("U", "unbar_model kept in the audit on the model", "200 model", kept ? `${kept.status} ${kept.target_kind}` : "NOT KEPT",
        kept?.status === 200 && kept?.target_kind === "model");
      // Its owner lists it again, as the console says they may.
      const again = await publish(u, `C3rev Unbar ${rand}`);
      const relisted = await api(`/api/share?op=list&id=${id}`, { method: "POST", token: u.access_token, body: { listed: true } });
      const last = await state();
      note("U", `owner republished: ${again.status} ${JSON.stringify(again.json).slice(0, 160)}; op=list ${relisted.status} ${relisted.text.slice(0, 160)}; now ${JSON.stringify(last)}`);
    }
  }

  // --- X. Export ----------------------------------------------------------------
  if (only.has("X")) {
    const a = await mint("a");
    const b = await mint("b");
    const handleB = `c3rev-b-${rand}`;
    const prof = await api("/api/people?op=profile", { method: "POST", token: b.access_token, body: { handle: handleB, name: "C3 Review B" } });
    const fol = await api("/api/people?op=follow", { method: "POST", token: a.access_token, body: { handle: handleB, on: true } });
    note("X", `B's profile ${prof.status}, A follows B ${fol.status} ${fol.text.slice(0, 100)}`);
    const counts = await api(`/api/people?op=follows&handle=${handleB}`);
    note("X", `what a visitor reads of B's followers: ${counts.text.slice(0, 200)}`);
    const page = await api(`/u/${handleB}?tests=1`, { fresh: false });
    row("X", "B's public page never names A's account", "absent", page.text.includes(a.kept.user_id) ? "PRESENT" : "absent",
      !page.text.includes(a.kept.user_id));
    const out = await as(`/api/admin?op=export&account=${b.kept.user_id}&tests=1`, { method: "POST" });
    const text = JSON.stringify(out.json);
    row("X", "B's export holds no other account's id (A follows B)", "A's id absent",
      text.includes(a.kept.user_id) ? `A's id PRESENT in ${Object.entries(out.json?.tables || {}).filter(([, list]) => JSON.stringify(list).includes(a.kept.user_id)).map(([name]) => name).join(", ")}` : "absent",
      !text.includes(a.kept.user_id));
    row("X", "B's export counts A as a follower, in no table", "followers 1, no follows.followed",
      `followers ${out.json?.followers}, ${"follows.followed" in (out.json?.tables || {}) || "follows.followed" in (out.json?.counts || {}) ? "follows.followed THERE" : "no follows.followed"}`,
      out.json?.followers === 1 && !("follows.followed" in (out.json?.tables || {})) && !("follows.followed" in (out.json?.counts || {}))
        && !("follows.followed" in (out.json?.more || {})));
    // A's own export keeps whom A follows: A's act, A's data.
    const mine = await as(`/api/admin?op=export&account=${a.kept.user_id}&tests=1`, { method: "POST" });
    row("X", "A's export keeps that A follows B", "follows.follower names B",
      `${(mine.json?.tables?.["follows.follower"] || []).map((one) => (one.followed === b.kept.user_id ? "B" : "other")).join(",") || "none"}`,
      (mine.json?.tables?.["follows.follower"] || []).some((one) => one.followed === b.kept.user_id));
    note("X", `export tables: ${JSON.stringify(out.json?.counts)}; followers ${out.json?.followers}`);
    // Secret-ish columns anywhere in an export of a real-shaped account: names only.
    const keys = new Set();
    const walk = (value, at) => {
      if (Array.isArray(value)) value.forEach((one) => walk(one, at));
      else if (value && typeof value === "object") for (const [k, v] of Object.entries(value)) { keys.add(`${at}.${k}`); walk(v, at); }
    };
    for (const [name, list] of Object.entries(out.json?.tables || {})) walk(list, name);
    note("X", `columns exported: ${[...keys].sort().join(" ")}`);
  }

  // --- S. Sign out everywhere ----------------------------------------------------
  if (only.has("S")) {
    const s = await mint("s");
    const fresh = await rest("/auth/v1/token?grant_type=refresh_token", { method: "POST", headers: { apikey: PUBLISHABLE },
      body: { refresh_token: s.kept.refresh_token } });
    const access = fresh.json?.access_token || s.access_token;
    const refresh = fresh.json?.refresh_token || s.kept.refresh_token;
    const out = await as(`/api/admin?op=sign_out&account=${s.kept.user_id}&tests=1`, { method: "POST" });
    row("S", "sign_out S", "200, sessions >= 1", `${out.status}, ${JSON.stringify(out.json)}`, out.status === 200 && out.json?.sessions >= 1);
    const renew = await rest("/auth/v1/token?grant_type=refresh_token", { method: "POST", headers: { apikey: PUBLISHABLE }, body: { refresh_token: refresh } });
    row("S", "S's refresh token after", "400", `${renew.status}`, renew.status >= 400);
    const gotrue = await rest("/auth/v1/user", { headers: { apikey: PUBLISHABLE, authorization: `Bearer ${access}` } });
    const ours = await api("/api/admin?op=data", { token: access });
    const rls = await rest(`/rest/v1/people?account=eq.${s.kept.user_id}&select=account`, { headers: { apikey: PUBLISHABLE, authorization: `Bearer ${access}` } });
    note("S", `S's access token after sign_out: Supabase /auth/v1/user ${gotrue.status}; the site's verify (op=data, a non-owner's 404 = accepted) ${ours.status}; PostgREST with it ${rls.status}`);
  }

  // --- N. The notice ----------------------------------------------------------------
  if (only.has("N")) {
    const long = await as("/api/admin?op=notice_set&tests=1", { method: "POST", body: { words: { en: "x".repeat(10000) } } });
    row("N", "10,000 characters", "400", `${long.status}`, long.status === 400);
    const rtl = "تحديث الموقع الساعة 02:00 UTC — c3rev";
    const set = await as("/api/admin?op=notice_set&tests=1", { method: "POST", body: { words: { en: `${rtl} ${rand}`, es: `Mantenimiento ${rand} <i>x</i>` }, tone: "info" } });
    noticeSet = set.status === 200;
    row("N", "set on this preview (scope its own)", "200, scope not live", `${set.status}, ${set.json?.scope}`, set.status === 200 && set.json?.scope !== "live");
    const pub = await api("/api/plans?op=notice", { fresh: false });
    note("N", `public answer: ${pub.status} cache-control ${pub.headers.get("cache-control")} ${pub.text.slice(0, 200)}`);
    for (const path of ["/es/gallery", "/fr/faq", "/de/plans", "/admin", "/404"]) {
      const page = await api(path, { fresh: false });
      row("N", `${path} loads theme.js (which loads notice.js)`, "yes", `${page.status} ${/\/theme\.js/.test(page.text) ? "yes" : "NO"}`, /\/theme\.js/.test(page.text));
    }
    if (models.length) {
      const m = await api(`/m/${models[0].id}?tests=1`, { fresh: false });
      row("N", "a server page (/m/<id>) loads theme.js", "yes", `${m.status} ${/\/theme\.js/.test(m.text) ? "yes" : "NO"}`, /\/theme\.js/.test(m.text));
    }
    const app = await api("/app", { fresh: false });
    note("N", `/app (the studio) loads theme.js: ${app.status} ${/\/theme\.js/.test(app.text) ? "yes" : "no"}; notice.js: ${/notice\.js/.test(app.text) ? "yes" : "no"}`);
    // Warm the CDN's copy, clear, and time how long the cleared notice is still served.
    for (let i = 0; i < 3; i += 1) { await api("/api/plans?op=notice", { fresh: false }); await wait(1500); }
    const warm = await api("/api/plans?op=notice", { fresh: false });
    note("N", `warm: x-vercel-cache ${warm.headers.get("x-vercel-cache")}, age ${warm.headers.get("age")}, notice ${warm.json?.notice ? "showing" : "none"}`);
    const cleared = await as("/api/admin?op=notice_clear&tests=1", { method: "POST" });
    noticeSet = cleared.status !== 200;
    const at = Date.now();
    let seconds = null;
    let seen = [];
    while (Date.now() - at < 420000) {
      const one = await api("/api/plans?op=notice", { fresh: false });
      seen.push(`${Math.round((Date.now() - at) / 1000)}s:${one.json?.notice ? "showing" : "none"}/${one.headers.get("x-vercel-cache")}`);
      if (!one.json?.notice) { seconds = Math.round((Date.now() - at) / 1000); break; }
      await wait(5000);
    }
    row("N", "a cleared notice stops being served within two minutes (the console says 'within a minute or two')", "<= 120 s",
      seconds === null ? "still served after 420 s" : `${seconds} s`, seconds !== null && seconds <= 120);
    note("N", `polls: ${seen.join(" ")}`);
  }

  // --- Q. console3.sql's grants on the database ------------------------------------
  if (only.has("Q")) {
    const anon = { apikey: PUBLISHABLE, authorization: `Bearer ${PUBLISHABLE}` };
    const signed = { apikey: PUBLISHABLE, authorization: `Bearer ${x.access_token}` };
    const probes = [
      ["rpc/admin_export", { p_account: randomUUID() }],
      ["rpc/admin_find", { p_query: "resend", p_tests: true }],
      ["rpc/admin_usage", {}],
      ["rpc/admin_person_more", { p_account: randomUUID() }],
      ["rpc/challenge_admin_entries", { p_challenge: 1 }],
      ["rpc/site_notice", { p_scope: "live" }],
      ["rpc/site_notices_list", { p_scope: "live", p_limit: 1 }],
      ["rpc/site_settings_list", {}],
      ["rpc/site_env_list", {}],
      ["rpc/admin_sign_out", { p_account: randomUUID() }],
      ["rpc/site_notice_clear", { p_scope: "c3rev-probe.invalid", p_by: "c3rev" }],
    ];
    for (const [fn, body] of probes) {
      const one = await rest(`/rest/v1/${fn}`, { method: "POST", headers: anon, body });
      const two = await rest(`/rest/v1/${fn}`, { method: "POST", headers: signed, body });
      row("Q", `${fn} as the publishable key / a signed-in stranger`, "refused both", `${one.status} / ${two.status}`,
        one.status >= 400 && two.status >= 400);
    }
    for (const table of ["site_notices", "site_env"]) {
      const one = await rest(`/rest/v1/${table}?select=*&limit=1`, { headers: anon });
      const two = await rest(`/rest/v1/${table}?select=*&limit=1`, { headers: signed });
      row("Q", `select ${table} as the publishable key / a signed-in stranger`, "refused both", `${one.status} / ${two.status}`,
        one.status >= 400 && two.status >= 400);
    }
  }

  // --- R. run_cron with a name from Object's prototype ------------------------------
  if (only.has("R")) {
    for (const job of ["constructor", "__proto__", "hasOwnProperty"]) {
      const out = await as(`/api/admin?op=run_cron&job=${job}&tests=1`, { method: "POST" });
      row("R", `run_cron job=${job}`, "400 (not a cron)", `${out.status} ${String(out.json?.error || "").slice(0, 80)}`, out.status === 400);
    }
    // The console's own ops named from Object's prototype: unknown (404), and never audited as an act.
    // The audit's newest row, the test acts' and the others'.
    const lastAudit = async () => Math.max(0, ...(await Promise.all(["/api/admin?op=audit&tests=1", "/api/admin?op=audit"]
      .map(async (path) => (await as(path)).json?.rows?.[0]?.id ?? 0))));
    const before = await lastAudit();
    for (const op of ["constructor", "__proto__", "hasOwnProperty", "toString"]) {
      const get = await as(`/api/admin?op=${op}&tests=1`);
      const post = await as(`/api/admin?op=${op}&tests=1`, { method: "POST" });
      row("R", `op=${op} GET / POST`, "404 / 404", `${get.status} / ${post.status}`, get.status === 404 && post.status === 404);
    }
    const after = await lastAudit();
    row("R", "...none of them audited", "the audit's newest row unchanged", `${before} -> ${after}`, before === after);
  }
} catch (trouble) {
  failed += 1;
  console.log(`FAIL  the run stopped: ${trouble?.stack || trouble}`);
} finally {
  if (noticeSet && owner) await api("/api/admin?op=notice_clear&tests=1", { method: "POST", token: owner.access_token }).catch(() => null);
  for (const m of models) await api(`/api/share?op=unpublish&id=${m.id}`, { method: "POST", token: m.token }).catch(() => null);
  for (const m of models) await rest(`/rest/v1/reports?model=eq.${m.id}`, { method: "DELETE" }).catch(() => null);
  let gone = 0;
  for (const one of made) {
    const there = await rest(`/auth/v1/admin/users/${one.id}`);
    if (there.status === 404 || await deleteAccount(one.email).catch(() => false)) gone += 1;
  }
  console.log(`throwaways made ${made.length}, left behind ${made.length - gone}`);
  console.log(`c3attack: ${rows.length - failed} of ${rows.length} as expected`);
  console.log(`JSON ${JSON.stringify(rows)}`);
}
