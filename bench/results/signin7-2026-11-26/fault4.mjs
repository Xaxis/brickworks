// signreview4: faults put between a relay (tools/web/relay_server.mjs) and what it asks, so a
// check can see what each route does when the database is slow, refuses, or loses a reply, and
// when Supabase's verify is out; and an orangecheck that answers here and counts what reaches it.
//
//   FAULT4_FILE=/abs/rules.json FAULT4_LOG=/abs/log NODE_OPTIONS="--import=/abs/fault4.mjs" node relay_server.mjs ...
//
// The rules are read from FAULT4_FILE on every request, so a check changes them while the relay
// runs (an absent or empty file: no faults). Each key is optional:
//   {"verify429": true}                         /auth/v1/verify answered 429, never asked
//   {"slow": {"rpc/session_standing": 16000}}   that path waited on this long, then asked
//   {"fail": {"rpc/session_standing": 503}}     that path answered with this status, never asked
//   {"dropAfter": ["rpc/oauth_code_grant"]}     that path asked, and its reply then lost (fetch failed)
//   {"oc": ["oc-stand-in.invalid", ...]}        any request to these hosts answered here, 400, and counted
// Every fault and every orangecheck request is one line of FAULT4_LOG: "<ms> <kind> <path>".
import { appendFileSync, readFileSync } from "node:fs";

const FILE = process.env.FAULT4_FILE || "";
const LOG = process.env.FAULT4_LOG || "";
const note = (line) => {
  if (LOG) {
    try { appendFileSync(LOG, `${Date.now()} ${line}\n`); } catch { /* the log is not the test */ }
  }
};
const rules = () => {
  try { return JSON.parse(readFileSync(FILE, "utf8") || "{}"); } catch { return {}; }
};
const real = globalThis.fetch;
const pathOf = (url) => {
  const rest = /\/rest\/v1\/([^?]+)/.exec(url.pathname);
  return rest ? rest[1] : url.pathname.replace(/^\/+/, "");
};
const waited = (ms, signal) => new Promise((done, refuse) => {
  const timer = setTimeout(done, ms);
  signal?.addEventListener?.("abort", () => { clearTimeout(timer); refuse(signal.reason); }, { once: true });
});

globalThis.fetch = async (input, init = {}) => {
  let url;
  try { url = new URL(typeof input === "string" ? input : input?.url || String(input)); } catch { return real(input, init); }
  const now = rules();
  const path = pathOf(url);
  if (Array.isArray(now.oc) && now.oc.includes(url.hostname)) {
    note(`oc ${url.hostname}${url.pathname}`);
    if (/jwks/.test(url.pathname)) return new Response(JSON.stringify({ keys: [] }), { status: 200, headers: { "content-type": "application/json" } });
    return new Response(JSON.stringify({ ok: false, error: "invalid_grant" }), { status: 400, headers: { "content-type": "application/json" } });
  }
  if (now.verify429 && url.pathname === "/auth/v1/verify") {
    note(`verify429 ${url.pathname}`);
    return new Response(JSON.stringify({ code: 429, msg: "over_request_rate_limit" }), { status: 429, headers: { "content-type": "application/json" } });
  }
  if (now.fail && now.fail[path]) {
    note(`fail${now.fail[path]} ${path}`);
    return new Response(JSON.stringify({ message: "stood in: the pooler refused" }), { status: Number(now.fail[path]),
      headers: { "content-type": "application/json" } });
  }
  if (now.slow && now.slow[path]) {
    note(`slow${now.slow[path]} ${path}`);
    await waited(Number(now.slow[path]), init?.signal);
  }
  const reply = await real(input, init);
  if (Array.isArray(now.dropAfter) && now.dropAfter.includes(path)) {
    note(`drop ${path} (answered ${reply.status}, lost)`);
    await reply.text().catch(() => "");
    throw new TypeError("fetch failed", { cause: Object.assign(new Error("other side closed"), { code: "UND_ERR_SOCKET" }) });
  }
  return reply;
};
