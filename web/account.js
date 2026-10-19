// Signing in on the site's own pages (the directory, 2026-10-13): the
// gallery's model pages, profiles and lists, and /profile.
//
// There is one sign-in, the app's: a code emailed by /api/otp and redeemed
// with Supabase directly, the session kept in this browser where the app
// keeps it (src/account/account.gd), so signing in here signs the app in
// and the other way round — as the sign-in page Claude sends people to
// does (web/authorize.js). Renewing a session replaces its refresh token,
// so the renewed one is put back for the app to find; and an access token
// is kept for this tab until it runs out, so a page renews once, not on
// every click.
//
// Nothing here is shown as markup: the pages that import it put every
// word on the page as text.
//
// After a first sign-in, one question (2026-10-18, supabase/trust.sql), as
// the app asks it: the month and year the person was born, with nothing
// before the answer to say which answer opens what. The server keeps only
// whether that is 13 or over (api/account.js). Under 13, the dialog says
// afterwards what is and is not open to them.

const KEY = "brickworks.session";
const ACCESS = "brickworks.access";
let project = null;

async function json(reply) {
  try {
    return await reply.json();
  } catch {
    return {};
  }
}

/// Where codes are redeemed: the Supabase project and its publishable key,
/// as /api/account says.
async function where() {
  if (project) return project;
  const said = await json(await fetch("/api/account"));
  if (!said.enabled || !said.url || !said.key) throw new Error("Brickworks cannot sign anyone in just now.");
  project = { url: said.url, key: said.key };
  return project;
}

function kept() {
  try {
    return JSON.parse(localStorage.getItem(KEY) || "null");
  } catch {
    return null;
  }
}

function keep(body, email) {
  try {
    localStorage.setItem(KEY, JSON.stringify({
      refresh_token: body.refresh_token,
      email: body.user?.email || email || "",
      user_id: body.user?.id || "",
      url: project.url,
      key: project.key,
    }));
    sessionStorage.setItem(ACCESS, JSON.stringify({
      token: body.access_token, until: Date.now() + (Number(body.expires_in) || 3600) * 1000 - 60000,
      email: body.user?.email || email || "",
    }));
  } catch {
    // A browser that keeps nothing is signed in for this page only.
  }
}

/// Whether this browser has a sign-in to use, without asking anybody.
export function signedIn() {
  const was = kept();
  return Boolean(was && was.refresh_token);
}

/// The address it is for, as kept.
export function email() {
  return (kept() || {}).email || "";
}

/// An access token for the kept sign-in: this tab's while it lasts,
/// renewed when not. Null when there is no sign-in or it has ended.
export async function token() {
  try {
    const held = JSON.parse(sessionStorage.getItem(ACCESS) || "null");
    if (held && held.token && held.until > Date.now() && held.email === email()) return held.token;
  } catch {
    // Asked again below.
  }
  const was = kept();
  if (!was || !was.refresh_token) return null;
  await where();
  const reply = await fetch(`${project.url}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { apikey: project.key, "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: was.refresh_token }),
  });
  const body = await json(reply);
  if (!reply.ok || !body.access_token) return null;
  keep(body, was.email);
  return body.access_token;
}

/// Send a code to [address]. Says why not, in words, when it cannot.
export async function sendCode(address) {
  const wanted = String(address || "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(wanted)) throw new Error("That is not an email address.");
  await where();
  const reply = await fetch("/api/otp", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: wanted }),
  });
  if (!reply.ok) throw new Error((await json(reply)).error || `Could not send a code just now (${reply.status}).`);
  return wanted;
}

/// Sign in with the code sent to [address]; the session kept for the app too.
export async function redeem(address, code) {
  await where();
  const reply = await fetch(`${project.url}/auth/v1/verify`, {
    method: "POST",
    headers: { apikey: project.key, "content-type": "application/json" },
    // "email", even for a code minted as a magic link (see account.gd).
    body: JSON.stringify({ type: "email", email: address, token: String(code || "").replace(/[\s-]/g, "") }),
  });
  const body = await json(reply);
  if (!reply.ok || !body.access_token) {
    if (body.error_code === "otp_expired" || body.error_code === "invalid_credentials") {
      throw new Error("That code is wrong or has expired. Check it, or ask for a new one.");
    }
    throw new Error(body.msg || body.error_description || "Could not sign in. Try again.");
  }
  keep(body, address);
  return body.access_token;
}

export function signOut() {
  try {
    localStorage.removeItem(KEY);
    sessionStorage.removeItem(ACCESS);
  } catch {
    // Nothing kept, nothing to forget.
  }
}

/// A call to the site's own API with the sign-in, as JSON: {status, body}.
export async function call(path, { method = "GET", body } = {}) {
  const access = await token();
  const headers = { accept: "application/json" };
  if (access) headers.authorization = `Bearer ${access}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const reply = await fetch(path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await json(reply) };
}

/// The two steps of signing in, in a dialog the page opens over itself:
/// an address, then the code sent to it. Resolves true once signed in,
/// false when the person closes it.
export function askToSignIn(why) {
  return new Promise((done) => {
    const dialog = document.createElement("dialog");
    dialog.className = "sign-in";
    const title = document.createElement("h2");
    title.textContent = "Sign in to Brickworks";
    const said = document.createElement("p");
    said.textContent = why || "Sign in with your email address: we send you a code, no password.";
    const form = document.createElement("form");
    const label = document.createElement("label");
    label.textContent = "Email";
    const field = document.createElement("input");
    field.type = "email";
    field.autocomplete = "email";
    field.required = true;
    field.value = email();
    label.append(field);
    const note = document.createElement("p");
    note.className = "said";
    note.setAttribute("role", "status");
    const go = document.createElement("button");
    go.className = "cta";
    go.type = "submit";
    go.textContent = "Email me a code";
    const close = document.createElement("button");
    close.className = "cta ghost";
    close.type = "button";
    close.textContent = "Not now";
    const row = document.createElement("div");
    row.className = "actions";
    row.append(go, close);
    form.append(label, row, note);
    dialog.append(title, said, form);
    document.body.append(dialog);
    let address = "";
    let finished = false;
    const end = (result) => {
      if (finished) return;
      finished = true;
      dialog.close();
      dialog.remove();
      done(result);
    };
    close.addEventListener("click", () => end(false));
    dialog.addEventListener("cancel", () => end(false));
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      go.disabled = true;
      note.textContent = "";
      try {
        if (!address) {
          address = await sendCode(field.value);
          label.firstChild.textContent = `The code sent to ${address}`;
          field.type = "text";
          field.inputMode = "numeric";
          field.autocomplete = "one-time-code";
          field.value = "";
          go.textContent = "Sign in";
          field.focus();
        } else {
          await redeem(address, field.value);
          // Signed in: the age question next, if this account has not
          // answered it, before the page carries on.
          finished = true;
          dialog.close();
          dialog.remove();
          await askAgeIfAsked().catch(() => null);
          done(true);
        }
      } catch (trouble) {
        note.textContent = trouble.message;
      } finally {
        go.disabled = false;
      }
    });
    dialog.showModal();
    field.focus();
  });
}

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August",
  "September", "October", "November", "December"];

/// What the server keeps of this sign-in's age: {ask, over_13}, or null
/// when nobody is signed in or it does not ask here.
export async function age() {
  const access = await token();
  if (!access) return null;
  const said = await json(await fetch("/api/account", { headers: { authorization: `Bearer ${access}` } }));
  return said.signed_in && said.age ? said.age : null;
}

/// The age question, if this account is to be asked it: resolves with
/// {ask, over_13} as kept after, or null when there was nothing to ask or
/// it was put off.
export async function askAgeIfAsked() {
  const now = await age();
  if (!now || !now.ask) return now;
  return askAge();
}

/// The question itself, in a dialog over the page. Neutral: the same
/// question for everybody, and nothing before the answer about what either
/// answer opens.
function askAge() {
  return new Promise((done) => {
    const dialog = document.createElement("dialog");
    dialog.className = "sign-in age";
    const title = document.createElement("h2");
    title.textContent = "One question first";
    const said = document.createElement("p");
    said.textContent = "When were you born?";
    const form = document.createElement("form");
    const monthLabel = document.createElement("label");
    monthLabel.textContent = "Month";
    const month = document.createElement("select");
    month.id = "age-month";
    month.required = true;
    const none = document.createElement("option");
    none.value = "";
    none.textContent = "Choose…";
    month.append(none);
    MONTHS.forEach((name, at) => {
      const option = document.createElement("option");
      option.value = String(at + 1);
      option.textContent = name;
      month.append(option);
    });
    monthLabel.append(month);
    const yearLabel = document.createElement("label");
    yearLabel.textContent = "Year";
    const year = document.createElement("input");
    year.id = "age-year";
    year.inputMode = "numeric";
    year.autocomplete = "bday-year";
    year.maxLength = 4;
    year.required = true;
    year.pattern = "[0-9]{4}";
    yearLabel.append(year);
    const note = document.createElement("p");
    note.className = "said";
    note.setAttribute("role", "status");
    const go = document.createElement("button");
    go.className = "cta";
    go.type = "submit";
    go.id = "age-go";
    go.textContent = "Carry on";
    const row = document.createElement("div");
    row.className = "actions";
    row.append(go);
    const quiet = document.createElement("p");
    quiet.className = "note";
    quiet.textContent = "Brickworks asks everyone this once. The date itself is not kept.";
    form.append(monthLabel, yearLabel, row, note, quiet);
    dialog.append(title, said, form);
    document.body.append(dialog);
    let finished = false;
    const end = (result) => {
      if (finished) return;
      finished = true;
      dialog.close();
      dialog.remove();
      done(result);
    };
    dialog.addEventListener("cancel", () => end(null));
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      go.disabled = true;
      note.textContent = "";
      const answer = await call("/api/account?op=age", { method: "POST",
        body: { month: Number(month.value), year: Number(year.value) } });
      go.disabled = false;
      if (answer.status !== 200 || !answer.body.age) {
        note.textContent = answer.body.error || "That did not go just now. Try again in a minute.";
        return;
      }
      const kept = answer.body.age;
      if (kept.over_13 !== false) {
        end(kept);
        return;
      }
      // Said after the answer, never before it.
      title.textContent = "Thank you";
      said.textContent = "You can build here, keep your models and share them by link with anyone you choose. "
        + "The gallery, a public profile and a name shown on a link are for people 13 and over, so they are "
        + "not open on this account.";
      const carry = document.createElement("button");
      carry.className = "cta";
      carry.type = "button";
      carry.id = "age-done";
      carry.textContent = "Carry on";
      carry.addEventListener("click", () => end(kept));
      form.replaceWith(carry);
      carry.focus();
    });
    dialog.showModal();
    month.focus();
  });
}
