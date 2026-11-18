// What a phone is told before the studio opens, each in its case and in no
// other, on a computer, a phone and a tablet (phonetruth, 2026-11-18;
// docs/PHONE.md). Chromium, each kind its own fresh browser profile:
//
//   desktop  1280x800, a mouse
//   phone    390x844 at 3x, touch only (as an iPhone 13 or a Pixel 7 is)
//   tablet   820x1180 at 2x, touch only (an iPad Air's size)
//
//   1. A model too big for a phone (web/phone-warn.js). The gallery's
//      largest is the measured default (docs/PHONE.md), so it goes straight
//      on at the number the site serves, as every gallery model does today.
//      Then with a number under it handed to the page as the owner's
//      (--number, 5,000): Build it and Open in Brickworks ask first on the
//      phone alone ("About N parts: on a phone this may close the tab"),
//      with the question in view at 430x932; Not now and Escape stay, Open
//      it anyway goes on. The picture still opens the 3D view in its place,
//      unasked. A model under the number, and the computer and the tablet
//      with the big one, go straight on. A press before the owner's number
//      came waits for it.
//   2. The console's number is the one pages use (--owner, previews only,
//      never brickworks.diy): Switches' Phones form, as the owner, set to
//      under the small model's parts; the small model then asks on the
//      phone; put back as it was after.
//   3. No WebGL 2 (taken from the page's canvas): the loader says so in plain
//      words on all three, at once, and lets the engine's files go; with it,
//      none of them is told so.
//   4. A first visit on a phone (Fast 4G, so its download takes a while):
//      the loader says how long it will take, and how close its first
//      estimate came is written down; a return to the same phone, the
//      computer and the tablet are told nothing.
//   5. The engine's memory refused, as iOS Safari refuses a 2 GB shared one
//      on some iPhones (godot#70621): said as that, in plain words, with
//      what to do, on the phone and the computer alike; no time to wait
//      given. The other cases above never say it.
//
//   node tools/web/phonewarn_flow.mjs --url=https://<preview>/app [--bypass=SECRET] [--owner]
//     [--big=ID:PARTS] [--small=ID:PARTS] [--number=5000] [--only=1,2,3,4,5] [--out=DIR]
//
// Exit 0 when every check passed. The pictures, and warn.json with what
// each case saw, go to --out.
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { launch } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...v] = a.replace(/^--/, "").split("=");
  return [k, v.length ? v.join("=") : true];
}));
const site = String(args.url || "https://brickworks.diy").replace(/\/+$/, "").replace(/\/app$/, "");
const live = /^(?:www\.)?brickworks\.diy$/.test(new URL(site).host);
const out = String(args.out || "shots/phonewarn");
mkdirSync(out, { recursive: true });
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const only = args.only ? new Set(String(args.only).split(",")) : null;
const wanted = (n) => !only || only.has(String(n));
const pair = (given, fallback) => {
  const [id, parts] = String(given || fallback).split(":");
  return { id, parts: Number(parts) };
};
// Gallery models of the live site's (tools/web/phonetruth_flow.mjs LADDER).
const BIG = pair(args.big, "EzEXhtXE2C:10101");
const SMALL = pair(args.small, "XqW6brmPQs:741");
// The owner's number a page is handed in section 1: under BIG, over SMALL.
const NUMBER = Number(args.number || 5000);
const KINDS = {
  desktop: { viewport: { width: 1280, height: 800 } },
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
  tablet: { viewport: { width: 820, height: 1180 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true },
  // The largest phone (an iPhone Pro Max's), where what a press says must still come into view.
  phone430: { viewport: { width: 430, height: 932 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
};
/// Whether [selector]'s box is wholly inside the viewport.
const inView = (page, selector) => page.evaluate((one) => {
  const el = document.querySelector(one);
  if (!el) return false;
  const box = el.getBoundingClientRect();
  return box.width > 0 && box.height > 0 && box.left >= 0 && box.top >= 0
    && box.right <= innerWidth && box.bottom <= (visualViewport ? visualViewport.height : innerHeight);
}, selector);
const FAST4G = { offline: false, latency: 165, downloadThroughput: (9e6 / 8) * 0.9, uploadThroughput: (1.5e6 / 8) * 0.9 };
const NO_GL2 = "This browser can't draw the studio in 3D: it has no WebGL 2.";
const NO_MEMORY = "This browser would not give the studio the memory it needs";

let failed = 0;
let passed = 0;
const check = (what, ok, said = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said ? `: ${said}` : ""}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const seen = {};
const errors = [];
const t0 = Date.now();
const at = () => `${Math.round((Date.now() - t0) / 1000)}s`;

const browser = await launch({ signedOut: true });

/// A fresh profile of [kind], the bypass carried, its page. A page that
/// loads the studio carries it by the address and its cookie (studio()):
/// a header of its own on every request would be asked about first by the
/// part store, which is another site.
async function fresh(kind, { noGl2 = false, noMemory = false, net = null, studio = true } = {}) {
  const context = await browser.newContext({ ...KINDS[kind], ...(studio ? {} : { extraHTTPHeaders: headers }) });
  if (noMemory) {
    // Safari's own refusal, for the engine's shared memory past 1 GB.
    await context.addInitScript(() => {
      const Made = WebAssembly.Memory;
      WebAssembly.Memory = function Memory(given) {
        if (given && given.shared && given.maximum > 16384) throw new RangeError("Out of memory");
        return new Made(given);
      };
      WebAssembly.Memory.prototype = Made.prototype;
    });
  }
  if (noGl2) {
    await context.addInitScript(() => {
      const made = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
        return kind === "webgl2" ? null : made.call(this, kind, ...rest);
      };
    });
  }
  // The studio a link goes on to, not loaded where a model page's link is all that is checked.
  if (!studio) await context.route(/\/app\?/, (route) => route.fulfill({ status: 200, contentType: "text/html", body: "<p>the studio</p>" }));
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${kind}: ${String(e).slice(0, 200)}`));
  const cdp = await context.newCDPSession(page);
  if (net) {
    await cdp.send("Network.enable");
    await cdp.send("Network.emulateNetworkConditions", net);
  }
  return { context, page, cdp };
}

const studio = () => `${site}/app${bypass ? `?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true` : ""}`;
const pointer = (page) => page.evaluate(() => ({ coarse: matchMedia("(pointer: coarse)").matches,
  fine: matchMedia("(any-pointer: fine)").matches, short: Math.min(screen.width, screen.height) }));
const warned = (page) => page.evaluate(() => {
  const dialog = document.querySelector("dialog.phone-warn");
  return { open: Boolean(dialog?.open), said: dialog?.querySelector("#phone-warn-said")?.textContent || "",
    state: document.documentElement.dataset.phoneWarn || "" };
});

/// [id]'s page in [kind]: [press] (a link's selector) pressed, and what came of it.
/// With [number], the page is handed it as the owner's number; with
/// [early], the owner's number is [early] parts and comes 1.2 s late (a slow
/// phone's reply), and the press is made before it has come.
async function press(kind, id, selector, { then = null, early = 0, number = 0 } = {}) {
  const { context, page } = await fresh(kind, { studio: false });
  if (early || number) {
    await context.route(/\/api\/plans\?op=phone/, async (route) => {
      if (early) await new Promise((done) => { setTimeout(done, 1200); });
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ phone_parts: early || number, phone_start_s: 40 }) });
    });
  }
  await page.goto(`${site}/m/${id}`, { waitUntil: "load", timeout: 120000 });
  if (!early) await page.waitForTimeout(1200);
  const how = await pointer(page);
  const link = page.locator(selector).first();
  const href = await link.getAttribute("href").catch(() => null);
  if (KINDS[kind].hasTouch) await link.tap({ timeout: 20000 });
  else await link.click({ timeout: 20000 });
  await page.waitForTimeout(early ? 4000 : 1500);
  const after = { url: page.url(), ...(await warned(page).catch(() => ({ open: false, said: "", state: "" }))) };
  after.waited = await page.evaluate(() => document.documentElement.dataset.phoneWarnWaited === "1").catch(() => null);
  const result = { kind, id, selector, href, pointer: how, after };
  if (then) result.then = await then(page);
  await page.screenshot({ path: join(out, `${kind}_${id}_${selector.replace(/\W+/g, "_")}.png`), timeout: 30000 }).catch(() => {});
  await context.close();
  return result;
}
const wentOn = (r) => /\/app\?/.test(r.after.url) && !r.after.open;
const asked = (r) => r.after.open && !/\/app\?/.test(r.after.url) && r.after.state === "asked";
const BUILD = ".actions a.cta[href*='&build']";
const COPY = ".actions a.cta[href*='/app?copy=']";

try {
  if (wanted(1)) {
    console.log(`1. A model too big for a phone  [${at()}]`);
    const served = await fetch(`${site}/api/plans?op=phone`, { headers }).then((r) => r.json()).catch(() => ({}));
    const measured = await press("phone", BIG.id, BUILD);
    seen.big_phone_served = { served, ...measured };
    const over = BIG.parts > Number(served.phone_parts);
    check(`phone, ${BIG.parts} parts at the number served (${served.phone_parts}): ${over ? "asked first" : "straight on"}`,
      over ? asked(measured) : wentOn(measured), measured.after.url.replace(site, ""));
    const big = await press("phone", BIG.id, BUILD, { number: NUMBER,
      then: async (page) => {
        await page.keyboard.press("Escape");
        await page.waitForTimeout(400);
        const escaped = { url: page.url(), ...(await warned(page)) };
        await page.locator(COPY).first().tap({ timeout: 20000 });
        await page.waitForTimeout(800);
        const copy = await warned(page);
        await page.locator("dialog.phone-warn button.cta").tap();
        await page.waitForTimeout(400);
        const notNow = { url: page.url(), ...(await warned(page)) };
        await page.locator(BUILD).first().tap({ timeout: 20000 });
        await page.waitForTimeout(800);
        await page.locator("dialog.phone-warn a[data-phone-warned]").tap();
        await page.waitForURL(/\/app\?/, { timeout: 20000 }).catch(() => {});
        return { escaped, copy, notNow, anyway: page.url() };
      },
    });
    seen.big_phone = big;
    check(`phone, ${BIG.parts} parts past the owner's ${NUMBER}, Build it: asked first, the page kept (${big.pointer.coarse ? "coarse" : "fine"}, short side ${big.pointer.short})`,
      asked(big), big.after.said.slice(0, 90));
    check("… it says about how many parts and that the tab may close",
      /About 10,100 parts: on a phone this may close the tab\./.test(big.after.said) || (BIG.parts !== 10101 && /About [\d,]+ parts/.test(big.after.said)),
      big.after.said.slice(0, 60));
    check("… Escape stays on the page", big.then.escaped.state === "stayed" && !big.then.escaped.open && !/\/app\?/.test(big.then.escaped.url));
    check("… Open in Brickworks asks too", big.then.copy.open);
    check("… Not now stays on the page", big.then.notNow.state === "stayed" && !/\/app\?/.test(big.then.notNow.url));
    check("… Open it anyway goes on to the studio with the model", big.then.anyway.includes(`view=${BIG.id}`), big.then.anyway.replace(site, ""));
    const picture = await press("phone", BIG.id, "a.picture", { number: NUMBER,
      then: (page) => page.evaluate(() => Boolean(document.querySelector(".view3d"))) });
    seen.picture_phone = picture;
    check("phone, the same model's picture: its 3D view opens in its place, unasked", picture.then && !picture.after.open
      && !/\/app\?/.test(picture.after.url));
    const large = await press("phone430", BIG.id, BUILD, { number: NUMBER,
      then: async (page) => ({ dialog: await inView(page, "dialog.phone-warn"), stay: await inView(page, "dialog.phone-warn button.cta"),
        go: await inView(page, "dialog.phone-warn a[data-phone-warned]") }) });
    seen.big_phone430 = large;
    check("phone at 430x932, the same: asked, with the question and both its ways in view", asked(large)
      && large.then.dialog && large.then.stay && large.then.go, JSON.stringify(large.then));
    const small = await press("phone", SMALL.id, BUILD, { number: NUMBER });
    seen.small_phone = small;
    check(`phone, ${SMALL.parts} parts, under the owner's ${NUMBER}: straight on to the studio`, wentOn(small), small.after.url.replace(site, ""));
    // Pressed before the owner's number has come: it is waited on. Under
    // the measured default, the small one asked is the owner's number used.
    const lateLow = await press("phone", SMALL.id, BUILD, { early: SMALL.parts - 41 });
    seen.late_low_phone = lateLow;
    check(`phone, pressed before the owner's ${SMALL.parts - 41} came: ${SMALL.parts} parts asked, the number waited on`, asked(lateLow) && lateLow.after.waited,
      lateLow.after.said.slice(0, 60));
    for (const kind of ["desktop", "tablet"]) {
      const r = await press(kind, BIG.id, BUILD, { number: NUMBER });
      seen[`big_${kind}`] = r;
      check(`${kind}, ${BIG.parts} parts past the owner's ${NUMBER}: straight on to the studio (${r.pointer.coarse ? "coarse" : "fine"}, short side ${r.pointer.short})`,
        wentOn(r), r.after.url.replace(site, ""));
    }
  }

  if (wanted(2) && args.owner) {
    console.log(`2. The console's number is the pages'  [${at()}]`);
    if (live) {
      check("not on brickworks.diy: its visitors would be warned by a check's number", true);
    } else {
      const owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
      const asOwner = async (kind) => {
        const context = await browser.newContext({ ...KINDS[kind], extraHTTPHeaders: headers });
        const access = JSON.stringify({ token: owner.access_token, until: Date.now() + 50 * 60 * 1000, email: owner.kept.email });
        await context.addInitScript(([key, value, token]) => {
          try {
            if (!localStorage.getItem(key)) {
              localStorage.setItem(key, value);
              sessionStorage.setItem("brickworks.access", token);
            }
          } catch { /* nothing kept */ }
        }, [STORAGE_KEY, JSON.stringify(owner.kept), access]);
        const page = await context.newPage();
        page.on("dialog", (d) => d.accept());
        await page.goto(`${site}/admin#switches`, { waitUntil: "load", timeout: 120000 });
        await page.waitForFunction(() => document.querySelector("#phones-form input[name=phone_parts]")?.value, null, { timeout: 60000 });
        return { context, page };
      };
      const keep = async (page, parts, start) => {
        await page.fill("#phones-form input[name=phone_parts]", String(parts));
        await page.fill("#phones-form input[name=phone_start_s]", String(start));
        const was = await page.evaluate(() => document.getElementById("phones-note").textContent);
        await page.click("#phones-form button[type=submit]");
        const valid = await page.evaluate(() => document.getElementById("phones-form").checkValidity());
        if (valid) {
          await page.waitForFunction((before) => (document.getElementById("phones-note")?.textContent || "") !== before, was, { timeout: 30000 })
            .catch(() => {});
        }
        return page.evaluate((ok) => ({ valid: ok, note: document.getElementById("phones-note").textContent,
          bad: document.getElementById("phones-note").classList.contains("bad"),
          parts: document.querySelector("#phones-form input[name=phone_parts]").value,
          start: document.querySelector("#phones-form input[name=phone_start_s]").value,
          said: document.getElementById("phones-said").textContent }), valid);
      };
      const one = await asOwner("phone");
      const before = await one.page.evaluate(() => ({ parts: document.querySelector("#phones-form input[name=phone_parts]").value,
        start: document.querySelector("#phones-form input[name=phone_start_s]").value, said: document.getElementById("phones-said").textContent }));
      seen.console_before = before;
      await one.page.locator("#phones-form").scrollIntoViewIfNeeded();
      await one.page.screenshot({ path: join(out, "console_phones_390.png"), timeout: 30000 }).catch(() => {});
      check("Switches, Phones: the numbers shown", Number(before.parts) > 0 && Number(before.start) > 0, `${before.parts} parts, ${before.start} s; ${before.said}`);
      // The browser's own refusal, with its words, before anything is sent
      // (the API's, for whatever comes another way: tests/test_console3.py).
      const refused = await keep(one.page, 10, before.start);
      const message = await one.page.evaluate(() => document.querySelector("#phones-form input[name=phone_parts]").validationMessage);
      check("… 10 parts refused with words, nothing sent", !refused.valid && Boolean(message) && !/^Kept:/.test(refused.note), message);
      const low = SMALL.parts - 41;
      const set = await keep(one.page, low, before.start);
      seen.console_set = set;
      const noted = await inView(one.page, "#phones-note");
      check(`… ${low} parts kept, and said where the press is`, !set.bad && /^Kept:/.test(set.note) && noted, `${set.note}${noted ? "" : " (out of view)"}`);
      await one.context.close();
      // The CDN keeps the number's answer a minute, and a stale one once more.
      let small = null;
      for (const begun = Date.now(); Date.now() - begun < 240000;) {
        small = await press("phone", SMALL.id, BUILD);
        if (small.after.open) break;
        await new Promise((done) => setTimeout(done, 15000));
      }
      seen.small_phone_after = small;
      check(`phone, ${SMALL.parts} parts, past the console's ${low}: asked first`, asked(small), small.after.said.slice(0, 60));
      const desk = await asOwner("desktop");
      await desk.page.screenshot({ path: join(out, "console_phones_1280.png"), timeout: 30000 }).catch(() => {});
      const back = await keep(desk.page, before.parts, before.start);
      seen.console_back = back;
      check(`… put back as it was (${before.parts} parts, ${before.start} s)`, !back.bad && back.parts === before.parts, back.note);
      await desk.context.close();
    }
  }

  if (wanted(3)) {
    console.log(`3. No WebGL 2  [${at()}]`);
    for (const kind of ["desktop", "phone", "tablet"]) {
      // On Fast 4G, so the engine's files are still coming when it is said.
      const { context, page, cdp } = await fresh(kind, { noGl2: true, net: FAST4G });
      const files = new Map();
      cdp.on("Network.requestWillBeSent", (e) => { if (/\/index\.(wasm|pck)(\?|$)/.test(e.request.url)) files.set(e.requestId, { url: e.request.url, got: 0, end: "" }); });
      cdp.on("Network.dataReceived", (e) => { const f = files.get(e.requestId); if (f) f.got += e.encodedDataLength || e.dataLength || 0; });
      cdp.on("Network.loadingFinished", (e) => { const f = files.get(e.requestId); if (f) { f.end = "finished"; f.got = Math.max(f.got, e.encodedDataLength || 0); } });
      cdp.on("Network.loadingFailed", (e) => { const f = files.get(e.requestId); if (f) f.end = e.canceled ? "canceled" : `failed ${e.errorText}`; });
      const began = Date.now();
      await page.goto(studio(), { waitUntil: "commit", timeout: 120000 });
      const told = await page.waitForFunction((words) => (document.getElementById("note")?.textContent || "").startsWith(words), NO_GL2, { timeout: 60000 })
        .then(() => Date.now() - began, () => NaN);
      await page.waitForTimeout(3000);
      const note = await page.evaluate(() => ({ note: document.getElementById("note").textContent, eta: !document.getElementById("eta").hidden }));
      await page.screenshot({ path: join(out, `nogl2_${kind}.png`), timeout: 30000 }).catch(() => {});
      const fetched = [...files.values()].map((f) => ({ file: f.url.replace(/^.*\//, ""), mb: Math.round(f.got / 1e5) / 10, end: f.end || "still open" }));
      seen[`nogl2_${kind}`] = { told_ms: told, ...note, fetched };
      check(`${kind}, no WebGL 2: said plainly within ${Number.isFinite(told) ? (told / 1000).toFixed(1) : "–"} s`, Number.isFinite(told) && told < 30000,
        note.note.slice(0, 80));
      check(`… the engine's files let go (${fetched.map((f) => `${f.file} ${f.mb} MB ${f.end}`).join(", ") || "none asked"})`,
        fetched.every((f) => f.end !== "finished") || fetched.length === 0);
      check("… and no time to wait given", !note.eta);
      await context.close();
    }
  }

  if (wanted(4)) {
    console.log(`4. A first visit on a phone, and what is told elsewhere  [${at()}]`);
    for (const [kind, net] of [["phone", FAST4G], ["desktop", null], ["tablet", FAST4G]]) {
      const { context, page } = await fresh(kind, { net });
      const visits = [];
      for (const visit of kind === "phone" ? ["first", "return"] : ["first"]) {
        const tab = visit === "first" ? page : await context.newPage();
        const began = Date.now();
        await tab.goto(visit === "first" ? studio() : `${site}/app`, { waitUntil: "commit", timeout: 120000 });
        const told = [];
        let up = NaN;
        let gl2 = false;
        let shown = null;
        for (;;) {
          const now = await tab.evaluate(() => ({ eta: document.getElementById("eta") && !document.getElementById("eta").hidden
            ? document.getElementById("eta").textContent : "", left: window.brickworksEta?.left, on: window.brickworksEta?.on,
          up: Boolean(window.brickworksBoot?.ui), note: document.getElementById("note")?.textContent || "" })).catch(() => null);
          const ms = Date.now() - began;
          if (now) {
            if (now.eta) told.push({ ms, said: now.eta, left: Math.round(now.left) });
            if (now.eta && shown === null) shown = await inView(tab, "#eta").catch(() => false);
            if (now.note.startsWith(NO_GL2) || now.note.startsWith(NO_MEMORY)) gl2 = true;
            if (now.up) {
              up = ms;
              break;
            }
          }
          if (ms > 600000) break;
          await tab.waitForTimeout(500);
        }
        await tab.waitForTimeout(1000);
        const after = await tab.evaluate(() => !document.getElementById("eta").hidden).catch(() => null);
        const first = told[0];
        visits.push({ visit, up_ms: up, told: told.length, first: first ? { at_s: first.ms / 1000, said: first.said,
          foresaw_s: first.left + first.ms / 1000 } : null, last: told.at(-1) || null, shown_after: after, gl2_said: gl2, in_view: shown });
        if (visit === "first") await tab.screenshot({ path: join(out, `eta_${kind}.png`), timeout: 30000 }).catch(() => {});
      }
      seen[`eta_${kind}`] = visits;
      const [first, again] = visits;
      const up = (v) => (Number.isFinite(v.up_ms) ? `up in ${(v.up_ms / 1000).toFixed(1)} s` : "never up");
      if (kind === "phone") {
        check(`phone, first visit on Fast 4G: told how long (${up(first)})`, first.told > 0 && Number.isFinite(first.up_ms),
          first.first ? `at ${first.first.at_s.toFixed(1)} s "${first.first.said}"; it foresaw ${first.first.foresaw_s.toFixed(0)} s` : "never told");
        check("… in view while it loads", first.in_view === true);
        check("… and no longer once the studio is up", first.shown_after === false);
        check(`… a return to the same phone told nothing (${up(again)})`, again.told === 0 && Number.isFinite(again.up_ms));
      } else {
        check(`${kind}, first visit${net ? " on Fast 4G" : ""}: told nothing (${up(first)})`, first.told === 0 && Number.isFinite(first.up_ms));
      }
      check(`… and never that WebGL 2 is missing, or the memory refused`, visits.every((v) => !v.gl2_said));
      await context.close();
    }
  }
  if (wanted(5)) {
    console.log(`5. The engine's memory refused  [${at()}]`);
    for (const kind of ["phone", "desktop"]) {
      const { context, page } = await fresh(kind, { noMemory: true });
      const began = Date.now();
      await page.goto(studio(), { waitUntil: "commit", timeout: 120000 });
      const told = await page.waitForFunction((words) => (document.getElementById("note")?.textContent || "").startsWith(words), NO_MEMORY, { timeout: 120000 })
        .then(() => Date.now() - began, () => NaN);
      await page.waitForTimeout(2000);
      const note = await page.evaluate(() => ({ note: document.getElementById("note").textContent, eta: !document.getElementById("eta").hidden,
        up: Boolean(window.brickworksBoot?.ui) }));
      await page.screenshot({ path: join(out, `nomemory_${kind}.png`), timeout: 30000 }).catch(() => {});
      seen[`nomemory_${kind}`] = { told_ms: told, ...note };
      check(`${kind}, the memory refused: said plainly${Number.isFinite(told) ? ` in ${(told / 1000).toFixed(1)} s` : ""}, and still said 2 s on`,
        Number.isFinite(told) && !note.up && note.note.startsWith(NO_MEMORY), note.note.slice(0, 120));
      check("… and no time to wait given", !note.eta);
      await context.close();
    }
  }
} catch (trouble) {
  check(`the run went through (${String(trouble.message || trouble).split("\n")[0].slice(0, 200)})`, false);
} finally {
  await browser.close().catch(() => {});
}
writeFileSync(join(out, "warn.json"), `${JSON.stringify({ site, big: BIG, small: SMALL, seen, errors }, null, 1)}\n`);
if (errors.length) console.log(`  page errors: ${errors.slice(0, 3).join(" | ")}`);
console.log(`phonewarn: ${passed} passed, ${failed} failed  [${at()}]`);
process.exit(failed ? 1 : 0);
