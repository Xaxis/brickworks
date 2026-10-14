// The sign-in page's half (authorize.html): check the request Claude sent,
// sign the person in, and ask once.
//
// Signing in is the app's own: a code emailed by /api/otp and redeemed
// with Supabase directly, so the session is between the person and
// Supabase. If the app is already signed in in this browser, its kept
// session is used instead — renewed, and the renewed one put back where the
// app looks, as the admin page does — so someone who pressed Connect
// Claude in the app only has to say yes. A session made here is kept the
// same way, so the app opens signed in afterwards.
//
// Then Allow sends the request and the session's access token to
// /api/oauth?op=approve, which checks both again and answers with where to
// send the person: back to Claude, with a code. Once is enough: signed in,
// the page first asks /api/oauth?op=remembered whether this account is
// connected to this same app already, and if it is goes straight back with
// a code, asking nothing. Everything shown is put on the page as text,
// never markup.

const $ = (id) => document.getElementById(id);
// Where the app keeps its session (src/account/account.gd).
const KEY = "brickworks.session";
const STEPS = ["checking", "refused", "email-step", "code-step", "allow-step", "leaving"];
const request = Object.fromEntries(new URLSearchParams(location.search));

let project = null; // { url, key }: where codes are redeemed
let session = null; // { access, email }
let email = "";
let client = "Claude"; // who is asking, as the server names it

function show(step) {
  for (const id of STEPS) $(id).classList.toggle("hide", id !== step);
  say("");
  const field = { "email-step": "email", "code-step": "code" }[step];
  if (field) $(field).focus();
}

function say(text, bad = false) {
  $("say").textContent = text;
  $("say").classList.toggle("bad", bad);
}

function busy(button, on, label) {
  button.disabled = on;
  if (label) button.textContent = label;
}

async function json(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}

function kept() {
  try {
    return JSON.parse(localStorage.getItem(KEY) || "null");
  } catch {
    return null;
  }
}

/// Kept where the app looks, unless the app here is signed in as somebody
/// else: connecting Claude for one address must not sign this browser's
/// app out of another.
function keep(body) {
  const was = kept();
  const who = (body.user?.email || email || "").toLowerCase();
  if (was && was.refresh_token && String(was.email || "").toLowerCase() !== who) return;
  try {
    localStorage.setItem(KEY, JSON.stringify({
      refresh_token: body.refresh_token,
      email: body.user?.email || email,
      user_id: body.user?.id || "",
      url: project.url,
      key: project.key,
    }));
  } catch {
    // A browser that keeps nothing still signs in, for this page.
  }
}

/// The app's session in this browser, renewed; null if there is none or
/// it has ended.
async function renewKept() {
  const was = kept();
  if (!was || !was.refresh_token || !project) return null;
  try {
    const reply = await fetch(`${project.url}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { apikey: project.key, "content-type": "application/json" },
      body: JSON.stringify({ refresh_token: was.refresh_token }),
    });
    const body = await json(reply);
    if (!reply.ok || !body.access_token) return null;
    email = body.user?.email || was.email || "";
    keep(body);
    return { access: body.access_token, email };
  } catch {
    return null;
  }
}

/// Supabase's refusals as sentences, the way the app says them.
function readable(body) {
  switch (body.error_code) {
    case "otp_expired":
    case "invalid_credentials":
      return "That code is wrong or has expired. Check it, or ask for a new one.";
    case "over_email_send_rate_limit":
    case "over_request_rate_limit":
      return "Too many attempts just now. Wait a minute and try again.";
    default:
      return body.msg || body.error_description || body.message || "Could not sign in. Try again.";
  }
}

function toAllow() {
  $("signed-in-as").textContent = session.email || "your account";
  show("allow-step");
  $("allow").focus();
}

/// Whether this account has allowed this app before and is still connected
/// to it: then Brickworks answers at once, as it did the first time, and
/// the person is not asked again (op=remembered). Disconnect, in Account in
/// Brickworks, ends that, and the next connection asks.
async function remembered() {
  try {
    const reply = await fetch("/api/oauth?op=remembered", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${session.access}` },
      body: JSON.stringify(request),
    });
    const body = await json(reply);
    if (!reply.ok || !body.redirect) return false;
    $("leaving-why").textContent = `You allowed ${client} before, signed in as `
      + `${session.email || "this account"}. Disconnect it any time from Account in Brickworks.`;
    show("leaving");
    location.assign(body.redirect);
    return true;
  } catch {
    return false;
  }
}

async function start() {
  // What the request is, before anything is asked of the person.
  let checked;
  try {
    const reply = await fetch(`/api/oauth?op=check&${new URLSearchParams(request)}`);
    checked = await json(reply);
    if (!reply.ok && !checked.refuse) throw new Error(checked.error_description || `the server said ${reply.status}`);
  } catch (trouble) {
    $("refused-why").textContent = `Brickworks could not check it just now (${trouble.message}). Try again in a minute.`;
    return show("refused");
  }
  if (checked.refuse) {
    $("refused-why").textContent = checked.refuse;
    return show("refused");
  }
  if (checked.back) {
    // A request Brickworks will not serve, from an app it can answer. Said
    // here, with a way back, rather than sending the browser on by itself:
    // anyone may register a return address, and a page that forwards
    // automatically to it would be a redirector for any link.
    const back = new URL(checked.back);
    $("refused-why").textContent = `${back.searchParams.get("error_description") || "The request was not one "
      + "Brickworks can answer"}.`;
    const link = document.createElement("a");
    link.href = checked.back;
    link.textContent = `Back to ${back.host || "the app"}`;
    $("refused-why").append(" ", link);
    return show("refused");
  }

  client = checked.client;
  for (const name of document.querySelectorAll(".client")) name.textContent = client;
  const back = $("back-to");
  back.replaceChildren();
  if (checked.loopback) {
    back.classList.add("warn");
    back.append("You will go back to a program on this computer, at ");
    const where = document.createElement("b");
    where.textContent = checked.return_to;
    back.append(where, ". Allow it only if you just started connecting one — Claude Code, for example.");
  } else {
    back.append("You will go back to ");
    const where = document.createElement("b");
    where.textContent = checked.return_to;
    back.append(where, ".");
  }
  $("leaving-to").textContent = `Taking you back to ${checked.return_to}…`;

  try {
    const account = await json(await fetch("/api/account"));
    if (account.enabled && account.url && account.key) project = { url: account.url, key: account.key };
  } catch {
    project = null;
  }
  if (!project) {
    $("refused-why").textContent = "Brickworks cannot sign anyone in just now. Try again in a minute.";
    return show("refused");
  }
  session = await renewKept();
  if (session) return (await remembered()) || toAllow();
  show("email-step");
}

$("email-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  email = $("email").value.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return say("That is not an email address.", true);
  busy($("send"), true, "Sending…");
  try {
    const reply = await fetch("/api/otp", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email }),
    });
    if (!reply.ok) {
      say((await json(reply)).error || `Could not send a code just now (${reply.status}).`, true);
      return;
    }
    $("sent-to").textContent = email;
    $("code").value = "";
    show("code-step");
  } catch {
    say("Could not reach Brickworks to send a code. Check your connection.", true);
  } finally {
    busy($("send"), false, "Email me a code");
  }
});

$("code-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const token = $("code").value.replace(/[\s-]/g, "");
  if (!token) return say("Enter the code from the email.", true);
  busy($("verify"), true, "Signing in…");
  try {
    const reply = await fetch(`${project.url}/auth/v1/verify`, {
      method: "POST",
      headers: { apikey: project.key, "content-type": "application/json" },
      // "email", even for a code minted as a magic link (see account.gd).
      body: JSON.stringify({ type: "email", email, token }),
    });
    const body = await json(reply);
    if (!reply.ok || !body.access_token) return say(readable(body), true);
    keep(body);
    session = { access: body.access_token, email: body.user?.email || email };
    if (!(await remembered())) toAllow();
  } catch {
    say("Could not reach Brickworks to sign in. Check your connection.", true);
  } finally {
    busy($("verify"), false, "Sign in");
  }
});

async function answer(op) {
  const button = op === "approve" ? $("allow") : $("deny");
  busy($("allow"), true);
  busy($("deny"), true);
  button.textContent = op === "approve" ? "Connecting…" : "Cancelling…";
  try {
    const headers = { "content-type": "application/json" };
    if (op === "approve") headers.authorization = `Bearer ${session.access}`;
    const reply = await fetch(`/api/oauth?op=${op}`, {
      method: "POST", headers, body: JSON.stringify(request),
    });
    const body = await json(reply);
    if (body.redirect) {
      if (op === "approve") show("leaving");
      return location.assign(body.redirect);
    }
    if (body.refuse) {
      $("refused-why").textContent = body.refuse;
      return show("refused");
    }
    if (reply.status === 401) {
      // The session ended between signing in and saying yes.
      session = null;
      show("email-step");
      return say("Your sign-in had ended. Sign in again to connect.", true);
    }
    say(body.error_description || body.error || `Something went wrong (${reply.status}). Try again.`, true);
  } catch {
    say("Could not reach Brickworks. Check your connection and try again.", true);
  } finally {
    busy($("allow"), false, "Allow");
    busy($("deny"), false, "Cancel");
  }
}

$("allow").addEventListener("click", () => answer("approve"));
$("deny").addEventListener("click", () => answer("deny"));
for (const id of ["other-email", "not-me"]) {
  $(id).addEventListener("click", () => {
    session = null;
    $("email").value = "";
    show("email-step");
  });
}

start();
