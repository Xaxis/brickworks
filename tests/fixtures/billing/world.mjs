// Everything api/_billing.js, api/plans.js and api/account.js's deletion
// talk to, in memory, behind the one fetch: the stand-in Admission
// (fake_admission.mjs), and the Supabase they use (the snapshot functions
// of supabase/admission_snapshots.sql, the keys sessions are signed with,
// and the auth that deletes an account).
// Every request any of them is sent is in [calls], so a test can say none
// was.
//
//   const w = await world({ billing: "test" });
//   const token = await w.signIn({ sub: "u1", email: "ada@example.com" });

import { webcrypto } from "node:crypto";
import { Readable } from "node:stream";
import { ADMISSION_URL, FAKE_KEY, fakeAdmission } from "./fake_admission.mjs";

export const SUPABASE_URL = "https://db.test";

const b64url = (bytes) => Buffer.from(bytes).toString("base64url");

/// One request through api/plans.js's handler, as Vercel would make it:
/// {status, json}, and {location} when it redirects. [raw], a string, is a
/// body as Vercel's helpers leave it: parsed as JSON into the body, and its
/// bytes to read again as the request's data (@vercel/node restoreBody).
export const askPlans = (asked) => ask("plans", asked);

/// One request through api/account.js's handler, as askPlans makes one.
export const askAccount = (asked) => ask("account", asked);

/// One request through api/admin.js's handler, as askPlans makes one.
export const askAdmin = (asked) => ask("admin", asked);

async function ask(route, { method = "GET", query = {}, headers = {}, body, raw } = {}) {
  const { default: handle } = await import(`../../../api/${route}.js`);
  let status = 0;
  let json = null;
  let location = null;
  const response = {
    setHeader: (name, value) => {
      if (name.toLowerCase() === "location") location = value;
      return response;
    },
    status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; },
    end: () => response,
  };
  let request = { method, query, headers, body };
  if (raw !== undefined) {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      parsed = undefined;
    }
    request = Object.assign(Readable.from([Buffer.from(raw)]), { method, query, headers, body: parsed });
  }
  await handle(request, response);
  return location === null ? { status, json } : { status, json, location };
}

export const GITHUB = "https://api.github.com";
const RELEASES = "/repos/Xaxis/brickworks-releases/releases";
/// v0.10.0's assets as GitHub lists them, by id.
const ASSETS = { 11: "Brickworks-0.10.0-linux-x86_64.AppImage", 12: "Brickworks-0.10.0-macos-universal.zip",
  13: "SHA256SUMS" };

export async function world({ billing = "", key = FAKE_KEY, master = "owner@example.com" } = {}) {
  process.env.SUPABASE_URL = SUPABASE_URL;
  process.env.SUPABASE_SECRET_KEY = "secret";
  process.env.SUPABASE_PUBLISHABLE_KEY = "publishable";
  process.env.ADMISSION_URL = ADMISSION_URL;
  process.env.MASTER_EMAIL = master;
  for (const [name, value] of [["BRICKWORKS_BILLING", billing], ["ADMISSION_KEY", key]]) {
    if (value) process.env[name] = value;
    else delete process.env[name];
  }
  const admission = fakeAdmission();
  const snapshots = new Map();
  // supabase/plan_consents.sql's rows, as plan_consent_note keeps them.
  const consents = [];
  const signer = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const jwk = { ...(await webcrypto.subtle.exportKey("jwk", signer.publicKey)), kid: "k1", alg: "ES256" };
  const self = {
    admission,
    snapshots,
    consents,
    /// plan_consents.sql not applied: its function answers 404.
    noConsents: false,
    /// The days supabase/desktop_paid_through.sql keeps, by account.
    paidThrough: new Map(),
    /// GitHub answering an asset's bytes with the bytes (a 200), as its API
    /// "may", instead of the 302 it gives.
    githubStreams: false,
    /// The authorization each request to GitHub carried, or null.
    githubAuth: [],
    /// Accounts Supabase's auth deleted (api/account.js ?op=delete), by id.
    deleted: [],
    /// Supabase's auth refusing to delete one, as an outage would.
    authDown: false,
    /// Every request, "METHOD url" without its query.
    calls: [],
    /// The snapshot store unreachable, as a database outage.
    storeDown: false,
    /// Every kept snapshot made [ms] older, as time passing would.
    age(ms) {
      for (const [key, value] of snapshots) {
        const snap = JSON.parse(value);
        if (snap.at) snapshots.set(key, JSON.stringify({ ...snap, at: snap.at - ms }));
      }
    },
    async signIn(claims) {
      const header = b64url(JSON.stringify({ alg: "ES256", kid: "k1", typ: "JWT" }));
      const body = b64url(JSON.stringify({ aud: "authenticated", iss: `${SUPABASE_URL}/auth/v1`,
        exp: Math.floor(Date.now() / 1000) + 3600, email_verified: true, amr: [{ method: "otp" }], ...claims }));
      const signature = await webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, signer.privateKey,
        new TextEncoder().encode(`${header}.${body}`));
      return `${header}.${body}.${b64url(signature)}`;
    },
  };
  const json = (status, body) => new Response(body === undefined ? "" : JSON.stringify(body), { status });
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    self.calls.push(`${(init.method || "GET").toUpperCase()} ${url.origin}${url.pathname}`);
    if (url.origin === ADMISSION_URL) return admission.fetch(input, init);
    if (url.origin === GITHUB) {
      const headers = new Headers(init.headers);
      self.githubAuth.push(headers.get("authorization"));
      if (url.pathname === `${RELEASES}/tags/v0.10.0`) {
        return json(200, { tag_name: "v0.10.0", assets: Object.entries(ASSETS).map(([id, name]) => ({
          id: Number(id), name, url: `${GITHUB}${RELEASES}/assets/${id}` })) });
      }
      const asset = new RegExp(`^${RELEASES}/assets/(\\d+)$`).exec(url.pathname);
      if (asset && ASSETS[asset[1]] && headers.get("accept") === "application/octet-stream") {
        if (self.githubStreams) return new Response("the bytes", { status: 200 });
        return new Response(null, { status: 302, headers: {
          location: `https://release-assets.githubusercontent.com/asset-${asset[1]}?se=soon&sig=signed` } });
      }
      return json(404, { message: "Not Found" });
    }
    if (url.origin !== SUPABASE_URL) throw new TypeError(`nothing here answers ${url.origin}`);
    if (url.pathname === "/auth/v1/.well-known/jwks.json") return json(200, { keys: [jwk] });
    const user = /^\/auth\/v1\/admin\/users\/([^/]+)$/.exec(url.pathname);
    if (user && init.method === "DELETE") {
      if (self.authDown) return json(500, { message: "down" });
      self.deleted.push(user[1]);
      return json(200, {});
    }
    if (self.storeDown) throw new TypeError("fetch failed");
    const asked = JSON.parse(String(init.body || "{}"));
    if (url.pathname === "/rest/v1/rpc/admission_snapshot_get") return json(200, snapshots.get(asked.p_key) ?? null);
    if (url.pathname === "/rest/v1/rpc/desktop_paid_through_get") {
      return json(200, self.paidThrough.get(asked.p_user) ?? null);
    }
    if (url.pathname === "/rest/v1/rpc/desktop_paid_through_put") {
      if (!(self.paidThrough.get(asked.p_user) >= asked.p_day)) self.paidThrough.set(asked.p_user, asked.p_day);
      return new Response(null, { status: 204 });
    }
    if (url.pathname === "/rest/v1/rpc/admission_snapshot_put") {
      snapshots.set(asked.p_key, asked.p_value);
      // 200, not 204: a Response refuses a 204 with a body, which threw
      // after the snapshot was kept, so the client took every put as failed.
      return json(200);
    }
    // No orangecheck account made by Connect (supabase/orangecheck_connect_leaving.sql).
    if (url.pathname === "/rest/v1/rpc/oc_connect_leaving") return json(200, false);
    if (url.pathname === "/rest/v1/rpc/plan_consent_note" && !self.noConsents) {
      consents.push(asked);
      return json(200);
    }
    return json(404, { message: "no such function" });
  };
  return self;
}
