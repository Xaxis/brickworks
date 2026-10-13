// Signing in from a test, without an inbox.
//
// Everyone who uses Brickworks signs in with a code sent to their email
// (2026-10-11), and a browser test has no inbox. So the test side mints
// the code the way api/otp.js does — Supabase's admin generate_link, which
// returns the code and sends nothing — and then either types it into the
// app like a person (account_flow.mjs), or redeems it here and hands the
// app the session it would have kept, as a returning visitor's browser
// would (browser.mjs, for every other flow).
//
// Only the minting is a shortcut, and it needs SUPABASE_SECRET_KEY, so it
// runs only where .env is. Nothing in production is weakened for it.
//
//   set -a; . ./.env; set +a
//
// The tests sign in as one test account, at a Resend test address that
// accepts mail and delivers it nowhere, so a code that is sent costs no
// one an inbox and no sender a bounce. BW_TEST_EMAIL picks another.

export const TEST_EMAIL = process.env.BW_TEST_EMAIL || "delivered+brickworks-tests@resend.dev";
// Where the app keeps its session in the browser (src/account/account.gd).
export const STORAGE_KEY = "brickworks.session";

function project() {
  const url = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const key = process.env.SUPABASE_PUBLISHABLE_KEY || "";
  return url && secret && key ? { url, secret, key } : null;
}

/// Whether this machine can sign a test in at all.
export function canSignIn() {
  return project() !== null;
}

/// A sign-in code for [email], made the way api/otp.js makes one and sent
/// nowhere. Making it replaces any code sent before.
export async function mintCode(email = TEST_EMAIL) {
  const p = project();
  if (!p) throw new Error("no SUPABASE_URL / SUPABASE_SECRET_KEY / SUPABASE_PUBLISHABLE_KEY — source .env");
  const reply = await fetch(`${p.url}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}`, "content-type": "application/json" },
    body: JSON.stringify({ type: "magiclink", email }),
  });
  const body = await reply.json();
  const code = body.email_otp || body.properties?.email_otp;
  if (!code) throw new Error(`no code minted: ${reply.status}`);
  return code;
}

/// A whole session for [email]: a code minted and redeemed, as the app
/// redeems one. What the app keeps of it is what is returned.
///
/// Flows run two at a time sign in the one test account, and minting a
/// code replaces the last: one flow's code was refused (403) because the
/// other minted between its mint and its redeem, and three checks failed
/// behind the sign-in screen (2026-10-13). So a refused code is minted
/// again, after a wait that differs between the two.
export async function mintSession(email = TEST_EMAIL) {
  const p = project();
  let reply = null;
  let body = {};
  for (let attempt = 1; attempt <= 5; attempt++) {
    const code = await mintCode(email);
    reply = await fetch(`${p.url}/auth/v1/verify`, {
      method: "POST",
      headers: { apikey: p.key, "content-type": "application/json" },
      body: JSON.stringify({ type: "email", email, token: code }),
    });
    body = await reply.json();
    if (body.refresh_token || reply.status !== 403) break;
    await new Promise((done) => setTimeout(done, 400 + Math.random() * 1600 * attempt));
  }
  if (!body.refresh_token) throw new Error(`the code would not redeem: ${reply.status}`);
  return {
    access_token: body.access_token,
    kept: {
      refresh_token: body.refresh_token,
      email: body.user?.email || email,
      user_id: body.user?.id || "",
      url: p.url,
      key: p.key,
    },
  };
}

/// Put a session where the app keeps one, in every page this context
/// opens — once: a reload must find what the app itself kept since, which
/// is a renewed token, not this one again.
export async function signInContext(context, email = TEST_EMAIL) {
  const { kept } = await mintSession(email);
  await context.addInitScript(([name, value]) => {
    try {
      if (!localStorage.getItem(name)) localStorage.setItem(name, value);
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(kept)]);
  return kept;
}

/// An account and everything of it gone: for the throwaway ones a test
/// makes. Never the shared test account.
export async function deleteAccount(email) {
  const p = project();
  if (!p || !email || email === TEST_EMAIL) return false;
  const listed = await (await fetch(`${p.url}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
  })).json();
  const user = (listed.users || []).find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
  if (!user) return false;
  const gone = await fetch(`${p.url}/auth/v1/admin/users/${user.id}`, {
    method: "DELETE",
    headers: { apikey: p.secret, authorization: `Bearer ${p.secret}` },
  });
  return gone.ok;
}
