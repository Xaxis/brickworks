// What the app needs to know about accounts, in one request.
//
// The client asks this on start-up and gets back two different things
// depending on whether it sent a token:
//
//   No token  — where to sign in, and whether this deployment has
//               accounts at all. Enough to draw the sign-in panel.
//   A token   — who you are, your tier, and how many designs you have
//               left this month.
//
// Collapsed into one endpoint because the two are never wanted apart,
// and because a build that probes twice spends two cold starts before it
// can draw anything.
//
// Publishable key, not the secret one. It is meant to be in the client —
// it identifies the project and nothing more, and every table it can
// reach is behind row level security. Serving it from here rather than
// compiling it in means a rotated key reaches the desktop build without
// anyone reinstalling.

import { AuthError, BUDGETS, authConfigured, bearer, tierFor, verify } from "./_auth.js";

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
  // The answer depends on the token, so a shared cache must not treat one
  // player's reply as everybody's.
  response.setHeader("Cache-Control", "private, max-age=30");
  response.setHeader("Vary", "Authorization");

  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET only" });
  }

  const enabled = authConfigured();
  const base = {
    enabled,
    url: enabled ? process.env.SUPABASE_URL.replace(/\/+$/, "") : null,
    key: enabled ? process.env.SUPABASE_PUBLISHABLE_KEY : null,
    // Said plainly so the app never has to infer it: what a visitor with
    // no account can do here.
    free_tier: "build, search the catalogue, save and load — no assistant",
  };

  const token = bearer(request);
  if (!enabled || !token) {
    return response.status(200).json({ ...base, signed_in: false });
  }

  let claims;
  try {
    claims = await verify(token);
  } catch (error) {
    // Not an error the app should show. A token that has aged out is the
    // ordinary way a session ends, and the app's job is to offer the
    // sign-in panel again, so this reports "signed out" with the reason
    // attached rather than a failure.
    return response.status(200).json({
      ...base,
      signed_in: false,
      reason: error instanceof AuthError ? error.message : "sign in again",
    });
  }

  const tier = await tierFor(claims.sub);
  const budget = BUDGETS[tier] ?? BUDGETS.builder;
  return response.status(200).json({
    ...base,
    signed_in: true,
    email: claims.email || null,
    tier,
    budget,
    used: await designsUsed(claims.sub),
  });
}

/// This month's count, read as the service role. Zero when there is no
/// row yet, which is the common case and not worth distinguishing from
/// a read that failed — both mean "nothing to show yet".
async function designsUsed(account) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) return 0;
  const month = new Date();
  const first = `${month.getUTCFullYear()}-${String(month.getUTCMonth() + 1).padStart(2, "0")}-01`;
  try {
    const url =
      `${process.env.SUPABASE_URL.replace(/\/+$/, "")}/rest/v1/assistant_usage` +
      `?select=designs&user_id=eq.${encodeURIComponent(account)}&month=eq.${first}`;
    const reply = await fetch(url, {
      headers: { apikey: secret, authorization: `Bearer ${secret}` },
      signal: AbortSignal.timeout(5000),
    });
    if (!reply.ok) return 0;
    const [row] = await reply.json();
    return row?.designs ?? 0;
  } catch {
    return 0;
  }
}
