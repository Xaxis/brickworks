// What the owner's account can see, and nobody else can: who has an
// account, when each last signed in, and whose Claude connectors there
// are.
//
// Everything here reads as the service role, which can see every row in
// the database regardless of the policies that keep one person out of
// another's. That is the whole risk of the file: the check that this is
// the owner's account is the only thing between a signed-in stranger and
// a list of everybody's email addresses.
//
// So it is the first thing that happens, it is done against a verified
// token rather than anything the caller supplies, and it fails closed —
// MASTER_EMAIL unset means nobody rather than everybody. There is nothing
// about an account to change from here. The writes are the gallery's: a
// model listed there that should not be (2026-10-13) is taken out, and
// barred, so its owner cannot list it again — and since the directory's
// moderation (supabase/moderation.sql), neither can anybody list the same
// file again at another link; and an account can be taken out whole, every
// model of it, so that publishing again does not dodge it. Links still
// work; taking those down is their owners'. What visitors reported is here
// to act on, or to let go.
//
//   GET /api/admin                       accounts, sign-ins, connectors, the
//                                        email sender, the gallery's models,
//                                        open reports, accounts taken out
//   POST /api/admin?op=unlist&id=X       take model X out of the gallery for good
//   POST /api/admin?op=bar&id=X          take the account that shares X out of it
//   POST /api/admin?op=unbar&account=U   let account U list again
//   POST /api/admin?op=dismiss&report=N  let report N go: nothing wrong
//   POST /api/admin?op=untest&id=X&v=N   clear the Tested mark of version N
//                                        of model X (the newest without v):
//                                        the app's finding, which the server
//                                        cannot check (supabase/tested.sql)
//
// Restored 2026-10-11 with accounts, without the tiers and the design
// budget the first one managed: those belonged to the proxy that spent
// the project's key, which has not come back.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";
import { db } from "./_db.js";
import { modelHash } from "./_directory.js";

const ID = /^[A-Za-z0-9]{10}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// As the service role. Every call here is one.
async function asServer(path) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) throw new AuthError("accounts are not configured here", 503);
  const reply = await fetch(`${project()}${path}`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!reply.ok) throw new AuthError(`the database said ${reply.status}`, 502);
  return reply.json();
}

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
  // Never cached, anywhere. This is somebody's account list.
  response.setHeader("Cache-Control", "no-store");

  if (!authConfigured()) {
    return response.status(503).json({ error: "accounts are not configured here" });
  }

  let claims;
  try {
    claims = await verify(bearer(request));
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 401;
    return response.status(status).json({ error: error.message });
  }
  if (!isMaster(claims)) {
    // Deliberately the same answer as a route that does not exist. A
    // 403 here would confirm to anyone signed in that there is an admin
    // surface and that they are simply not it.
    return response.status(404).json({ error: "not found" });
  }
  const op = String(request.query?.op || "");
  const acts = { unlist, bar, unbar, dismiss, untest };
  if (request.method === "POST" && acts[op]) {
    try {
      return await acts[op](request, response);
    } catch (error) {
      return response.status(error instanceof AuthError ? error.status : 502).json({ error: error.message });
    }
  }
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=unlist, bar, unbar, dismiss or untest" });
  }

  try {
    return response.status(200).json(await report());
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 500;
    return response.status(status).json({ error: error.message });
  }
}

/// The model's file as published, for its fingerprint: null when its
/// files went (taken down by its owner).
async function modelText(id) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${project()}/storage/v1/object/shared-models/${id}.mpd`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(20000),
  });
  return reply.ok ? reply.text() : null;
}

/// The file's fingerprint kept, so that the same model published again at
/// another link, by anybody, cannot be listed (api/share.js).
async function barFile(id) {
  const text = await modelText(id);
  if (text === null) return false;
  await db("barred_models?on_conflict=hash", { method: "POST",
    body: { hash: modelHash(text), model: id }, prefer: "resolution=ignore-duplicates" });
  return true;
}

/// What was reported about [where] (a PostgREST filter), settled.
async function settle(where, resolution) {
  await db(`reports?${where}&resolved_at=is.null`, { method: "PATCH",
    body: { resolved_at: new Date().toISOString(), resolution } });
}

/// Out of the gallery, and barred from it: listed false, and a republish
/// with the box ticked refused (api/share.js), at this link or with the
/// same file at any other. The row and its files are untouched, so the
/// link goes on working.
async function unlist(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  const rows = await db(`shared_models?id=eq.${id}`, {
    method: "PATCH", body: { listed: false, listed_at: null, barred: true },
    prefer: "return=representation" });
  if (!Array.isArray(rows) || rows.length === 0) return response.status(404).json({ error: "no model at that link" });
  const file = await barFile(id);
  await settle(`model=eq.${id}`, "taken_out");
  return response.status(200).json({ id, listed: false, barred: true, file_barred: file });
}

/// The account that shares a model, or one named, out of the gallery: none
/// of its models listed or listable, its profile not shown, and the files
/// of what it had listed barred too, so a new account cannot list them.
async function bar(request, response) {
  const id = String(request.query?.id || "");
  let account = String(request.query?.account || "");
  if (ID.test(id)) {
    const rows = await db(`shared_models?id=eq.${id}&select=owner`);
    if (!rows.length) return response.status(404).json({ error: "no model at that link" });
    account = rows[0].owner;
  }
  if (!UUID.test(account)) return response.status(400).json({ error: "name a model (?id=) or an account (?account=)" });
  const reason = String(request.body?.reason || "").slice(0, 200) || null;
  await db("barred_accounts?on_conflict=account", { method: "POST", body: { account, reason },
    prefer: "resolution=ignore-duplicates" });
  const listed = await db(`shared_models?owner=eq.${account}&listed=is.true&select=id&limit=500`);
  let files = 0;
  for (const model of listed) if (await barFile(model.id)) files += 1;
  await db(`shared_models?owner=eq.${account}&listed=is.true`, { method: "PATCH",
    body: { listed: false, listed_at: null, barred: true } });
  const models = (await db(`shared_models?owner=eq.${account}&select=id`)).map((m) => m.id);
  for (let at = 0; at < models.length; at += 100) {
    await settle(`model=in.(${models.slice(at, at + 100).join(",")})`, "account_barred");
  }
  const person = await db(`people?account=eq.${account}&select=handle`);
  if (person.length) await settle(`handle=eq.${person[0].handle}`, "account_barred");
  return response.status(200).json({ account, barred: true, unlisted: listed.length, files_barred: files });
}

/// An account let back: it may list again. What it had listed stays out
/// (each model still barred); the owner of this page lists them again by
/// hand if they should be.
async function unbar(request, response) {
  const account = String(request.query?.account || "");
  if (!UUID.test(account)) return response.status(400).json({ error: "name an account: ?account=<id>" });
  await db(`barred_accounts?account=eq.${account}`, { method: "DELETE" });
  return response.status(200).json({ account, barred: false });
}

async function dismiss(request, response) {
  const report = Number(request.query?.report);
  if (!Number.isInteger(report) || report < 1) return response.status(400).json({ error: "name a report: ?report=<number>" });
  await db(`reports?id=eq.${report}&resolved_at=is.null`, { method: "PATCH",
    body: { resolved_at: new Date().toISOString(), resolution: "dismissed" } });
  return response.status(200).json({ report, resolution: "dismissed" });
}

/// A Tested mark cleared: the app said it passed, and the site's owner says
/// it should not be shown. Kept, with when and why, so it is not shown
/// again; the model's next version is tested afresh.
async function untest(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  let n = Number(request.query?.v || 0);
  if (!n) {
    const newest = await db(`share_versions?model=eq.${id}&select=n&order=n.desc&limit=1`);
    n = newest[0]?.n ?? 0;
  }
  if (!Number.isInteger(n) || n < 1) return response.status(404).json({ error: "no version of that model" });
  const why = String(request.query?.why || "").replace(/[\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 280)
    || "Cleared by Brickworks";
  const rows = await db(`share_tests?model=eq.${id}&n=eq.${n}`, { method: "PATCH",
    body: { cleared_at: new Date().toISOString(), cleared_why: why }, prefer: "return=representation" });
  if (!Array.isArray(rows) || rows.length === 0) return response.status(404).json({ error: "that version is not tested" });
  return response.status(200).json({ id, version: n, cleared: true, why });
}

/// Every Tested mark showing, newest first, with its model's name; none
/// while supabase/tested.sql is not applied.
async function marks() {
  try {
    const rows = await db("share_tests?passed=is.true&cleared_at=is.null&select=model,n,at,app,parts,steps"
      + "&order=at.desc&limit=200");
    const ids = [...new Set(rows.map((row) => row.model))];
    const names = ids.length ? await db(`shared_models?id=in.(${ids.join(",")})&select=id,name,published`) : [];
    const named = new Map(names.map((one) => [one.id, one]));
    return rows.filter((row) => named.get(row.model)?.published)
      .map((row) => ({ ...row, name: named.get(row.model)?.name ?? null }));
  } catch {
    return [];
  }
}

async function report() {
  const [listed, tabs, gallery, reports, barred, tested] = await Promise.all([
    asServer("/auth/v1/admin/users?page=1&per_page=1000"),
    asServer("/rest/v1/relay_tabs?select=owner,seen_at,open&owner=not.is.null"),
    // What strangers can see in /gallery right now, and whose it is.
    asServer("/rest/v1/shared_models?listed=is.true&published=is.true"
      + "&select=id,owner,name,author,parts,listed_at&order=listed_at.desc&limit=500"),
    // What visitors said should not be there, still to act on.
    asServer("/rest/v1/reports?resolved_at=is.null&select=id,model,handle,collection,reason,note,contact,at,"
      + "shared_models(name,owner,listed,published)&order=at.desc&limit=300"),
    asServer("/rest/v1/barred_accounts?select=account,at,reason&order=at.desc&limit=200"),
    marks(),
  ]);
  const users = listed.users || [];
  const emails = new Map(users.map((user) => [user.id, user.email || null]));

  // Whose connectors, and when each was last heard from.
  const connectors = new Map();
  for (const tab of tabs) {
    const mine = connectors.get(tab.owner) || { count: 0, seen: null };
    mine.count += 1;
    if (!mine.seen || tab.seen_at > mine.seen) mine.seen = tab.seen_at;
    connectors.set(tab.owner, mine);
  }

  const week = Date.now() - 7 * 24 * 3600 * 1000;
  const people = users
    .map((user) => ({
      id: user.id,
      email: user.email || null,
      joined: user.created_at || null,
      last_sign_in: user.last_sign_in_at || null,
      connectors: connectors.get(user.id)?.count || 0,
      connector_seen: connectors.get(user.id)?.seen || null,
    }))
    .sort((a, b) => String(b.last_sign_in || "").localeCompare(String(a.last_sign_in || "")));

  return {
    accounts: people.length,
    signed_in_this_week: people.filter((p) => p.last_sign_in && Date.parse(p.last_sign_in) > week).length,
    connectors: tabs.length,
    // Asked of the configuration, not of the last send: each function is
    // its own instance, and what api/otp.js saw last is not visible here.
    email: {
      sender: process.env.EMAIL_FROM || "Brickworks <noreply@brickworks.diy>",
      // Only ever set while the proper domain waits on its DNS records,
      // so its presence is the signal that codes go out under another
      // product's name.
      borrowing: process.env.EMAIL_FROM_FALLBACK || null,
    },
    people,
    gallery: gallery.map((model) => ({
      id: model.id, name: model.name, author: model.author, parts: model.parts,
      listed_at: model.listed_at, email: emails.get(model.owner) || null,
    })),
    // Each open report with what it is about; the reporter is never named.
    reports: reports.map((report) => ({
      id: report.id, model: report.model, handle: report.handle, collection: report.collection,
      reason: report.reason, note: report.note, contact: report.contact, at: report.at,
      name: report.shared_models?.name ?? null, listed: report.shared_models?.listed ?? null,
      email: report.shared_models ? emails.get(report.shared_models.owner) || null : null,
    })),
    barred: barred.map((one) => ({ account: one.account, at: one.at, reason: one.reason,
      email: emails.get(one.account) || null })),
    tested,
  };
}
