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
// MASTER_EMAIL unset means nobody rather than everybody. It reads and
// never writes: there is nothing about an account to change from here.
//
//   GET /api/admin     accounts, sign-ins, connectors, the email sender
//
// Restored 2026-10-11 with accounts, without the tiers and the design
// budget the first one managed: those belonged to the proxy that spent
// the project's key, which has not come back.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";

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
      .setHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
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
  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET only" });
  }

  try {
    return response.status(200).json(await report());
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 500;
    return response.status(status).json({ error: error.message });
  }
}

async function report() {
  const [listed, tabs] = await Promise.all([
    asServer("/auth/v1/admin/users?page=1&per_page=1000"),
    asServer("/rest/v1/relay_tabs?select=owner,seen_at,open&owner=not.is.null"),
  ]);
  const users = listed.users || [];

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
  };
}
