// Can a person who relies on a screen reader, or on the keyboard, use the
// site? (docs/COMPETITIVE.md item 14, docs/DESIGN_SYSTEM.md)
//
//   node tools/web/a11y_flow.mjs [--out=DIR]               this checkout's web/ and api/, served here
//   node tools/web/a11y_flow.mjs --url=<deployment>        a deployment's pages, the API answered here
//   [--only=gallery,model] [--widths=390,1280] [--themes=light,dark]
//
// Every page and every state design_flow.mjs visits (tools/web/site_pages.mjs:
// each dialog and menu opened), at 390 and 1280 px, light and dark, signed
// out and signed in, judged two ways:
//
//   axe-core (tools/web/axe-core, vendored): the WCAG 2.2 A and AA rules
//     and its best practices. A serious or critical finding fails; the
//     moderate and minor ones are listed after, each rule once with where;
//   the names a screen reader says: every control in the page's
//     accessibility tree (Chromium's own, as a screen reader is given it)
//     that a person can reach (a link, a button, a field, a tab, a menu's
//     item) has a name, and a name that means something: not a bare number
//     or sign (but a day or a year in a dropdown), not a picture's file,
//     not "button" or "icon".
//     On the pages people use most, the controls they use are there by
//     the names they are listed under below (NAMES), so a name that turns
//     back into "Like" on twenty cards at once, or an icon button that
//     loses its label, fails by name.
//
// With no --url nothing leaves this machine, as in design_flow.mjs.
// --out keeps each state's findings, page_width_theme_who.json.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { onDeployment, sitePages, visit } from "./site_pages.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
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
const AXE = readFileSync(path.join(here, "axe-core", "axe.min.js"), "utf8");

let passed = 0;
let failed = 0;
const fail = (where, what) => {
  failed += 1;
  console.log(`  FAIL  ${where}: ${what}`);
};

// --- the names a screen reader says -----------------------------------------

// The roles a person reaches and acts on.
const ACTED = new Set(["link", "button", "textbox", "searchbox", "combobox", "checkbox", "radio", "menuitem",
  "menuitemcheckbox", "menuitemradio", "tab", "switch", "slider", "spinbutton", "listbox", "option", "PopUpButton",
  "DisclosureTriangle", "ToggleButton"]);

// Chromium's own roles for what a screen reader says is a button: a
// <summary>, a button that opens a popup, a toggle.
const BUTTONS = new Set(["DisclosureTriangle", "PopUpButton", "ToggleButton"]);

/// Why [name] says nothing to a person, or "" when it says something.
function meaningless(role, name) {
  const said = String(name || "").replace(/\s+/g, " ").trim();
  if (!said) return "has no name";
  // A choice in a named dropdown may be a number: a day, a year.
  if (role === "option") return "";
  if (/^[\d\s.,·:;!?()+\-–—#×✓…]*$/.test(said)) return `is named only "${said}"`;
  if (/^(button|link|icon|image|img|graphic|svg|click( here)?|here|menu item|undefined|null|true|false|\[object \w+\])$/i.test(said)) {
    return `is named only "${said}"`;
  }
  // A picture's file, where its words should be.
  if (/(^(blob|data):|\.(png|jpe?g|webp|svg|gif)(\?\S*)?$)/i.test(said)) return `is named by a file, "${said}"`;
  return "";
}

/// Chromium's accessibility tree for the page, or for what [scope] holds:
/// [{ role, name, disabled, focusable }] for each control a person acts on.
async function controls(page, scope) {
  const session = await page.context().newCDPSession(page);
  try {
    let { nodes } = await session.send("Accessibility.getFullAXTree");
    if (scope) {
      // What the part holds: every element under its own, by the ids the
      // tree's nodes carry. (A plain <div> is not in the tree itself.)
      const { root } = await session.send("DOM.getDocument", { depth: -1 });
      const { nodeId } = await session.send("DOM.querySelector", { nodeId: root.nodeId, selector: scope });
      const inside = new Set();
      const gather = (node, under) => {
        const now = under || node.nodeId === nodeId;
        if (now) inside.add(node.backendNodeId);
        for (const child of node.children || []) gather(child, now);
      };
      if (nodeId) gather(root, false);
      nodes = nodes.filter((one) => inside.has(one.backendDOMNodeId));
    }
    const prop = (one, key) => (one.properties || []).find((p) => p.name === key)?.value?.value;
    const acted = nodes.filter((one) => !one.ignored && ACTED.has(one.role?.value))
      .map((one) => ({ role: BUTTONS.has(one.role.value) ? "button" : one.role.value, name: String(one.name?.value || "").replace(/\s+/g, " ").trim(),
        disabled: prop(one, "disabled") === true, focusable: prop(one, "focusable") === true, backend: one.backendDOMNodeId }));
    // Which element a control is, said as its tag, id and classes, for one
    // whose name says nothing.
    for (const one of acted) {
      if (!meaningless(one.role, one.name) || !one.backend) continue;
      const { node } = await session.send("DOM.describeNode", { backendNodeId: one.backend }).catch(() => ({}));
      const attrs = Object.fromEntries((node?.attributes || []).reduce((pairs, value, i, all) => (i % 2 ? pairs : [...pairs, [value, all[i + 1]]]), []));
      one.element = `${node?.localName || "?"}${attrs.id ? `#${attrs.id}` : ""}${attrs.class ? `.${attrs.class.trim().split(/\s+/).join(".")}` : ""}`;
    }
    return acted;
  } finally {
    await session.detach().catch(() => {});
  }
}

/// What a person must find on the pages they use most, by role and name,
/// signed out (out), signed in (in) or either (any); here (local), signed
/// in, what only the stand-in's own model and designer have (a
/// deployment's are its own, which the stand-in answering the API does not
/// know). Each is a [role, name] pair, the name a pattern; at least one
/// control there must match.
const NAMES = {
  home: { any: [["link", /^Skip to content$/], ["link", /^Open the app$/]] },
  gallery: {
    any: [["searchbox", /search/i], ["link", /^Top$/], ["link", /^New$/], ["button", /^Filters/]],
    // Each card's like says which model it likes: twenty "Like" buttons
    // in a row say nothing about which.
    in: [["button", /^Like .{2,}/]],
  },
  model: {
    any: [["button", /^Share/], ["button", /^More/]],
    in: [["button", /^Like/], ["button", /^Save/], ["button", /^Comment/]],
    local: [["textbox", /comment/i], ["button", /^Reply to .+/]],
  },
  person: { any: [["button", /^Share/], ["button", /^More/]], local: [["button", /^Follow|^Following/]] },
  notifications: { in: [["button", /^Mark all read$/], ["link", /^Notifications/], ["link", /^Feed|^Your feed/]] },
  feed: { in: [["button", /^Follow/]] },
  account: { in: [["button", /^Edit profile$/], ["link", /^Settings$/]], out: [["button", /^Sign in/]] },
  settings: { in: [["button", /^Sign out$/], ["button", /^System$/], ["button", /^Light$/], ["button", /^Dark$/]] },
  download: { any: [["link", /download|\.dmg|\.exe|\.AppImage|Windows|macOS|Linux/i]] },
};

// --- axe ----------------------------------------------------------------------

const RULES = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

/// axe's findings on the page or inside [scope]: [{ rule, impact, help, targets }].
async function axe(page, scope) {
  if (!(await page.evaluate(() => Boolean(window.axe)))) await page.evaluate(AXE);
  return page.evaluate(async ({ scope, rules }) => {
    const context = scope ? { include: [scope] } : document;
    const said = await window.axe.run(context, { runOnly: { type: "tag", values: rules }, resultTypes: ["violations"] });
    return said.violations.map((one) => ({ rule: one.id, impact: one.impact, help: one.help,
      targets: one.nodes.map((node) => `${node.target.join(" ")}${node.failureSummary
        ? ` (${node.failureSummary.replace(/^Fix (any|all) of the following:\s*/i, "").split("\n")[0].trim()})` : ""}`) }));
  }, { scope, rules: RULES });
}

// --- run ---------------------------------------------------------------------

console.log(`a11y flow: ${remote || `${root} (its web/ and api/, served here)`}`);
const PAGES = sitePages({ remote });
const remoteDb = remote ? await onDeployment(PAGES, remote, headers) : "";

const browser = await launch({ signedOut: true });
// Each moderate or minor finding once: "rule | target" -> where first seen.
const lesser = new Map();
let states = 0;
let named = 0;

async function judge(page, label, what, scope, { name, signedIn }) {
  states += 1;
  const where = `${label} ${what}`;
  if (/\(missing\)$/.test(what)) {
    fail(where, "was not there to open");
    return;
  }
  // The pointer off the page: a control under it is drawn hovered (a
  // brighter button, by a filter axe cannot read).
  await page.mouse.move(0, 0);
  const found = [];
  for (const one of await axe(page, scope)) {
    if (one.impact === "serious" || one.impact === "critical") {
      for (const target of one.targets) found.push(`axe ${one.impact} ${one.rule} (${one.help}): ${target}`);
    } else {
      for (const target of one.targets) {
        const key = `${one.impact} ${one.rule} (${one.help}) | ${target.replace(/ \(.*$/, "")}`;
        if (!lesser.has(key)) lesser.set(key, where);
      }
    }
  }
  const acted = await controls(page, scope);
  named += acted.length;
  for (const one of acted) {
    const why = meaningless(one.role, one.name);
    if (why) found.push(`${one.role} ${one.element} ${why}`);
  }
  // The controls a person comes for, on the whole page.
  if (!scope && NAMES[name]) {
    const wanted = [...(NAMES[name].any || []), ...((signedIn ? NAMES[name].in : NAMES[name].out) || []),
      ...((signedIn && !remote && NAMES[name].local) || [])];
    for (const [role, pattern] of wanted) {
      if (!acted.some((one) => one.role === role && pattern.test(one.name))) {
        const near = acted.filter((one) => one.role === role).map((one) => `"${one.name}"`).slice(0, 6).join(", ");
        found.push(`no ${role} named ${pattern} (its ${role}s: ${near || "none"})`);
      }
    }
  }
  for (const line of found) fail(where, line);
  if (!found.length) {
    passed += 1;
    console.log(`  ok    ${where}: ${acted.length} named controls`);
  }
  if (out) writeFileSync(path.join(out, `${where.replace(/\W+/g, "_")}.json`), JSON.stringify({ found, acted }, null, 1));
}

try {
  for (const one of PAGES) {
    if ((only && !only.includes(one.name)) || one.skip || (remote && one.local)) continue;
    for (const signedIn of one.signedInOnly ? [true] : [false, true]) {
      for (const width of widths) {
        for (const theme of themes) {
          const label = `${one.name} ${width} ${theme} ${signedIn ? "in" : "out"}`;
          const context = await visit(browser, one, { width, theme, signedIn, web, api, remote, headers, remoteDb });
          const page = await context.newPage();
          const how = { name: one.name, signedIn };
          try {
            await page.goto(base + one.path, { waitUntil: "load", timeout: 60000 });
            if (one.ready && !(await one.ready(page, { width, signedIn }))) fail(label, "did not finish drawing");
            await page.waitForTimeout(300);
            if (!one.dialogOnly) await judge(page, label, "page", null, how);
            const now = (what, scope) => judge(page, label, what, scope, how);
            for (const [what, scope] of one.open ? await one.open(page, { width, signedIn, judge: now }) : []) {
              await page.waitForTimeout(200);
              await judge(page, label, what, scope, how);
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
if (lesser.size) {
  console.log(`\nmoderate and minor, each once (${lesser.size}):`);
  for (const [key, where] of [...lesser.entries()].sort()) console.log(`  --    ${key} (first on ${where})`);
}
console.log(`\na11y flow: ${states} pages and dialogs, ${named} named controls; ${passed} checks passed, ${failed} failed`);
if (!states) {
  console.log("a11y flow: nothing was judged");
  process.exit(1);
}
process.exit(failed ? 1 : 0);
