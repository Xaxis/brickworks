// Everything api/_billing.js, api/plans.js and api/account.js's deletion
// talk to, in memory, behind the one fetch: the stand-in Admission
// (fake_admission.mjs), and the Supabase they use (the snapshot functions
// of supabase/admission_snapshots.sql, the keys sessions are signed with,
// and the auth that deletes an account).
// Every request any of them is sent is in [calls], so a test can say none
// was. And api/models.js's account_models (supabase/account_models.sql,
// account_models_delete.sql, account_models_plan.sql), in [models], kept
// as those functions keep it. And photos of real builds (supabase/builds.sql)
// in [photos], each {id, account, model}, read by an account's deletion,
// whose files' deletions are kept in [storageDeletes], each request's
// names.
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

/// One request through api/models.js's handler: {status, json}.
export async function askModels({ method = "GET", query = {}, headers = {}, body } = {}) {
  const { default: handle } = await import("../../../api/models.js");
  let status = 0;
  let json = null;
  const response = {
    setHeader: () => response,
    status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; },
    end: () => response,
  };
  await handle({ method, query, headers, body }, response);
  return { status, json };
}

/// save_account_model, save_account_model_within and save_account_model_any
/// on [mine] (an account's models, by name): what they answer, and whether
/// it is a refusal. [totals] is how many models the account may keep in
/// all, the 500 of save_account_model (a test sets fewer), or null for
/// save_account_model_any's none; the 64 MB is not held here.
function saveModel(mine, a, most, totals) {
  const there = mine.get(a.p_name);
  if (there && there.sum === a.p_sum) return { name: a.p_name, version: there.version, same: true };
  const row = { version: 1, sum: a.p_sum, model: a.p_model, parts: a.p_parts, raw_bytes: a.p_raw_bytes,
    saved_at: new Date().toISOString() };
  if (there && there.version === a.p_base) {
    mine.set(a.p_name, { ...row, version: there.version + 1 });
    return { name: a.p_name, version: there.version + 1 };
  }
  let free = a.p_name;
  for (let n = 2; mine.has(free); n += 1) free = `${a.p_name} ${n}`;
  if (totals !== null && mine.size + 1 > totals) return { refused: "models: too many" };
  if (most !== null && mine.size + 1 > most) return { refused: "models: plan" };
  mine.set(free, row);
  return { name: free, version: 1, ...(there ? { conflict: free } : {}) };
}

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
    /// Accounts Supabase's auth deleted (api/account.js ?op=delete), by id.
    deleted: [],
    /// Supabase's auth refusing to delete one, as an outage would.
    authDown: false,
    /// supabase/trust.sql applied and every account not asked its age yet
    /// (rpc/age_of); off, the function answers 404, as before trust.sql.
    ageAsk: false,
    /// Every request, "METHOD url" without its query.
    calls: [],
    /// build_photos' rows, {id, account, model}; none, its table answers 404
    /// as before builds.sql.
    photos: null,
    /// The names each storage DELETE of build-photos asked for.
    storageDeletes: [],
    /// The models each account keeps, by owner, then by name.
    models: new Map(),
    /// Each save the database was asked, {fn, body}, as sent.
    saves: [],
    /// supabase/account_models_plan.sql not applied.
    noPlanSql: false,
    /// supabase/account_models_any.sql not applied.
    noAnySql: false,
    /// How many models save_account_model keeps in all (its 500).
    mostModels: 500,
    /// save_account_model_any refusing a save: the hour's most saved (too fast).
    tooFast: false,
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
    if (url.pathname === "/rest/v1/rpc/admission_snapshot_put") {
      snapshots.set(asked.p_key, asked.p_value);
      // 200, not 204: a Response refuses a 204 with a body, which threw
      // after the snapshot was kept, so the client took every put as failed.
      return json(200);
    }
    const mine = (owner) => {
      if (!self.models.has(owner)) self.models.set(owner, new Map());
      return self.models.get(owner);
    };
    const save = /^\/rest\/v1\/rpc\/(save_account_model(_within|_any)?)$/.exec(url.pathname);
    if (save) {
      self.saves.push({ fn: save[1], body: String(init.body) });
      const gone = save[2] === "_within" ? self.noPlanSql : save[2] === "_any" ? self.noAnySql : false;
      if (gone) return json(404, { code: "PGRST202", message: "Could not find the function" });
      if (save[2] === "_any" && self.tooFast) return json(400, { code: "P0001", message: "models: too fast" });
      const kept = saveModel(mine(asked.p_owner), asked, save[2] === "_within" ? asked.p_most : null,
        save[2] === "_any" ? null : self.mostModels);
      return kept.refused ? json(400, { code: "P0001", message: kept.refused }) : json(200, kept);
    }
    if (url.pathname === "/rest/v1/rpc/delete_account_model") {
      const there = mine(asked.p_owner).get(asked.p_name);
      if (!there) return json(200, { name: asked.p_name, gone: true });
      if (there.version !== asked.p_version) return json(200, { name: asked.p_name, kept: there.version });
      mine(asked.p_owner).delete(asked.p_name);
      return json(200, { name: asked.p_name, deleted: true });
    }
    if (url.pathname === "/rest/v1/rpc/account_models_kept") {
      return json(200, { models: mine(asked.p_owner).size, bytes: 0 });
    }
    if (url.pathname === "/rest/v1/account_models") {
      const owner = /^eq\.(.+)$/.exec(url.searchParams.get("owner") || "")?.[1];
      return json(200, [...mine(owner)].map(([name, row]) => ({ name, ...row })));
    }
    if (url.pathname === "/rest/v1/rpc/age_of" && self.ageAsk) {
      return json(200, { over_13: null, asked_at: null, ask: true });
    }
    // The count of codes asked for (api/otp.js), cleared for an answer under 13.
    if (url.pathname === "/rest/v1/otp_requests" && init.method === "DELETE") return json(200, []);
    // Photos of real builds (supabase/builds.sql), when the test has some:
    // an account's own, and those of its models (none here); their files
    // deleted by name.
    if (self.photos && url.pathname === "/rest/v1/shared_models") return json(200, []);
    if (self.photos && url.pathname === "/rest/v1/build_photos") {
      const account = /^eq\.(.+)$/.exec(url.searchParams.get("account") || "")?.[1];
      return json(200, self.photos.filter((one) => one.account === account).map((one) => ({ id: one.id })));
    }
    if (url.pathname === "/storage/v1/object/build-photos" && init.method === "DELETE") {
      self.storageDeletes.push(asked.prefixes || []);
      return json(200, (asked.prefixes || []).map((name) => ({ name })));
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
