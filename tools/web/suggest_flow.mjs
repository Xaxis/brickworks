// A change sent back, on the site, in a real browser (suggestedit,
// 2026-11-23): Ann sends her remix's change from its page, Dee's header
// counts it within a minute without a reload, Dee's model's page lists it
// with its way into the studio, and once Dee's version 2 takes part of it
// in, her model's page credits Ann under its credit and in its Log.
//
//   node tools/web/suggest_flow.mjs [--out=DIR] [--widths=390,1280]
//
// Nothing leaves this machine: every page and every call is made by this
// checkout's api/share.js and api/people.js over the Supabase in memory of
// tests/fixtures/suggest/world.mjs (Dee's car, Ann's remix of it), and the
// site's own files.
//
// At each width:
//
//   1. Ann on her remix's page: the box under its credit says she may send
//      her change back, with a note; Send says it went to Red car's designer
//      and what it changes. Nobody else sees the box: Dee on Ann's page sees
//      none, nor does anybody signed out.
//   2. Dee on her own page, opened before it was sent, its header counting
//      nothing: within 60 s of the send it counts 1, with no reload (the
//      site asks again every 45 s, web/follow.js). Reloaded, the box lists
//      Ann's change, its note and Open it in the studio, to
//      /app?suggestion=N. Ann on Dee's page sees no list.
//   3. Taken in part and published as Dee's version 2 (through the same
//      handlers): Dee's page says "With part of Ann's change from their
//      remix “Red car, wider”, version 2" under its credit, each a link,
//      and its Log's version 2 says it too.
//
// Pictures: DIR/send_<width>.png, DIR/open_<width>.png, DIR/credit_<width>.png.
import { launch } from "./browser.mjs";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const web = path.join(root, "web");
const out = path.resolve(String(args.out || "shots/suggest"));
mkdirSync(out, { recursive: true });
const widths = String(args.widths || "390,1280").split(",").map(Number);
// A width a process: each world signs its sessions with a key of its own
// (tests/fixtures/billing/world.mjs), and the handlers keep the first
// key they read.
if (widths.length > 1) {
  let bad = 0;
  for (const width of widths) {
    const run = spawnSync(process.execPath, [fileURLToPath(import.meta.url), `--out=${out}`, `--widths=${width}`],
      { stdio: ["ignore", "inherit", "inherit"] });
    if (run.status !== 0) bad += 1;
  }
  console.log(`suggest flow, every width: ${bad === 0 ? "all pass" : `${bad} width(s) FAILED`}`);
  process.exit(bad === 0 ? 0 : 1);
}
const SITE = "https://brickworks.test";

let failed = 0;
const check = (what, ok) => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  return ok;
};
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);
for (const level of ["warn", "info"]) console[level] = () => {};
const troubles = [];
console.error = (...said) => troubles.push(said.join(" ").slice(0, 300));

const fixtures = path.join(root, "tests/fixtures/suggest");
const mine = readFileSync(path.join(fixtures, "car.mine.ldr"), "utf8");
const theirs = readFileSync(path.join(fixtures, "car.theirs.ldr"), "utf8");
const { suggestWorld } = await import(path.join(fixtures, "world.mjs"));
const { mergeSuggestion } = await import(path.join(root, "api/_suggest.js"));

const TYPES = { ".js": "text/javascript", ".css": "text/css", ".html": "text/html; charset=utf-8", ".json": "application/json",
  ".svg": "image/svg+xml", ".png": "image/png", ".webp": "image/webp", ".woff2": "font/woff2", ".ico": "image/x-icon" };

/// A context of [w]'s site at [width], signed in as [as] (or nobody).
async function opened(browser, w, width, as) {
  const phone = width < 600;
  // No service worker: the site's would answer a reload from its own fetch,
  // which this context's routes never see.
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: "light",
    serviceWorkers: "block", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await context.route(/.*/, (route) => answer(route).catch((trouble) => {
    troubles.push(`${width} ${as} ${route.request().url()}: ${String(trouble?.stack || trouble).slice(0, 300)}`);
    return route.fulfill({ status: 500, contentType: "text/plain", body: "" }).catch(() => {});
  }));
  async function answer(route) {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin !== SITE) return route.fulfill({ status: 404, body: "" });
    const api = /^\/api\/(share|people)$/.exec(url.pathname)?.[1];
    const page = /^\/m\/([A-Za-z0-9]{10})(?:\/v\/(\d+))?$/.exec(url.pathname);
    if (api || page) {
      let body;
      try {
        body = request.postData() ? JSON.parse(request.postData()) : undefined;
      } catch {
        body = undefined;
      }
      const auth = request.headers().authorization || "";
      const who = Object.entries(w.tokens).find(([, token]) => auth === `Bearer ${token}`)?.[0];
      const said = page
        ? await w.ask("share", { query: { op: "page", id: page[1], ...(page[2] ? { v: page[2] } : {}) }, page: true })
        : await w.ask(api, { method: request.method(), query: Object.fromEntries(url.searchParams), body, as: who });
      const html = typeof said.body === "string";
      return route.fulfill({ status: said.status, contentType: html ? "text/html; charset=utf-8" : "application/json",
        body: html ? said.body : JSON.stringify(said.body ?? null) });
    }
    if (url.pathname.startsWith("/api/")) return route.fulfill({ status: 404, contentType: "application/json", body: "{}" });
    const file = path.join(web, url.pathname === "/" ? "index.html" : url.pathname.slice(1));
    if (!file.startsWith(web) || !existsSync(file) || statSync(file).isDirectory()) return route.fulfill({ status: 404, body: "" });
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || "application/octet-stream",
      body: readFileSync(file) });
  }
  if (as) {
    const session = JSON.stringify({ refresh_token: "suggest-flow", email: `${as}@example.com`, user_id: as === "dee" ? w.DEE : w.ANN,
      url: "https://db.test", key: "publishable" });
    const access = JSON.stringify({ token: w.tokens[as], until: Date.now() + 3600 * 1000, email: `${as}@example.com` });
    await context.addInitScript(([value, kept]) => {
      try {
        localStorage.setItem("brickworks.session", value);
        sessionStorage.setItem("brickworks.access", kept);
      } catch { /* nothing kept */ }
    }, [session, access]);
  }
  const tab = await context.newPage();
  tab.on("pageerror", (e) => troubles.push(`${width} ${as}: ${String(e).slice(0, 200)}`));
  return { context, page: tab, phone };
}

const boxOf = (page) => page.evaluate(() => {
  const box = document.querySelector("#suggest-box");
  return { shown: Boolean(box && !box.hidden), text: box?.textContent.replace(/\s+/g, " ").trim() || "",
    form: Boolean(box?.querySelector("form.suggest-send")), open: [...(box?.querySelectorAll(".suggest-open li") || [])]
      .map((li) => ({ text: li.textContent.replace(/\s+/g, " ").trim(), go: li.querySelector("a.cta")?.getAttribute("href") || "" })) };
});
// The header's count: its account button's badge, wherever a phone's menu keeps it.
const counted = () => Math.max(0, ...[...document.querySelectorAll(".site-head .count")].map((one) => Number(one.textContent) || 0));
const countOf = (page) => page.evaluate(counted);

const browser = await launch({ signedOut: true });
for (const width of widths) {
  console.log(`width ${width}`);
  const w = await suggestWorld({ mine, theirs });
  // 2 first: Dee's page open before anything is sent, its header counting nothing.
  const dee = await opened(browser, w, width, "dee");
  await dee.page.goto(`${SITE}/m/${w.MODEL}`, { waitUntil: "load" });
  await until(dee.page, () => document.querySelector(".site-head .account-btn, .site-head a[data-account]"), null, 15000);
  check(`${width}: Dee's header counts nothing before it is sent (${await countOf(dee.page)})`, (await countOf(dee.page)) === 0);
  const deeBox = await boxOf(dee.page);
  check(`${width}: Dee's own page has no box while nothing is sent to it, and no Send (not a remix)`, !deeBox.shown && !deeBox.form);

  // 1. Ann sends hers from her remix's page.
  const ann = await opened(browser, w, width, "ann");
  await ann.page.goto(`${SITE}/m/${w.REMIX}`, { waitUntil: "load" });
  await until(ann.page, () => document.querySelector("#suggest-box form.suggest-send"), null, 15000);
  const annBox = await boxOf(ann.page);
  check(`${width}: Ann's remix's page offers her to send it back ("${annBox.text.slice(0, 90)}…")`, annBox.shown && annBox.form);
  await ann.page.fill("#suggest-note", "Wider wheels, and a spoiler");
  await ann.page.locator("#suggest-box button[type=submit]").scrollIntoViewIfNeeded();
  if (ann.phone) await ann.page.tap("#suggest-box button[type=submit]");
  else await ann.page.click("#suggest-box button[type=submit]");
  const sentAt = Date.now();
  const saidSent = await until(ann.page, () => /Sent to/.test(document.querySelector("#suggest-box .said")?.textContent || ""), null, 15000);
  const sentWords = await ann.page.evaluate(() => document.querySelector("#suggest-box .said")?.textContent || "");
  check(`${width}: Send says where it went: "${sentWords}"`, saidSent
    && sentWords === "Sent to the designer of “Red car”, who hears of it now: 2 added, 1 taken away, 1 moved, 1 recoloured, 1 swapped, 1 to another step.");
  check(`${width}: one change kept, open, with her note`, w.suggestions.length === 1 && w.suggestions[0].status === "open"
    && w.suggestions[0].note === "Wider wheels, and a spoiler");
  await ann.page.locator("#suggest-box").scrollIntoViewIfNeeded();
  await ann.page.screenshot({ path: path.join(out, `send_${width}.png`) });

  // Nobody else sees the box: Dee on Ann's page, and anybody signed out.
  const deeOnAnn = await opened(browser, w, width, "dee");
  await deeOnAnn.page.goto(`${SITE}/m/${w.REMIX}`, { waitUntil: "load" });
  await deeOnAnn.page.waitForTimeout(1500);
  const outside = await opened(browser, w, width, null);
  await outside.page.goto(`${SITE}/m/${w.REMIX}`, { waitUntil: "load" });
  await outside.page.waitForTimeout(1500);
  check(`${width}: Dee on Ann's remix and anybody signed out see no box`, !(await boxOf(deeOnAnn.page)).shown
    && !(await boxOf(outside.page)).shown);
  await deeOnAnn.context.close();
  await outside.context.close();

  // 2. Dee's header counts it within a minute, no reload.
  const lit = await until(dee.page, `(${counted})() >= 1`, null, 62000);
  const after = (Date.now() - sentAt) / 1000;
  check(`${width}: Dee's header counts it ${after.toFixed(1)} s after it was sent, with no reload, within 60 s`, lit && after <= 60);
  await dee.page.reload({ waitUntil: "load" });
  await until(dee.page, () => document.querySelector("#suggest-box .suggest-open li"), null, 15000);
  const listed = await boxOf(dee.page);
  check(`${width}: reloaded, her page lists it: "${listed.open[0]?.text || ""}"`, listed.shown && listed.open.length === 1
    && listed.open[0].text.startsWith("Ann sent a change from their remix “Red car, wider”: 2 added, 1 taken away, 1 moved, 1 recoloured, 1 swapped, 1 to another step.")
    && listed.open[0].text.includes("Wider wheels, and a spoiler"));
  check(`${width}: its way into the studio is /app?suggestion=${w.suggestions[0].id} (${listed.open[0]?.go})`,
    listed.open[0]?.go === `/app?suggestion=${w.suggestions[0].id}`);
  check(`${width}: and no Send on her own model`, !listed.form);
  await dee.page.locator("#suggest-box").scrollIntoViewIfNeeded();
  await dee.page.screenshot({ path: path.join(out, `open_${width}.png`) });
  // Ann on Dee's page: no list.
  await ann.page.goto(`${SITE}/m/${w.MODEL}`, { waitUntil: "load" });
  await ann.page.waitForTimeout(1500);
  check(`${width}: Ann on Dee's page sees no list`, !(await boxOf(ann.page)).shown);

  // 3. Taken in part (all but the recolour), published as version 2.
  const id = w.suggestions[0].id;
  const asked = await w.ask("share", { query: { op: "suggestion", id: String(id) }, as: "dee" });
  const ids = asked.body.changes.filter((c) => c.kind !== "recoloured").map((c) => c.id);
  const merged = await w.ask("share", { method: "POST", query: { op: "suggestion_merge" }, as: "dee", body: { id, n: 1, take: ids } });
  const published = await w.ask("share", { method: "POST", as: "dee", body: { id: w.MODEL, name: "Red car", model: merged.body.text,
    suggestion: { id, taken: merged.body.taken, whole: merged.body.whole } } });
  check(`${width}: taken in part and published as version ${published.body?.version}, marked taken`, published.status === 200
    && merged.body.text === mergeSuggestion(mine, theirs, ids).text && w.suggestions[0].status === "taken");
  await dee.page.reload({ waitUntil: "load" });
  const credit = await dee.page.evaluate(() => {
    const line = document.querySelector(".model-page .suggested-credit li");
    const log = [...document.querySelectorAll("#versions .log-entry")].map((li) => ({
      head: li.querySelector(".log-head a")?.textContent || "", credit: li.querySelector(".log-credit")?.textContent || "" }));
    return { line: line?.textContent.replace(/\s+/g, " ").trim() || "", links: [...(line?.querySelectorAll("a") || [])].map((a) => a.getAttribute("href")),
      log };
  });
  check(`${width}: under its credit: "${credit.line}"`, credit.line === "With part of Ann’s change from their remix “Red car, wider”, version 2"
    && JSON.stringify(credit.links) === JSON.stringify(["/u/ann", `/m/${w.REMIX}`, `/m/${w.MODEL}/v/2`]));
  const v2 = credit.log.find((one) => one.head === "Version 2");
  check(`${width}: its Log's version 2 says it: "${v2?.credit || ""}"`, v2?.credit === "With part of Ann’s change from their remix “Red car, wider”"
    && credit.log.filter((one) => one.credit).length === 1);
  check(`${width}: and the box is gone, nothing open`, !(await boxOf(dee.page)).shown);
  await dee.page.locator(".model-page .suggested-credit").scrollIntoViewIfNeeded();
  await dee.page.screenshot({ path: path.join(out, `credit_${width}.png`) });
  await dee.context.close();
  await ann.context.close();
}
await browser.close();
check(`no page error or server trouble (${troubles.slice(0, 3).join(" | ")})`, troubles.length === 0);
console.log(`suggest flow: ${failed === 0 ? "all pass" : `${failed} FAILED`}; pictures in ${out}`);
process.exit(failed === 0 ? 0 : 1);
