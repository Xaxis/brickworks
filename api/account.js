// What the app needs to know about this deployment and about who is
// using it, in one request.
//
//   No token  — where the part geometry the build did not ship is served
//               from, whether this deployment has accounts, and where to
//               sign in. The same answer for everybody, so any cache may
//               keep it. Enough to draw the sign-in screen.
//   A token   — the same, and who that token belongs to: the address,
//               and whether it is the owner's (MASTER_EMAIL), which is
//               what puts the admin page in the account panel.
//
// Everyone who uses Brickworks signs in (2026-10-11). There were
// accounts before, until 2026-10-09, so that one of them could design on
// the project's key; they went with that, and came back because the
// owner wants every person on the platform to have one — and because a
// connector that drives somebody's tab should belong to somebody. The
// route kept answering through both, so builds already out never lost
// their parts.
//
// Publishable key, not the secret one. It is meant to be in the client —
// it identifies the project and nothing more, and every table it can
// reach is behind row level security. Serving it from here rather than
// compiling it in means a rotated key reaches the desktop build without
// anyone reinstalling.

import { AuthError, authConfigured, bearer, isMaster, verify } from "./_auth.js";

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
  response.setHeader("Vary", "Authorization");

  if (request.method !== "GET") {
    return response.status(405).json({ error: "GET only" });
  }

  const enabled = authConfigured();
  const base = {
    // True: this deployment has accounts, and the app asks everyone to
    // sign in before it can be used.
    enabled,
    url: enabled ? process.env.SUPABASE_URL.replace(/\/+$/, "") : null,
    key: enabled ? process.env.SUPABASE_PUBLISHABLE_KEY : null,
    // The assistant runs on the person's own key, sent only to
    // Anthropic, or on their own Claude plan through the connector.
    // Never on ours.
    assistant: "own_key",
    // Where the geometry this build did not ship is served from. The
    // library runs to 27,000 meshes and a deployment takes 15,000 files,
    // so the parts cannot live beside the app. Null means "next to the
    // app", which is what a deployment carrying its own parts wants.
    parts_url: process.env.PARTS_URL || null,
  };

  const token = bearer(request);
  if (!enabled || !token) {
    // The same answer for everybody, so any cache may keep it a while.
    response.setHeader("Cache-Control", "public, max-age=300");
    return response.status(200).json({ ...base, signed_in: false });
  }

  // From here the answer is about one person.
  response.setHeader("Cache-Control", "private, no-store");
  let claims;
  try {
    claims = await verify(token);
  } catch (error) {
    // Not an error the app should show. A token that has aged out is
    // the ordinary way a session ends, and the app renews it with
    // Supabase rather than asking here; this only reports what it saw.
    return response.status(200).json({
      ...base,
      signed_in: false,
      reason: error instanceof AuthError ? error.message : "sign in again",
    });
  }

  return response.status(200).json({
    ...base,
    signed_in: true,
    email: claims.email || null,
    master: isMaster(claims),
  });
}
