// The console's Switches (admin.html #switches, console3): the site's
// notice, set and cleared here (api/admin.js notice_set, notice_clear, each
// kept in the audit) with a preview of it as visitors see it (web/notice.js,
// site.css .site-notice); the settings the console keeps, the beta's
// flipped here as in Beta (beta_switch, one act); the numbers a phone is
// warned by (phone_rules, api/_phone.js; phonetruth), and the engine an iPhone
// starts (phone_engine; nothreads); and every variable of the
// deployment by name: whether this deployment has it, which of Vercel's
// environments have it, what it switches and where it is changed. Never a
// value, never its length (/api/admin?op=switches, api/_console_switches.js).
//
// Everything is put on the page as text, never as markup.
import { $, act, adminJson, ago, ask, cell, emptyRow, make, post, say, segmented, sift, when } from "/admin-kit.js";

const LANGS = { en: "English", de: "Deutsch", fr: "Français", es: "Español" };
let tone = "info";
let after = () => {};
/// [then]() after an act here, for the Overview's counts.
export function whenChanged(then) { after = then; }

/// The notice as web/notice.js draws it, from the form's English.
function previewNotice() {
  const form = $("notice-form");
  const words = form.elements.en.value.trim();
  const card = make("aside", `site-notice shown${tone === "warn" ? " warn" : ""}`);
  card.setAttribute("aria-label", "Site notice, as visitors will see it");
  const text = make("p", words ? "words" : "words faint", words || "Its words, in English.");
  const close = make("span", "icon-btn small");
  close.setAttribute("aria-hidden", "true");
  close.innerHTML = '<svg class="icon" aria-hidden="true" focusable="false"><use href="/icons.svg#close"></use></svg>';
  card.append(text, close);
  const typed = Object.keys(LANGS).filter((lang) => form.elements[lang].value.trim());
  $("notice-preview").replaceChildren(card, make("p", "note", typed.length > 1
    ? `In ${typed.map((lang) => LANGS[lang]).join(", ")}; the other pages show the English.`
    : "Every page shows the English: no other language is typed."));
}

segmented($("notice-tone"), (value) => { tone = value === "warn" ? "warn" : "info"; previewNotice(); });
$("notice-form").addEventListener("input", previewNotice);

// The notice's end: a day (none, or today and the next 60) and a quarter
// hour, in this browser's time, as the console asks every time.
function endsPickers() {
  const dayPick = $("notice-ends-day");
  const timePick = $("notice-ends-time");
  if (!dayPick || dayPick.options.length) return;
  dayPick.append(new Option("None: until it is cleared", ""));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let at = 0; at <= 60; at += 1) {
    const d = new Date(today);
    d.setDate(today.getDate() + at);
    dayPick.append(new Option(at === 0 ? "Today" : at === 1 ? "Tomorrow" : d.toLocaleDateString(undefined, { weekday: "short", day: "numeric",
      month: "short" }), d.toISOString()));
  }
  for (let minutes = 0; minutes < 24 * 60; minutes += 15) {
    const t = new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60);
    timePick.append(new Option(t.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), String(minutes)));
  }
  const pair = () => { timePick.disabled = !dayPick.value; };
  dayPick.addEventListener("change", pair);
  pair();
}
endsPickers();

/// The end chosen, as an ISO time, or "" for none.
function endsChosen() {
  const dayPick = $("notice-ends-day");
  if (!dayPick?.value) return "";
  const at = new Date(dayPick.value);
  at.setMinutes(Number($("notice-ends-time").value) || 0);
  return at.toISOString();
}

/// [iso] shown in the end's pickers (its day added if it is past the 60).
function endsShown(iso) {
  const dayPick = $("notice-ends-day");
  if (!dayPick) return;
  if (!iso) {
    dayPick.value = "";
  } else {
    const at = new Date(iso);
    const midnight = new Date(at);
    midnight.setHours(0, 0, 0, 0);
    const value = midnight.toISOString();
    if (![...dayPick.options].some((one) => one.value === value)) {
      dayPick.append(new Option(midnight.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" }), value));
    }
    dayPick.value = value;
    $("notice-ends-time").value = String(Math.floor((at.getHours() * 60 + at.getMinutes()) / 15) * 15);
  }
  dayPick.dispatchEvent(new Event("change"));
}

$("notice-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const words = Object.fromEntries(Object.keys(LANGS).map((lang) => [lang, form.elements[lang].value.trim()]).filter(([, w]) => w));
  if (!words.en) return say("notice-note", "Give it its words in English.", true);
  // Its end, if one is chosen: the time it goes by itself (api/_announce.js).
  const ends = endsChosen();
  send.disabled = true;
  await post({ op: "notice_set" }, "notice-note", (said) => `Shown on every page of the site, not the studio${said.languages?.length > 1 ? `, in ${said.languages
    .map((lang) => LANGS[lang]).join(", ")}` : ""}${said.ends_at ? `, until ${when(said.ends_at)}` : ""}: visitors see it within a minute or two.`
    + `${said.ends_said ? ` ${said.ends_said}` : ""}`, { body: { words, tone, ...(ends ? { ends } : {}) },
    after: async () => { await loadSwitches(); after(); } });
  send.disabled = false;
});

$("notice-clear").addEventListener("click", async () => {
  if (!(await ask({ title: "Clear the notice?", body: "It goes from every page within a minute or two.", yes: "Clear it" }))) return;
  $("notice-clear").disabled = true;
  await post({ op: "notice_clear" }, "notice-note", "Cleared: it goes from every page within a minute or two.",
    { after: async () => { await loadSwitches(); after(); } });
  $("notice-clear").disabled = false;
});

$("variables-q").addEventListener("input", () => sift($("variables"), $("variables-q").value));

// The numbers a phone is warned by: both kept in one act, or neither.
$("phones-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const body = { phone_parts: form.elements.phone_parts.value.trim(), phone_start_s: form.elements.phone_start_s.value.trim() };
  send.disabled = true;
  await post({ op: "phone_rules" }, "phones-note", (said) => `Kept: ${Number(said.phone_parts).toLocaleString("en-US")} parts, `
    + `${said.phone_start_s} s. Pages read them within a minute or two.`, { body,
    after: async () => { delete form.dataset.drawn; await loadSwitches(); after(); } });
  send.disabled = false;
  // Switches drawn again above can push it off a phone's screen: what the
  // press came to is brought into view.
  $("phones-note").scrollIntoView({ block: "nearest" });
});

// Which engine an iPhone or iPad starts (nothreads, api/_phone.js): one act.
$("phones-engine").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const on = form.elements.phone_nothreads.checked;
  send.disabled = true;
  await post({ op: "phone_engine" }, "phones-engine-note", (said) => (said.phone_nothreads
    ? "Kept: iPhones and iPads start the engine without threads here."
    : "Kept: iPhones and iPads start the threaded engine here, as everyone else does.")
    + " Pages read it within a minute or two.", { body: { on },
    after: async () => { delete form.dataset.drawn; await loadSwitches(); after(); } });
  send.disabled = false;
  $("phones-engine-note").scrollIntoView({ block: "nearest" });
});

function drawEngine(s) {
  const form = $("phones-engine");
  const engine = (s.phone || []).find((one) => one.kind === "switch");
  form.querySelector('button[type="submit"]').disabled = !engine;
  if (!engine) return say("phone_nothreads-was", "not read just now: off, as measured");
  // A tick not yet kept stays as ticked when the page redraws.
  if (!form.dataset.drawn) form.elements.phone_nothreads.checked = engine.value === true;
  form.dataset.drawn = "yes";
  say("phone_nothreads-was", engine.set ? `${engine.value ? "on" : "off"}, set ${ago(engine.set_at)}${engine.set_by ? ` by ${engine.set_by}` : ""}`
    : "off until it is set here");
}

function drawPhones(s) {
  const form = $("phones-form");
  say("phones-scope", s.scope === "live" ? "brickworks.diy" : `this preview (${s.scope})`);
  drawEngine(s);
  const rules = (s.phone || []).filter((one) => one.kind !== "switch");
  form.querySelector('button[type="submit"]').disabled = !rules.length;
  if (!rules.length) return say("phones-said", "Not read just now: the measured numbers stand.", true);
  for (const one of rules) {
    const input = form.elements[one.name];
    if (!input) continue;
    // What is typed and not yet kept stays as typed when the page redraws.
    if (!form.dataset.drawn) input.value = String(one.value);
    say(`${one.name}-was`, one.set ? `set ${ago(one.set_at)}${one.set_by ? ` by ${one.set_by}` : ""}; measured ${one.fallback.toLocaleString("en-US")}`
      : `as measured`);
  }
  form.dataset.drawn = "yes";
  const set = rules.filter((one) => one.set).length;
  say("phones-said", set ? `${set === rules.length ? "Both" : "One"} set here; the rest as measured.` : "As measured: neither is set here yet.");
}

function drawNotice(s) {
  const now = s.notice;
  const form = $("notice-form");
  say("notice-scope", s.scope === "live" ? "brickworks.diy" : `this preview (${s.scope})`);
  if (!s.notice_ready) {
    say("notice-said", "Not open yet: supabase/console3.sql is not applied.", true);
    form.querySelector('button[type="submit"]').disabled = true;
  } else {
    form.querySelector('button[type="submit"]').disabled = false;
    say("notice-said", now ? `Showing since ${when(now.set_at)}, set by ${now.set_by}${now.ends_at ? `, until ${when(now.ends_at)}`
      : ", until you clear it"}.` : "None is showing.");
  }
  $("notice-clear").hidden = !now;
  // The form holds what is showing, to change or clear it.
  if (now && !form.dataset.drawn) {
    for (const lang of Object.keys(LANGS)) form.elements[lang].value = now.words?.[lang] || "";
    endsShown(now.ends_at || "");
    tone = now.tone === "warn" ? "warn" : "info";
    for (const button of $("notice-tone").querySelectorAll("button")) button.setAttribute("aria-pressed", String(button.dataset.value === tone));
    if (Object.keys(now.words || {}).some((lang) => lang !== "en")) form.querySelector("details.more-langs").open = true;
  }
  form.dataset.drawn = "yes";
  previewNotice();
  const before = $("notices");
  before.replaceChildren();
  for (const one of s.notices || []) {
    const row = make("tr");
    row.dataset.notice = String(one.id);
    cell(row, when(one.set_at), "when");
    cell(row, one.words?.en || "—", "said");
    cell(row, Object.keys(one.words || {}).map((lang) => LANGS[lang] || lang).join(", "));
    cell(row, one.set_by || "—");
    const ended = !one.cleared_at && one.ends_at && Date.parse(one.ends_at) <= Date.now();
    cell(row, one.cleared_at ? `${when(one.cleared_at)} by ${one.cleared_by}` : ended ? `ended ${when(one.ends_at)}`
      : one.ends_at ? `showing until ${when(one.ends_at)}` : "showing", one.cleared_at || ended ? "" : "bad");
    before.append(row);
  }
  if (!before.rows.length) emptyRow(before, s.notice_ready ? "No notice has been set here." : "Not kept yet.");
}

function drawSettings(s) {
  const body = $("settings");
  body.replaceChildren();
  // This site's first, then each preview's.
  const list = [...(s.settings || [])].sort((a, b) => Number(b.here) - Number(a.here) || Number(b.scope === "live") - Number(a.scope === "live")
    || String(b.set_at).localeCompare(String(a.set_at)));
  for (const one of list) {
    const row = make("tr");
    row.dataset.setting = `${one.name}@${one.scope}`;
    const name = make("th", "", one.name === "beta" ? "The beta" : (s.phone || []).find((rule) => rule.name === one.name)?.said || one.name);
    name.scope = "row";
    row.append(name);
    cell(row, `${one.scope === "live" ? "brickworks.diy" : one.scope}${one.here ? " (here)" : ""}`, "about");
    cell(row, String(one.value ?? "—"));
    cell(row, one.set_at ? `${ago(one.set_at)}${one.set_by ? ` by ${one.set_by}` : ""}` : "—");
    const acts = make("td", "acts");
    // The beta's switch here: Beta's act, the one place it is done.
    if (one.switch === "beta_switch" && one.here) {
      const next = one.value === "open" ? "off" : "open";
      acts.append(act(next === "open" ? "Open the beta" : "Turn the beta off", async () => (await ask(next === "open"
        ? { title: "Open the beta here?", body: "Visitors may join it.", yes: "Open the beta" }
        : { title: "Turn the beta off here?", body: "Nobody new may join; testers stay testers.", yes: "Turn the beta off" }))
        && post({ op: "beta_switch" }, "settings-note", next === "open" ? "The beta is open here." : "The beta is off here.",
          { body: { mode: next }, after: async () => { await loadSwitches(); after(); } }), "cta ghost small"));
    }
    row.append(acts);
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, s.settings === null ? "Not read." : "None kept yet: the beta follows BRICKWORKS_BETA here.");
  const here = list.find((one) => one.here && one.name === "beta");
  say("settings-note", here ? "" : `The beta here follows BRICKWORKS_BETA (${s.beta?.mode || "—"}) until it is flipped in Beta.`);
}

function drawVariables(s) {
  const body = $("variables");
  body.replaceChildren();
  const yes = (on) => make("span", on ? "pill good" : "pill", on ? "Set" : "Not set");
  for (const one of s.variables || []) {
    const row = make("tr");
    row.dataset.variable = one.name;
    const name = make("th", "", make("code", "", one.name));
    name.scope = "row";
    name.dataset.value = one.name;
    if (one.unread) name.append(" ", make("span", "badge", "Unread"));
    row.append(name);
    cell(row, yes(one.here));
    for (const where of ["production", "preview"]) {
      cell(row, one.environments === null ? make("span", "faint", "not known") : yes(one.environments.includes(where)));
    }
    cell(row, one.what, "said");
    const at = make("td", "about");
    if (one.href) {
      const to = make("a", "", one.where);
      to.href = one.href;
      if (/^https:/.test(one.href)) {
        to.rel = "noopener";
        to.target = "_blank";
      }
      at.append(to);
    } else {
      at.append(one.where);
    }
    row.append(at);
    body.append(row);
  }
  const unread = (s.variables || []).filter((one) => one.unread).map((one) => one.name);
  say("variables-said", `${s.vercel_ready ? s.vercel_noted_at ? `Vercel's environments as the release train last wrote them down, `
    + `${when(s.vercel_noted_at)}. ` : "Vercel's environments are written down by the next release. "
    : "Vercel's environments: not kept yet (supabase/console3.sql). "}Here is this deployment.${unread.length
    ? ` Nothing in the code reads ${unread.join(", ")}: it can be taken out at Vercel.` : ""}`);
}

export async function loadSwitches() {
  const s = await adminJson({ op: "switches" });
  drawNotice(s);
  drawSettings(s);
  drawPhones(s);
  drawVariables(s);
  return s;
}
