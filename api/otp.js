// Sending somebody a code to sign in with.
//
// Everyone signs in to use Brickworks, and this is the only way in: an
// email address and a code sent to it. No passwords anywhere. A password
// is a thing to choose badly, reuse, forget and reset — by email, which
// is this, one step later and less securely.
//
// Restored 2026-10-11 as it stood before accounts were removed on
// 2026-10-09; the rate limit (may_ask_for_code) and the tables behind it
// had stayed in the database the whole time.
//
// The code is minted by Supabase and delivered by us. A new address's
// account is made by the admin API, and Supabase's admin generate_link
// makes a one-time code for it and, asked this way, sends nothing — which is what lets the email come from our own sender
// through Resend rather than from a project nobody recognises. The
// client then redeems the code against Supabase directly, so the
// session and the token are Supabase's throughout and this server never
// holds either.
//
// Two rules shape the replies.
//
// It never says whether an address has an account. That sentence turns
// a sign-in form into a way of asking whether somebody is a member, so
// a request for an unknown address and one for a known address get the
// same reply. It does say when *we* failed — a mail provider refusing
// us is a fact about this service, not about the person, and reporting
// it as success leaves somebody waiting for an email that was never
// sent.
//
// And it is rate limited in the database rather than in memory. The
// limit here is what stops a stranger being sent a hundred codes on our
// Resend bill, and a serverless instance forgets everything whenever it
// recycles.

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const TTL_MINUTES = 10;

function project() {
  return (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

function asServer() {
  const secret = process.env.SUPABASE_SECRET_KEY;
  return { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" };
}

/// Ask Supabase for a code without asking it to send one: the account
/// made first, here, as the server, then a one-time code for it.
///
/// Made by the admin API rather than by generate_link, which made a new
/// address's account until 2026-10-24: that goes through Supabase's own
/// sign-up, which is to be turned off (disable_signup, since a public
/// sign-up with a password made an account and a session at any address),
/// and the admin API makes one either way. Confirmed, since only the code
/// redeemed signs anybody in to it. An address that has its account
/// already is answered 422, and asked its code all the same. The daily
/// canary (api/_canary.js) signs in by this, and by deliver below.
export async function mint(email) {
  const made = await fetch(`${project()}/auth/v1/admin/users`, {
    method: "POST", headers: asServer(), body: JSON.stringify({ email, email_confirm: true }),
    signal: AbortSignal.timeout(10000),
  });
  if (!made.ok && made.status !== 422) return null;
  const reply = await fetch(`${project()}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: asServer(),
    // magiclink: a one-time code for the account, and nothing sent.
    body: JSON.stringify({ type: "magiclink", email }),
    signal: AbortSignal.timeout(10000),
  });
  if (!reply.ok) return null;
  const body = await reply.json();
  // Top level in current GoTrue, nested in older ones.
  return body.email_otp || body.properties?.email_otp || null;
}

function letter(code) {
  return `<!doctype html>
<div style="font:16px/1.6 ui-sans-serif,-apple-system,'Segoe UI',Roboto,sans-serif;
            color:#14181d;max-width:460px;margin:0 auto;padding:28px 22px">
  <p style="margin:0 0 20px;font-size:15px;color:#5b6472">Brickworks</p>
  <p style="margin:0 0 8px">Your sign-in code:</p>
  <p style="margin:0 0 20px;font-size:34px;font-weight:700;letter-spacing:.14em;
            font-family:ui-monospace,SFMono-Regular,Menlo,monospace">${code}</p>
  <p style="margin:0 0 18px;color:#5b6472;font-size:14px">
    It works once and expires in ${TTL_MINUTES} minutes.</p>
  <p style="margin:0;color:#97a0ae;font-size:13px">
    If you did not ask for this, nothing has happened to your account and
    you can ignore it.</p>
</div>`;
}

/// Where sign-in codes come from.
///
/// brickworks.diy, because that is what the app is. A sender has to be
/// on a domain verified with Resend, which means DNS records on the
/// domain — so until those exist this address is refused with a 403 and
/// nothing arrives.
///
/// EMAIL_FROM_FALLBACK exists for exactly that window and for no other
/// reason. Borrowing another product's verified domain is the wrong
/// thing and looks it in somebody's inbox; it is here only so sign-in
/// keeps working while the records are added, and every use of it is
/// recorded so it cannot quietly become permanent.
const SENDER = "Brickworks <noreply@brickworks.diy>";

/// Set when the proper sender was refused. Only for the log: each
/// serverless function is its own instance, so this cannot be read from
/// /api/admin — that asks the configuration instead, which is a fact
/// rather than whatever the last invocation happened to see.
let borrowed = null;

async function post(key, from, email, code) {
  return fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify({
      from,
      to: [email],
      subject: `${code} is your Brickworks sign-in code`,
      html: letter(code),
      text: `Your Brickworks sign-in code is ${code}. `
        + `It works once and expires in ${TTL_MINUTES} minutes.`,
    }),
    signal: AbortSignal.timeout(10000),
  });
}

// Resend's test inboxes, where every probe and flow signs in
// (api/_auth.js isTestAccount). Mail sent there reaches nobody.
const TEST_INBOX = /@resend\.dev$/i;

export async function deliver(email, code) {
  const key = process.env.RESEND_API_KEY;
  // A unit's preview runs without the mail key (tools/deploy.sh --unit), so
  // unreviewed code can never send from brickworks.diy. A test inbox would
  // have received nothing anyway, and its flow mints its own code
  // (tools/web/session.mjs mintCode), so it is "delivered" as Resend would.
  if (!key) return TEST_INBOX.test(email);

  const wanted = process.env.EMAIL_FROM || SENDER;
  let reply = await post(key, wanted, email, code);
  if (reply.ok) {
    borrowed = null;
    return true;
  }

  // A 403 here means one thing: the domain is not verified. Worth
  // separating from every other failure, because it is the one with a
  // fix that is three DNS records rather than a mystery.
  const detail = await reply.text().catch(() => "");
  const unverified = reply.status === 403 && /not verified/i.test(detail);
  const spare = process.env.EMAIL_FROM_FALLBACK;
  if (!unverified || !spare) {
    console.error(`otp: Resend refused ${wanted} — ${reply.status} ${detail.slice(0, 160)}`);
    return false;
  }

  borrowed = { wanted, using: spare, since: new Date().toISOString() };
  console.error(
    `otp: ${wanted} is not verified with Resend, so this went out as `
    + `${spare}. Verify the domain and drop EMAIL_FROM_FALLBACK.`,
  );
  reply = await post(key, spare, email, code);
  return reply.ok;
}

async function allowed(email, ip) {
  const reply = await fetch(`${project()}/rest/v1/rpc/may_ask_for_code`, {
    method: "POST",
    headers: asServer(),
    body: JSON.stringify({ for_email: email, from_ip: ip }),
    signal: AbortSignal.timeout(8000),
  });
  if (!reply.ok) {
    // Fails closed. Letting requests through because the limiter is
    // unreachable is how a limiter becomes decorative at exactly the
    // moment it matters. Null, not false: refused for asking too often
    // and refused because the limiter could not be asked are different
    // things to tell a person.
    return null;
  }
  return await reply.json() === true;
}

/// Any of the three calls below, with a network that failed or timed
/// out turned into the answer that call gives for "it did not work",
/// rather than an exception that becomes a bare 500 with no words.
async function attempt(call, failed) {
  try {
    return await call();
  } catch (trouble) {
    console.error(`otp: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return failed;
  }
}

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type")
      .setHeader("Access-Control-Allow-Methods", "POST, OPTIONS")
      .end();
  }
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Cache-Control", "no-store");

  // Vercel's cron, once a day (/api/otp/canary): signing in played through.
  if (request.method === "GET" && request.query?.op === "canary") {
    const { canaryRoute } = await import("./_canary.js");
    return canaryRoute(request, response, { mint, deliver });
  }
  if (request.method !== "POST") {
    return response.status(405).json({ error: "POST only" });
  }
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SECRET_KEY) {
    return response.status(503).json({ error: "Accounts are not configured here." });
  }

  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      return response.status(400).json({ error: "body is not JSON" });
    }
  }

  const email = String(body?.email || "").trim().toLowerCase();
  // The one thing worth refusing out loud: a malformed address cannot
  // be a person waiting for an email, so saying so helps and leaks
  // nothing.
  if (!EMAIL.test(email) || email.length > 320) {
    return response.status(422).json({ error: "That is not an email address." });
  }
  // Where orangecheck accounts' made-up addresses are (api/orangecheck.js):
  // no mail is delivered there, and a code is never the way into one,
  // whether or not this deployment can send mail (a unit's preview cannot).
  if (/@oc\.brickworks\.diy$/.test(email)) {
    return response.status(422).json({ error: "That address takes no email. Sign in with orangecheck instead." });
  }
  if (!process.env.RESEND_API_KEY && !TEST_INBOX.test(email)) {
    return response.status(503).json({ error: "Email is not configured here." });
  }

  const ip =
    (request.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
    request.socket?.remoteAddress ||
    "";

  const may = await attempt(() => allowed(email, ip), null);
  if (may === null) {
    return response.status(503).json({
      error: "We could not start a sign-in just now. Try again in a minute.",
    });
  }
  if (!may) {
    return response.status(429).json({
      error: "Too many codes asked for. Wait a few minutes and try again.",
    });
  }

  // Two different facts, and only one of them is private.
  //
  // Whether an address has an account is private, and nothing here will
  // ever say. Whether our mail provider would take the message is not
  // private at all — it is a fact about us — and reporting it as
  // success left the app saying "check your email" about an email that
  // was never sent, which is the most confusing failure available:
  // the person waits, then doubts their own inbox.
  //
  // Both failures below happen identically whether or not the address
  // is known to us, so saying so leaks nothing.
  const code = await attempt(() => mint(email), null);
  if (!code) {
    console.error("otp: Supabase would not mint a code");
    return response.status(502).json({
      error: "We could not start a sign-in just now. Try again in a minute.",
    });
  }
  if (!(await attempt(() => deliver(email, code), false))) {
    console.error(
      `otp: could not deliver to ${email.replace(/(.).*(@.*)/, "$1…$2")}`,
    );
    return response.status(502).json({
      error: "We could not send the email just now. Try again in a minute.",
    });
  }
  return response.status(200).json({ ok: true, expires_in_minutes: TTL_MINUTES });
}
