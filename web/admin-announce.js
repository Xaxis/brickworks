// The console's Announcements (admin.html › Announcements, docs/ANNOUNCE.md):
// the owner tells the site's people something, in their own Notifications
// (api/_announce.js, supabase/announce.sql). Four tabs: Write (the words, who
// it is for, and beside them the exact group their page will show and the
// menu's line, with how many it reaches now; drafts), Sent and scheduled
// (each one's reach, who read and followed it, its mail; Edit, Withdraw,
// Unschedule), the Banner (the site notice, set under Switches), and
// Settings (the most a day; the news mail's most a day, whether Resend
// stopped it, and the postal address at its foot).
//
// Nothing goes by itself. A send is the owner's press of Send now (or
// Schedule) in the sheet that shows the words kept on the server, and the
// press carries their hash and the version seen: words changed since are
// refused, and a second press finds it gone. Keeping a scheduled one again
// (an edit) makes it a draft.
//
// Loaded when the section is first opened (admin.js), so the console's
// first screen asks none of it. Everything is put on the page as text.
import { $, act, adminJson, ask, cell, count, emptyRow, make, say, timeCell, when } from "/admin-kit.js";
import { group as noticeGroup } from "/notice-view.js";

const MOST_TITLE = 120;
const MOST_BODY = 1000;
const KINDS = [["everyone", "Everyone"], ["plan", "Everyone on a plan"], ["beta", "The beta's testers"],
  ["since", "Who signed up since a day"], ["published", "Who published a model"], ["person", "One person, by handle"]];
const STATE = { draft: "Draft", scheduled: "Scheduled", sent: "Sent", withdrawn: "Withdrawn" };
const MONTHS = Array.from({ length: 12 }, (_, at) => new Intl.DateTimeFormat("en-GB", { month: "short", timeZone: "UTC" })
  .format(Date.UTC(2000, at, 1)));
const MINUTES = Array.from({ length: 96 }, (_, at) => at * 15);

let state = null;
// The draft in the form: its number and the version kept, or none for a new one.
let editing = null;

const section = () => document.querySelector('[data-section="announcements"]');
const tab = (name) => section().querySelector(`[data-tab="${name}"]`);
const lengthOf = (text) => [...String(text || "")].length;

// ---------------------------------------------------------------------------
// The tabs' places, made once.

function build() {
  if (build.done) return;
  build.done = true;
  tab("write").innerHTML = `
    <div class="with-preview">
      <form id="announce-form" class="card console-form" novalidate aria-labelledby="announce-form-h">
        <h3 id="announce-form-h">A new announcement</h3>
        <label><span class="counted">Title <small id="announce-title-n"></small></span>
          <input name="title" autocomplete="off" aria-describedby="announce-title-n"></label>
        <label><span class="counted">Words <small id="announce-body-n"></small></span>
          <textarea name="body" rows="6" aria-describedby="announce-body-n"></textarea></label>
        <label>Link <small>optional: a page here, as /challenge, or an address that starts https://</small>
          <input name="link" inputmode="url" spellcheck="false" autocomplete="off" placeholder="/challenge"></label>
        <fieldset class="audience">
          <legend>Who it is for</legend>
          <label>Audience <select name="kind" id="announce-kind"></select></label>
          <label id="announce-plan-l" hidden>Plan <select name="plan" id="announce-plan"></select></label>
          <fieldset class="date" id="announce-since-l" hidden><legend>Signed up on or after</legend>
            <div class="dropdowns" id="announce-since"></div></fieldset>
          <label id="announce-handle-l" hidden>Their handle
            <input name="handle" autocomplete="off" spellcheck="false" autocapitalize="none" placeholder="@handle"></label>
        </fieldset>
        <label class="choice"><input type="checkbox" name="email" id="announce-email">
          <span>Email it too, to those of them who chose Brickworks news in their Settings</span></label>
        <p class="note" id="announce-email-note"></p>
        <div class="row">
          <button type="submit" class="ghost">Keep the draft</button>
          <button type="button" class="cta" id="announce-review">Review and send…</button>
          <button type="button" class="ghost" id="announce-new">New</button>
          <span class="note" id="announce-note" role="status"></span>
        </div>
      </form>
      <aside class="card preview" aria-labelledby="h-announce-preview">
        <h3 id="h-announce-preview">As they will see it</h3>
        <p class="note" id="announce-count" role="status"></p>
        <div class="announce-shown" id="announce-shown"></div>
      </aside>
    </div>
    <div class="part">
      <div class="lead"><h3 id="h-announce-drafts">Drafts</h3><p class="note">Kept until you send or drop them. Nobody sees a draft.</p></div>
      <div class="table" tabindex="0" role="region" aria-labelledby="h-announce-drafts">
        <table class="queue cards">
          <caption class="visually-hidden">Drafts</caption>
          <thead><tr><th scope="col">Kept</th><th scope="col">For</th><th scope="col">Title</th>
            <th scope="col"><span class="visually-hidden">What to do</span></th></tr></thead>
          <tbody id="announce-drafts"></tbody>
        </table>
      </div>
    </div>`;
  tab("sent").innerHTML = `
    <p class="note">Each one's reach is who it was put before as it went; read is who opened it, clicked who followed
      its link. Withdrawn, it leaves every list; edited, it says so.</p>
    <div class="stats" id="announce-stats"></div>
    <div class="table" tabindex="0" role="region" aria-labelledby="h-announce-sent">
      <table class="queue cards">
        <caption id="h-announce-sent" class="visually-hidden">Sent and scheduled</caption>
        <thead><tr><th scope="col">When</th><th scope="col">Title</th><th scope="col">For</th><th scope="col">State</th>
          <th scope="col" class="num">Reach</th><th scope="col" class="num">Read</th>
          <th scope="col" class="num">Clicked</th><th scope="col">Email</th>
          <th scope="col"><span class="visually-hidden">What to do</span></th></tr></thead>
        <tbody id="announce-sent"></tbody>
      </table>
    </div>
    <p class="note" id="announce-sent-note" role="status"></p>`;
  tab("banner").innerHTML = `
    <div class="card console-form">
      <h3>The site notice</h3>
      <p class="note" id="announce-banner-said" role="status"></p>
      <div id="announce-banner"></div>
      <p class="note">One line at the foot of every page of the site (not the studio), for upkeep or news: on or off,
        its words in each language, warn or plain, and an end, when it goes by itself. Anyone hides it with its ×:
        in that browser, and on every device of theirs once signed in. Each change is in the Audit log.</p>
      <p><a class="cta" href="#switches" id="announce-banner-go">Set, change or clear it under Switches</a></p>
    </div>`;
  tab("settings").innerHTML = `
    <form id="announce-most-form" class="card console-form" novalidate>
      <h3>How many a day</h3>
      <label>At most this many sent a day (UTC), scheduled ones counted on their day
        <input name="most" type="number" min="1" max="20" step="1" inputmode="numeric" required></label>
      <div class="row"><button type="submit">Keep it</button>
        <span class="note" id="announce-most-note" role="status"></span></div>
      <p class="note" id="announce-today"></p>
      <p class="note" id="announce-mail-said"></p>
    </form>
    <form id="announce-news-form" class="card console-form" novalidate>
      <h3>News by email</h3>
      <p class="note">The Resend team that sends these also sends every site's sign-in codes. So news mail stops at
        this many a day, stops until the next day when Resend says the team's quota is used, and always waits its turn
        behind a sign-in code.</p>
      <label>At most this many news mails a day (UTC), every announcement's together; 0 for none
        <input name="most" type="number" min="0" max="10000" step="1" inputmode="numeric" required></label>
      <p class="note" id="announce-news-today" role="status"></p>
      <label>The postal address at the foot of each news mail, up to four lines (none until you give one)
        <textarea name="address" rows="4" autocomplete="street-address"></textarea></label>
      <div class="row"><button type="submit">Keep these</button>
        <span class="note" id="announce-news-note" role="status"></span></div>
    </form>`;
  const kind = $("announce-kind");
  kind.append(...KINDS.map(([value, words]) => new Option(words, value)));
  sinceDropdowns();
  const form = $("announce-form");
  form.addEventListener("input", () => { counted(); previewSoon(); });
  form.addEventListener("change", () => { shownFor(); counted(); previewSoon(); });
  form.addEventListener("submit", (event) => { event.preventDefault(); keep(); });
  $("announce-review").addEventListener("click", () => review());
  $("announce-new").addEventListener("click", async () => {
    if (await keptFirst()) startNew();
  });
  $("announce-most-form").addEventListener("submit", (event) => { event.preventDefault(); keepMost(); });
  $("announce-news-form").addEventListener("submit", (event) => { event.preventDefault(); keepNews(); });
  sheet();
}

/// The day they signed up from, as the site asks every date (site.css
/// fieldset.date): day, month and year, 2024 to this year.
function sinceDropdowns() {
  const year = new Date().getUTCFullYear();
  const choose = (part, said, choices) => {
    const label = make("label");
    const select = make("select");
    select.name = `since_${part}`;
    select.append(...choices.map(([value, text]) => new Option(text, String(value))));
    label.append(make("span", "visually-hidden", `Signed up on or after: ${said}`), select);
    return label;
  };
  const years = [];
  for (let at = year; at >= 2024; at -= 1) years.push([at, String(at)]);
  $("announce-since").replaceChildren(
    choose("day", "day", Array.from({ length: 31 }, (_, at) => [at + 1, String(at + 1)])),
    choose("month", "month", MONTHS.map((name, at) => [at + 1, name])),
    choose("year", "year", years));
  // A month ago, to start from.
  const then = new Date(Date.now() - 30 * 86400000);
  const form = $("announce-form");
  form.elements.since_day.value = String(then.getUTCDate());
  form.elements.since_month.value = String(then.getUTCMonth() + 1);
  form.elements.since_year.value = String(then.getUTCFullYear());
}

/// Only the audience's own question shown: the plan, the day, or the handle.
function shownFor() {
  const kind = $("announce-kind").value;
  $("announce-plan-l").hidden = kind !== "plan";
  $("announce-since-l").hidden = kind !== "since";
  $("announce-handle-l").hidden = kind !== "person";
}

/// Each field's count of what it holds and its most, over said in words:
/// never cut, refused by the server with the same words.
function counted() {
  const form = $("announce-form");
  for (const [name, most] of [["title", MOST_TITLE], ["body", MOST_BODY]]) {
    const n = lengthOf(form.elements[name].value.trim());
    const said = $(`announce-${name}-n`);
    said.textContent = n > most ? `${n} of ${most}: ${n - most} over` : `${n} of ${most}`;
    said.classList.toggle("bad", n > most);
  }
}

// ---------------------------------------------------------------------------
// The read, and the tabs drawn from it.

/// GET op=announce: the section whole, drawn.
export async function loadAnnouncements() {
  build();
  state = await adminJson({ op: "announce" });
  draw();
  previewSoon(0);
}

async function reread() {
  state = await adminJson({ op: "announce" });
  draw();
}

function draw() {
  const ready = state?.ready === true;
  let line = section().querySelector("#announce-not-yet");
  if (!line) {
    line = make("p", "note bad");
    line.id = "announce-not-yet";
    line.setAttribute("role", "alert");
    section().querySelector(".tabs").before(line);
  }
  line.hidden = ready;
  line.textContent = ready ? "" : state?.said || "Not open yet.";
  for (const button of section().querySelectorAll("#announce-form button, #announce-most-form button, #announce-news-form button")) {
    button.disabled = !ready;
  }
  if (!ready) return;
  drawPlans();
  drawEmail();
  drawDrafts();
  drawSent();
  drawBanner();
  drawSettings();
  const due = state.announcements.filter((one) => one.status === "scheduled").length;
  const n = $("tab-announce-due");
  if (n) n.textContent = due ? String(due) : "";
}

function drawPlans() {
  const plan = $("announce-plan");
  const kind = $("announce-kind");
  const off = state.plans === null;
  kind.querySelector('option[value="plan"]').disabled = off;
  kind.querySelector('option[value="plan"]').textContent = off ? "Everyone on a plan (billing is off here)" : "Everyone on a plan";
  if (off && kind.value === "plan") kind.value = "everyone";
  const was = plan.value;
  plan.replaceChildren(...(state.plans || []).map((one) => new Option(`${one.name}${one.default ? " (everyone's, unless they chose another)" : ""}`,
    one.key)));
  if (was) plan.value = was;
  shownFor();
}

function drawEmail() {
  const box = $("announce-email");
  // The checks' pool, and a preview of the site, never mail anybody.
  box.disabled = state.test === true || !state.mail;
  if (box.disabled) box.checked = false;
  say("announce-email-note", state.test ? "Never by email here: this is the checks' own pool (a preview, or ?tests=1), which mails nobody."
    : !state.mail ? `Never by email here: this site has no ${missingWords()}.`
      : "Off unless you tick it. In-app reaches everyone it is for; the email only those who chose news, with one-click unsubscribe.");
}

/// A cell of whole numbers, for the table's counts.
const num = (row, n) => cell(row, count(n), "num");

function drawDrafts() {
  const body = $("announce-drafts");
  body.replaceChildren();
  for (const one of state.announcements.filter((a) => a.status === "draft")) {
    const row = make("tr");
    row.id = `announce-draft-${one.id}`;
    timeCell(row, one.changed_at || one.made_at);
    cell(row, said(one.audience));
    cell(row, one.title, "text");
    const acts = cell(row, "", "acts");
    const open = make("button", "cta ghost small", "Open");
    open.type = "button";
    open.setAttribute("aria-label", `Open the draft "${one.title}"`);
    open.addEventListener("click", async () => {
      if (await keptFirst()) fill(one);
    });
    const drop = act("Drop", async () => {
      if (!(await ask({ title: `Drop the draft "${one.title}"?`, body: "It cannot be brought back.", yes: "Drop it", danger: true }))) {
        return false;
      }
      try {
        await adminJson({ op: "announce_drop" }, { method: "POST", body: { id: one.id } });
        if (editing?.id === one.id) startNew();
        await reread();
        say("announce-note", "Dropped.");
        $("announce-review").focus();
        return true;
      } catch (problem) {
        say("announce-note", problem.message, true);
        return false;
      }
    }, "ghost small");
    drop.setAttribute("aria-label", `Drop the draft "${one.title}"`);
    acts.append(open, drop);
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, "No drafts.");
  labelCells(body);
}

function drawSent() {
  const body = $("announce-sent");
  body.replaceChildren();
  const gone = state.announcements.filter((a) => a.status !== "draft");
  for (const one of gone) {
    const row = make("tr");
    row.id = `announce-${one.id}`;
    timeCell(row, one.sent_at || one.send_at || one.changed_at);
    const title = make("span", "", one.title);
    cell(row, title, "text");
    if (one.edited_at) title.after(make("small", "", `edited ${when(one.edited_at)}`));
    if (one.said) title.after(make("small", "", one.said));
    cell(row, said(one.audience));
    cell(row, one.status === "scheduled" ? `Scheduled for ${when(one.send_at)}`
      : one.status === "withdrawn" ? `Withdrawn ${when(one.withdrawn_at)}` : STATE[one.status] || one.status);
    num(row, one.reach);
    num(row, one.read);
    num(row, one.clicked);
    const mails = one.mails || {};
    cell(row, !one.email ? "No" : ["sent", "failed", "dry", "sending"].filter((k) => mails[k]).map((k) => `${count(mails[k])} ${k}`)
      .join(", ") || (one.status === "sent" ? "Going" : "When sent"));
    const acts = cell(row, "", "acts");
    if (one.status === "scheduled") {
      const change = make("button", "ghost small", "Change");
      change.type = "button";
      change.setAttribute("aria-label", `Change "${one.title}": it is a draft again until you send it`);
      change.addEventListener("click", async () => {
        if (!(await keptFirst())) return;
        fill(one);
        location.hash = "#announcements/write";
      });
      const stop = act("Unschedule", () => doAct("announce_unschedule", one, "Unscheduled: it is a draft again, under Write."), "ghost small");
      stop.setAttribute("aria-label", `Unschedule "${one.title}"`);
      acts.append(change, stop);
    }
    if (one.status === "sent") {
      const edit = make("button", "ghost small", "Edit…");
      edit.type = "button";
      edit.setAttribute("aria-label", `Edit "${one.title}" for everyone it reached`);
      edit.addEventListener("click", () => editSent(one));
      const pull = act("Withdraw", async () => {
        if (!(await ask({ title: `Withdraw "${one.title}"?`, body: `It leaves the Notifications of ${reached(one.reach)}. `
          + "Mail already sent stays sent.", yes: "Withdraw it", danger: true }))) return false;
        return doAct("announce_withdraw", one, `Withdrawn: gone from the Notifications of ${reached(one.reach)}.`);
      }, "ghost small");
      pull.setAttribute("aria-label", `Withdraw "${one.title}"`);
      acts.append(edit, pull);
    }
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, "Nothing sent or scheduled yet.");
  labelCells(body);
  const sent = gone.filter((a) => a.status === "sent");
  const reach = sent.reduce((n, a) => n + (Number(a.reach) || 0), 0);
  const read = sent.reduce((n, a) => n + (Number(a.read) || 0), 0);
  $("announce-stats").replaceChildren(...[["Sent", count(sent.length)], ["Scheduled", count(gone.filter((a) => a.status === "scheduled").length)],
    ["Reached", count(reach)], ["Read", reach ? `${Math.round((100 * read) / reach)}%` : "—"]].map(([what, n]) =>
    make("div", "stat", make("b", "", n), make("small", "", what))));
}

/// One of the rows' acts, said in the Sent tab, focus kept in the table.
async function doAct(op, one, words) {
  try {
    await adminJson({ op }, { method: "POST", body: { id: one.id } });
    await reread();
    say("announce-sent-note", words);
    $("announce-sent").closest(".table").focus();
    return true;
  } catch (problem) {
    say("announce-sent-note", problem.message, true);
    await reread().catch(() => null);
    return false;
  }
}

function drawBanner() {
  const now = state.banner;
  say("announce-banner-said", !now ? "Off: no notice shows." : `On since ${when(now.set_at)}, set by ${now.set_by || "—"}${now.ends_at
    ? `, until ${when(now.ends_at)}` : ", until it is cleared"}.`);
  const words = now?.words?.en || "";
  $("announce-banner").replaceChildren(...(now ? [make("p", `words${now.tone === "warn" ? " warn" : ""}`, words)] : []));
}

function drawSettings() {
  const form = $("announce-most-form");
  if (document.activeElement !== form.elements.most) form.elements.most.value = String(state.most);
  say("announce-today", `Today (UTC): ${count(state.today?.sent)} sent and ${count(state.today?.scheduled)} scheduled, of ${state.most}.`
    + `${state.set_by ? ` The most was set by ${state.set_by}, ${when(state.set_at)}.` : " The most is the default."}`);
  say("announce-mail-said", state.test ? "Mail: never from here, the checks' own pool." : state.mail
    ? "Mail: through Resend from brickworks.diy, a hundred to a batch and a batch every 1.1 seconds at most, only to those who chose news."
    : `Mail: none, this site has no ${missingWords()}.`);
  drawNews();
}

/// What this deployment lacks to mail news, in words (api/_announce.js
/// mailMissing): "mail key", "unsubscribe secret (NEWS_UNSUB_SECRET)".
function missingWords() {
  const missing = Array.isArray(state.mail_missing) ? state.mail_missing : [];
  return missing.map((one) => `${one.words.replace(/^(a|its) /, "")} (${one.name})`).join(" or ") || "mail key";
}

/// News mail's most a day, today's count, whether Resend stopped it, and
/// the address at its foot.
function drawNews() {
  const form = $("announce-news-form");
  const news = state.news_mail;
  if (!news) {
    form.elements.most.disabled = true;
    form.querySelector("button").disabled = true;
    say("announce-news-today", "Not kept yet: supabase/announce2.sql is not applied, so news mail has no most a day here.", true);
    return;
  }
  form.elements.most.disabled = false;
  if (document.activeElement !== form.elements.most) form.elements.most.value = String(news.most);
  if (document.activeElement !== form.elements.address) form.elements.address.value = state.address || "";
  const stopped = news.stopped?.until
    ? ` Stopped until ${when(news.stopped.until)}: Resend said the team's ${news.stopped.why === "monthly_quota_exceeded" ? "monthly"
      : "daily"} quota is used, so what is left goes to sign-in codes. It starts again by itself.`
    : "";
  say("announce-news-today", `Today (UTC): ${count(news.today)} of ${count(news.most)} news mails.`
    + `${news.most_by ? ` The most was set by ${news.most_by}, ${when(news.most_at)}.` : " The most is the default."}${stopped}`,
  Boolean(stopped));
}

async function keepNews() {
  const form = $("announce-news-form");
  const most = Number(form.elements.most.value);
  if (!Number.isInteger(most) || most < 0 || most > 10000) return say("announce-news-note", "A whole number from 0 to 10,000.", true);
  const address = form.elements.address.value;
  if (address.split("\n").filter((line) => line.trim()).length > 4) return say("announce-news-note", "An address is at most four lines.", true);
  if ([...address.trim()].length > 200) {
    return say("announce-news-note", `The address is ${[...address.trim()].length} characters: at most 200.`, true);
  }
  const button = form.querySelector("button");
  if (button.disabled) return;
  button.disabled = true;
  try {
    if (most !== state.news_mail?.most) await adminJson({ op: "announce_mail_most" }, { method: "POST", body: { most } });
    if (address.trim() !== (state.address || "")) {
      await adminJson({ op: "announce_mail_address" }, { method: "POST", body: { address } });
    }
    await reread();
    say("announce-news-note", `Kept: at most ${count(most)} a day${$("announce-news-form").elements.address.value.trim()
      ? ", with the address at each one's foot" : ", with no address"}.`);
  } catch (problem) {
    say("announce-news-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
}

async function keepMost() {
  const form = $("announce-most-form");
  const most = Number(form.elements.most.value);
  if (!Number.isInteger(most) || most < 1 || most > 20) return say("announce-most-note", "A whole number from 1 to 20.", true);
  const button = form.querySelector("button");
  if (button.disabled) return;
  button.disabled = true;
  try {
    await adminJson({ op: "announce_limit" }, { method: "POST", body: { most } });
    await reread();
    say("announce-most-note", `Kept: at most ${most} a day.`);
  } catch (problem) {
    say("announce-most-note", problem.message, true);
  } finally {
    button.disabled = false;
  }
}

/// Each cell named by its column, for the rows drawn as cards on a phone.
function labelCells(body) {
  const heads = [...(body.closest("table")?.tHead?.rows[0]?.cells || [])].map((th) => th.textContent.trim());
  for (const row of body.rows) [...row.cells].forEach((td, at) => { if (heads[at] && td.colSpan === 1) td.dataset.label = heads[at]; });
}

/// Who it is for, in words.
function said(audience) {
  switch (audience?.kind) {
    case "everyone": return "Everyone";
    case "plan": return `On ${(state?.plans || []).find((one) => one.key === audience.plan)?.name || audience.plan}`;
    case "beta": return "The beta's testers";
    case "since": return `Signed up since ${new Date(audience.since).toLocaleDateString(undefined, { day: "numeric", month: "short",
      year: "numeric", timeZone: "UTC" })}`;
    case "published": return "Who published";
    case "person": return `@${audience.handle}`;
    default: return "—";
  }
}

// ---------------------------------------------------------------------------
// The form: what is typed, kept, and looked at as its people will see it.

function audienceTyped() {
  const form = $("announce-form").elements;
  const kind = form.kind.value;
  if (kind === "plan") return { kind, plan: form.plan.value };
  if (kind === "since") {
    const at = Date.UTC(Number(form.since_year.value), Number(form.since_month.value) - 1, Number(form.since_day.value));
    return { kind, since: new Date(at).toISOString() };
  }
  if (kind === "person") return { kind, handle: form.handle.value };
  return { kind };
}

function typed() {
  const form = $("announce-form").elements;
  return { ...(editing ? { id: editing.id } : {}), title: form.title.value, body: form.body.value, link: form.link.value,
    audience: audienceTyped(), ...(form.email.checked ? { email: true } : {}) };
}

/// [one] in the form, to change and send.
function fill(one) {
  const form = $("announce-form").elements;
  editing = { id: one.id, changed_at: one.changed_at };
  form.title.value = one.title || "";
  form.body.value = one.body || "";
  form.link.value = one.link || "";
  form.kind.value = one.audience?.kind || "everyone";
  if (one.audience?.kind === "plan") form.plan.value = one.audience.plan;
  if (one.audience?.kind === "person") form.handle.value = `@${one.audience.handle}`;
  if (one.audience?.kind === "since") {
    const at = new Date(one.audience.since);
    form.since_day.value = String(at.getUTCDate());
    form.since_month.value = String(at.getUTCMonth() + 1);
    form.since_year.value = String(at.getUTCFullYear());
  }
  form.email.checked = one.email === true && !form.email.disabled;
  $("announce-form-h").textContent = one.status === "scheduled" ? `Changing number ${one.id}: scheduled until kept again`
    : `Draft number ${one.id}`;
  shownFor();
  counted();
  previewSoon(0);
  say("announce-note", "");
  held = JSON.stringify(typed());
  form.title.focus();
}

// What the form held when it was last kept, opened or emptied. Words typed
// since are kept before New or another announcement takes their place, and
// stay in the form, said why, when they cannot be: never lost.
let held = "";

async function keptFirst() {
  const form = $("announce-form").elements;
  const empty = !["title", "body", "link"].some((name) => form[name].value.trim());
  if (empty || JSON.stringify(typed()) === held) return true;
  const row = await keep({ quiet: true });
  if (row) say("announce-note", `What you typed is kept as draft number ${row.id}.`);
  return Boolean(row);
}

function startNew() {
  editing = null;
  const form = $("announce-form");
  for (const name of ["title", "body", "link", "handle"]) form.elements[name].value = "";
  form.elements.kind.value = "everyone";
  form.elements.email.checked = false;
  $("announce-form-h").textContent = "A new announcement";
  shownFor();
  counted();
  previewSoon(0);
  held = JSON.stringify(typed());
}

// The form kept, once at a time: Enter in a field is Keep, and a second
// Enter or press while the first is on its way does nothing.
let keeping = null;

/// The form kept on the server: the row as kept (with its hash), or null,
/// said at the form's line.
function keep({ quiet = false } = {}) {
  if (keeping) return keeping;
  const buttons = [...$("announce-form").querySelectorAll("button")];
  for (const button of buttons) button.disabled = true;
  keeping = (async () => {
    try {
      const done = await adminJson({ op: "announce_keep" }, { method: "POST", body: typed() });
      editing = { id: done.announcement.id, changed_at: done.announcement.changed_at };
      held = JSON.stringify(typed());
      $("announce-form-h").textContent = `Draft number ${done.announcement.id}`;
      await reread();
      if (!quiet || done.outcome === "unscheduled") {
        say("announce-note", done.outcome === "unscheduled" ? "Kept, and no longer scheduled: a change makes it a draft again. Send it again to schedule it."
          : "Kept as a draft. Nobody sees it until you send it.");
      }
      return done.announcement;
    } catch (problem) {
      say("announce-note", problem.message, true);
      return null;
    } finally {
      for (const button of buttons) button.disabled = false;
      keeping = null;
    }
  })();
  return keeping;
}

// What the preview shows is the server's: the group as the person's page
// draws it, and the count of who it reaches now. Asked a moment after the
// typing stops; an answer older than the last asked is dropped.
let asked = 0;
let soon = 0;
function previewSoon(wait = 350) {
  clearTimeout(soon);
  soon = setTimeout(() => preview(), wait);
}

async function preview() {
  if (!state?.ready) return;
  const mine = ++asked;
  const words = typed();
  let looked;
  try {
    looked = await adminJson({ op: "announce_preview", words: JSON.stringify(words) });
  } catch (problem) {
    if (mine === asked) say("announce-count", problem.message, true);
    return;
  }
  if (mine !== asked) return;
  if (looked.refused) say("announce-count", looked.refused, true);
  else say("announce-count", reachWords(looked.count, words.email ? looked.mail : null));
  shown($("announce-shown"), looked.group);
}

/// Who a sent one reached, in words: "the one person it reached", "all 12 it reached".
const reached = (n) => (Number(n) === 1 ? "the one person it reached" : `all ${count(n)} it reached`);
const reachWords = (n, mail) => `Reaches ${count(n)} ${n === 1 ? "person" : "people"} now${mail === null || mail === undefined ? ""
  : `, ${count(mail)} of them by email too`}. Who it reaches is fixed as it goes.`;

/// [group] (the server's) drawn where it is shown: in their Notifications,
/// and their account menu's line, each by the site's own styles in a place
/// of its own (a shadow root), so nothing of the console's styles reaches
/// it. Its links go nowhere from here; where they open is said under it.
function shown(where, group) {
  const page = make("div", "shown-page");
  const menu = make("div", "shown-menu");
  page.setAttribute("role", "group");
  page.setAttribute("aria-label", "On their Notifications page");
  menu.setAttribute("role", "group");
  menu.setAttribute("aria-label", "In their account menu");
  where.replaceChildren(make("p", "note", "On their Notifications page, new:"), page, make("p", "note", "In their account menu:"), menu);
  if (!group) {
    page.append(make("p", "note faint", "Give it a title to see it."));
    return;
  }
  const opens = make("p", "note");
  where.append(opens);
  const drawn = noticeGroup({ ...group, unread: true, rows: (group.rows || []).map((row) => ({ ...row, unread: true })) }, 0);
  const to = drawn.querySelector(".body h2 a")?.href || "";
  opens.textContent = `Opens ${to.replace(location.origin, "brickworks.diy")}, in each person's language.`;
  framed(page, make("ol", "notices", drawn));
  const list = make("div", "site-head");
  const panel = make("div", "menu-list");
  const part = make("div", "account-part");
  const nav = make("nav");
  const entry = make("a", "", "Notifications");
  entry.href = "/notifications";
  const n = make("span", "count", "1");
  n.setAttribute("aria-label", "1 new");
  entry.append(" ", n);
  nav.append(entry);
  part.append(nav);
  panel.append(part);
  list.append(panel);
  framed(menu, list);
}

/// [inside] in [host]'s own shadow root with the site's styles.
function framed(host, inside) {
  const root = host.shadowRoot || host.attachShadow({ mode: "open" });
  const sheetOf = (href) => Object.assign(document.createElement("link"), { rel: "stylesheet", href });
  const own = document.createElement("style");
  own.textContent = ":host { display: block; } .notices { max-width: none; } "
    + ".site-head { position: static; backdrop-filter: none; -webkit-backdrop-filter: none; background: none; border: 0; } "
    + ".menu-list { position: static; min-width: 0; max-width: 260px; }";
  root.replaceChildren(sheetOf("/site.css"), sheetOf("/directory.css"), own, inside);
  for (const a of root.querySelectorAll("a")) a.tabIndex = -1;
  if (!root.held) {
    root.held = true;
    root.addEventListener("click", (event) => { if (event.target.closest("a")) event.preventDefault(); });
  }
}

// ---------------------------------------------------------------------------
// The press: the sheet that shows exactly what goes, to whom, with Send now,
// or a day and a quarter-hour to Schedule.

async function review() {
  const row = await keep({ quiet: true });
  if (!row) return;
  let looked;
  try {
    looked = await adminJson({ op: "announce_preview", words: JSON.stringify({ id: row.id, title: row.title, body: row.body,
      link: row.link, audience: row.audience, ...(row.email ? { email: true } : {}) }) });
  } catch (problem) {
    return say("announce-note", problem.message, true);
  }
  if (looked.refused) return say("announce-note", looked.refused, true);
  const note = make("p", "note");
  note.setAttribute("role", "status");
  const place = make("div", "announce-shown");
  shown(place, looked.group);
  const parts = [
    make("p", "", `For ${said(row.audience).replace(/^[A-Z]/, (c) => c.toLowerCase())}: ${reachWords(looked.count, row.email ? looked.mail : null)}`),
    place,
  ];
  const now = act("Send now", () => press(row, null, note), "cta");
  parts.push(make("div", "row", now));
  const dayPick = make("select");
  dayPick.append(Object.assign(new Option("Day", "", true, true), { disabled: true, hidden: true }));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let at = 0; at <= 60; at += 1) {
    const d = new Date(today);
    d.setDate(today.getDate() + at);
    dayPick.append(new Option(at === 0 ? "Today" : at === 1 ? "Tomorrow" : d.toLocaleDateString(undefined, { weekday: "short", day: "numeric",
      month: "short" }), d.toISOString()));
  }
  const timePick = make("select");
  timePick.append(Object.assign(new Option("Time", "", true, true), { disabled: true, hidden: true }));
  for (const minutes of MINUTES) {
    const t = new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60);
    timePick.append(new Option(t.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), String(minutes)));
  }
  const zone = Intl.DateTimeFormat().resolvedOptions().timeZone || "this computer's time";
  const later = act("Schedule", async () => {
    if (!dayPick.value || timePick.value === "") {
      say(note, "Choose a day and a time.", true);
      return false;
    }
    const at = new Date(dayPick.value);
    at.setMinutes(Number(timePick.value));
    return press(row, at.toISOString(), note);
  }, "ghost");
  parts.push(make("div", "part", make("h3", "", "Or at a time"),
    make("p", "note", `In ${zone}. Looked for every quarter of an hour, so it goes within 15 minutes of then, to whoever it is for then, `
      + "and only as these words: change it and it is a draft again."),
    make("div", "when-pair", make("label", "", make("span", "visually-hidden", "Day"), dayPick),
      make("label", "", make("span", "visually-hidden", "Time"), timePick), later)));
  parts.push(note);
  openSheet("Send this announcement?", parts);
}

/// The owner's press on [row] (now, or at [at]): the hash and version they
/// saw, sent with it.
async function press(row, at, note) {
  try {
    const done = await adminJson({ op: "announce_send" }, { method: "POST", body: { id: row.id, hash: row.hash, changed_at: row.changed_at,
      ...(at ? { at } : {}) } });
    closeSheet();
    startNew();
    await reread();
    say("announce-note", done.outcome === "scheduled" ? `Scheduled for ${when(done.announcement.send_at)}: under Sent and scheduled.`
      : `Sent to ${count(done.reach)} ${done.reach === 1 ? "person" : "people"}${done.mail?.sent ? `, ${count(done.mail.sent)} emailed so far` : ""}.`);
    $("announce-review").focus();
    return true;
  } catch (problem) {
    say(note, problem.message, true);
    await reread().catch(() => null);
    // A Send refused is looked at again (Review), never pressed twice from
    // this sheet; a time refused is chosen again.
    return !at;
  }
}

// ---------------------------------------------------------------------------
// A sent one's words changed for everybody: looked at first (the server
// draws it, marked edited), then changed on that exact look.

function editSent(one) {
  const form = make("form", "console-form");
  form.noValidate = true;
  const title = Object.assign(make("input"), { name: "title", value: one.title || "", autocomplete: "off" });
  const body = Object.assign(make("textarea"), { name: "body", rows: 5, value: one.body || "" });
  const link = Object.assign(make("input"), { name: "link", value: one.link || "", inputMode: "url", spellcheck: false, autocomplete: "off" });
  form.append(make("label", "", "Title", title), make("label", "", "Words", body), make("label", "", "Link", link));
  const note = make("p", "note");
  note.setAttribute("role", "status");
  const place = make("div", "announce-shown");
  let seen = null;
  const words = () => ({ id: one.id, changed_at: one.changed_at, title: title.value, body: body.value, link: link.value });
  const go = act("Change it for everyone", async () => {
    if (!seen) return false;
    try {
      await adminJson({ op: "announce_edit" }, { method: "POST", body: { ...seen, hash: seen.hash } });
      closeSheet();
      await reread();
      say("announce-sent-note", `Changed for ${reached(one.reach)}, marked edited.`);
      $(`announce-${one.id}`)?.querySelector("button")?.focus();
      return true;
    } catch (problem) {
      say(note, problem.message, true);
      return false;
    }
  }, "cta");
  go.disabled = true;
  const look = make("button", "ghost", "Look at it");
  look.type = "submit";
  form.addEventListener("input", () => { seen = null; go.disabled = true; });
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (look.disabled) return;
    look.disabled = true;
    try {
      const asked = words();
      const done = await adminJson({ op: "announce_edit" }, { method: "POST", body: asked });
      seen = { ...asked, hash: done.hash };
      shown(place, done.group);
      say(note, "This is how it will read for everyone it reached. Change it, or look again after a change.");
      go.disabled = false;
    } catch (problem) {
      say(note, problem.message, true);
    } finally {
      look.disabled = false;
    }
  });
  form.append(make("div", "row", look, go), note);
  openSheet(`Edit "${one.title}"`, [make("p", "note", "It changes where it is, in every list it is in; nobody is told again, and it says edited. "
    + "Mail already sent stays as it was."), form, place]);
}

// ---------------------------------------------------------------------------
// The section's own sheet (dialog.sheet, site.css).

function sheet() {
  if ($("announce-sheet")) return;
  const dialog = make("dialog", "sheet");
  dialog.id = "announce-sheet";
  dialog.setAttribute("aria-labelledby", "announce-sheet-title");
  const head = make("div", "sheet-head");
  const title = make("h2", "", "—");
  title.id = "announce-sheet-title";
  const close = make("button", "icon-btn");
  close.type = "button";
  close.setAttribute("aria-label", "Close");
  close.innerHTML = '<svg class="icon" aria-hidden="true"><use href="/icons.svg#close"/></svg>';
  close.addEventListener("click", closeSheet);
  head.append(title, close);
  const body = make("div", "sheet-body");
  body.id = "announce-sheet-body";
  dialog.append(head, body);
  dialog.addEventListener("click", (event) => { if (event.target === dialog) closeSheet(); });
  document.body.append(dialog);
}

function openSheet(title, body) {
  $("announce-sheet-title").textContent = title;
  $("announce-sheet-body").replaceChildren(...body);
  if (!$("announce-sheet").open) $("announce-sheet").showModal();
}

function closeSheet() {
  if ($("announce-sheet").open) $("announce-sheet").close();
}
