// What the master account can see, and nobody else can.
//
// Everything here reads or writes as the service role, which can see
// every row in the database regardless of the policies that keep one
// player out of another's. That is the whole risk of the file: the
// check that this is the master account is the only thing between a
// signed-in stranger and a list of everybody's email addresses.
//
// So it is the first thing that happens, it is done against a verified
// token rather than anything the caller supplies, and it fails closed —
// MASTER_EMAIL unset means nobody rather than everybody.
//
//   GET  /api/admin            accounts, usage, the month's totals
//   POST /api/admin            { action: "set_tier", user, tier }

import { AuthError, BUDGETS, authConfigured, bearer, isMaster, verify } from "./_auth.js";

const TIERS = new Set(["builder", "pro"]);

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// As the service role. Every call here is one, which is why it is one
/// function rather than a header repeated at each call site.
async function table(path, options = {}) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) throw new AuthError("accounts are not configured here", 503);
  const reply = await fetch(`${project()}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: secret,
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
      ...(options.headers || {}),
    },
    signal: AbortSignal.timeout(10000),
  });
  if (!reply.ok) {
    throw new AuthError(`the database said ${reply.status}`, 502);
  }
  return reply.status === 204 ? null : reply.json();
}

function thisMonth() {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-01`;
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

  try {
    if (request.method === "GET") return await report(response);
    if (request.method === "POST") return await change(request, response);
  } catch (error) {
    const status = error instanceof AuthError ? error.status : 500;
    return response.status(status).json({ error: error.message });
  }
  return response.status(405).json({ error: "GET or POST" });
}

async function report(response) {
  const month = thisMonth();
  const [accounts, usage, conversations] = await Promise.all([
    table("profiles?select=id,email,tier,created_at&order=created_at.desc&limit=500"),
    table(`assistant_usage?select=user_id,designs&month=eq.${month}`),
    table(`assistant_designs?select=user_id,turns&month=eq.${month}`),
  ]);

  const designsBy = new Map(usage.map((row) => [row.user_id, row.designs]));
  const turnsBy = new Map();
  for (const row of conversations) {
    turnsBy.set(row.user_id, (turnsBy.get(row.user_id) || 0) + row.turns);
  }

  const people = accounts.map((row) => ({
    id: row.id,
    email: row.email,
    tier: row.tier,
    joined: row.created_at,
    designs: designsBy.get(row.id) || 0,
    turns: turnsBy.get(row.id) || 0,
    budget: BUDGETS[row.tier] ?? BUDGETS.builder,
  }));

  return response.status(200).json({
    month,
    // The totals are of what this deployment paid for. A design run on
    // somebody's own key never touches this server, so it is not here
    // and could not be — which is the arrangement working, not a gap.
    accounts: people.length,
    designs: people.reduce((sum, one) => sum + one.designs, 0),
    turns: people.reduce((sum, one) => sum + one.turns, 0),
    people,
  });
}

async function change(request, response) {
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      return response.status(400).json({ error: "body is not JSON" });
    }
  }
  if (body?.action !== "set_tier") {
    return response.status(400).json({ error: "unknown action" });
  }

  const tier = String(body.tier || "");
  if (!TIERS.has(tier)) {
    return response.status(400).json({ error: `tier ${tier} is not one we have` });
  }
  const user = String(body.user || "");
  // A uuid, because this goes into a URL against the database and a
  // string from a request has no business being trusted with that.
  if (!/^[0-9a-f-]{36}$/i.test(user)) {
    return response.status(400).json({ error: "that is not an account id" });
  }

  await table(`profiles?id=eq.${user}`, {
    method: "PATCH",
    headers: { prefer: "return=minimal" },
    body: JSON.stringify({ tier }),
  });
  return response.status(200).json({ ok: true, user, tier });
}
