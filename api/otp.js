// Sending somebody a code to sign in with.
//
// No passwords anywhere. A password is a thing to choose badly, reuse,
// forget and reset, and none of that is worth carrying for an app whose
// account exists to hold a tier and a design count.
//
// The code is minted by Supabase and delivered by us. Supabase's admin
// generate_link makes a one-time code and, asked this way, sends
// nothing — which is what lets the email come from our own sender
// through Resend rather than from a project nobody recognises. The
// client then redeems the code against Supabase directly, so the
// session and the token are Supabase's throughout and this server never
// holds either.
//
// Two rules shape the replies.
//
// It always answers the same way. "That address has no account" is a
// sentence that turns a sign-in form into a way of asking whether
// somebody is a member, so there isn't one: every well-formed request
// gets {ok: true}, whether or not an email went anywhere.
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

/// Ask Supabase for a code without asking it to send one.
async function mint(email) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${project()}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: {
      apikey: secret,
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
    },
    // magiclink covers both cases: Supabase creates the account if the
    // address is new and signs it in if it is not, so there is no
    // separate sign-up path to keep in step with this one.
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

async function deliver(email, code) {
  const key = process.env.RESEND_API_KEY;
  if (!key) return false;
  // Must be a domain verified with Resend. Their sandbox sender only
  // reaches the account owner and 403s for everybody else, which fails
  // as a silent non-delivery rather than as an error anyone sees.
  const from = process.env.EMAIL_FROM || "Brickworks <noreply@soniq.bot>";
  const reply = await fetch("https://api.resend.com/emails", {
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
  return reply.ok;
}

async function allowed(email, ip) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${project()}/rest/v1/rpc/may_ask_for_code`, {
    method: "POST",
    headers: {
      apikey: secret,
      authorization: `Bearer ${secret}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ for_email: email, from_ip: ip }),
    signal: AbortSignal.timeout(8000),
  });
  if (!reply.ok) {
    // Fails closed. Letting requests through because the limiter is
    // unreachable is how a limiter becomes decorative at exactly the
    // moment it matters.
    return false;
  }
  return await reply.json() === true;
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

  if (request.method !== "POST") {
    return response.status(405).json({ error: "POST only" });
  }
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SECRET_KEY) {
    return response.status(503).json({ error: "Accounts are not configured here." });
  }
  if (!process.env.RESEND_API_KEY) {
    return response.status(503).json({ error: "Email is not configured here." });
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

  const ip =
    (request.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
    request.socket?.remoteAddress ||
    "";

  if (!(await allowed(email, ip))) {
    return response.status(429).json({
      error: "Too many codes asked for. Wait a few minutes and try again.",
    });
  }

  const code = await mint(email);
  if (code) {
    const sent = await deliver(email, code);
    if (!sent) {
      // The caller is told nothing — the reply is the same either way
      // on purpose — so this is the only place a delivery failure is
      // visible at all. Without it, "the code never arrives" has no
      // thread to pull.
      console.error(`otp: could not deliver to ${email.replace(/(.).*(@.*)/, "$1…$2")}`);
    }
  }
  // Same answer either way. See the note at the top.
  return response.status(200).json({ ok: true, expires_in_minutes: TTL_MINUTES });
}
