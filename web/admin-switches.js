// The console's Switches (admin.html #switches, console3): the site's
// notice, set and cleared here (api/admin.js notice_set, notice_clear, each
// kept in the audit) with a preview of it as visitors see it (web/notice.js,
// site.css .site-notice); the settings the console keeps, the beta's
// flipped here as in Beta (beta_switch, one act); and every variable of the
// deployment by name: whether this deployment has it, which of Vercel's
// environments have it, what it switches and where it is changed. Never a
// value, never its length (/api/admin?op=switches, api/_console_switches.js).
//
// Everything is put on the page as text, never as markup.
import { $, act, adminJson, ago, cell, emptyRow, make, post, say, segmented, sift, when } from "/admin-kit.js";

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

$("notice-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = event.currentTarget;
  const send = form.querySelector('button[type="submit"]');
  const words = Object.fromEntries(Object.keys(LANGS).map((lang) => [lang, form.elements[lang].value.trim()]).filter(([, w]) => w));
  if (!words.en) return say("notice-note", "Give it its words in English.", true);
  send.disabled = true;
  await post({ op: "notice_set" }, "notice-note", (said) => `Shown on every page${said.languages?.length > 1 ? `, in ${said.languages
    .map((lang) => LANGS[lang]).join(", ")}` : ""}: visitors see it within a minute or two.`, { body: { words, tone },
    after: async () => { await loadSwitches(); after(); } });
  send.disabled = false;
});

$("notice-clear").addEventListener("click", async () => {
  if (!confirm("Clear the notice? It goes from every page within a minute or two.")) return;
  $("notice-clear").disabled = true;
  await post({ op: "notice_clear" }, "notice-note", "Cleared: it goes from every page within a minute or two.",
    { after: async () => { await loadSwitches(); after(); } });
  $("notice-clear").disabled = false;
});

$("variables-q").addEventListener("input", () => sift($("variables"), $("variables-q").value));

function drawNotice(s) {
  const now = s.notice;
  const form = $("notice-form");
  say("notice-scope", s.scope === "live" ? "brickworks.diy" : `this preview (${s.scope})`);
  if (!s.notice_ready) {
    say("notice-said", "Not open yet: supabase/console3.sql is not applied.", true);
    form.querySelector('button[type="submit"]').disabled = true;
  } else {
    form.querySelector('button[type="submit"]').disabled = false;
    say("notice-said", now ? `Showing since ${when(now.set_at)}, set by ${now.set_by}.` : "None is showing.");
  }
  $("notice-clear").hidden = !now;
  // The form holds what is showing, to change or clear it.
  if (now && !form.dataset.drawn) {
    for (const lang of Object.keys(LANGS)) form.elements[lang].value = now.words?.[lang] || "";
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
    cell(row, one.cleared_at ? `${when(one.cleared_at)} by ${one.cleared_by}` : "showing", one.cleared_at ? "" : "bad");
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
    const name = make("th", "", one.name === "beta" ? "The beta" : one.name);
    name.scope = "row";
    row.append(name);
    cell(row, `${one.scope === "live" ? "brickworks.diy" : one.scope}${one.here ? " (here)" : ""}`, "about");
    cell(row, String(one.value ?? "—"));
    cell(row, one.set_at ? `${ago(one.set_at)}${one.set_by ? ` by ${one.set_by}` : ""}` : "—");
    const acts = make("td", "acts");
    // The beta's switch here: Beta's act, the one place it is done.
    if (one.switch === "beta_switch" && one.here) {
      const next = one.value === "open" ? "off" : "open";
      acts.append(act(next === "open" ? "Open the beta" : "Turn the beta off", () => (confirm(next === "open"
        ? "Open the beta here? Visitors may join it." : "Turn the beta off here? Nobody new may join; testers stay testers.")
        ? post({ op: "beta_switch" }, "settings-note", next === "open" ? "The beta is open here." : "The beta is off here.",
          { body: { mode: next }, after: async () => { await loadSwitches(); after(); } })
        : Promise.resolve(false)), "cta ghost small"));
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
  drawVariables(s);
  return s;
}
