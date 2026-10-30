// Every set in the catalogue a page (sets364, api/_sets.js, web/set-page.js,
// web/library.js), in real browsers, against a deployment.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/sets_flow.mjs --url=<preview> --out=DIR [--no-app]
//
//   1. /library lists the whole catalogue (25,000 sets or more), each card a
//      set's page; found by number (10497 is 10497-1 first); "Only with a 3D
//      model" leaves only cards marked 3D; Star Wars in 2007 by the address
//      leaves only those.
//   2. A set with no 3D model, 10497-1 Galaxy Explorer: its page, its
//      picture drawn from its parts (/library/set/10497-1.jpg, a JPEG), its
//      facts, Rebrickable credited, CreativeWork and no Product; its parts
//      list's first lots drawn with our own pictures; and the page's weight
//      and first paint, measured (1,278 parts).
//   3. A set with one, 10179-1 Millennium Falcon: its LDraw model's render,
//      Build it in 3D, the model's page, which links back.
//   4. Parts you own: a throwaway account (a Resend test address, its session
//      minted here) with three of 10497-1's lots in its collection sees
//      "Parts you own: N of M" with N those lots' pieces and M the set's
//      parts a collection can hold (1,264 of its 1,278: a print LDraw does
//      not draw is left out, as the app's My collection leaves it out), and
//      downloads what it is missing as a BrickLink wanted list. Deleted at
//      the end.
//   5. Open its parts in Brickworks (unless --no-app): the app opens with the
//      set's parts in its bin (brickworksState.bin_set), signed in as the
//      test account.
//   6. The sitemaps: /sitemaps/index.xml names /sitemap.xml and the sets'
//      files, each under 50,000 addresses, 10497-1's page among them, and
//      robots.txt names the index.
//
// Fails too when a script error reaches the console. Pictures in --out.
import { mkdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, signInContext } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("sets_flow: --url=<deployment>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/sets"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const PLAIN = "10497-1";
const MODELLED = "10179-1";
const email = `delivered+bw-sets-flow-${Date.now().toString(36)}@resend.dev`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const problems = [];
const watch = (page, where) => page.on("pageerror", (e) => problems.push(`${where}: ${String(e).slice(0, 200)}`));
async function until(page, test, arg = null, seconds = 30) {
  try {
    await page.waitForFunction(test, arg, { timeout: seconds * 1000, polling: 250 });
    return true;
  } catch {
    return false;
  }
}
const cards = (page) => page.$$eval("#models .model", (all) => all.map((one) => ({ id: one.dataset.id,
  href: one.querySelector("a.open")?.getAttribute("href"), set: one.querySelector("small.set")?.textContent.trim() || "",
  model3d: one.dataset.model3d === "yes" })));

const browser = await launch({ signedOut: true });
const signedIn = args["no-app"] ? null : await launch();
try {
  const made = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  const get = (address) => made.request.get(`${site}${address}`);

  // 1. The library.
  {
    console.log("the library");
    const page = await made.newPage();
    watch(page, "/library");
    await page.goto(`${site}/library`, { waitUntil: "load", timeout: 120000 });
    const ready = await until(page, () => document.documentElement.dataset.library === "ready", null, 60);
    const said = await page.textContent("#found-said").catch(() => "");
    const every = Number(String(said).replace(/[^0-9]/g, "")) || 0;
    const shown = await cards(page);
    check(`the whole catalogue: "${said}"`, ready && every >= 20000);
    check(`each card a set's page (${shown.length}, the first ${shown[0]?.href})`, shown.length > 0
      && shown.every((one) => /^\/library\/set\/[A-Za-z0-9.-]+$/.test(one.href || "")));
    await page.screenshot({ path: path.join(out, "library.png") });
    await page.fill("#q", "10497");
    const found = await until(page, () => document.querySelector("#models .model")?.dataset.id === "set-10497-1", null, 30);
    check(`10497 finds 10497-1 first (${(await cards(page))[0]?.id})`, found);
    for (const [address, what, test] of [
      ["/library?model=3d", "Only with a 3D model: every card marked 3D", (all) => all.every((one) => one.model3d)],
      ["/library?theme=Star%20Wars&decade=2000s&year=2007", "Star Wars in 2007: every card", (all) => all.every((one) =>
        / · Star Wars · 2007$/.test(one.set))],
    ]) {
      await page.goto(`${site}${address}`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.library === "ready", null, 60);
      const listed = await cards(page);
      check(`${what} (${listed.length}: ${listed.slice(0, 3).map((one) => one.set).join("; ")})`, listed.length > 0 && test(listed));
    }
    const filters = await page.$$eval("#filters select", (all) => all.map((one) => one.id));
    check(`the Filters menu has the year, the 3D model and minifigures (${filters.join(", ")})`,
      ["year", "model", "figs", "sub"].every((one) => filters.includes(one)));
    await page.close();
  }

  // 2. A set with no 3D model, its weight and first paint.
  {
    console.log(`a set with no 3D model, ${PLAIN}`);
    const page = await made.newPage();
    watch(page, PLAIN);
    const answer = await page.goto(`${site}/library/set/${PLAIN}`, { waitUntil: "load", timeout: 120000 });
    const facts = await page.evaluate(() => ({
      title: document.querySelector("h1")?.textContent.trim(), picture: document.querySelector(".picture img")?.getAttribute("src"),
      drawn: document.querySelector(".picture img")?.naturalWidth || 0,
      pills: [...document.querySelectorAll(".facts .pill")].map((one) => one.textContent.trim()),
      credit: document.querySelector(".credit")?.textContent.replace(/\s+/g, " ").trim() || "",
      data: [...document.querySelectorAll('script[type="application/ld+json"]')].map((one) => one.textContent).join(""),
      bin: document.querySelector("[data-bin]")?.getAttribute("href"), design: document.querySelector("[data-design]")?.getAttribute("href"),
      paint: performance.getEntriesByName("first-contentful-paint")[0]?.startTime || 0,
    }));
    check(`its page answers (${answer?.status()}): "${facts.title}"`, answer?.status() === 200 && facts.title === "Galaxy Explorer");
    const picture = await get(`/library/set/${PLAIN}.jpg`);
    check(`its picture is drawn from its parts (${facts.picture}, ${facts.drawn} px wide, ${picture.headers()["content-type"]})`,
      facts.picture === `/library/set/${PLAIN}.jpg` && facts.drawn === 1200 && picture.headers()["content-type"] === "image/jpeg");
    check(`its facts: ${facts.pills.join(" · ")}`, facts.pills.includes("1,278 parts") && facts.pills.includes("4 minifigures")
      && facts.pills.includes("2022") && facts.pills.includes("Icons"));
    check("Rebrickable credited", /^Set and inventory data: Rebrickable\./.test(facts.credit));
    check("CreativeWork, never a Product or a price", /"@type":"CreativeWork"/.test(facts.data) && !/Product|offers|price/i.test(facts.data));
    check(`Open its parts and Design with these parts open the app (${facts.bin})`, facts.bin === `/app?new=1&parts=${PLAIN}`
      && /^\/app\?new=1&assistant=on&parts=10497-1&brief=Design%20something%20new/.test(facts.design || ""));
    await page.locator("#parts").scrollIntoViewIfNeeded();
    const lots = await until(page, () => {
      const pics = [...document.querySelectorAll("#parts li.lot .pic")].slice(0, 5);
      return pics.length === 5 && pics.every((pic) => pic.dataset.picture === "drawn");
    }, null, 90);
    check("its parts list's first five lots drawn with our own pictures", lots);
    await page.screenshot({ path: path.join(out, "set_plain_parts.png") });
    await page.evaluate(() => scrollTo(0, 0));
    await page.screenshot({ path: path.join(out, "set_plain.png") });
    // What it weighs: the page and everything it fetched until its parts were drawn.
    const weight = await page.evaluate(() => {
      const all = [performance.getEntriesByType("navigation")[0], ...performance.getEntriesByType("resource")];
      const sum = (pick) => all.reduce((n, one) => n + (one ? pick(one) : 0), 0);
      return { requests: all.length, sent: sum((one) => one.transferSize || 0), body: sum((one) => one.decodedBodySize || 0),
        html: all[0]?.transferSize || 0, json: performance.getEntriesByType("resource").find((one) => one.name.endsWith("/parts.json"))?.transferSize || 0 };
    });
    console.log(`  the page of a 1,278-part set: first paint ${Math.round(facts.paint)} ms, ${weight.requests} requests, `
      + `${Math.round(weight.sent / 1024)} kB over the wire (${Math.round(weight.body / 1024)} kB unpacked), the page `
      + `${Math.round(weight.html / 1024)} kB, its parts list ${Math.round(weight.json / 1024)} kB`);
    check(`its first paint under 2.5 s (${Math.round(facts.paint)} ms) and the page under 40 kB (${Math.round(weight.html / 1024)} kB)`,
      facts.paint > 0 && facts.paint < 2500 && weight.html < 40 * 1024);
    await page.close();
  }

  // 3. A set with a 3D model.
  {
    console.log(`a set with a 3D model, ${MODELLED}`);
    const page = await made.newPage();
    watch(page, MODELLED);
    const answer = await page.goto(`${site}/library/set/${MODELLED}`, { waitUntil: "load", timeout: 120000 });
    const facts = await page.evaluate(() => ({
      title: document.querySelector("h1")?.textContent.trim(), picture: document.querySelector(".picture img")?.getAttribute("src"),
      drawn: document.querySelector(".picture img")?.naturalWidth || 0,
      build: document.querySelector("[data-build3d]")?.getAttribute("href"),
      model: [...document.querySelectorAll("a")].some((one) => one.getAttribute("href") === "/library/omr-10179-1"),
    }));
    check(`its page answers (${answer?.status()}): "${facts.title}"`, answer?.status() === 200 && facts.title === "Millennium Falcon");
    check(`its picture is its LDraw model's render (${facts.picture}, ${facts.drawn} px)`,
      facts.picture === "/library/omr-10179-1.cutout.webp" && facts.drawn > 0);
    check(`Build it in 3D opens the model (${facts.build}), and its page is linked`,
      facts.build === "/app?new=1&library=omr-10179-1" && facts.model);
    await page.screenshot({ path: path.join(out, "set_modelled.png") });
    await page.goto(`${site}/library/omr-10179-1`, { waitUntil: "load" });
    const back = await page.$eval(`a[href="/library/set/${MODELLED}"]`, (one) => one.textContent.trim()).catch(() => "");
    check(`the model's page links back to the set's ("${back}")`, back === `Set ${MODELLED}`);
    const none = await get("/library/set/nosuch-99");
    check(`a set the catalogue has not got is a 404 (${none.status()})`, none.status() === 404);
    await page.close();
  }

  // 4. Parts you own.
  {
    console.log("parts you own");
    const listed = await (await get(`/library/set/${PLAIN}/parts.json`)).json();
    const three = listed.lots.slice(0, 3);
    const pieces = three.reduce((n, lot) => n + lot.count, 0);
    const { access_token: token } = await mintSession(email);
    const put = await made.request.put(`${site}/api/collection`, { headers: { ...headers, authorization: `Bearer ${token}`,
      "content-type": "application/json" }, data: { sets: [], parts: three.map((lot) => ({ part: lot.part, colour: lot.colour, qty: lot.count })) } });
    check(`a throwaway's collection of three of its lots, ${pieces} parts (${put.status()})`, put.ok());
    const mine = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers, acceptDownloads: true });
    await signInContext(mine, email);
    const page = await mine.newPage();
    watch(page, "owned");
    await page.goto(`${site}/library/set/${PLAIN}`, { waitUntil: "load" });
    const counted = await until(page, () => /^\d+\/\d+$/.test(document.documentElement.dataset.owned || ""), null, 60);
    const owned = await page.evaluate(() => ({ said: document.getElementById("owned-said")?.textContent || "",
      data: document.documentElement.dataset.owned }));
    // Of the parts a collection can hold, as the app's My collection counts
    // them (api/_owned.js keyed): a print Rebrickable numbers and LDraw does
    // not draw is left out of both sides, as the app leaves it out.
    const [have, of] = String(owned.data).split("/").map(Number);
    check(`"${owned.said}"`, counted && have === pieces && of <= listed.pieces && of >= 0.95 * listed.pieces
      && owned.said.startsWith(`Parts you own: ${pieces.toLocaleString("en-US")} of ${of.toLocaleString("en-US")}`));
    const short = Number((/in ([\d,]+) lots?\.$/.exec(owned.said) || [])[1]?.replace(/,/g, "")) || 0;
    await page.locator("#owned").scrollIntoViewIfNeeded();
    await page.screenshot({ path: path.join(out, "owned.png") });
    const [download] = await Promise.all([page.waitForEvent("download", { timeout: 15000 }).catch(() => null),
      page.click('[data-wanted="bricklink"]').catch(() => null)]);
    const text = download ? readFileSync(await download.path(), "utf8") : "";
    const items = (text.match(/<ITEM>/g) || []).length;
    check(`what is missing downloads as a BrickLink wanted list (${download?.suggestedFilename()}, ${items} lots)`,
      /^<INVENTORY>/.test(text) && items > 0 && items <= short && items >= short - 10);
    await mine.close();
  }

  // 5. Open its parts in Brickworks.
  if (signedIn) {
    console.log("open its parts in Brickworks");
    const app = await signedIn.newContext({ viewport: { width: 1400, height: 900 }, extraHTTPHeaders: headers });
    const page = await app.newPage();
    watch(page, "app");
    await page.goto(`${site}/library/set/${PLAIN}`, { waitUntil: "load" });
    await Promise.all([page.waitForURL("**/app?**", { timeout: 60000 }).catch(() => null), page.click("[data-bin]")]);
    const up = await until(page, () => /^10497-1 Galaxy Explorer$/.test(window.brickworksState?.bin_set || ""), null, 420);
    const state = await page.evaluate(() => ({ set: window.brickworksState?.bin_set, found: window.brickworksState?.found || [] }));
    check(`the app opens with its parts in the bin: "${state.set}", ${state.found.slice(0, 4).join(", ")}`, up && state.found.length > 0);
    // And still there once the app has settled: its catalogue arriving asks
    // the bin again by itself, which put the set away (sets364, the preview).
    await until(page, () => window.brickworksState && !window.brickworksState.awaited, null, 120);
    await page.waitForTimeout(15000);
    const later = await page.evaluate(() => window.brickworksState?.bin_set || "");
    check(`...and still there once the app has settled ("${later}")`, later === "10497-1 Galaxy Explorer");
    await page.screenshot({ path: path.join(out, "app_bin.png") });
    await app.close();
  }

  // 6. The sitemaps.
  {
    console.log("the sitemaps");
    const index = await (await get("/sitemaps/index.xml")).text();
    const files = [...index.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    check(`the index names the site's sitemap and ${files.length - 1} of the sets'`, files.some((one) => one.endsWith("/sitemap.xml"))
      && files.filter((one) => /\/sitemaps\/sets-\d+\.xml$/.test(one)).length >= 2);
    let listed = 0;
    let plain = false;
    for (const file of files.filter((one) => /\/sitemaps\/sets-\d+\.xml$/.test(one))) {
      const answer = await get(new URL(file).pathname);
      const locs = [...(await answer.text()).matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
      check(`${new URL(file).pathname}: ${locs.length} pages (${answer.status()})`, answer.status() === 200 && locs.length > 0 && locs.length <= 50000);
      listed += locs.length;
      plain = plain || locs.some((one) => one.endsWith(`/library/set/${PLAIN}`));
    }
    check(`${listed} set pages listed, ${PLAIN}'s among them`, listed >= 20000 && plain);
    const robots = await (await get("/robots.txt")).text();
    check("robots.txt names the index", /Sitemap: https:\/\/brickworks\.diy\/sitemaps\/index\.xml/.test(robots));
  }
} catch (trouble) {
  check(`the flow ran to its end (${String(trouble?.message || trouble).slice(0, 200)})`, false);
} finally {
  await browser.close();
  if (signedIn) await signedIn.close();
  const gone = await deleteAccount(email).catch(() => false);
  console.log(`  the throwaway account ${gone ? "deleted" : "was not there to delete"}`);
}
check(`no script error on the pages${problems.length ? `: ${problems.join("; ")}` : ""}`, problems.length === 0);
console.log(failed ? `sets_flow: ${failed} failed` : "sets_flow: all passed");
process.exit(failed ? 1 : 0);
