// The minifig maker, driven in a browser on this checkout's own files
// (figmaker, 2026-11-24; web/minifig-maker.js): no sign-in and no
// deployment, the parts from assets/generated/parts as the part store
// would send them. It opens the maker on a figure made in the layers'
// maker before it (v 1) and checks it opens as the same figure, waits for
// the 3D figure, opens every tab and picks in each, poses it, turns it,
// presses a part on it, tries Undo, Redo, Surprise me with a lock and a
// starting figure, saves, and checks the picture and the recipe it gives.
// At 1280 and 390 wide, light and dark, a picture of each step.
//
//   node tools/web/minifig_maker_probe.mjs [--out=DIR] [--only=1280-light]
//
// Exit 0 when every check passed. The browser draws in software: run it
// under ~/.claude/claude-core/bin/heavy.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { serveDir } from "./static_server.mjs";
import { launch } from "./browser.mjs";
import { figureShape, fromLayers, LEGS, POSES, STARTERS } from "../../web/minifig-parts.js";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = resolve(String(args.out || join(ROOT, "bench/results/minifig_maker_probe")));
mkdirSync(out, { recursive: true });

// The dialog as Edit profile has it.
const profile = readFileSync(join(ROOT, "web/profile.html"), "utf8");
const dialog = /<dialog class="minifig-dialog"[\s\S]*?<\/dialog>/.exec(profile)?.[0];
if (!dialog) throw new Error("minifig_maker_probe: no #minifig-dialog in web/profile.html");
const page = (theme) => `<!DOCTYPE html><html lang="en" data-theme="${theme}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css"></head>
<body><main id="main"><div class="wrap page account"><p>The minifig maker, where the profile page has it.</p>
${dialog}</div></main>
<script type="module">
import { makeMinifig } from "/minifig-maker.js";
window.openMaker = (start) => {
  window.made = undefined;
  makeMinifig(document.getElementById("minifig-dialog"), start).then(async (made) => {
    window.made = made ? { recipe: made.recipe, type: made.blob.type, bytes: made.blob.size,
      url: await new Promise((done) => { const r = new FileReader(); r.onload = () => done(r.result); r.readAsDataURL(made.blob); }) } : null;
  });
};
window.ready = true;
</script></body></html>`;

// A figure made in the layers' maker (web/card.js minifigShape).
const OLD = { v: 1, face: "3626cp87", hair: "61506", hairColour: 70, print: "973p18", torso: 272, legs: 0, background: 3 };

const results = [];
const check = (name, ok, said = "") => {
  results.push({ name, ok: Boolean(ok), said });
  console.log(`${ok ? "PASS" : "FAIL"} ${name}${said ? `: ${said}` : ""}`);
};

const site = await serveDir(join(ROOT, "web"));
// Signed out: the maker is drawn from this checkout's files, its account answered below.
const browser = await launch({ signedOut: true });
const runs = [[1280, 900, "light"], [1280, 900, "dark"], [390, 844, "light"], [390, 844, "dark"]]
  .filter(([w, , theme]) => !args.only || String(args.only).split(",").includes(`${w}-${theme}`));
try {
  for (const [width, height, theme] of runs) {
    const tag = `${width}-${theme}`;
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1,
      hasTouch: width < 700, isMobile: width < 700 });
    const tab = await context.newPage();
    const errors = [];
    tab.on("pageerror", (e) => errors.push(e.message));
    tab.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    const fetched = new Set();
    await tab.route(`${site.url}/api/account`, (route) => route.fulfill({ contentType: "application/json",
      body: JSON.stringify({ parts_url: `${site.url}/__parts/` }) }));
    await tab.route(`${site.url}/__parts/**`, (route) => {
      const file = new URL(route.request().url()).pathname.replace(/^\/__parts\//, "");
      fetched.add(file);
      try {
        route.fulfill({ body: readFileSync(join(ROOT, "assets/generated/parts", file)), contentType: "application/octet-stream",
          headers: { "Cache-Control": "public, max-age=31536000, immutable" } });
      } catch {
        route.fulfill({ status: 404, body: "" });
      }
    });
    await tab.route(`${site.url}/__maker.html`, (route) => route.fulfill({ contentType: "text/html", body: page(theme) }));
    await tab.goto(`${site.url}/__maker.html`);
    await tab.waitForFunction(() => window.ready);
    const shot = (name) => tab.screenshot({ path: join(out, `${tag}-${name}.png`) });
    const recipeNow = () => tab.evaluate(() => document.getElementById("minifig-dialog").dataset.recipe);
    const wordsNow = () => tab.evaluate(() => document.getElementById("mf-stage").getAttribute("aria-label"));

    // 1. An old figure opens as the same figure: what Save gives at once is
    // the old recipe as v 2.
    await tab.evaluate((start) => window.openMaker(start), OLD);
    await tab.waitForFunction(() => ["ready", "failed"].includes(document.getElementById("minifig-dialog").dataset.figure),
      null, { timeout: 60000 });
    const state = await tab.evaluate(() => ({ ...document.getElementById("minifig-dialog").dataset }));
    check(`${tag}: the 3D figure drew`, state.figure === "ready", `${state.figure}, ${state.firstFrame} ms`);
    await tab.waitForTimeout(400);
    await shot("01-opened");
    check(`${tag}: skin is the first tab, open`, await tab.evaluate(() =>
      document.querySelector("[role=tab]")?.dataset.tab === "skin"
      && document.querySelector("[role=tab][aria-selected=true]")?.dataset.tab === "skin"));
    check(`${tag}: at least 8 real skin tones`, (await tab.locator("input[name=mf-sk]").count()) >= 8);
    const sizes = await tab.evaluate(() => [...document.querySelectorAll("#minifig-light .avatar img, #minifig-dark .avatar img")]
      .filter((img) => img.src.startsWith("data:image/png")).length);
    check(`${tag}: shown at three sizes on light and dark`, sizes === 6, `${sizes} of 6`);
    const parts = await tab.evaluate(() => [...document.querySelectorAll("[role=tab]")].map((one) => one.textContent));
    check(`${tag}: nine tabs`, parts.length === 9, parts.join(", "));
    // The figure and the tabs side by side right under the dialog's words,
    // whatever the page round it gives its sections (.page section).
    // (On a phone the tabs are under the figure: only the figure's top.)
    const tops = await tab.evaluate((columns) => {
      const under = document.querySelector("#minifig-dialog .minifig-lead").getBoundingClientRect().bottom;
      const lead = getComputedStyle(document.querySelector("#minifig-dialog .minifig-lead")).display !== "none";
      const top = document.querySelector("#minifig-dialog h2").getBoundingClientRect().bottom;
      return columns.map((one) => Math.round(document.querySelector(one).getBoundingClientRect().top - (lead ? under : top)));
    }, width < 700 ? [".mf-look"] : [".mf-look", ".mf-edit"]);
    check(`${tag}: the figure and its tabs right under the words`, tops.every((gap) => gap >= 0 && gap <= 24), `${tops.join(" and ")} px below`);
    // Nothing reaches past the dialog's side, so it never moves sideways
    // under a finger (the tabs' row reached 16 px into a page's gutter).
    const sideways = await tab.evaluate(() => { const d = document.getElementById("minifig-dialog"); return d.scrollWidth - d.clientWidth; });
    check(`${tag}: nothing wider than the dialog`, sideways <= 1, `${sideways} px over`);

    // Every target a finger presses is 44 px at the phone's size.
    if (width < 700) {
      const small = await tab.evaluate(() => [...document.querySelectorAll("#minifig-dialog button, #minifig-dialog summary, #minifig-dialog .mf-tile, #minifig-dialog .mf-swatch > span[style]")]
        .filter((one) => one.offsetParent && !one.closest(".mf-tabs") && !one.closest(".menu-list"))
        .map((one) => { const box = one.getBoundingClientRect(); return [one.id || one.textContent.trim().slice(0, 20) || one.className, box.width, box.height]; })
        .filter(([, w, h]) => Math.min(w, h) < 43.5));
      check(`${tag}: every target at least 44 px`, small.length === 0, small.slice(0, 6).map(([n, w, h]) => `${n} ${w}x${h}`).join("; "));
    }

    // 2. Each tab, picking something in it.
    const pickIn = async (selector) => {
      const one = tab.locator(selector).first();
      await one.scrollIntoViewIfNeeded();
      await one.click();
      await tab.waitForTimeout(250);
    };
    const tabTo = async (key) => {
      await tab.click(`[role=tab][data-tab=${key}]`);
      await tab.waitForTimeout(150);
    };
    await tabTo("skin");
    await pickIn("label.mf-tile:has(input[name=mf-sk][value='84'])");
    await shot("02-skin");
    await tabTo("face");
    await tab.click("[data-filter=glasses]");
    check(`${tag}: the faces filter to glasses`, await tab.evaluate(() =>
      [...document.querySelectorAll("label.mf-tile:not([hidden]) input[name=mf-fa]")].length >= 8
      && [...document.querySelectorAll("label.mf-tile:not([hidden])")].every((one) => (one.dataset.kinds || "").includes("glasses"))));
    await pickIn("label.mf-tile:not([hidden]):has(input[name=mf-fa])");
    await shot("03-face");
    await tabTo("hair");
    await tab.fill("#mf-q", "pony");
    await tab.waitForTimeout(100);
    const ponytails = await tab.locator("label.mf-tile:not([hidden]) input[name=mf-hd]").count();
    check(`${tag}: searching hair finds the ponytails`, ponytails >= 2, `${ponytails}`);
    await pickIn("label.mf-tile:not([hidden]):has(input[name=mf-hd])");
    await pickIn("label.mf-swatch:has(input[name=mf-hc][value='484'])");
    await shot("04-hair");
    await tabTo("torso");
    await pickIn("label.mf-tile:has(input[name=mf-to][value='973p0l'])");
    await pickIn("label.mf-swatch:has(input[name=mf-tc][value='15'])");
    await shot("05-torso");
    await tabTo("arms");
    await tab.locator("#mf-each-arm").check();
    await tab.waitForTimeout(150);
    await pickIn("label.mf-swatch:has(input[name=mf-ar][value='4'])");
    await pickIn("label.mf-swatch:has(input[name=mf-al][value='1'])");
    await shot("06-arms");
    await tabTo("legs");
    await pickIn("label.mf-tile:has(input[name=mf-lg][value='shorts'])");
    await pickIn("label.mf-swatch:has(input[name=mf-hp][value='272'])");
    await shot("07-legs");
    await tabTo("extras");
    await pickIn("label.mf-tile:has(input[name=mf-nk][value='2524'])");
    await tab.click("[data-extras=right]");
    await pickIn("label.mf-tile:has(input[name=mf-ir][value='3899'])");
    await tab.click("[data-extras=left]");
    await pickIn("label.mf-tile:has(input[name=mf-il][value='3596'])");
    await shot("08-accessories");
    await tabTo("pose");
    await tab.waitForFunction(() => [...document.querySelectorAll(".mf-pose img")].every((img) => !img.hidden), null, { timeout: 60000 })
      .catch(() => null);
    await pickIn("[data-pose=wave]");
    await shot("09-pose");
    await tabTo("ground");
    await pickIn("label.mf-swatch:has(input[name=mf-bg][value='s1'])");
    await shot("10-background");

    const made = await tab.evaluate(() => document.getElementById("mf-stage").getAttribute("aria-label"));
    check(`${tag}: the figure's words say what it is`, /Medium Nougat/.test(made) && /Cup/.test(made) && /Flag/.test(made), made);

    // 3. Undo and Redo, Surprise me with a lock, a starting figure.
    const before = await recipeNow();
    await tab.click("#mf-undo");
    await tab.waitForTimeout(200);
    const undone = await recipeNow();
    await tab.click("#mf-redo");
    await tab.waitForTimeout(200);
    const redone = await recipeNow();
    check(`${tag}: Undo and Redo`, undone !== before && redone === before, `${undone === before ? "undo changed nothing" : ""}`);
    await tabTo("skin");
    await tab.click("#mf-lock");
    await tab.click("#minifig-surprise");
    await tab.waitForTimeout(400);
    const surprised = JSON.parse(await recipeNow());
    check(`${tag}: Surprise me keeps a locked skin`, surprised.sk === 84 && JSON.stringify(surprised) !== before, await wordsNow());
    await shot("11-surprised");
    await tab.click("#mf-starters summary");
    await tab.waitForTimeout(400);
    // Each one there to press where it is shown, not cut off by a row that
    // scrolls: a click by Playwright would scroll the row to reach it.
    const starters = await tab.evaluate(() => [...document.querySelectorAll("#mf-starters .menu-list button")].filter((one) => {
      const box = one.getBoundingClientRect();
      const at = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
      return at === one || one.contains(at);
    }).length);
    check(`${tag}: every starting figure can be pressed`, starters === Object.keys(STARTERS).length,
      `${starters} of ${Object.keys(STARTERS).length}`);
    await shot("12a-starters");
    await tab.click("[data-starter=astronaut]");
    await tab.waitForTimeout(600);
    await shot("12-starter");

    // 4. Turned by a drag, and a press on the figure opens its part's tab.
    const stage = await tab.locator("#mf-stage").boundingBox();
    await tab.mouse.move(stage.x + stage.width / 2, stage.y + stage.height * 0.55);
    await tab.mouse.down();
    await tab.mouse.move(stage.x + stage.width / 2 + 80, stage.y + stage.height * 0.55, { steps: 6 });
    await tab.mouse.up();
    await tab.waitForTimeout(200);
    await shot("13-turned");
    await tab.click("#mf-turn");
    await tab.waitForTimeout(150);
    await tab.mouse.click(stage.x + stage.width / 2, stage.y + stage.height * 0.5);
    await tab.waitForTimeout(200);
    const opened = await tab.evaluate(() => document.querySelector("[role=tab][aria-selected=true]")?.dataset.tab);
    check(`${tag}: pressing the figure opens its part's tab`, ["torso", "arms", "legs", "extras"].includes(opened), opened);

    // 5. Save: a picture and the recipe it was made of.
    await tab.click("#minifig-save");
    await tab.waitForFunction(() => window.made !== undefined, null, { timeout: 30000 });
    const saved = await tab.evaluate(() => window.made);
    check(`${tag}: Save gives a recipe the server keeps`, Boolean(figureShape(saved?.recipe)), JSON.stringify(saved?.recipe));
    check(`${tag}: Save gives a PNG of the figure`, saved?.type === "image/png" && saved.bytes > 20000 && saved.bytes < 900000,
      `${saved?.type}, ${saved?.bytes} bytes`);
    check(`${tag}: the recipe fits the column (400 bytes)`, JSON.stringify(saved?.recipe).length <= 400 - 40,
      `${JSON.stringify(saved?.recipe).length}`);
    if (saved?.url) writeFileSync(join(out, `${tag}-14-saved.png`), Buffer.from(saved.url.split(",")[1], "base64"));

    // 6. The old figure again, saved straight away: the same figure, as v 2.
    await tab.evaluate((start) => window.openMaker(start), OLD);
    await tab.waitForFunction(() => document.getElementById("minifig-dialog").dataset.figure === "ready", null, { timeout: 60000 });
    await tab.waitForTimeout(300);
    await shot("15-old-figure");
    await tab.click("#minifig-save");
    await tab.waitForFunction(() => window.made !== undefined, null, { timeout: 30000 });
    const again = await tab.evaluate(() => window.made);
    check(`${tag}: an old figure opens as the same figure`, JSON.stringify(again?.recipe) === JSON.stringify(figureShape(fromLayers(OLD))),
      JSON.stringify(again?.recipe));

    // 7. Cancel keeps what there was; Escape too.
    await tab.evaluate((start) => window.openMaker(start), OLD);
    await tab.waitForFunction(() => document.getElementById("minifig-dialog").dataset.figure === "ready", null, { timeout: 60000 });
    await tab.keyboard.press("Escape");
    await tab.waitForFunction(() => window.made !== undefined, null, { timeout: 10000 });
    check(`${tag}: Escape closes it with nothing saved`, (await tab.evaluate(() => window.made)) === null);

    check(`${tag}: no errors on the page`, errors.length === 0, errors.slice(0, 3).join(" | "));
    check(`${tag}: only the parts shown were fetched`, fetched.size > 5 && fetched.size < 120, `${fetched.size} files`);
    await context.close();
  }
} finally {
  await browser.close();
  site.close();
}
// Some figures: every legs choice and pose ok as a recipe.
check("every legs choice and pose makes a recipe", LEGS.every(([lg]) => Object.values(POSES).every((po) =>
  figureShape({ ...fromLayers(OLD), lg, po: [...po] }))));
const failed = results.filter((one) => !one.ok);
writeFileSync(join(out, "results.json"), `${JSON.stringify(results, null, 1)}\n`);
console.log(`minifig_maker_probe: ${results.length - failed.length} of ${results.length} passed; pictures in ${out}`);
process.exit(failed.length ? 1 : 0);
