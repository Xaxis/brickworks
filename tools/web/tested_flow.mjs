// The Tested mark on shared models, in real browsers: worked out by the app
// as a model is published, kept with its version as the app's finding, and
// shown on the model's page, its gallery card and the viewer; a failure only
// to its owner; and a gallery filter, Tested only.
//
//   tools/export.sh web
//   node --env-file=.env tools/web/relay_server.mjs 8923 --static=build/web --hold=share_tests &
//   node --env-file=.env tools/web/tested_flow.mjs --url=http://127.0.0.1:8923 --out=shots/tested
//
// Until supabase/tested.sql is applied, the local relay holds its table in
// memory (--hold, tools/web/held_tables.mjs), and says what the gallery's
// functions would once it is; everything else is the real project.
//
//   1. Three small models, their steps carried and tested as the Share
//      panel does it (src/dev/tested_probe.gd --write): three bricks stacked
//      in order, which pass all four tests; the same with the top one put in
//      before what holds it, which fails steps; and a third sent with no
//      finding. Published and listed by a throwaway owner: the first marked
//      Tested, the second kept as failed, the third untested. A finding of
//      another file is not kept.
//   2. A browser that never signed in: the passed one's page shows the mark,
//      the four results in its title and when it is tapped open; the other
//      two show no mark and no failure. On the gallery the passed card is
//      marked and the others are not, and Tested only lists the passed one
//      alone. Its viewer shows the mark, the four on hover.
//   3. The owner, signed in: the failing one's page says which test failed
//      and why, plainly, as a note only they see; ?op=mine says each.
//   4. The owner publishes from the app's own Share panel (the model it
//      opens with): the app tests it and says what it found, and what the
//      server kept is that.
//
// Pictures in --out. The account is deleted at the end with its rows, after
// its models are taken down, so nothing is left in the bucket.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:8923").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/tested"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const owner = `delivered+bw-tested-owner-${rand}@resend.dev`;
const LINE = "Stands at every step · every step reachable · every part made in its colour · nothing loose";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

// --- the models, their steps carried and tested ----------------------------

/// Three 2 x 4 bricks in three steps, the top one in step 2 when [air].
function stack(name, air) {
  const at = air ? [0, -48, -24] : [0, -24, -48];
  const lines = [`0 ${name}`, `0 Name: ${name.toLowerCase().replace(/\s+/g, "_")}.ldr`, "0 Author: Tested Flow", ""];
  at.forEach((y, n) => {
    lines.push(`1 ${[4, 1, 14][n]} 0 ${y} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  });
  return `${lines.join("\r\n")}\r\n`;
}
const models = path.join(out, "models");
mkdirSync(models, { recursive: true });
const NAMES = { passed: "Tested Flow Stack", failed: "Tested Flow Overhang", none: "Tested Flow Untested" };
const files = [];
for (const [key, air] of [["passed", false], ["failed", true], ["none", false]]) {
  writeFileSync(path.join(models, `${key}_bare.ldr`), stack(NAMES[key], air));
  files.push(path.join(models, `${key}_bare.ldr`), path.join(models, `${key}.ldr`));
}
const made = spawnSync("godot", ["--headless", "--path", root, "--script", "src/dev/tested_probe.gd",
  "--", "--write", ...files], { encoding: "utf8", timeout: 600000,
  env: { ...process.env, XDG_DATA_HOME: process.env.XDG_DATA_HOME || path.join(root, ".scratch-data") } });
const text = {};
const finding = {};
for (const key of Object.keys(NAMES)) {
  text[key] = readFileSync(path.join(models, `${key}.ldr`), "utf8");
  finding[key] = JSON.parse(readFileSync(path.join(models, `${key}.ldr.tested.json`), "utf8"));
}
if (!finding.passed.tests || !finding.failed.tests) {
  throw new Error(`the models were not tested: ${String(made.stdout || "").slice(-400)} ${String(made.stderr || "").slice(-300)}`);
}
check(`the app tested them: the stack passes all four (${Object.values(finding.passed.tests).map((t) => t.ok).join(", ")}), `
  + `the overhang fails steps ("${finding.failed.tests.steps.why}")`,
  Object.values(finding.passed.tests).every((t) => t.ok) && finding.failed.tests.steps.ok === false);

// --- helpers ---------------------------------------------------------------

const browser = await launch({ signedOut: true });

async function context({ as = null } = {}) {
  const made = await browser.newContext({ viewport: { width: 1280, height: 860 }, extraHTTPHeaders: headers });
  if (as) {
    const { kept } = await mintSession(as);
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(kept)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

/// Press what the app shows by its name, once two of its reports agree on
/// where it is (share_flow.mjs press).
async function press(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    let at = (await controls(page))[name];
    for (let n = 0; at && n < 6; n += 1) {
      await page.waitForTimeout(550);
      const again = (await controls(page))[name];
      if (again && again.x === at.x && again.y === at.y) break;
      at = again;
    }
    if (at) {
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(400);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

async function type(page, name, words) {
  await press(page, name);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(words, { delay: 40 });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(token, pathname, body, method = "POST") {
  const reply = await fetch(`${site}${pathname}`, { method,
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
    body: method === "GET" ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

const ids = {};
let ownerToken = "";
let fromApp = "";
try {
  // --- 1. published, with what the app found -------------------------------
  console.log("three models published, with what the app found");
  ownerToken = (await mintSession(owner)).access_token;
  for (const key of Object.keys(NAMES)) {
    const body = { name: NAMES[key], model: text[key], listed: true };
    if (key !== "none") body.tested = finding[key];
    const one = await api(ownerToken, "/api/share", body);
    ids[key] = one.body.id || "";
    const kept = one.body.tested;
    if (key === "passed") {
      check(`the stack at /m/${ids[key]}: kept as the app's finding, passed (${JSON.stringify(kept && { kept: kept.kept, passed: kept.passed, by: kept.by, app: kept.app })})`,
        one.status === 201 && kept?.kept === true && kept.passed === true && kept.by === "app" && kept.app === finding.passed.app);
    } else if (key === "failed") {
      check(`the overhang at /m/${ids[key]}: kept, not passed, steps saying why ("${kept?.tests?.steps?.why}")`,
        one.status === 201 && kept?.kept === true && kept.passed === false && /put down in the air/.test(kept.tests.steps.why));
    } else {
      check(`the untested one at /m/${ids[key]}: no finding, nothing kept (${JSON.stringify(kept)})`, one.status === 201 && kept === null);
    }
  }
  // A finding of another file is not kept, and the model is published still.
  const forged = await api(ownerToken, "/api/share", { id: ids.none, name: NAMES.none, model: text.none,
    listed: true, tested: finding.passed });
  check(`a finding of another file is not kept, and the model is published still: "${forged.body.tested?.why}"`,
    forged.status === 200 && forged.body.tested?.kept === false && /another file/.test(forged.body.tested.why));
  const held = await fetch(`${site}/__held/share_tests`, { headers });
  if (held.ok) {
    const rows = await held.json();
    check(`...the server holds two marks, both by the app (${rows.filter((r) => Object.values(ids).includes(r.model)).length})`,
      rows.filter((r) => Object.values(ids).includes(r.model) && r.by === "app").length === 2);
  }

  // --- 2. what anybody sees --------------------------------------------------
  console.log("as anybody sees them");
  const visitorContext = await context();
  const visitor = await visitorContext.newPage();
  listen(visitor, "visitor");
  const markOn = () => {
    const mark = document.querySelector(".tested-mark");
    return { mark: Boolean(mark), title: mark?.querySelector("summary")?.getAttribute("title") || "",
      said: [...(mark?.querySelectorAll(".tested-says li") || [])].map((li) => li.textContent),
      note: !document.getElementById("tested-note")?.hidden, text: document.body.innerText };
  };
  await visitor.goto(`${site}/m/${ids.passed}`, { waitUntil: "load" });
  const passedPage = await visitor.evaluate(markOn);
  check(`the stack's page is marked Tested, the four on hover: "${passedPage.title}"`, passedPage.mark && passedPage.title === LINE);
  await visitor.click(".tested-mark summary");
  const opened = await visitor.evaluate(() => document.querySelector(".tested-mark")?.open === true);
  check(`...and on a tap: ${passedPage.said.join("; ")}`, opened && passedPage.said.length === 4);
  const whose = await visitor.evaluate(() => document.querySelector(".tested-says .note")?.innerText || "");
  check(`...saying it is the app's finding: "${whose}"`, /Worked out by the Brickworks app 0\.\d+\.\d+/.test(whose));
  await shot(visitor, "1_page_marked_tested.png");
  for (const key of ["failed", "none"]) {
    await visitor.goto(`${site}/m/${ids[key]}`, { waitUntil: "load" });
    const seen = await visitor.evaluate(markOn);
    check(`the ${key === "failed" ? "overhang" : "untested one"}'s page shows no mark and no failure`,
      !seen.mark && !seen.note && !/Not marked Tested|put down in the air/.test(seen.text));
  }

  await visitor.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
  await until(visitor, () => document.documentElement.dataset.gallery === "ready", "the gallery", 60);
  // The list's own cards: the front's shelves (the pick, small builds)
  // hide under a filter but stay in the page, holding copies of the cards.
  const cards = (wanted) => visitor.evaluate((which) => Object.fromEntries(Object.entries(which).map(([key, one]) => {
    const card = document.querySelector(`#models a.model[data-id="${one}"]`);
    return [key, card ? (card.dataset.tested === "yes" ? "marked" : "shown") : "absent"];
  })), wanted);
  const all = await cards(ids);
  check(`on the gallery, the stack's card is marked and the others not (${JSON.stringify(all)})`,
    all.passed === "marked" && all.failed === "shown" && all.none === "shown");
  const chip = await visitor.evaluate((one) => document.querySelector(`#models a.model[data-id="${one}"] .tested`)?.title || "", ids.passed);
  check(`...the four on its card's hover: "${chip}"`, chip === LINE);
  await visitor.evaluate(() => { document.getElementById("filters").open = true; });
  await visitor.check("#tested");
  await until(visitor, () => document.documentElement.dataset.gallery === "ready"
    && location.search.includes("tested=1"), "Tested only", 60);
  const only = await cards(ids);
  const others = await visitor.evaluate(() => [...document.querySelectorAll("#models a.model")].filter((a) => a.dataset.tested !== "yes").length);
  check(`Tested only lists the stack and nothing untested (${JSON.stringify(only)}, ${others} unmarked)`,
    only.passed === "marked" && only.failed === "absent" && only.none === "absent" && others === 0);
  await shot(visitor, "2_gallery_tested_only.png");

  await visitor.goto(`${site}/app?view=${ids.passed}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  const view = await until(visitor, () => {
    const v = (window.brickworksShare || {}).view || {};
    return v.state === "ready" ? v : null;
  }, "the viewer", 300);
  check(`the viewer is marked Tested, the four on hover: "${view.tested_says}"`, view.tested === true
    && view.tested_says.startsWith(LINE));
  await shot(visitor, "3_viewer_marked_tested.png");
  await visitor.goto(`${site}/app?view=${ids.failed}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  const plain = await until(visitor, () => {
    const v = (window.brickworksShare || {}).view || {};
    return v.state === "ready" ? v : null;
  }, "the overhang's viewer", 300);
  check("...and the overhang's viewer is not", plain.tested === false);
  await visitorContext.close();

  // --- 3. what its owner is told ---------------------------------------------
  console.log("as its owner sees them");
  const ownerContext = await context({ as: owner });
  const ownerPage = await ownerContext.newPage();
  listen(ownerPage, "owner");
  await ownerPage.goto(`${site}/m/${ids.failed}`, { waitUntil: "load" });
  const note = await until(ownerPage, () => {
    const n = document.getElementById("tested-note");
    return n && !n.hidden ? { text: n.textContent, failed: [...n.querySelectorAll("[data-failed]")].map((s) => s.dataset.failed) } : null;
  }, "the owner's note", 30).catch(() => ({ text: "", failed: [] }));
  check(`the overhang's owner is told which and why: "${note.text.trim()}"`,
    note.failed.join() === "steps" && /Only you see this/.test(note.text) && /put down in the air/.test(note.text));
  await shot(ownerPage, "4_owner_told_why.png");
  await ownerPage.goto(`${site}/m/${ids.passed}`, { waitUntil: "load" });
  await ownerPage.waitForTimeout(2500);
  check("...and the stack's owner is told nothing more", await ownerPage.evaluate(() => document.getElementById("tested-note")?.hidden === true));
  const mine = await api(ownerToken, "/api/share?op=mine", null, "GET");
  const said = Object.fromEntries((mine.body.shared || []).filter((one) => Object.values(ids).includes(one.id))
    .map((one) => [Object.keys(ids).find((key) => ids[key] === one.id), one.tested ? (one.tested.passed ? "passed" : "failed") : "untested"]));
  check(`?op=mine says each to its owner (${JSON.stringify(said)})`, said.passed === "passed" && said.failed === "failed" && said.none === "untested");
  const strangers = await fetch(`${site}/api/share?op=tested&id=${ids.failed}`, { headers });
  check(`?op=tested tells nobody else (${strangers.status})`, strangers.status === 401 || strangers.status === 403);

  // --- 4. from the app's own Share panel -------------------------------------
  console.log("published from the app's Share panel");
  await ownerPage.goto(`${site}/app`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await until(ownerPage, () => (window.brickworksAccount || {}).state === "signed_in", "the owner signed in");
  await until(ownerPage, () => (window.brickworksState || {}).bricks > 0, "a model on the baseplate");
  await ownerPage.waitForTimeout(Number(args.load || 15000));
  await press(ownerPage, "tool_share");
  await until(ownerPage, () => (window.brickworksShare.panel || {}).open, "the Share panel");
  await type(ownerPage, "share_name", "Tested Flow From The App");
  await press(ownerPage, "share_publish");
  const panel = await until(ownerPage, () => {
    const p = (window.brickworksShare || {}).panel || {};
    return p.state === "published" || p.state === "failed" ? p : null;
  }, "publishing", 300);
  fromApp = panel.id || "";
  const tests = panel.tested?.tests || {};
  check(`the app tested it as it published: ${Object.entries(tests).map(([k, t]) => `${k} ${t.ok ? "ok" : "fails"}`).join(", ")}`,
    panel.state === "published" && Object.keys(tests).length === 4);
  check(`...and says so to its owner: "${panel.tested_said}"`, /Marked Tested|Not marked Tested \(only you see why\)/.test(panel.tested_said)
    && panel.status.includes(panel.tested_said));
  const kept = await api(ownerToken, `/api/share?op=tested&id=${fromApp}`, null, "GET");
  check(`...and what the server kept is what it found (passed ${kept.body.tested?.passed}, app ${kept.body.tested?.app})`,
    kept.status === 200 && kept.body.tested?.passed === panel.tested_passed && kept.body.tested?.app === panel.tested.app
    && Object.keys(tests).every((k) => kept.body.tested.tests[k].ok === tests[k].ok));
  await shot(ownerPage, "5_share_panel_tested.png");
  await ownerContext.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const one of [...Object.values(ids), fromApp]) {
    if (one && ownerToken) await api(ownerToken, `/api/share?op=unpublish&id=${one}`, {}).catch(() => {});
  }
  await browser.close();
  await deleteAccount(owner).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "a model is marked Tested by what the app found, shown to all when it passed and only to its owner when not");
process.exit(failed ? 1 : 0);
