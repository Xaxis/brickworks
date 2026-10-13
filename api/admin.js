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
// about an account to change from here. The one write is the gallery's:
// a model listed there that should not be (2026-10-13) is taken out, and
// barred, so its owner cannot list it again. Its link still works; taking
// that down is its owner's.
//
//   GET /api/admin                   accounts, sign-ins, connectors, the
//                                    email sender, the gallery's models
//   POST /api/admin?op=unlist&id=X   take X out of the gallery for good
//
// Restored 2026-10-11 with accounts, without the tiers and the design
// budget the first one managed: those belonged to the proxy that spent
// the project's key, which has not come back.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";
import { db } from "./_db.js";

const ID = /^[A-Za-z0-9]{10}$/;

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
  if (request.method === "POST" && op === "unlist") {
    try {
      return await unlist(request, response);
    } catch (error) {
      return response.status(error instanceof AuthError ? error.status : 502).json({ error: error.message });
    }
  }
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET, or POST ?op=unlist" });
  }

  try {
    return response.status(200).json(await report());
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 500;
    return response.status(status).json({ error: error.message });
  }
}

/// Out of the gallery, and barred from it: listed false, and a republish
/// with the box ticked refused (api/share.js). The row and its files are
/// untouched, so the link goes on working.
async function unlist(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  const rows = await db(`shared_models?id=eq.${id}`, {
    method: "PATCH", body: { listed: false, listed_at: null, barred: true },
    prefer: "return=representation" });
  if (!Array.isArray(rows) || rows.length === 0) return response.status(404).json({ error: "no model at that link" });
  return response.status(200).json({ id, listed: false, barred: true });
}

async function report() {
  const [listed, tabs, gallery] = await Promise.all([
    asServer("/auth/v1/admin/users?page=1&per_page=1000"),
    asServer("/rest/v1/relay_tabs?select=owner,seen_at,open&owner=not.is.null"),
    // What strangers can see in /gallery right now, and whose it is.
    asServer("/rest/v1/shared_models?listed=is.true&published=is.true"
      + "&select=id,owner,name,author,parts,listed_at&order=listed_at.desc&limit=500"),
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
  };
}
