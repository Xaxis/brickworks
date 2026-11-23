// The app's loading page (src/boot/shell.html; bootlook, bootlook2,
// 2026-11-23): our mark built of bricks in 3D as the app arrives, and the
// tips under it, pictured and checked.
//
//   set -a; . ./.env; set +a
//   ~/.claude/claude-core/bin/heavy node tools/web/bootlook_flow.mjs --dir=build/web --out=DIR \
//     [--base=OTHER/build/web] [--port=11651] [--only=pictures|checks]
//
// A build folder (tools/export.sh web, or an export with this checkout's
// page put in front of it: python3 tools/web/shell_arm.py BASE OUT) is
// served by tools/web/serve.py as the deployment sends it (--compressed
// --cached), on --port, and --base on the port after it.
//
// Pictures: at 1280 x 800 and a phone's 390 x 844 (3x, by touch), dark and
// light, early, mid and late in a load held to a slow network (--kbps,
// 2500), so the mark is caught being built: DIR/pictures/<size>-<scheme>-
// <when>.png, each the window as it was (never a full page). In each of
// those loads: nothing on the page moved (the layout shifts' sum is 0),
// and the tip changed every 5 s or so with its card where it was.
//
// Checks, each line PASS or FAIL:
//   - every tip in English, German, French and Spanish, on a computer and on
//     a phone: in its card's room, in that language, a new one each time,
//     heard by a screen reader once (aria-live), stepped through on the
//     page's own clock (page.clock) with the engine kept away;
//   - under the pointer a tip waits, and the next comes once it leaves;
//   - the next visit begins at the next tip (localStorage brickworks.tip);
//   - with reduced motion nothing animates, the mark stands finished, and
//     a tip changes without a fade;
//   - the site's kept theme (brickworks.theme) wins over the system's;
//   - the page goes on to start the app (#boot done) with the mark
//     complete, and then nothing on it moves; its tab opened by link in
//     another tab says where it is, its tip put away and its mark stopped;
//     with --base, it asked for nothing
//     the base's page did not;
//   - in a browser without WebGL 2, the trouble said, the tip put away and
//     the mark stopped, nothing moved; the tips also fit a 320-wide phone.
// Exit 1 on any FAIL.
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { launch, START_MS } from "./browser.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.dir || !args.out) {
  console.error("bootlook_flow: --dir=<build folder> and --out=DIR are required");
  process.exit(2);
}
const out = resolve(String(args.out));
mkdirSync(join(out, "pictures"), { recursive: true });
const port = Number(args.port || 11651);
const kbps = Number(args.kbps || 2500);
const only = args.only ? String(args.only) : "";

let failed = 0;
const lines = [];
function check(ok, what) {
  const line = `${ok ? "PASS" : "FAIL"} ${what}`;
  if (!ok) failed++;
  lines.push(line);
  console.log(line);
}

// One build folder, served until the run ends.
const servers = [];
async function serve(dir, at) {
  const child = spawn("python3", [join(ROOT, "tools/web/serve.py"), resolve(String(dir)), String(at), "--compressed", "--cached"],
    { stdio: ["ignore", "ignore", "inherit"] });
  servers.push(child);
  const until = Date.now() + 20000;
  while (Date.now() < until) {
    try {
      const reply = await fetch(`http://127.0.0.1:${at}/index.html`);
      // Read to its end: an answer left unread, then closed by serve.py,
      // threw inside node's fetch and ended the run (bootlook's flow1).
      await reply.arrayBuffer();
      if (reply.ok) return `http://127.0.0.1:${at}/index.html`;
    } catch {}
    await new Promise((done) => setTimeout(done, 200));
  }
  throw new Error(`serve.py did not answer on ${at}`);
}

const DESKTOP = { label: "1280", viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 };
const PHONE = { label: "390", viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true };
// The smallest phone still sold (an iPhone SE's 320 x 568), for the tips' room.
const SMALL = { label: "320", viewport: { width: 320, height: 568 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };

// What the page did, watched from before its first script: each layout
// shift, each tip as it came (with where its card and the mark were), and
// every address it asked for.
function watchPage() {
  window.__look = { shifts: [], tips: [] };
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        if (e.hadRecentInput) continue;
        window.__look.shifts.push({ at: Math.round(e.startTime), value: e.value,
          from: (e.sources || []).map((s) => (s.node && (s.node.id || s.node.className || s.node.nodeName)) || "?") });
      }
    }).observe({ type: "layout-shift", buffered: true });
  } catch {}
  document.addEventListener("DOMContentLoaded", () => {
    const line = document.getElementById("tip-text");
    if (!line) return;
    const where = (id) => {
      const r = document.getElementById(id)?.getBoundingClientRect();
      return r ? [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)].join(",") : "";
    };
    const note = () => window.__look.tips.push({ at: Math.round(performance.now()), text: line.textContent,
      tip: where("tip"), wall: where("wall"), status: where("laid") });
    note();
    new MutationObserver(note).observe(line, { childList: true });
  });
}

async function newPage(browser, device, { scheme = "dark", motion = "no-preference", init = null } = {}) {
  const context = await browser.newContext({ ...device, colorScheme: scheme, reducedMotion: motion });
  await context.addInitScript(watchPage);
  if (init) await context.addInitScript(init.fn, init.arg);
  const page = await context.newPage();
  const asked = [];
  // Its own addresses; a blob: or data: one is made afresh by each page.
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.protocol === "http:" || url.protocol === "https:") asked.push(url.pathname);
  });
  page.on("pageerror", (error) => console.log(`  page error: ${String(error.message || error).split("\n")[0]}`));
  return { context, page, asked };
}

const read = (page) => page.evaluate(() => ({
  laid: Number(document.getElementById("laid")?.textContent || 0),
  total: Number(document.getElementById("total")?.textContent || 0),
  note: document.getElementById("note")?.textContent || "",
  done: document.getElementById("boot")?.classList.contains("done") || false,
  look: window.__look,
}));

// -- pictures, each load held to a slow network -------------------------
async function pictures(browser, url) {
  for (const device of [DESKTOP, PHONE]) {
    for (const scheme of ["dark", "light"]) {
      const { context, page } = await newPage(browser, device, { scheme });
      const cdp = await context.newCDPSession(page);
      await cdp.send("Network.enable");
      await cdp.send("Network.emulateNetworkConditions",
        { offline: false, latency: 40, downloadThroughput: (kbps * 1024) / 8, uploadThroughput: (1024 * 1024) / 8 });
      const name = `${device.label}-${scheme}`;
      try {
        await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
        await page.waitForSelector("#bricks .brick", { state: "attached", timeout: 30000 });
        const stages = [["early", (s) => s.laid >= Math.ceil(s.total * 0.2)], ["mid", (s) => s.laid >= Math.ceil(s.total * 0.5)],
          ["late", (s) => s.laid >= Math.floor(s.total * 0.86)]];
        let last = null;
        let during = null;
        for (const [when, reached] of stages) {
          const until = Date.now() + 240000;
          let now = await read(page);
          while (!reached(now) && !now.done && Date.now() < until) {
            await page.waitForTimeout(250);
            now = await read(page);
          }
          // The bricks just laid half way in: a flight takes 0.76 s.
          await page.waitForTimeout(380);
          now = await read(page);
          if (now.done) break;
          await page.screenshot({ path: join(out, "pictures", `${name}-${when}.png`) });
          console.log(`  ${name}-${when}: ${now.laid} of ${now.total} bricks, "${now.note}"`);
          last = now;
          // The tips while the files come: once they are here the engine
          // compiles on the page's thread, and no timer runs until it is done.
          if (when === "mid") during = now.look;
        }
        if (!last) {
          check(false, `${name}: the mark was never caught being built (the page was up first)`);
          continue;
        }
        const { look } = last;
        const moved = look.shifts.reduce((sum, s) => sum + s.value, 0);
        check(moved === 0, `${name}: nothing on the page moved while it loaded (layout shifts ${moved.toFixed(4)}`
          + `${look.shifts.length ? `, from ${[...new Set(look.shifts.flatMap((s) => s.from))].join(", ")}` : ""})`);
        const timed = (during || look).tips;
        const gaps = timed.slice(1).map((tip, i) => tip.at - timed[i].at).slice(1);
        const still = look.tips.every((tip) => tip.tip === look.tips[0].tip && tip.wall === look.tips[0].wall);
        check(gaps.length >= 1 && gaps.every((gap) => gap > 4500 && gap < 6500) && still,
          `${name}: ${look.tips.length} tips, one every ${gaps.map((gap) => (gap / 1000).toFixed(1)).join(", ")} s while the files came, the card and the mark where they were`);
      } catch (trouble) {
        check(false, `${name}: ${String(trouble.message || trouble).split("\n")[0]}`);
      } finally {
        await context.close();
      }
    }
  }
}

// -- the tips, on the page's own clock ---------------------------------
const LABEL = { en: "Tip", de: "Tipp", fr: "Astuce", es: "Consejo" };
async function tips(browser, url) {
  const english = {};
  for (const code of ["en", "de", "fr", "es"]) {
    for (const device of [DESKTOP, PHONE, SMALL]) {
      const name = `${code} ${device.label}`;
      // A fresh browser: a first visit, so its first tip is the first.
      const { context, page } = await newPage(browser, device);
      // The engine kept away (its script never answered), so the page stays.
      await context.route(/\/index\.js$/, () => {});
      try {
        await page.clock.install();
        await page.goto(`${url}${code === "en" ? "" : `?lang=${code}`}`, { waitUntil: "domcontentloaded", timeout: 60000 });
        await page.waitForSelector("#tip-text", { timeout: 30000 });
        const count = await page.evaluate(() => window.brickworksTips.count);
        const seen = [];
        for (let i = 0; i <= count; i++) {
          seen.push(await page.evaluate(() => {
            const line = document.getElementById("tip-text");
            const box = document.getElementById("tip").getBoundingClientRect();
            return { text: line.textContent, live: line.getAttribute("aria-live"), over: line.scrollHeight - line.clientHeight,
              keys: line.querySelectorAll("kbd").length, raw: /\{\{|\}\}/.test(line.textContent),
              box: [box.x, box.y, box.width, box.height].map(Math.round).join(","),
              label: document.getElementById("tip-label").textContent };
          }));
          await page.clock.runFor(5000 + 240 + 20);
        }
        const tipsSeen = seen.slice(0, count);
        if (code === "en") english[device.label] = tipsSeen.map((tip) => tip.text);
        check(seen[0].label === LABEL[code], `${name}: the label says "${seen[0].label}"`);
        check(new Set(tipsSeen.map((tip) => tip.text)).size === count && count >= (device.hasTouch ? 12 : 24),
          `${name}: ${count} tips, each a new one`);
        const over = tipsSeen.filter((tip) => tip.over > 1);
        check(!over.length, `${name}: every tip fits its card${over.length ? `; not: ${over.map((tip) => `"${tip.text}" (${tip.over} px)`).join("; ")}` : ""}`);
        check(seen.every((tip) => tip.box === seen[0].box), `${name}: the card never moved or grew (${[...new Set(seen.map((tip) => tip.box))].join(" / ")})`);
        check(!seen.some((tip) => tip.raw), `${name}: every key drawn as a key, none left as {{…}}`);
        const heard = seen.map((tip) => tip.live);
        check(heard[0] === "off" && heard.slice(1, count).every((live) => live === "polite") && heard[count] === "off",
          `${name}: a screen reader hears each tip once (aria-live ${heard[0]}, then ${[...new Set(heard.slice(1, count))].join("/")}, come round again ${heard[count]})`);
        check(seen[count].text === seen[0].text, `${name}: after the last, the first again`);
        if (code !== "en" && english[device.label]) {
          const same = tipsSeen.filter((tip, i) => tip.text === english[device.label][i]);
          check(!same.length, `${name}: every tip in the language${same.length ? `; in English: ${same.map((tip) => `"${tip.text}"`).join("; ")}` : ""}`);
        }
        if (code === "en" && device === DESKTOP) {
          check(/^Press F1 for every key/.test(seen[0].text) && seen[0].keys === 1, `${name}: a first visit's first tip is the keys sheet's, "${seen[0].text}"`);
          // Under the pointer it waits; away, the next comes.
          const before = await page.evaluate(() => document.getElementById("tip-text").textContent);
          await page.hover("#tip");
          await page.clock.runFor(15000);
          const held = await page.evaluate(() => document.getElementById("tip-text").textContent);
          await page.mouse.move(4, 4);
          await page.clock.runFor(5300);
          const after = await page.evaluate(() => document.getElementById("tip-text").textContent);
          check(held === before && after !== held, `under the pointer the tip waited 15 s ("${held.slice(0, 40)}…"), and changed once it left`);
          // The next visit, in the same browser, begins where this one stopped.
          const shown = await page.evaluate(() => window.brickworksTips.at);
          const again = await context.newPage();
          await again.clock.install();
          await again.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
          const first = await again.evaluate(() => window.brickworksTips.at);
          check(first === (shown + 1) % count, `the next visit begins at the next tip (${shown} shown last, ${first} first)`);
        }
      } catch (trouble) {
        check(false, `${name}: ${String(trouble.message || trouble).split("\n")[0]}`);
      } finally {
        await context.close();
      }
    }
  }
}

// -- a browser the app cannot start in ----------------------------------
async function cannot(browser, url) {
  const { context, page } = await newPage(browser, DESKTOP);
  await context.addInitScript(() => {
    const made = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
      return kind === "webgl2" ? null : made.call(this, kind, ...rest);
    };
  });
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
    await page.waitForFunction(() => /no WebGL 2/.test(document.getElementById("note")?.textContent || ""), null, { timeout: 30000 });
    await page.waitForTimeout(6000);
    const seen = await page.evaluate(() => ({ note: document.getElementById("note").textContent,
      bad: document.getElementById("note").classList.contains("bad"),
      tip: getComputedStyle(document.getElementById("tip")).visibility, on: window.brickworksTips.on,
      turn: getComputedStyle(document.querySelector("#wall .scene")).animationPlayState,
      shifts: window.__look.shifts.reduce((sum, s) => sum + s.value, 0) }));
    check(seen.bad && seen.tip === "hidden" && !seen.on && seen.turn === "paused" && seen.shifts === 0,
      `no WebGL 2: "${seen.note.slice(0, 50)}…" said as trouble, the tip put away (${seen.tip}), the mark stopped (${seen.turn}), nothing moved (${seen.shifts.toFixed(4)})`);
  } catch (trouble) {
    check(false, `no WebGL 2: ${String(trouble.message || trouble).split("\n")[0]}`);
  } finally {
    await context.close();
  }
}

// -- motion, the theme kept, and the start --------------------------------
async function manners(browser, url, base) {
  for (const motion of ["no-preference", "reduce"]) {
    const { context, page } = await newPage(browser, DESKTOP, { motion });
    await context.route(/\/index\.js$/, () => {});
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
      await page.waitForSelector("#bricks .brick", { state: "attached" });
      await page.waitForTimeout(1500);
      const said = await page.evaluate(() => ({
        running: document.getAnimations().filter((a) => a.playState === "running").map((a) => a.animationName || "?"),
        fade: getComputedStyle(document.getElementById("tip-text")).transitionDuration,
        shown: [...document.querySelectorAll("#bricks .brick")].filter((one) => getComputedStyle(one).visibility === "visible").length,
        bricks: document.querySelectorAll("#bricks .brick").length,
      }));
      if (motion === "reduce") {
        check(!said.running.length && /^0s(, 0s)*$/.test(said.fade) && said.bricks > 0 && said.shown === said.bricks,
          `reduced motion: nothing animates (${said.running.join(", ") || "none"}), the mark stands finished (${said.shown} of ${said.bricks} bricks shown), a tip changes without a fade (${said.fade})`);
      } else {
        check(said.running.includes("turn"), `the mark turns (${said.running.join(", ")})`);
      }
    } catch (trouble) {
      check(false, `motion ${motion}: ${String(trouble.message || trouble).split("\n")[0]}`);
    } finally {
      await context.close();
    }
  }
  for (const [scheme, kept, want] of [["dark", null, "rgb(11, 12, 14)"], ["light", null, "rgb(251, 251, 250)"],
    ["dark", "light", "rgb(251, 251, 250)"], ["light", "dark", "rgb(11, 12, 14)"], ["dark", "system", "rgb(11, 12, 14)"]]) {
    const init = kept ? { fn: (theme) => localStorage.setItem("brickworks.theme", theme), arg: kept } : null;
    const { context, page } = await newPage(browser, DESKTOP, { scheme, init });
    await context.route(/\/index\.js$/, () => {});
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
      const ground = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      check(ground === want, `a ${scheme} system${kept ? `, the site's ${kept} kept` : ""}: the page's ground ${ground}`);
    } catch (trouble) {
      check(false, `theme ${scheme}/${kept}: ${String(trouble.message || trouble).split("\n")[0]}`);
    } finally {
      await context.close();
    }
  }
  // The start, unthrottled: the app comes up behind it, then nothing moves.
  const loads = {};
  for (const [arm, at] of [["mine", url], ...(base ? [["base", base]] : [])]) {
    const { context, page, asked } = await newPage(browser, DESKTOP);
    try {
      const began = Date.now();
      await page.goto(at, { waitUntil: "domcontentloaded", timeout: 60000 });
      await page.waitForSelector("#boot.done", { state: "attached", timeout: START_MS });
      const took = Date.now() - began;
      await page.waitForTimeout(1500);
      const after = await page.evaluate(() => ({
        running: document.getAnimations().filter((a) => a.playState === "running").length,
        still: Boolean(document.querySelector(".stage.still")),
        laid: document.querySelectorAll("#bricks .brick.laid").length,
        bricks: document.querySelectorAll("#bricks .brick").length,
      }));
      const { look } = await read(page);
      loads[arm] = new Set(asked);
      if (arm === "mine") {
        check(after.running === 0 && after.still && after.bricks > 0 && after.laid === after.bricks,
          `the app came up behind it in ${(took / 1000).toFixed(1)} s, the mark complete (${after.laid} of ${after.bricks} bricks), then nothing on the page moved (${after.running} animations)`);
        const moved = (look?.shifts || []).reduce((sum, s) => sum + s.value, 0);
        check(moved === 0, `nothing on the page moved before the app was up (layout shifts ${moved.toFixed(4)})`);
        // Its tab asked for by link in another tab of this browser: that page
        // starts nothing and says where the model is, its tip put away.
        const id = await page.evaluate(() => window.brickworksTab || "");
        const linked = await context.newPage();
        await linked.goto(`${at}?tab=${id}`, { waitUntil: "domcontentloaded", timeout: 60000 });
        await linked.waitForFunction(() => window.brickworksElsewhere, null, { timeout: 60000 }).catch(() => {});
        const there = await linked.evaluate(() => ({ elsewhere: window.brickworksElsewhere || "",
          note: document.getElementById("note").textContent, tip: getComputedStyle(document.getElementById("tip")).visibility,
          on: window.brickworksTips.on, held: document.getElementById("wall").classList.contains("held") }));
        check(Boolean(id) && there.elsewhere === id && /another Brickworks tab/.test(there.note) && there.tip === "hidden" && !there.on && there.held,
          `its tab opened by link in another tab: "${there.note.slice(0, 60)}…", the tip put away (${there.tip}), the mark stopped`);
        await linked.close();
      } else {
        console.log(`  base: up in ${(took / 1000).toFixed(1)} s`);
      }
    } catch (trouble) {
      check(false, `${arm} start: ${String(trouble.message || trouble).split("\n")[0]}`);
    } finally {
      await context.close();
    }
  }
  if (loads.mine && loads.base) {
    const added = [...loads.mine].filter((path) => !loads.base.has(path));
    check(!added.length, `the page asked for nothing the base's did not (${loads.mine.size} addresses, base ${loads.base.size}${added.length ? `; new: ${added.join(", ")}` : ""})`);
  }
}

const browser = await launch({ signedOut: true });
try {
  const url = await serve(args.dir, port);
  const base = args.base ? await serve(args.base, port + 1) : "";
  if (only !== "checks") await pictures(browser, url);
  if (only !== "pictures") {
    await tips(browser, url);
    await manners(browser, url, base);
    await cannot(browser, url);
  }
} finally {
  await browser.close().catch(() => {});
  for (const child of servers) child.kill();
}
writeFileSync(join(out, "results.txt"), lines.join("\n") + "\n");
console.log(`bootlook: ${lines.length - failed} of ${lines.length} passed (${join(out, "results.txt")})`);
process.exit(failed ? 1 : 0);
