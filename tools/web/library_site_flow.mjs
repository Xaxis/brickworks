// The LDraw library on the site (web/library.html, web/library.js,
// api/_library.js, api/share.js ?op=library and /library/<id>), in real
// browsers, against a deployment.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/library_site_flow.mjs --url=<preview> --out=DIR [--no-app]
//
//   1. /library at 390 and 1400 px, light and dark: the whole shelf counted
//      (1,500 sets or more), its cards each with its cover drawn, its name,
//      its set's number and who modelled it; nothing sideways; the gallery's
//      tab and the footer link to it.
//   2. Searched by a set's number, 10179: its one card, the Millennium
//      Falcon; then a theme's pill, Star Wars, every card of it; and the
//      address keeps the question.
//   3. Its card opens its page, /library/omr-10179-1, at both widths and in
//      both themes: its title, its cover drawn, Modelled by Roland Dahl for
//      LDraw's Official Model Repository (a link to its page there), CC BY
//      2.0 with the licence's link, its facts (parts, steps, set, theme,
//      year), View in 3D and Open in Brickworks opening it in the app as
//      the app's Library does, its parts list drawn with our pictures, and
//      Share's sheet with its link. More of its theme under it.
//   4. Open in Brickworks (unless --no-app): /library/omr-106-1's button
//      opens the app with the set in it, 106-1 UNICEF Van, 65 parts. In a
//      browser of its own, signed in as the test account (.env sourced), as
//      the app shows nothing else until somebody is; the site's pages are
//      looked at signed out.
//
// Fails too when a script error reaches the console. Pictures in --out:
// library_<width>_<theme>.png, set_<width>_<theme>.png, app.png.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("library_site_flow: --url=<deployment>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/library_site"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SET = "omr-10179-1";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const problems = [];

const browser = await launch({ signedOut: true });
async function context({ width, dark }) {
  return browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", isMobile: width < 600, hasTouch: width < 600 });
}
async function opened(made, address) {
  const page = await made.newPage();
  page.on("pageerror", (e) => problems.push(`${address}: ${String(e).slice(0, 200)}`));
  const said = await page.goto(`${site}${address}`, { waitUntil: "load", timeout: 120000 });
  return { page, status: said?.status() };
}
/// Whether [test] in the page comes true within [seconds].
async function until(page, test, arg = null, seconds = 30) {
  try {
    await page.waitForFunction(test, arg, { timeout: seconds * 1000, polling: 250 });
    return true;
  } catch {
    return false;
  }
}
/// The cards on the page: their ids, names, set lines, credits, and whether
/// their pictures are drawn.
const cards = (page) => page.$$eval("#models .model, .next .model", (all) => all.map((one) => ({
  id: one.dataset.id, name: one.querySelector("a.open")?.textContent.trim(), href: one.querySelector("a.open")?.getAttribute("href"),
  set: one.querySelector("small.set")?.textContent.trim() || "", by: one.querySelector("[data-modelled-by]")?.textContent.trim() || "",
  drawn: (one.querySelector(".frame img")?.naturalWidth || 0) > 0 })));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);

try {
  console.log(`library: ${site}`);

  // 1. The shelf.
  for (const width of [390, 1400]) {
    for (const dark of [false, true]) {
      const at = `${width} px ${dark ? "dark" : "light"}`;
      const made = await context({ width, dark });
      const { page, status } = await opened(made, "/library");
      check(`${at}: /library answers 200`, status === 200);
      const ready = await until(page, () => document.documentElement.dataset.library === "ready", null, 60);
      check(`${at}: the shelf is drawn`, ready);
      const theme = await page.evaluate(() => getComputedStyle(document.documentElement).colorScheme);
      check(`${at}: in the ${dark ? "dark" : "light"} theme (${theme})`, theme === (dark ? "dark" : "light"));
      const said = await page.locator("#found-said").innerText().catch(() => "");
      const every = Number(said.replace(/[^0-9]/g, ""));
      check(`${at}: the whole shelf, "${said}"`, every >= 1500);
      // The first screen's pictures are asked at once: each drawn.
      await until(page, () => [...document.querySelectorAll("#models .model .frame img")].slice(0, 4)
        .every((img) => img.complete && img.naturalWidth > 0), null, 30);
      const shown = await cards(page);
      check(`${at}: a page of cards, 24 (${shown.length})`, shown.length === 24);
      check(`${at}: the first four with their covers drawn`, shown.slice(0, 4).every((one) => one.drawn));
      check(`${at}: each card a set's page, its number and who modelled it`, shown.every((one) =>
        /^\/library\/[a-z]+-[A-Za-z0-9_-]+$/.test(one.href || "") && /^[0-9A-Za-z-]+ · /.test(one.set) && /^Modelled by \S/.test(one.by)));
      const wide = await sideways(page);
      check(`${at}: nothing sideways (${wide} px past the window)`, wide <= 0);
      check(`${at}: the footer links /library`, Boolean(await page.$('.site-foot a[href="/library"]')));
      await page.screenshot({ path: path.join(out, `library_${width}_${dark ? "dark" : "light"}.png`), fullPage: false });
      await made.close();
    }
  }
  {
    const made = await context({ width: 1400, dark: false });
    const { page } = await opened(made, "/gallery");
    check("the gallery's tabs link the LDraw library", Boolean(await page.$('#tabs a[href="/library"]')));
    await made.close();
  }

  // 2. Searched by a set's number, then a theme.
  {
    const made = await context({ width: 390, dark: false });
    const { page } = await opened(made, "/library");
    await until(page, () => document.documentElement.dataset.library === "ready", null, 60);
    await page.fill("#q", "10179");
    const found = await until(page, (set) => document.documentElement.dataset.library === "ready"
      && [...document.querySelectorAll("#models .model")].map((one) => one.dataset.id).join() === set, SET, 30);
    const shown = await cards(page);
    check(`10179 finds the Millennium Falcon alone (${shown.map((one) => `${one.id} ${one.name}`).join(", ")})`,
      found && shown.length === 1 && shown[0].name === "Millennium Falcon");
    check(`the address keeps it (${new URL(page.url()).search})`, new URL(page.url()).searchParams.get("q") === "10179");
    await page.fill("#q", "");
    await page.click('#themes [data-pick="Star Wars"]');
    await until(page, () => document.documentElement.dataset.library === "ready"
      && document.querySelector('#themes [data-pick="Star Wars"]')?.getAttribute("aria-pressed") === "true", null, 30);
    const themed = await cards(page);
    check(`Star Wars's pill: every card of it (${themed.length})`, themed.length > 0
      && themed.every((one) => one.set.includes("Star Wars")));
    await made.close();
  }

  // 3. A set's page, from its card.
  for (const width of [390, 1400]) {
    for (const dark of [false, true]) {
      const at = `${width} px ${dark ? "dark" : "light"}`;
      const made = await context({ width, dark });
      const { page } = await opened(made, "/library?q=10179");
      await until(page, (set) => document.querySelector(`#models .model[data-id="${set}"]`), SET, 60);
      await Promise.all([page.waitForURL(`**/library/${SET}`, { timeout: 60000 }).catch(() => null),
        page.click(`#models .model[data-id="${SET}"] a.open`)]);
      check(`${at}: its card opens /library/${SET}`, new URL(page.url()).pathname === `/library/${SET}`);
      const drawn = await until(page, () => (document.querySelector(".model-page .picture img")?.naturalWidth || 0) > 0, null, 30);
      check(`${at}: its cover drawn`, drawn);
      const facts = await page.evaluate(() => ({
        title: document.querySelector("main h1")?.textContent.trim(),
        credit: document.querySelector(".modelled-by")?.textContent.replace(/\s+/g, " ").trim(),
        ldraw: document.querySelector(".modelled-by a")?.getAttribute("href"),
        licence: document.querySelector(".licence")?.textContent.replace(/\s+/g, " ").trim(),
        deed: document.querySelector('.licence a[rel="license"]')?.getAttribute("href"),
        pills: [...document.querySelectorAll(".facts .pill")].map((one) => one.textContent.trim()),
        viewer: document.querySelector(".model-page a.picture")?.getAttribute("href"),
        open: [...document.querySelectorAll(".side .actions a")].find((one) => one.textContent.trim() === "Open in Brickworks")?.getAttribute("href"),
        crumbs: document.querySelector(".crumbs")?.textContent.replace(/\s+/g, " ").trim(),
        next: document.querySelectorAll("#similar .model").length,
      }));
      check(`${at}: its title, "${facts.title}"`, facts.title === "Millennium Falcon");
      check(`${at}: "${facts.credit}", linked to LDraw (${facts.ldraw})`,
        facts.credit === "Modelled by Roland Dahl for LDraw's Official Model Repository"
        && /^https:\/\/library\.ldraw\.org\/omr\/sets\/\d+$/.test(facts.ldraw || ""));
      check(`${at}: CC BY 2.0, crediting him, with the licence's link`,
        /CC BY 2\.0\..*credit Roland Dahl/.test(facts.licence || "") && facts.deed === "https://creativecommons.org/licenses/by/2.0/");
      check(`${at}: its facts (${facts.pills.join(" | ")})`, facts.pills.some((one) => /^5,2\d\d parts$/.test(one))
        && facts.pills.some((one) => /steps, laid out by its modeller$/.test(one)) && facts.pills.includes("Set 10179-1")
        && facts.pills.includes("Star Wars") && facts.pills.includes("2007"));
      check(`${at}: View in 3D and Open in Brickworks open it in the app (${facts.viewer}, ${facts.open})`,
        facts.viewer === `/app?new=1&library=${SET}` && facts.open === facts.viewer);
      check(`${at}: under the LDraw library and its theme (${facts.crumbs})`, facts.crumbs === "LDraw library › Star Wars");
      check(`${at}: more Star Wars sets under it (${facts.next})`, facts.next >= 3);
      const wide = await sideways(page);
      check(`${at}: nothing sideways (${wide} px past the window)`, wide <= 0);
      await page.screenshot({ path: path.join(out, `set_${width}_${dark ? "dark" : "light"}.png`), fullPage: false });
      if (width === 1400 && !dark) {
        await page.locator("#parts").scrollIntoViewIfNeeded();
        // Each lot's picture drawn from its part's geometry (web/part-pictures.js):
        // data-picture="drawn", a canvas in place of its colour's swatch.
        const lots = await until(page, () => {
          const pics = [...document.querySelectorAll("#parts li.lot .pic")].slice(0, 5);
          return pics.length === 5 && pics.every((pic) => pic.dataset.picture === "drawn");
        }, null, 90);
        const count = await page.$$eval("#parts li.lot", (all) => all.length);
        check(`its parts list drawn, the first five lots with our own pictures (${count} lots shown)`, lots);
        await page.screenshot({ path: path.join(out, "set_parts.png"), fullPage: false });
        await page.evaluate(() => scrollTo(0, 0));
        await page.click("[data-share]");
        const sheet = await until(page, () => document.querySelector("#share-sheet")?.open === true, null, 10);
        const link = await page.inputValue("#share-link").catch(() => "");
        check(`Share opens its sheet with its link (${link})`, sheet && link.endsWith(`/library/${SET}`));
        check("...and no embed code, which a set has none of", !(await page.$("#share-embed")));
        await page.screenshot({ path: path.join(out, "set_share.png"), fullPage: false });
      }
      await made.close();
    }
  }
  {
    const made = await context({ width: 1400, dark: false });
    const { status } = await opened(made, "/library/omr-no-such-set-1");
    check(`a set the library has not got is a 404 (${status})`, status === 404);
    const parts = await made.request.get(`${site}/library/${SET}/parts.json`);
    const listed = parts.ok() ? await parts.json() : {};
    check(`its parts.json lists its lots (${listed.lots?.length}, ${listed.pieces} parts)`,
      parts.status() === 200 && listed.lots?.length > 100);
    const cover = await made.request.get(`${site}/library/${SET}.webp`);
    check(`its cover is a WebP from this site (${cover.headers()["content-type"]})`,
      cover.status() === 200 && cover.headers()["content-type"] === "image/webp");
    await made.close();
  }

  // 4. Open in Brickworks.
  if (!args["no-app"]) {
    const signedIn = await launch();
    const made = await signedIn.newContext({ viewport: { width: 1400, height: 900 }, extraHTTPHeaders: headers });
    const { page } = await opened(made, "/library/omr-106-1");
    await Promise.all([page.waitForURL("**/app?**", { timeout: 60000 }).catch(() => null),
      page.click('.side .actions a.cta:has-text("Open in Brickworks")')]);
    // The model's title is the page's (library_tab_flow.mjs reads it so).
    const up = await until(page, () => /^106-1 UNICEF Van/.test(document.title)
      && window.brickworksState?.bricks === 65 && !window.brickworksState?.awaited, null, 420);
    const state = await page.evaluate(() => ({ title: document.title, bricks: window.brickworksState?.bricks }));
    check(`Open in Brickworks opens the app with the set: "${state.title}", ${state.bricks} parts`, up);
    await page.screenshot({ path: path.join(out, "app.png"), fullPage: false });
    await signedIn.close();
  }
} catch (trouble) {
  check(`the flow ran to its end (${String(trouble?.message || trouble).slice(0, 200)})`, false);
} finally {
  await browser.close();
}
check(`no script error on the pages${problems.length ? `: ${problems.join("; ")}` : ""}`, problems.length === 0);
console.log(failed ? `library_site_flow: ${failed} failed` : "library_site_flow: all passed");
process.exit(failed ? 1 : 0);
