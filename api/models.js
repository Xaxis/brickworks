// A signed-in person's saved models, kept with their account as well as in
// the browser (2026-10-23, supabase/account_models.sql).
//
//   GET  /api/models          the account's models: {models: [{name,
//                             version, parts, bytes, sum, saved_at}],
//                             kept: {models, bytes, most_models,
//                             most_bytes}}, bytes as stored (left out
//                             until account_models_delete.sql is applied),
//                             never the files themselves; {models: [],
//                             off: <why>} where none are kept here
//   GET  /api/models?name=X   one model: {name, version, parts, sum, model},
//                             model the .ldr gzipped, in base64
//   POST /api/models          a save: {name, base, model}, model the same
//                             way, base the version it was made from (0 for
//                             a model this browser has never had from the
//                             account). {name, version}, with same when it
//                             was kept already, and conflict when it was
//                             made from an older version than the one there:
//                             then it is kept beside that one under a name
//                             of its own ("Castle 2"), and neither is lost
//   DELETE /api/models?name=X&version=N
//                             a model deleted in the app, as it was at
//                             version N: {name, deleted}, or {name, gone}
//                             when the account had none; {name, kept: M}
//                             when version M was saved since elsewhere,
//                             which is kept and never deleted unseen
//                             (supabase/account_models_delete.sql). A
//                             rename is a delete and a save under the new
//                             name.
//
// The app saves into the browser as it always has, and sends each save
// here once it is made (src/account/cloud_models.gd); every browser the
// person signs in to puts the account's models in File, Open.
//
// Checked at this edge, before anything is kept: a sign-in; a name of one
// line, 1 to 60 characters, none a file name may not have; base a whole
// number; the model gzip of UTF-8 text with no NUL in it, at most MOST_RAW
// once unzipped and MOST_STORED as sent. Its part count and its sum are
// worked out here from the file, never taken from the client. How many
// models and how much an account may keep is held by the database, in one
// transaction per account, so no script of requests at once gets past it
// (save_account_model: 500 models, 64 MB as stored).
//
// And how many a plan keeps, while plans are on (api/_billing.js): Free
// keeps 25, Pro and the owner any number (Admission's saved_models). Only a
// model new to the account counts, held in the same transaction
// (save_account_model_within, supabase/account_models_plan.sql): a save
// over one it has never does, and a delete makes room at once. Past it the
// save is answered 413 {full: "plan", error, pro: "/plans"}, and kept in
// the browser or on the computer as before. Plans off, Admission is not
// asked and the save is as it always was; a plan not known refuses nothing.
//
// The database is reached as the server alone (api/_db.js): no key a page
// holds can read or write the table. Until account_models.sql is applied
// the list says off and the rest 503, and the app keeps its models in the
// browser as before.
//
// A test account (a Resend test address, api/_auth.js isTestAccount) keeps
// models like any other, but for the one every browser flow's pages are
// signed in as (tools/web/session.mjs): dozens of pages at once, each of
// which would be sent every model the others saved. Its list is answered
// as a deployment without the table answers it, {models: [], off}, and its
// pages keep their models in the browser alone. Not an error status: a
// page check fails on any request answered with one (tools/web/check.mjs),
// and nothing is wrong. tools/web/cloud_library_flow.mjs signs in as an
// account of its own.
const SHARED_TEST = "delivered+brickworks-tests@resend.dev";

import { createHash } from "node:crypto";
import { gunzipSync } from "node:zlib";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
import { entitlementOf, mostModels, reportOwner } from "./_billing.js";
import { db, dbConfigured } from "./_db.js";

// As supabase/account_models.sql holds them.
export const MOST_STORED = 4 * 1024 * 1024;
export const MOST_RAW = 32 * 1024 * 1024;
export const MOST_MODELS = 500;
export const MOST_BYTES = 64 * 1024 * 1024;
// A name as the app names a model's file (ModelStore._safe_name), and as
// the table's check has it.
const NAME_BAD = /[\u0000-\u001f\u007f/\\:*?"<>|]/;

export function nameOf(raw) {
  const name = typeof raw === "string" ? raw : "";
  if (!name || name.length > 60 || name !== name.trim() || NAME_BAD.test(name) || name === "." || name === "..") {
    return null;
  }
  return name;
}

/// The model's text from what was sent, or a reason it is not one.
export function modelOf(sent) {
  if (typeof sent !== "string" || !sent || sent.length > MOST_STORED || !/^[A-Za-z0-9+/]+=*$/.test(sent)) {
    return { trouble: "The model is gzipped LDraw in base64, at most 4 MB." };
  }
  let raw;
  try {
    raw = gunzipSync(Buffer.from(sent, "base64"), { maxOutputLength: MOST_RAW });
  } catch (trouble) {
    if (/maxOutputLength|buffer/i.test(String(trouble?.message || trouble))) {
      return { trouble: "That model is too big to keep with your account (more than 32 MB). It is kept in this browser." };
    }
    return { trouble: "The model is gzipped LDraw in base64." };
  }
  const text = raw.toString("utf8");
  if (text.includes("\u0000") || text.includes("�")) return { trouble: "The model is LDraw text." };
  return { text, raw };
}

/// How many parts a model's text opens as, counted as the app counts them
/// (ModelStore.count_in): each copy of a sub-model as the parts in it, and
/// not the lines inside a part the file carries.
export function partsIn(text) {
  const refs = new Map();
  const isPart = new Map();
  const order = [];
  let name = "";
  let lines = [];
  let head = [];
  const key = (file) => file.trim().toLowerCase().replace(/\\/g, "/");
  for (const raw of `${text}\n0 NOFILE`.split("\n")) {
    const line = raw.trim();
    if (line.startsWith("0 FILE ") || line.startsWith("0 NOFILE")) {
      if (lines.length && !refs.has(name)) {
        refs.set(name, lines);
        isPart.set(name, head.some((h) => /^0 !LDRAW_ORG\s+(Unofficial_)?(Part|Subpart|Primitive|Shortcut)/i.test(h)));
        order.push(name);
      }
      name = line.startsWith("0 FILE ") ? key(line.slice(7)) : "";
      lines = [];
      head = [];
      continue;
    }
    if (head.length < 16) head.push(line);
    if (line.startsWith("1 ")) {
      const fields = line.split(/\s+/);
      if (fields.length >= 15) lines.push(key(fields.slice(14).join(" ")));
    }
  }
  if (!order.length) return 0;
  const count = (section, depth) => {
    let n = 0;
    for (const named of refs.get(section)) {
      if (depth < 32 && refs.has(named) && named !== section && !isPart.get(named)) n += count(named, depth + 1);
      else n += 1;
    }
    return n;
  };
  return count(order[0], 0);
}

function bodyOf(request) {
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }
  return body && typeof body === "object" ? body : {};
}

// PostgREST's answer when the table or the function is not there:
// account_models.sql not applied.
const NOT_HERE = /: 404$|: 400$/;

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
      .end();
  }
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Cache-Control", "private, no-store");
  if (!["GET", "POST", "DELETE"].includes(request.method)) {
    return response.status(405).json({ error: "GET, POST a save, or DELETE one" });
  }
  if (!authConfigured() || !dbConfigured()) {
    return response.status(503).json({ error: "Accounts are not configured here." });
  }
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  // Kept nowhere here: the list says so, and the app keeps them in the
  // browser alone, as before (CloudModels).
  const off = (why) => response.status(200).json({ models: [], off: why });
  if (String(claims.email || "").trim().toLowerCase() === SHARED_TEST) {
    return request.method === "GET" ? off("The shared test account keeps its models in the browser.")
      : response.status(409).json({ error: "The shared test account keeps its models in the browser." });
  }
  const owner = claims.sub;
  const unreached = (trouble, doing) => {
    const words = String(trouble?.message || trouble);
    if (NOT_HERE.test(words)) {
      console.error("models: supabase/account_models.sql is not applied here; models are kept in the browser only");
      if (request.method === "GET" && request.query?.name === undefined) {
        return off("Your account does not keep models here yet. They are kept in this browser.");
      }
      return response.status(503).json({ error: "Your account does not keep models here yet. They are kept in this browser." });
    }
    console.error(`models: ${doing}: ${words.slice(0, 120)}`);
    return response.status(502).json({ error: "Brickworks could not reach your models just now. They are kept in this browser." });
  };

  if (request.method === "GET") {
    const wanted = request.query?.name;
    if (wanted !== undefined) {
      const name = nameOf(String(wanted));
      if (!name) return response.status(422).json({ error: "That is not a model's name." });
      try {
        const rows = await db(`account_models?owner=eq.${owner}&name=eq.${encodeURIComponent(name)}`
          + "&select=name,version,parts,sum,model");
        if (!rows?.length) return response.status(404).json({ error: `Your account has no model “${name}”.` });
        return response.status(200).json(rows[0]);
      } catch (trouble) {
        return unreached(trouble, "not read");
      }
    }
    try {
      const [rows, kept] = await Promise.all([
        db(`account_models?owner=eq.${owner}&select=name,version,parts,raw_bytes,sum,saved_at`
          + "&order=saved_at.desc"),
        keptBy(owner),
      ]);
      return response.status(200).json({
        models: (rows || []).map((one) => ({ name: one.name, version: one.version, parts: one.parts,
          bytes: one.raw_bytes, sum: one.sum, saved_at: one.saved_at })),
        kept: { models: (rows || []).length, ...(kept ? { bytes: kept.bytes } : {}),
          most_models: MOST_MODELS, most_bytes: MOST_BYTES },
      });
    } catch (trouble) {
      return unreached(trouble, "not listed");
    }
  }

  if (request.method === "DELETE") {
    const name = nameOf(String(request.query?.name ?? ""));
    if (!name) return response.status(422).json({ error: "That is not a model's name." });
    const version = Number(request.query?.version);
    if (!Number.isInteger(version) || version < 1) {
      return response.status(422).json({ error: "version is the version that was deleted." });
    }
    try {
      return response.status(200).json(await db("rpc/delete_account_model",
        { method: "POST", body: { p_owner: owner, p_name: name, p_version: version } }));
    } catch (trouble) {
      return unreached(trouble, "not deleted");
    }
  }

  const body = bodyOf(request);
  const name = nameOf(body.name);
  if (!name) return response.status(422).json({ error: "A model's name is one line of 1 to 60 characters, without / \\ : * ? \" < > |." });
  const base = Number(body.base ?? 0);
  if (!Number.isInteger(base) || base < 0) return response.status(422).json({ error: "base is the version the save was made from, or 0." });
  const model = modelOf(body.model);
  if (model.trouble) return response.status(/too big/.test(model.trouble) ? 413 : 422).json({ error: model.trouble });
  // The plan's limit: nothing asked while plans are off.
  await reportOwner(claims);
  const plan = await entitlementOf(owner);
  const most = mostModels(plan);
  let kept;
  try {
    kept = await saved({
      p_owner: owner, p_name: name, p_base: base, p_model: body.model, p_raw_bytes: model.raw.length,
      p_parts: partsIn(model.text), p_sum: createHash("sha256").update(model.raw).digest("hex"),
    }, most);
  } catch (trouble) {
    return unreached(trouble, "not saved");
  }
  if (kept.full === "plan") {
    return response.status(413).json({ full: "plan", pro: "/plans", error: keepsAtMost(plan.plan.name, most) });
  }
  // full says which, for the app to word it for where the model is kept
  // (a browser, a computer) and to offer to delete old ones.
  if (kept.full === "too many") {
    return response.status(413).json({ full: "too many",
      error: `Your account keeps ${MOST_MODELS} models at most. This one is kept in this browser.` });
  }
  if (kept.full === "too big") {
    return response.status(413).json({ full: "too big",
      error: "Your account keeps 64 MB of models at most, and this one would go past it. It is kept in this browser." });
  }
  return response.status(200).json(kept);
}

/// How many models [owner] keeps and how much, as stored: {models, bytes},
/// or null where account_models_delete.sql is not applied yet.
async function keptBy(owner) {
  try {
    return await db("rpc/account_models_kept", { method: "POST", body: { p_owner: owner } });
  } catch {
    return null;
  }
}

/// What a save past the plan's limit is answered with.
export function keepsAtMost(plan, most) {
  return `${plan} keeps ${most} models in your account. Delete one, or get Pro for unlimited.`;
}

/// save_account_model, as the server, or save_account_model_within for a
/// plan that keeps at most [most]: what it kept, or {full} with its refusal
/// ("too many", "too big", "plan"), which PostgREST answers 400 with the
/// words that api/_db.js does not pass on.
async function saved(args, most = null) {
  const within = most !== null;
  const name = within ? "save_account_model_within" : "save_account_model";
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const answer = await fetch(`${base}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify(within ? { ...args, p_most: most } : args),
    signal: AbortSignal.timeout(20000),
  });
  if (answer.ok) return answer.json();
  const said = await answer.json().catch(() => ({}));
  const full = /^models: (too many|too big|plan)$/.exec(String(said?.message || ""));
  if (answer.status === 400 && full) return { full: full[1] };
  // A mistake of ours is never the person's to pay for: kept without the
  // plan's limit until the file is applied.
  if (within && answer.status === 404) {
    console.error("models: supabase/account_models_plan.sql is not applied here; saved without the plan's limit");
    return saved(args);
  }
  throw new Error(`database POST rpc/${name}: ${answer.status}`);
}
