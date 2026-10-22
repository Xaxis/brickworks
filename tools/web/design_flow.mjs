// Does any control on the site look wrong to a person? (web/site.css,
// docs/DESIGN_SYSTEM.md)
//
//   node tools/web/design_flow.mjs [--out=shots/design]              # this checkout's web/ and api/
//   node tools/web/design_flow.mjs --root=DIR [--out=...]            # another checkout's (an old one, to see it fail)
//   node tools/web/design_flow.mjs --url=<deployment> [--out=...]    # a deployment's pages, the API answered here
//   [--only=gallery,model] [--widths=390,1280] [--themes=light,dark]
//
// The owner found the age question's month was the browser's bare
// dropdown, small and unstyled beside a full-size year box: each unit had
// copied the control styles it needed, and what a copy missed fell back
// to the browser. This visits every page and opens every dialog, at 390
// and 1280 px, light and dark, signed out and signed in, and reads each
// visible input, select, textarea and button as the browser draws it. It
// fails on what a person would notice:
//
//   a control the browser drew its own way: a dropdown it drew (appearance
//     menulist), a checkbox in its own colour, any field or button in its
//     own 13.33 px type or font, a button with its outset border;
//   controls of one kind that differ from each other there: the fields
//     (text boxes, dropdowns, text areas, file pickers) in type, height,
//     corners, border or fill; the checkboxes; the buttons of one size;
//   a page that scrolls sideways at 390 px;
//   a count of none shown ("0 likes", "following 0"): a count is said once
//     there is one (docs/SOCIAL.md);
//   and, in any stylesheet or page style the page has, a font size, a
//     corner or a colour off the token scale (site.css :root): a size not
//     var(--t-*), a corner not var(--r-*) (or 0, or 50%), a colour written
//     as itself rather than a token. Each such rule is named once, with its
//     stylesheet, however many pages have it.
//
// With no --url nothing leaves this machine: the pages are served from
// --root's web/ by the browser's own routing, the pages the server makes
// (/m/<id>, /u/<handle>, /c/<id>, the embed) are made by --root's api/ in
// this process, and every API call is answered by design_stand_in.mjs.
// Signed in is a session put where web/account.js keeps one.
//
// Pictures of every page and dialog in --out, named page_width_theme_who.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(String(args.root || path.resolve(here, "../..")));
const web = path.join(root, "web");
const api = path.join(root, "api");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "390,1280").split(",").map(Number);
const themes = String(args.themes || "light,dark").split(",");
const only = args.only ? String(args.only).split(",") : null;
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let passed = 0;
let failed = 0;
const failures = [];
const fail = (where, what) => {
  failed += 1;
  failures.push(`${where}: ${what}`);
  console.log(`  FAIL  ${where}: ${what}`);
};

// --- the site, served from --root (or the deployment's, with --url) -------

// The Supabase project a deployment names (/api/account), standing for the
// stand-in's DB in what the browser is told and keeps.
let remoteDb = "";
const asProject = (text) => (remoteDb ? text.split(stand.DB).join(remoteDb) : text);
const serve = (context, state) => stand.serveSite(context, { web, api, remote, headers, remoteDb, state });

// --- what a person would notice, read in the page ---------------------------

/// Every visible control on the page (or inside [scope]): any the browser
/// drew its own way, and any that differs from the others of its kind
/// there. Runs in the page; returns { controls, findings: [what, why] }.
function audit(scope) {
  const where = scope ? document.querySelector(scope) : document;
  if (!where) return { controls: 0, findings: [[scope, "is not on the page"]] };
  const bodyFont = getComputedStyle(document.body).fontFamily;
  const shown = (el) => {
    if (!el.getClientRects().length) return false;
    const box = el.getBoundingClientRect();
    if (box.width <= 2 || box.height <= 2) return false;
    const style = getComputedStyle(el);
    if (style.visibility === "hidden" || Number(style.opacity) === 0) return false;
    // A dialog's controls are judged with the dialog, not the page under it.
    return Boolean(scope) || !el.closest("dialog");
  };
  const name = (el) => {
    const tag = el.tagName.toLowerCase();
    const type = tag === "input" ? `[type=${el.type}]` : "";
    const id = el.id ? `#${el.id}` : "";
    const cls = !id && el.classList.length ? `.${[...el.classList].join(".")}` : "";
    const words = (el.textContent || el.placeholder || el.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ").slice(0, 24);
    return `${tag}${type}${id}${cls}${words ? ` "${words}"` : ""}`;
  };
  // The browser's own type for a control is 13.33 px in its own font.
  const browserType = (style) => Math.abs(parseFloat(style.fontSize) - 13.333) < 0.05
    || (style.fontFamily !== bodyFont && !/mono/i.test(style.fontFamily));
  const px = (value) => Math.round(parseFloat(value) * 10) / 10;
  const findings = [];
  const groups = new Map();
  const join = (key, el, looks) => {
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ el, looks });
  };
  const controls = [...where.querySelectorAll("input, select, textarea, button, a.cta, summary.cta")]
    .filter((el) => el.type !== "hidden" && shown(el));
  for (const el of controls) {
    const style = getComputedStyle(el);
    const tag = el.tagName.toLowerCase();
    const type = tag === "input" ? el.type : "";
    const height = px(el.getBoundingClientRect().height);
    const corners = px(style.borderTopLeftRadius);
    if (type === "checkbox" || type === "radio") {
      if (style.accentColor === "auto") findings.push([name(el), `the browser's own ${type}`]);
      join("the other checkboxes", el, { size: `${px(el.getBoundingClientRect().width)} x ${height}`, colour: style.accentColor });
    } else if (tag === "input" || tag === "select" || tag === "textarea") {
      const kind = tag === "select" ? "dropdown" : tag === "textarea" ? "text area" : type === "file" ? "file picker" : "text box";
      if (tag === "select" && style.appearance !== "none") findings.push([name(el), `the browser's own dropdown (appearance ${style.appearance})`]);
      if (browserType(style)) findings.push([name(el), `the browser's own ${kind} type (${style.fontSize} ${style.fontFamily.split(",")[0]})`]);
      // Every field is one box: a dropdown as the text boxes are. A text
      // area is as tall as its rows.
      join("the other fields", el, { type: style.fontSize, corners, border: style.borderTopWidth, fill: style.backgroundColor,
        ...(tag === "textarea" ? {} : { height }) });
    } else {
      if (browserType(style) || style.borderTopStyle === "outset") {
        findings.push([name(el), `the browser's own button (${style.fontSize} ${style.fontFamily.split(",")[0]}, ${style.borderTopStyle} border)`]);
      }
      // Underlined words take the size of the words around them.
      if (el.classList.contains("link")) continue;
      // A .cta of one size is one button, primary or not; any other button
      // is like the others in the same place.
      const size = el.closest(".nav") ? "nav" : ["small", "big"].find((one) => el.classList.contains(one)) || "regular";
      const holder = el.parentElement?.closest("[class]");
      const key = el.classList.contains("cta") ? `the other ${size} buttons`
        : `the other buttons in .${holder ? holder.classList[0] : "page"}`;
      join(key, el, { height, type: style.fontSize, corners, weight: style.fontWeight });
    }
  }
  for (const [key, members] of groups) {
    if (members.length < 2) continue;
    // What most of them look like; each that does not is named.
    const counts = new Map();
    for (const one of members) {
      const said = JSON.stringify(one.looks);
      counts.set(said, (counts.get(said) || 0) + 1);
    }
    const usual = JSON.parse([...counts.entries()].sort((a, b) => b[1] - a[1])[0][0]);
    const like = members.find((one) => JSON.stringify(one.looks) === JSON.stringify(usual));
    for (const one of members) {
      const differs = Object.keys({ ...usual, ...one.looks })
        .filter((what) => usual[what] !== undefined && one.looks[what] !== undefined && usual[what] !== one.looks[what])
        .map((what) => `${what} ${one.looks[what]} where ${name(like.el)} has ${usual[what]}`);
      if (differs.length) findings.push([name(one.el), `differs from ${key}: ${differs.join(", ")}`]);
    }
  }
  return { controls: controls.length, findings };
}

/// Every declaration in the page's own stylesheets and style attributes
/// that is off the token scale (site.css :root defines it, and only rules
/// for :root may hold a literal). Runs in the page; returns
/// [[sheet, selector, declaration]].
function offScale() {
  const found = [];
  const colourProps = /^(color|background(-color|-image)?|border(-(top|right|bottom|left|block|inline)(-(start|end))?)?(-color)?|outline(-color)?|box-shadow|text-shadow|fill|stroke|accent-color|caret-color|text-decoration(-color)?|column-rule(-color)?)$/;
  // Colour words a style might use; the rest of CSS's names are as wrong.
  const named = /\b(white|black|red|green|blue|yellow|orange|purple|pink|gray|grey|silver|gold|navy|teal|maroon|olive|lime|aqua|fuchsia|brown|tan)\b/i;
  const literal = /#[0-9a-f]{3,8}\b|\b(rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\(/i;
  // A value with its tokens taken out: var(--x) and var(--x, fallback).
  const bare = (value) => {
    let out = value;
    for (let guard = 0; guard < 8 && /var\(/.test(out); guard += 1) out = out.replace(/var\([^()]*(\([^()]*\)[^()]*)*\)/g, " ");
    return out;
  };
  const judge = (sheet, selector, text) => {
    const root = /^:root\b/.test(selector.trim());
    for (const one of text.split(/;(?=\s*[-\w]+\s*:)/)) {
      const at = one.indexOf(":");
      if (at < 0) continue;
      const prop = one.slice(0, at).trim().toLowerCase();
      const value = one.slice(at + 1).replace(/!important/i, "").replace(/;\s*$/, "").trim();
      if (!prop || !value) continue;
      const said = `${prop}: ${value}`;
      if (prop.startsWith("--")) {
        // A token is made in :root and nowhere else.
        if (!root) found.push([sheet, selector, `${said} (a token made outside :root)`]);
        continue;
      }
      if (prop === "font-size" && !/^(var\(--t-[\w-]+\)|inherit)$/.test(value)) found.push([sheet, selector, said]);
      if (prop === "font" && /(^|[\s/])\d*\.?\d+(px|em|rem|pt|%)/.test(bare(value))) found.push([sheet, selector, said]);
      if (/radius$/.test(prop) && !value.split(/\s+\/?\s*/).every((part) => /^(var\(--(r-[\w-]+|radius|control-radius)\)|0(px)?|50%|inherit|\/)$/.test(part))) {
        found.push([sheet, selector, said]);
      }
      if (colourProps.test(prop) && (literal.test(bare(value)) || named.test(bare(value).replace(/url\([^)]*\)/g, "")))) {
        found.push([sheet, selector, said]);
      }
    }
  };
  const walk = (sheet, rules) => {
    for (const rule of rules) {
      if (rule.style && rule.selectorText !== undefined) judge(sheet, rule.selectorText, rule.style.cssText);
      if (rule.cssRules && !(rule instanceof CSSKeyframesRule)) walk(sheet, rule.cssRules);
    }
  };
  for (const sheet of document.styleSheets) {
    let rules;
    try {
      rules = sheet.cssRules;
    } catch {
      continue; // another site's, which this cannot read
    }
    const name = sheet.href ? new URL(sheet.href).pathname : `<style> of ${location.pathname}`;
    walk(name, rules);
  }
  for (const el of document.querySelectorAll("[style]")) {
    judge(`style="" of ${location.pathname}`, el.tagName.toLowerCase() + (el.id ? `#${el.id}` : ""), el.style.cssText);
  }
  return found;
}

/// A count of none said where a person reads it ("0 likes", "following
/// 0"). Runs in the page, on what is shown; returns the words found.
function zeroCounts() {
  const words = "likes?|views?|remix(es)?|built|builds?( finished)?|comments?|followers?|favourites?|saves?|photos?|votes?";
  const shown = document.body.innerText;
  return [...shown.matchAll(new RegExp(`(?<![\\d.,])0\\s+(${words})\\b|\\bfollowing\\s+0(?![\\d.,])`, "gi"))]
    .map((match) => match[0].replace(/\s+/g, " "));
}

// --- the pages, and the dialogs each opens ----------------------------------

const AUTHORIZE = "/oauth/authorize?response_type=code&client_id=design-flow&redirect_uri="
  + encodeURIComponent("https://claude.ai/api/mcp/auth_callback")
  + "&state=s1&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256";

const until = (page, test, ms = 8000) => page.waitForFunction(test, null, { timeout: ms }).then(() => true, () => false);

/// Each page: where it is, what it waits for before it is judged (ready),
/// and what it opens (open), which returns the states it left the page in
/// as [label, the part to judge, or null for the whole page]. A label
/// ending "(missing)" fails: what was to be opened was not there.
const PAGES = [
  { name: "home", path: "/" },
  { name: "gallery", path: "/gallery",
    ready: (page) => until(page, () => document.querySelectorAll("#models .model").length > 0),
    // Filters, a sheet over the cards at every width (docs/SOCIAL.md U3).
    open: async (page) => {
      await page.click("#filters summary");
      return [["filters", "#filters"]];
    } },
  { name: "model", path: `/m/${stand.MODEL_ID}`,
    // The comments listed (Comment's count), and signed out Report it made
    // live in More. On a deployment the page is its own model, whose
    // comments the stand-in answering the API has none of: there, the
    // comments asked and either listed or said why not.
    ready: (page, { signedIn }) => until(page, signedIn
      ? (remote ? () => !document.getElementById("comments")?.hidden
        || Boolean(document.querySelector("#comments .comments-said")?.textContent)
        : () => !document.getElementById("comments")?.hidden)
      : () => !document.querySelector('[data-report="this model"]')?.hidden),
    open: async (page, { signedIn }) => {
      if (!signedIn) {
        await page.click("#more > summary");
        const shown = await until(page, () => document.querySelector("#more[open]"));
        const states = [[shown ? "more" : "more (missing)", ".side"]];
        await page.click('[data-report="this model"]');
        const opened = await until(page, () => document.querySelector("dialog.report[open]"));
        states.push([opened ? "report" : "report (missing)", "dialog.report"]);
        return states;
      }
      // Save: your lists, Favourites first (web/model-page.js).
      await page.click('#marks [data-mark="save"]');
      const saved = await until(page, () => !document.getElementById("save-panel")?.hidden);
      const states = [[saved ? "save" : "save (missing)", ".side"]];
      const add = page.locator("[data-add-build]");
      if (await add.isVisible().catch(() => false)) {
        await add.click();
        const opened = await until(page, () => !document.querySelector("form.build-form")?.hidden);
        states.push([opened ? "add a photo" : "add a photo (missing)", "#builds"]);
      } else states.push(["add a photo (missing)", "#builds"]);
      return states;
    } },
  // A designer's own model in the gallery, signed in: Enter this month's
  // challenge, and its dialog (web/model-page.js enterDialog). Here only:
  // a deployment has no model of the stand-in's account.
  { name: "model-mine", path: "/m/SamModel01", signedInOnly: true,
    ready: (page) => until(page, () => document.querySelector("button[data-enter]")),
    open: async (page) => {
      await page.click("button[data-enter]");
      const opened = await until(page, () => document.querySelector("dialog.enter[open]"));
      return [[opened ? "enter" : "enter (missing)", "dialog.enter"]];
    } },
  { name: "model-older", path: `/m/${stand.MODEL_ID}/v/1` },
  // A model nobody has remixed or liked yet, as most of the live gallery
  // is: its page says no count of none ("0 remixes").
  { name: "model-quiet", path: "/m/DesignFox1", local: true },
  { name: "embed", path: `/m/${stand.MODEL_ID}/embed` },
  { name: "person", path: `/u/${stand.HANDLE}` },
  // A person's other tabs (api/people.js profilePage, docs/SOCIAL.md U5):
  // photos of real builds in columns, and collections as cards; the house
  // account, credited "Brickworks" as the live gallery's models are, and
  // somebody with nothing yet, whose tabs say what goes there. Its More
  // menu open. Here only: the stand-in's people.
  { name: "person-builds", path: `/u/${stand.HANDLE}?tab=builds`, local: true },
  { name: "person-lists", path: `/u/${stand.HANDLE}?tab=collections`, local: true,
    open: async (page) => {
      await page.click(".profile-head .more-menu summary");
      const opened = await until(page, () => document.querySelector(".profile-head .more-menu[open]"));
      return [[opened ? "more" : "more (missing)", ".profile-head .more-menu"]];
    } },
  { name: "person-house", path: "/u/brickworks?tests=1", local: true },
  { name: "person-new", path: "/u/new-here", local: true },
  { name: "collection", path: `/c/${stand.LIST_ID}` },
  { name: "challenge", path: "/challenge",
    ready: (page) => until(page, () => document.documentElement.dataset.challenge === "open") },
  { name: "feed", path: "/feed",
    ready: (page, { signedIn }) => (signedIn ? until(page, () => document.querySelectorAll(".feed-row").length > 0) : true) },
  // Your profile (docs/SOCIAL.md U6): your page's head and its first tab;
  // Edit profile's dialog; and the tabs only you see, each its own page.
  { name: "account", path: "/profile",
    ready: (page, { signedIn }) => (signedIn ? until(page, () => document.documentElement.dataset.profile === "ready") : true),
    open: async (page, { signedIn }) => {
      if (signedIn) {
        await page.click("#edit");
        const opened = await until(page, () => document.querySelector("dialog#edit-dialog[open]")
          && document.querySelector("#name")?.value);
        return [[opened ? "edit" : "edit (missing)", "dialog#edit-dialog"]];
      }
      await page.click("#sign-in");
      if (!(await until(page, () => document.querySelector("dialog.sign-in[open]")))) return [["sign-in (missing)", "dialog.sign-in"]];
      const states = [["sign-in", "dialog.sign-in"]];
      await page.fill("dialog.sign-in input", stand.EMAIL);
      await page.click('dialog.sign-in button[type="submit"]');
      const coded = await until(page, () => /code sent/.test(document.querySelector("dialog.sign-in label")?.textContent || ""));
      states.push([coded ? "sign-in code" : "sign-in code (missing)", "dialog.sign-in"]);
      return states;
    } },
  { name: "account-saved", path: "/profile?tab=saved", signedInOnly: true,
    ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready"
      && document.querySelectorAll("#favourites .model").length > 0) },
  { name: "account-sets", path: "/profile?tab=sets", signedInOnly: true,
    ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready") },
  { name: "account-insights", path: "/profile?tab=insights", signedInOnly: true,
    ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready") },
  // Your settings, apart from your profile (docs/SOCIAL.md U6): the same
  // rows the account page ended with.
  { name: "settings", path: "/settings",
    ready: (page, { signedIn }) => (signedIn ? until(page, () => document.documentElement.dataset.settings === "ready")
      : until(page, () => document.documentElement.dataset.settings === "signed-out")),
    open: async (page, { signedIn }) => {
      if (!signedIn) return [];
      await page.click("#delete-part summary");
      const opened = await until(page, () => document.querySelector("#delete-part details[open]"));
      return [[opened ? "delete" : "delete (missing)", "#delete-part"]];
    } },
  // The age question, which a signed-in page asks once of an account that
  // has not answered it: the owner's example. Only the dialog is judged.
  { name: "age", path: "/profile", askAge: true, signedInOnly: true, dialogOnly: true,
    open: async (page) => {
      const opened = await until(page, () => document.querySelector("dialog.age[open]"));
      return [[opened ? "age" : "age (missing)", "dialog.age"]];
    } },
  { name: "admin", path: "/admin", admin: true,
    ready: (page, { signedIn }) => (signedIn ? until(page, () => !document.querySelector("#view")?.classList.contains("hide")) : true) },
  { name: "authorize", path: AUTHORIZE,
    ready: (page) => until(page, () => [...document.querySelectorAll("main section")].some((s) => !s.classList.contains("hide"))) },
  { name: "compare", path: "/compare" },
  { name: "download", path: "/download" },
  { name: "faq", path: "/faq" },
  { name: "changelog", path: "/changelog" },
  { name: "terms", path: "/terms" },
  { name: "guidelines", path: "/guidelines" },
  { name: "privacy", path: "/privacy" },
  { name: "takedown", path: "/takedown" },
  { name: "404", path: "/no-such-page-here" },
  // Every component once (web/_kit.html, never published): what no page
  // uses yet is judged as the pages are, its "more" menu open.
  { name: "kit", path: "/_kit", local: true,
    ready: (page) => until(page, () => document.querySelectorAll("#cards .model").length === 3),
    open: async (page) => {
      await page.click("#more summary");
      const opened = await until(page, () => document.querySelector("#more[open]"));
      const states = [[opened ? "more" : "more (missing)", "#more"]];
      // Copy link says so in the toast (web/kit.js), judged and pictured
      // with the menu still open.
      if (opened) {
        await page.click("#copy");
        const said = await until(page, () => document.querySelector("body > .toast.shown")?.textContent === "Link copied");
        states.push([said ? "toast" : "toast (missing)", "body > .toast"]);
      }
      return states;
    } },
];

// --- run ---------------------------------------------------------------------

console.log(`design flow: ${remote || `${root} (its web/ and api/, served here)`}`);
// On a deployment, its own model, person and collection: the stand-in's
// are not there. Found the way a visitor finds them: the gallery's newest,
// who shared it, and a collection on their page.
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* none: the stand-in's own */ }
  const text = async (address) => {
    try {
      const reply = await fetch(remote + address, { headers });
      return reply.ok ? await reply.text() : "";
    } catch {
      return "";
    }
  };
  let listed = {};
  try {
    listed = JSON.parse(await text("/api/share?op=list&page=1")) || {};
  } catch { /* none */ }
  const id = (listed.models || [])[0]?.id || "";
  const modelPage = id ? await text(`/m/${id}`) : "";
  const handle = (/\/u\/([a-z0-9-]{3,24})"/.exec(modelPage) || [])[1] || "";
  const personPage = handle ? await text(`/u/${handle}`) : "";
  const list = (/\/c\/([A-Za-z0-9]{10})"/.exec(personPage) || [])[1] || "";
  const found = { model: id && `/m/${id}`, "model-mine": "", "model-older": "", embed: id && `/m/${id}/embed`,
    person: handle && `/u/${handle}`, collection: list && `/c/${list}` };
  for (const one of PAGES) {
    if (!(one.name in found)) continue;
    if (found[one.name]) one.path = found[one.name];
    else {
      one.skip = true;
      console.log(`  skip  ${one.name}: none on this deployment to visit`);
    }
  }
}

const browser = await launch({ signedOut: true });
const errors = [];
let states = 0;
let controls = 0;
// Each declaration off the token scale, once however many pages have it:
// "sheet | selector | declaration" -> the first page it was seen on.
const offScaleSeen = new Map();

async function judge(page, label, what, scope, file) {
  states += 1;
  const where = `${label} ${what}`;
  if (/\(missing\)$/.test(what)) {
    fail(where, "was not there to open");
    return;
  }
  const said = await page.evaluate(audit, scope);
  controls += said.controls;
  // On a phone, with whatever was opened open: nothing sideways.
  if (page.viewportSize().width < 600
    && await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1)) {
    said.findings.push(["the page", "scrolls sideways at 390 px"]);
  }
  if (!scope) {
    for (const words of await page.evaluate(zeroCounts)) said.findings.push(["the page", `shows a count of none: "${words}"`]);
    for (const [sheet, selector, declaration] of await page.evaluate(offScale)) {
      const key = `${sheet} | ${selector} | ${declaration}`;
      if (!offScaleSeen.has(key)) offScaleSeen.set(key, where);
    }
  }
  for (const [control, why] of said.findings) fail(where, `${control}: ${why}`);
  if (!said.findings.length) {
    passed += 1;
    console.log(`  ok    ${where}: ${said.controls} control${said.controls === 1 ? "" : "s"}`);
  }
  if (out) {
    await page.screenshot({ path: path.join(out, file), fullPage: !scope, timeout: 60000 })
      .catch((trouble) => console.log(`  --    no picture ${file}: ${String(trouble).split("\n")[0]}`));
  }
}

try {
  for (const one of PAGES) {
    if ((only && !only.includes(one.name)) || one.skip || (remote && one.local)) continue;
    for (const signedIn of one.signedInOnly ? [true] : [false, true]) {
      for (const width of widths) {
        for (const theme of themes) {
          const who = signedIn ? "in" : "out";
          const label = `${one.name} ${width} ${theme} ${who}`;
          const stem = `${one.name}_${width}_${theme}_${who}`;
          const phone = width < 600;
          const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 },
            colorScheme: theme, extraHTTPHeaders: headers,
            ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
          await serve(context, { askAge: Boolean(one.askAge), admin: Boolean(one.admin) });
          if (signedIn) {
            const kept = JSON.parse(asProject(JSON.stringify(stand.signedInStorage())));
            await context.addInitScript(([session, access]) => {
              try {
                localStorage.setItem("brickworks.session", session);
                sessionStorage.setItem("brickworks.access", access);
              } catch { /* a browser that keeps nothing */ }
            }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
          }
          const page = await context.newPage();
          page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
          page.on("console", (m) => {
            if (m.type() === "error" && /Content Security Policy|Refused|SyntaxError|TypeError/.test(m.text())) {
              errors.push(`${label}: ${m.text().slice(0, 200)}`);
            }
          });
          try {
            await page.goto(base + one.path, { waitUntil: "load", timeout: 60000 });
            if (one.ready && !(await one.ready(page, { width, signedIn }))) fail(label, "did not finish drawing");
            await page.waitForTimeout(300);
            if (!one.dialogOnly) await judge(page, label, "page", null, `${stem}.png`);
            for (const [what, scope] of one.open ? await one.open(page, { width, signedIn }) : []) {
              await page.waitForTimeout(200);
              await judge(page, label, what, scope, `${stem}_${what.replace(/\W+/g, "-")}.png`);
            }
          } catch (trouble) {
            fail(label, `could not be visited: ${String(trouble).split("\n")[0]}`);
          } finally {
            await context.close();
          }
        }
      }
    }
  }
} finally {
  await browser.close();
}
for (const error of errors) fail("script", error);
// Off the scale: one failure a rule, named with its stylesheet.
for (const [key, where] of offScaleSeen) fail("style", `${key}: off the token scale (first on ${where})`);
if (!offScaleSeen.size && states) console.log("  ok    style: every font size, corner and colour on the token scale");
// A check is a page or a dialog judged.
console.log(`\ndesign flow: ${states} pages and dialogs, ${controls} controls; ${passed} checks passed, ${failed} failed`);
if (failed) {
  const common = new Map();
  for (const line of failures) {
    const key = line.replace(/^\S+ \d+ \w+ \w+ [^:]*: /, "");
    common.set(key, (common.get(key) || 0) + 1);
  }
  console.log("the most common:");
  for (const [what, n] of [...common.entries()].sort((a, b) => b[1] - a[1]).slice(0, 15)) console.log(`  ${n} x ${what}`);
}
if (!controls) {
  console.log("design flow: no control was judged");
  process.exit(1);
}
process.exit(failed ? 1 : 0);
