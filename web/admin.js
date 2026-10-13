// The admin page's half: renew the app's session in this browser, ask
// /api/admin with it, and draw what comes back. See admin.html.
//
// Everything is put on the page as text, never as markup: the list is of
// addresses people typed, and an address is not something to let a
// browser interpret.

const $ = (id) => document.getElementById(id);
// Where the app keeps its session (src/account/account.gd).
const KEY = "brickworks.session";

function say(where, text, bad = false) {
  const el = $(where);
  el.textContent = text;
  el.classList.toggle("bad", bad);
}

/// A fresh access token from the app's kept session, with the renewed
/// session put back where the app will look for it: renewing replaces the
/// refresh token, and the app's next start must find the new one.
async function accessToken() {
  let kept;
  try {
    kept = JSON.parse(localStorage.getItem(KEY) || "null");
  } catch {
    kept = null;
  }
  if (!kept || !kept.refresh_token || !kept.url || !kept.key) {
    throw new Error("You are not signed in to Brickworks in this browser.");
  }
  const reply = await fetch(`${kept.url}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { apikey: kept.key, "content-type": "application/json" },
    body: JSON.stringify({ refresh_token: kept.refresh_token }),
  });
  const body = await reply.json().catch(() => ({}));
  if (!reply.ok || !body.access_token) {
    throw new Error("Your sign-in has ended. Sign in to Brickworks again.");
  }
  localStorage.setItem(KEY, JSON.stringify({
    ...kept,
    refresh_token: body.refresh_token,
    email: body.user?.email || kept.email,
    user_id: body.user?.id || kept.user_id,
  }));
  return body.access_token;
}

async function load() {
  const token = await accessToken();
  const reply = await fetch("/api/admin", { headers: { authorization: `Bearer ${token}` } });
  if (reply.status === 404) {
    // What every account but the owner's sees. Said plainly here, because
    // the person reading it is the one signed in.
    throw new Error("This account cannot see this page.");
  }
  if (!reply.ok) throw new Error(`The server said ${reply.status}.`);
  return reply.json();
}

const when = (iso) => iso
  ? new Date(iso).toLocaleString(undefined, {
    year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit",
  })
  : "—";

function cell(row, text, className) {
  const td = document.createElement("td");
  td.textContent = text;
  if (className) td.className = className;
  row.append(td);
}

function draw(data) {
  $("n-accounts").textContent = data.accounts.toLocaleString();
  $("n-week").textContent = data.signed_in_this_week.toLocaleString();
  $("n-connectors").textContent = data.connectors.toLocaleString();

  const borrowing = data.email?.borrowing;
  $("email-warning").classList.toggle("hide", !borrowing);
  if (borrowing) {
    $("email-detail").textContent =
      `${data.email.sender} is not verified with Resend, so codes are sent as `
      + `${borrowing}. Verify brickworks.diy with Resend (a key with domain `
      + `access, and the DNS records it issues), then remove EMAIL_FROM_FALLBACK `
      + `from the project.`;
  }

  const rows = $("people");
  rows.replaceChildren();
  for (const person of data.people) {
    const row = document.createElement("tr");
    cell(row, person.email ?? "no address", person.email ? "" : "faint");
    cell(row, when(person.joined));
    cell(row, when(person.last_sign_in));
    cell(row, String(person.connectors), "n");
    cell(row, when(person.connector_seen), person.connector_seen ? "" : "faint");
    rows.append(row);
  }

  // The gallery: names strangers chose, so text and never markup.
  const listed = $("gallery");
  listed.replaceChildren();
  for (const model of data.gallery || []) {
    const row = document.createElement("tr");
    const name = document.createElement("td");
    name.className = "model";
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(model.id)}`;
    link.textContent = model.name;
    name.append(link);
    row.append(name);
    cell(row, model.author ?? "nobody", model.author ? "" : "faint");
    cell(row, model.email ?? "—", model.email ? "" : "faint");
    cell(row, Number(model.parts).toLocaleString(), "n");
    cell(row, when(model.listed_at));
    const act = document.createElement("td");
    const out = document.createElement("button");
    out.textContent = "Take out";
    out.addEventListener("click", () => takeOut(model, out));
    act.append(out);
    row.append(act);
    listed.append(row);
  }
  say("gallery-note", data.gallery?.length ? "" : "Nothing is listed.");
}

/// Out of the gallery for good (api/admin.js ?op=unlist), asked first.
async function takeOut(model, button) {
  if (!confirm(`Take "${model.name}" out of the gallery? Its owner will not be able to list it again.`)) return;
  button.disabled = true;
  try {
    const token = await accessToken();
    const reply = await fetch(`/api/admin?op=unlist&id=${encodeURIComponent(model.id)}`, {
      method: "POST", headers: { authorization: `Bearer ${token}` } });
    if (!reply.ok) throw new Error(`The server said ${reply.status}.`);
    await refresh();
    say("gallery-note", `"${model.name}" is out of the gallery.`);
  } catch (problem) {
    button.disabled = false;
    say("gallery-note", problem.message, true);
  }
}

async function refresh() {
  try {
    draw(await load());
    $("view").classList.remove("hide");
    $("gate").classList.add("hide");
    say("note", `Updated ${new Date().toLocaleTimeString()}`);
  } catch (problem) {
    $("view").classList.add("hide");
    $("gate").classList.remove("hide");
    say("gate-note", problem.message, true);
  }
}

$("again").addEventListener("click", refresh);
refresh();
