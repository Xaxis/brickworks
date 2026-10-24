// A signed-in person's saved models, kept with their account as well as in
// the browser (2026-10-23, supabase/account_models.sql).
//
//   GET  /api/models          the account's models: {models: [{name,
//                             version, parts, bytes, sum, saved_at}],
//                             kept: {models, bytes, most_models,
//                             most_bytes}}, never the files themselves
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
// The database is reached as the server alone (api/_db.js): no key a page
// holds can read or write the table. Until account_models.sql is applied
// every answer is 503, and the app keeps its models in the browser as
// before.

import { createHash } from "node:crypto";
import { gunzipSync } from "node:zlib";
import { AuthError, authConfigured, bearer, verify } from "./_auth.js";
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
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Cache-Control", "private, no-store");
  if (!["GET", "POST"].includes(request.method)) {
    return response.status(405).json({ error: "GET, or POST a save" });
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
  const owner = claims.sub;
  const unreached = (trouble, doing) => {
    const words = String(trouble?.message || trouble);
    if (NOT_HERE.test(words)) {
      console.error("models: supabase/account_models.sql is not applied here; models are kept in the browser only");
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
      const rows = await db(`account_models?owner=eq.${owner}&select=name,version,parts,raw_bytes,sum,saved_at`
        + "&order=saved_at.desc");
      return response.status(200).json({
        models: (rows || []).map((one) => ({ name: one.name, version: one.version, parts: one.parts,
          bytes: one.raw_bytes, sum: one.sum, saved_at: one.saved_at })),
        kept: { models: (rows || []).length, most_models: MOST_MODELS, most_bytes: MOST_BYTES },
      });
    } catch (trouble) {
      return unreached(trouble, "not listed");
    }
  }

  const body = bodyOf(request);
  const name = nameOf(body.name);
  if (!name) return response.status(422).json({ error: "A model's name is one line of 1 to 60 characters, without / \\ : * ? \" < > |." });
  const base = Number(body.base ?? 0);
  if (!Number.isInteger(base) || base < 0) return response.status(422).json({ error: "base is the version the save was made from, or 0." });
  const model = modelOf(body.model);
  if (model.trouble) return response.status(/too big/.test(model.trouble) ? 413 : 422).json({ error: model.trouble });
  let kept;
  try {
    kept = await saved({
      p_owner: owner, p_name: name, p_base: base, p_model: body.model, p_raw_bytes: model.raw.length,
      p_parts: partsIn(model.text), p_sum: createHash("sha256").update(model.raw).digest("hex"),
    });
  } catch (trouble) {
    return unreached(trouble, "not saved");
  }
  if (kept.full === "too many") {
    return response.status(413).json({ error: `Your account keeps ${MOST_MODELS} models at most. This one is kept in this browser.` });
  }
  if (kept.full === "too big") {
    return response.status(413).json({ error: "Your account keeps 64 MB of models at most, and this one would go past it. It is kept in this browser." });
  }
  return response.status(200).json(kept);
}

/// save_account_model, as the server: what it kept, or {full} with its
/// refusal ("too many", "too big"), which PostgREST answers 400 with the
/// words that api/_db.js does not pass on.
async function saved(args) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const answer = await fetch(`${base}/rest/v1/rpc/save_account_model`, {
    method: "POST",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(20000),
  });
  if (answer.ok) return answer.json();
  const said = await answer.json().catch(() => ({}));
  const full = /^models: (too many|too big)$/.exec(String(said?.message || ""));
  if (answer.status === 400 && full) return { full: full[1] };
  throw new Error(`database POST rpc/save_account_model: ${answer.status}`);
}
