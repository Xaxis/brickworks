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

// The token the page was last drawn with, for the photos it shows: renewing
// replaces the refresh token, so it is not renewed once per photo.
let drawnWith = "";

async function load() {
  const token = await accessToken();
  drawnWith = token;
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
    act.className = "acts";
    const out = document.createElement("button");
    out.textContent = "Take out";
    out.addEventListener("click", () => takeOut(model, out));
    act.append(out);
    if (data.picks) act.append(pickButton(model.id, model.name));
    row.append(act);
    listed.append(row);
  }
  say("gallery-note", data.gallery?.length ? "" : "Nothing is listed.");

  drawPicks(data.picks);

  // Marked Tested: the app's finding, to clear when it should not be there.
  const tested = $("tested");
  tested.replaceChildren();
  for (const mark of data.tested || []) {
    const row = document.createElement("tr");
    const name = document.createElement("td");
    name.className = "model";
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(mark.model)}`;
    link.textContent = mark.name || mark.model;
    name.append(link);
    row.append(name);
    cell(row, String(mark.n), "n");
    cell(row, String(mark.app));
    cell(row, Number(mark.parts).toLocaleString(), "n");
    cell(row, Number(mark.steps).toLocaleString(), "n");
    cell(row, when(mark.at));
    const act = document.createElement("td");
    const clear = document.createElement("button");
    clear.textContent = "Clear the mark";
    clear.addEventListener("click", () => confirm(`Clear the Tested mark of version ${mark.n}?`)
      && post(`op=untest&id=${encodeURIComponent(mark.model)}&v=${encodeURIComponent(mark.n)}`,
        "tested-note", "Cleared: it is not marked Tested anywhere now."));
    act.append(clear);
    row.append(act);
    tested.append(row);
  }
  say("tested-note", data.tested?.length ? "" : "Nothing is marked Tested.");

  // What was reported: strangers' words again, so text and never markup.
  const reports = $("reports");
  reports.replaceChildren();
  for (const report of data.reports || []) {
    const row = document.createElement("tr");
    // Where the owner's email of reports links each one (api/_trust.js).
    if (Number.isInteger(report.id)) row.id = `report-${report.id}`;
    cell(row, when(report.at));
    const about = document.createElement("td");
    about.className = "model";
    const link = document.createElement("a");
    if (report.comment) {
      // A comment: its words, and the model it is on.
      link.href = `/m/${encodeURIComponent(report.model)}#comment-${encodeURIComponent(report.comment.id)}`;
      link.textContent = `A comment on ${report.name ?? report.model}`;
    } else if (report.photo) {
      // A photo of a build (supabase/builds.sql): the photo itself, asked for
      // with the owner's sign-in, since it may be hidden from everybody else.
      row.dataset.photo = report.photo.id;
      link.href = `/m/${encodeURIComponent(report.model)}#photo-${encodeURIComponent(report.photo.id)}`;
      link.textContent = `A photo of a build of ${report.name ?? report.model}`;
      const said = [report.photo.words ? `“${report.photo.words}”` : "", report.photo.hidden ? "hidden by the model's owner" : "",
        report.photo.email ? `posted by ${report.photo.email}` : ""].filter(Boolean).join(" · ");
      if (said) {
        const line = document.createElement("small");
        line.className = "faint photo-said";
        line.textContent = said;
        about.append(line, document.createElement("br"));
      }
      if (!report.photo.removed) about.prepend(photoOf(report.photo.id), document.createElement("br"));
    } else if (report.model) {
      link.href = `/m/${encodeURIComponent(report.model)}`;
      link.textContent = report.name ?? report.model;
    } else if (report.handle) {
      link.href = `/u/${encodeURIComponent(report.handle)}`;
      link.textContent = `@${report.handle}`;
    } else {
      link.href = `/c/${encodeURIComponent(report.collection)}`;
      link.textContent = `collection ${report.collection}`;
    }
    about.append(link);
    if (report.comment && report.comment.body) {
      const words = document.createElement("q");
      words.className = "comment-said";
      words.textContent = report.comment.body;
      about.append(document.createElement("br"), words);
    }
    row.append(about);
    cell(row, report.reason);
    cell(row, report.note ?? "—", report.note ? "said" : "faint");
    cell(row, report.contact ?? "—", report.contact ? "" : "faint");
    cell(row, report.email ?? "—", report.email ? "" : "faint");
    const acts = document.createElement("td");
    acts.className = "acts";
    if (report.comment) {
      acts.append(act("Remove the comment", () => confirm("Take this comment off its page for good?")
        && post(`op=uncomment&comment=${encodeURIComponent(report.comment.id)}`, "reports-note", "The comment is removed.")));
    } else if (report.photo) {
      acts.append(act("Take the photo out", () => confirm("Take this photo out? Its file is deleted, and it is shown nowhere again.")
        && post(`op=remove_photo&photo=${encodeURIComponent(report.photo.id)}`, "reports-note",
          "The photo is out, and its file deleted.")));
    } else if (report.model) {
      acts.append(act("Take out", () => confirm(`Take this model out of the gallery for good?`)
        && post(`op=unlist&id=${encodeURIComponent(report.model)}`, "reports-note", "Taken out.")));
      acts.append(act("Take out the account", () => confirm("Take every model of this account out of the gallery, and keep them out?")
        && post(`op=bar&id=${encodeURIComponent(report.model)}`, "reports-note", "The account is out.")));
    }
    acts.append(act("Let it go", () => post(`op=dismiss&report=${encodeURIComponent(report.id)}`, "reports-note", "Let go.")));
    row.append(acts);
    reports.append(row);
  }
  say("reports-note", data.reports?.length ? "" : "Nothing is reported.");
  // Opened from that email: the report it named, marked (and put in view
  // once the page shows, by refresh).
  const named = /^#report-\d+$/.test(location.hash) ? document.getElementById(location.hash.slice(1)) : null;
  if (named) {
    named.classList.add("asked");
  } else if (/^#report-\d+$/.test(location.hash)) {
    say("reports-note", "The report that email named is no longer open: it was settled.");
  }

  // Comments: strangers' words, so text and never markup.
  const comments = $("comments");
  comments.replaceChildren();
  for (const one of data.comments || []) {
    const row = document.createElement("tr");
    row.id = `comment-${one.id}`;
    cell(row, when(one.at));
    const on = document.createElement("td");
    on.className = "model";
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(one.model)}#comment-${encodeURIComponent(one.id)}`;
    link.textContent = one.name ?? one.model;
    on.append(link, document.createTextNode(one.step ? `, step ${one.step} of version ${one.version}`
      : `, version ${one.version}`));
    row.append(on);
    cell(row, one.body, "said");
    cell(row, one.handle ? `@${one.handle}` : one.email ?? "—", one.handle || one.email ? "" : "faint");
    cell(row, one.removed ? `removed by ${one.removed_by === "admin" ? "you" : "its author"}`
      : one.hidden ? "hidden by its builder" : one.edited_at ? "edited" : "shown", one.removed ? "faint" : "");
    const acts = document.createElement("td");
    acts.className = "acts";
    if (!one.removed) {
      acts.append(act("Remove", () => confirm("Take this comment off its page for good?")
        && post(`op=uncomment&comment=${encodeURIComponent(one.id)}`, "comments-note", "Removed.")));
    }
    row.append(acts);
    comments.append(row);
  }
  say("comments-note", data.comments?.length ? "" : "Nobody has commented yet.");

  const barred = $("barred");
  barred.replaceChildren();
  for (const one of data.barred || []) {
    const row = document.createElement("tr");
    cell(row, one.email ?? one.account);
    cell(row, when(one.at));
    cell(row, one.reason ?? "—", one.reason ? "" : "faint");
    const acts = document.createElement("td");
    acts.append(act("Let back in", () => post(`op=unbar&account=${encodeURIComponent(one.account)}`, "barred-note", "Let back in.")));
    row.append(acts);
    barred.append(row);
  }
  say("barred-note", data.barred?.length ? "" : "Nobody is taken out.");
}

/// A reported photo, small, fetched with the owner's sign-in and shown from
/// memory (a blob: address, which this page's policy allows).
function photoOf(id) {
  const img = document.createElement("img");
  img.className = "reported-photo";
  img.alt = "The reported photo";
  img.width = 160;
  (async () => {
    try {
      const reply = await fetch(`/api/admin?op=photo&photo=${encodeURIComponent(id)}`,
        { headers: { authorization: `Bearer ${drawnWith}` } });
      if (!reply.ok) throw new Error(String(reply.status));
      img.src = URL.createObjectURL(await reply.blob());
    } catch {
      img.alt = "The photo could not be shown";
    }
  })();
  return img;
}

/// Make it the pick (api/admin.js ?op=pick), for a week.
function pickButton(id, name) {
  return act("Make it the pick", () => confirm(`Make "${name}" this week's pick, for seven days?`)
    && post(`op=pick&id=${encodeURIComponent(id)}&days=7`, "pick-note", `"${name}" is this week's pick.`));
}

/// This week's pick: what visitors see now, the choices still open, and
/// the week worked out. Names strangers chose, so text and never markup.
function drawPicks(picks) {
  const now = $("pick-now");
  now.replaceChildren();
  const said = document.createElement("span");
  if (!picks) {
    said.className = "note";
    said.textContent = "Not open yet: supabase/discovery.sql is not applied.";
    now.append(said);
  } else if (!picks.now || !picks.now.model) {
    said.textContent = "No pick this week: nothing in the gallery was built, remixed or listed Tested in the past seven days.";
    now.append(said);
  } else {
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(picks.now.model.id)}`;
    link.textContent = picks.now.model.name;
    const week = picks.now.week || {};
    said.textContent = picks.now.chosen ? ` — chosen, until ${when(picks.now.until)}` : ` — worked out: built ${
      week.builds || 0} this week, remixed ${week.remixes || 0}${week.tested ? ", Tested" : ""} (score ${week.score || 0})`;
    const lead = document.createElement("b");
    lead.textContent = "Visitors see ";
    now.append(lead, link, said);
    now.dataset.model = picks.now.model.id;
    now.dataset.chosen = picks.now.chosen ? "yes" : "no";
  }
  const choices = $("choices");
  choices.replaceChildren();
  for (const one of picks?.choices || []) {
    const row = document.createElement("tr");
    row.dataset.pick = String(one.pick);
    row.dataset.model = String(one.model);
    const name = document.createElement("td");
    name.className = "model";
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(one.model)}`;
    link.textContent = one.name || one.model;
    name.append(link);
    row.append(name);
    cell(row, when(one.chosen_at));
    cell(row, when(one.until));
    cell(row, one.shown ? "yes" : one.test ? "no: a test account's" : "no: not in the gallery now", one.shown ? "" : "faint");
    const acts = document.createElement("td");
    acts.append(act("End", () => post(`op=unpick&pick=${encodeURIComponent(one.pick)}`, "pick-note",
      "Ended: back to the pick worked out.")));
    row.append(acts);
    choices.append(row);
  }
  const week = $("week");
  week.replaceChildren();
  for (const one of picks?.week || []) {
    if (!one.model) continue;
    const row = document.createElement("tr");
    const name = document.createElement("td");
    name.className = "model";
    const link = document.createElement("a");
    link.href = `/m/${encodeURIComponent(one.model.id)}`;
    link.textContent = one.model.name;
    name.append(link);
    row.append(name);
    cell(row, String(one.week?.builds ?? 0), "n");
    cell(row, String(one.week?.remixes ?? 0), "n");
    cell(row, one.week?.tested ? "yes" : "no", one.week?.tested ? "" : "faint");
    cell(row, String(one.week?.score ?? 0), "n");
    const acts = document.createElement("td");
    acts.append(pickButton(one.model.id, one.model.name));
    row.append(acts);
    week.append(row);
  }
  if (picks && !(picks.week || []).length && !(picks.choices || []).length) {
    say("pick-note", "Nothing chosen, and nothing in the past seven days to work one out from.");
  }
}

function act(words, run) {
  const button = document.createElement("button");
  button.textContent = words;
  button.addEventListener("click", async () => {
    button.disabled = true;
    const done = await run();
    if (!done) button.disabled = false;
  });
  return button;
}

/// One of the owner's acts (api/admin.js), then the page drawn again.
async function post(query, where, said) {
  try {
    const token = await accessToken();
    const reply = await fetch(`/api/admin?${query}`, { method: "POST", headers: { authorization: `Bearer ${token}` } });
    // What the server said, in its words when it gave some (a pick refused).
    if (!reply.ok) throw new Error((await reply.json().catch(() => ({}))).error || `The server said ${reply.status}.`);
    await refresh();
    say(where, said);
    return true;
  } catch (problem) {
    say(where, problem.message, true);
    return false;
  }
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
    const asked = document.querySelector("#reports tr.asked");
    if (asked && !refresh.shown) {
      refresh.shown = true;
      asked.scrollIntoView({ block: "center" });
    }
    say("note", `Updated ${new Date().toLocaleTimeString()}`);
  } catch (problem) {
    $("view").classList.add("hide");
    $("gate").classList.remove("hide");
    say("gate-note", problem.message, true);
  }
}

$("again").addEventListener("click", refresh);
refresh();
