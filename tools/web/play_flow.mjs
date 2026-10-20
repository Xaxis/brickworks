// Play in a shared model's view, in a real browser: a set's steering turned
// by its steering wheel, by the mouse on a laptop's window and by a finger
// on a phone, and put back with Reset.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8771 --parts assets/generated/parts --delay 0 \
//       --share Pl4yFl0w01=vendor/omr/files/8808-1.mpd &
//   node tools/web/play_flow.mjs --url=http://127.0.0.1:8771 --out=shots/play_web
//   set -a; . ./.env; set +a
//   BW_BYPASS=… node tools/web/play_flow.mjs --url=<preview> --publish --out=DIR
//
// The model is 8808-1 (vendor/omr/files, 93 parts): a racer whose steering
// wheel turns a pinion in its track rod's rack, the front wheels on their
// arms. Locally serve.py --share plays its link; --publish publishes it to
// that deployment from a throwaway probe account (a Resend test address, so
// a test model, which only a list asked with tests shows), saying what
// moves as the app would, and takes it down and deletes the account at the
// end. On a deployment only the API's routes are used, with the bypass.
//
// In Chromium on SwiftShader, at each size (a laptop's window, 1280 x 800,
// by the mouse; a phone, 390 x 844 at three device pixels to the point,
// touch, by a finger):
//
//   1. /m/<id> goes on to the viewer; once its joints are read it says what
//      moves and how ("Moves: steering", "Drag a part that moves"; on the
//      phone, "Touch a part that moves and drag it"), inside the page.
//   2. The steering wheel taken where the app says it shows (its handle,
//      window.brickworksGrab, which the page asks for with
//      window.brickworksGrabAsk) and turned round its column in small steps:
//      the steering turns 10 degrees or more, the view does not.
//   3. Let go: Reset is offered, and the link's model is as it was (asked
//      for again: the same text).
//   4. Reset tapped: the steering is back where it was built, Reset gone.
//
// The app's own work in each drag frame (GrabDrag: following the pointer,
// drawing, weighing) is held under --work ms (33); the page's frame gaps
// during the drag, which are mostly SwiftShader drawing, are said beside it.
// On the phone the CPU is slowed --slow times (4, as a mid-range phone's,
// CDP Emulation.setCPUThrottlingRate) for the drag.
// With --publish the gallery is asked too: its list, asked with tests and
// Technic or mechanism, finds the model with "steering" on its card, once
// supabase/play.sql is applied there (before, that is said and not judged).
//
// Then the gallery's page itself (web/gallery.html and gallery.js from this
// checkout, the list's answer played in the browser): a card says what
// moves ("Moves: steering"; "Moves: doors"), one with nothing says nothing,
// and ticking Technic or mechanism asks the list with technic=1.
//
// Pictures in --out: <size>_1_ready.png, _2_turned.png, _3_let_go.png,
// _4_reset.png, <size>_5_gallery.png.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession } from "./session.mjs";
import { createHash, randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:8771").replace(/\/$/, "");
const out = String(args.out || "shots/play_web");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const workLimit = Number(args.work || 33);
const slow = Number(args.slow || 4);
const SIZES = {
  laptop: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 },
  phone: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
};
const wanted = String(args.sizes || "laptop,phone").split(",");
mkdirSync(out, { recursive: true });
const headers = bypass ? { "x-vercel-protection-bypass": bypass } : {};

let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);
const errors = [];
const sha = (text) => createHash("sha256").update(String(text)).digest("hex");

async function until(page, test, what, seconds = 300, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}
const share = (page) => page.evaluate(() => window.brickworksShare || {});
const play = async (page) => ((await share(page)).view || {}).play || {};
const grab = (page) => page.evaluate(() => window.brickworksGrab || {});
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const yaw = async (page) => Number(((await page.evaluate(() => window.brickworksState || {})).view || {}).yaw || 0);
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 180000 })
  .then(() => console.log(`        picture: ${path.join(out, name)}`))
  .catch((trouble) => say(`no picture ${name}: ${String(trouble).split("\n")[0]}`));

// The page's frames, timed by requestAnimationFrame from now until read.
async function startGaps(page) {
  await page.evaluate(() => {
    window.__gaps = [];
    window.__gapsOn = true;
    let last = performance.now();
    const tick = (now) => {
      window.__gaps.push(now - last);
      last = now;
      if (window.__gapsOn) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}
async function readGaps(page) {
  return page.evaluate(() => {
    window.__gapsOn = false;
    const gaps = window.__gaps.slice(1);
    const total = gaps.reduce((a, b) => a + b, 0);
    gaps.sort((a, b) => a - b);
    return { frames: gaps.length, mean: Math.round(total / Math.max(gaps.length, 1)),
      median: Math.round(gaps[Math.floor(gaps.length / 2)] || 0), worst: Math.round(gaps[gaps.length - 1] || 0) };
  });
}

// Points round the handle's joint line on the page, from the handle, by
// [degrees] in [steps]: a turn of the wheel as a hand draws it.
function arc(handle, degrees, steps) {
  const cx = Number(handle.pivot_x ?? handle.x);
  const cy = Number(handle.pivot_y ?? handle.y);
  let dx = handle.x - cx;
  let dy = handle.y - cy;
  // A handle on the line itself: round a point a little beside it.
  if (Math.hypot(dx, dy) < 12) { dx = 0; dy = -30; }
  // Round from where it was taken, at its own distance from the line: a
  // first move out from the line reads as a slide along it (an axle in a
  // round hole does both). A small wheel, a phone's few points across, is
  // turned further for the same sweep of the hand.
  const reach = Math.hypot(dx, dy);
  if (reach < 30) degrees *= Math.min(30 / reach, 2.4);
  const points = [];
  for (let n = 1; n <= steps; n += 1) {
    const a = (degrees * Math.PI / 180) * n / steps;
    points.push({ x: cx + dx * Math.cos(a) - dy * Math.sin(a), y: cy + dx * Math.sin(a) + dy * Math.cos(a) });
  }
  return points;
}

// The gallery's page from this checkout, its list played: what a card says
// of what moves, at [size].
const WEB = path.join(root, "web");
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml",
  ".png": "image/png", ".json": "application/json", ".webmanifest": "application/manifest+json" };
async function galleryCards(size, shape) {
  const context = await browser.newContext({ ...shape });
  const page = await context.newPage();
  const asked = [];
  const card = (id, name, moves, technic = false) => ({ id, name, author: "Play Flow", parts: 93, views: 3,
    likes: 1, remixes: 0, builds: 2, technic, tested: false, moves, url: `/m/${id}`, image: null, thumb: null });
  const models = [card("Pl4yCard01", "Play racer", ["steering"]), card("Pl4yCard02", "Play house", ["doors"]),
    card("Pl4yCard03", "Play hut", [])];
  await context.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.origin !== new URL(site).origin) return route.abort();
    if (url.pathname === "/api/share") {
      const op = url.searchParams.get("op");
      asked.push(url.search);
      if (op === "list") {
        const technic = url.searchParams.get("technic") === "1";
        const shown = technic ? models.filter((m) => m.technic || m.moves.some((w) => w !== "doors")) : models;
        return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({
          models: shown, more: false, page: 1, kinds: [], sizes: [], sorts: [{ id: "newest", label: "Newest" }] }) });
      }
      if (op === "shelves") {
        return route.fulfill({ status: 200, contentType: "application/json",
          body: JSON.stringify({ pick: null, small: { models: [], more: false } }) });
      }
    }
    if (url.pathname.startsWith("/api/")) {
      return route.fulfill({ status: 404, contentType: "application/json", body: "{}" });
    }
    const file = path.join(WEB, url.pathname === "/gallery" ? "gallery.html" : url.pathname.slice(1));
    if (!file.startsWith(WEB) || !existsSync(file)) return route.fulfill({ status: 404, body: "" });
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || "application/octet-stream",
      body: readFileSync(file) });
  });
  await page.goto(`${site}/gallery`, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForSelector('a.model[data-id="Pl4yCard03"]', { timeout: 30000 });
  const said = await page.evaluate(() => Object.fromEntries([...document.querySelectorAll("a.model")].map((a) =>
    [a.dataset.id, (a.querySelector("small.moves") || {}).textContent || ""])));
  check(`${size}: the racer's card says "${said.Pl4yCard01}", the house's "${said.Pl4yCard02}", the hut's nothing`,
    said.Pl4yCard01 === "Moves: steering" && said.Pl4yCard02 === "Moves: doors" && said.Pl4yCard03 === "");
  const box = await page.evaluate(() => {
    const line = document.querySelector('a.model[data-id="Pl4yCard01"] small.moves');
    const r = line ? line.getBoundingClientRect() : null;
    return r ? { x: r.x, y: r.y, w: r.width, h: r.height, page: document.documentElement.clientWidth } : null;
  });
  check(`${size}: it shows inside the page (${box ? `${Math.round(box.x)}, ${Math.round(box.y)}, ${Math.round(box.w)} wide` : "not shown"})`,
    Boolean(box) && box.w > 0 && box.x >= 0 && box.x + box.w <= box.page + 1);
  await page.evaluate(() => document.querySelector('a.model[data-id="Pl4yCard01"]').scrollIntoView({ block: "center" }));
  await page.waitForTimeout(400);
  await shot(page, `${size}_5_gallery.png`);
  // Technic or mechanism, ticked as a person ticks it.
  await page.evaluate(() => { const d = document.querySelector("details.filters, .filters details"); if (d) d.open = true; });
  await page.locator("#technic").check({ force: true });
  await page.waitForTimeout(1500);
  const technicAsked = asked.some((q) => /op=list/.test(q) && /technic=1/.test(q));
  const shown = await page.evaluate(() => [...document.querySelectorAll("a.model")].map((a) => a.dataset.id));
  check(`${size}: Technic or mechanism asks the list with technic=1, and shows ${shown.join(", ")}`,
    technicAsked && shown.includes("Pl4yCard01") && !shown.includes("Pl4yCard02"));
  await context.close();
}

// --- the link ----------------------------------------------------------------

const MODEL = path.join(root, "vendor/omr/files/8808-1.mpd");
let id = String(args.id || "Pl4yFl0w01");
let probe = "";
let token = "";
let published = null;
if (args.publish) {
  probe = `delivered+bw-play-${randomBytes(4).toString("hex")}@resend.dev`;
  token = (await mintSession(probe)).access_token;
  const reply = await fetch(`${site}/api/share`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
    // What the app sends for this set (src/dev/share_play_probe.gd, 7).
    body: JSON.stringify({ name: `Play flow racer ${randomBytes(3).toString("hex")}`,
      model: readFileSync(MODEL, "utf8"), listed: true, moves: ["steering"] }),
  });
  published = await reply.json().catch(() => ({}));
  if (!published.id) throw new Error(`publishing 8808-1: ${reply.status} ${published.error || ""}`);
  id = published.id;
  console.log(`published 8808-1 as ${id} (${published.parts} parts), moves kept: ${JSON.stringify(published.moves)}`);
}
const fetched = async () => {
  const reply = await fetch(`${site}/api/share?id=${id}`, { headers });
  const body = await reply.json().catch(() => ({}));
  return sha(body.model || "");
};
const served = await fetched();

const browser = await launch({ signedOut: true });
try {
  for (const size of wanted) {
    const shape = SIZES[size];
    if (!shape) throw new Error(`no size ${size}`);
    const finger = Boolean(shape.hasTouch);
    const { width, height } = shape.viewport;
    console.log(`\n${size}, ${width} x ${height} at ${shape.deviceScaleFactor}x, ${finger ? "a finger" : "the mouse"}`);
    const context = await browser.newContext({ ...shape, extraHTTPHeaders: headers });
    const page = await context.newPage();
    await page.addInitScript(() => { window.brickworksGrabAsk = true; });
    page.on("pageerror", (e) => errors.push(`${size}: ${String(e).slice(0, 200)}`));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(`${size}: ${m.text().slice(0, 300)}`);
    });
    const cdp = finger ? await context.newCDPSession(page) : null;
    const touch = async (type, at) => cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: at ? [{ x: at.x, y: at.y, id: 1, radiusX: 4, radiusY: 4, force: 1 }] : [] });

    // 1. The link, as somebody follows it.
    await page.goto(`${site}/m/${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
    // On a deployment the link is the model's own page, whose button opens
    // it in the app (the local relay goes straight on); m87's preview waited
    // 600 s on the page for an app that was never opened.
    const cta = await page.$('.actions a.cta[href^="/app?view="]').catch(() => null);
    if (cta) {
      await Promise.all([page.waitForURL(/\/app\?view=/, { timeout: 180000 }), finger ? cta.tap() : cta.click()]);
    }
    await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the shared model opened", 600);
    const ready = await until(page, () => {
      const p = ((window.brickworksShare || {}).view || {}).play || {};
      return p.ready && p.shown ? p : null;
    }, "what moves said", Number(args.ready || 300));
    check(`the viewer says what moves: "${ready.title}" / "${ready.says}"`,
      String(ready.title).startsWith("Moves: ") && (ready.moves || []).includes("steering"));
    check(`and how, ${finger ? "with a finger" : "with the mouse"}: "${ready.says}"`,
      finger ? /^Touch a part that moves/.test(ready.says) : /^Drag a part that moves/.test(ready.says));
    const read = await grab(page);
    say(`its joints read in ${read.ready_ms} ms ${read.ready_off_thread ? "on a worker" : "on the page's thread"}: ${read.bodies}`);
    // Placed on the page once it has stood still for two of its tellings.
    const pill = await until(page, () => (window.brickworksControls || {}).view_play || null,
      "the pill on the page", 30).catch(() => null);
    check(`the words are inside the page (${pill ? `${pill.x}, ${pill.y}` : "not found"})`,
      Boolean(pill) && pill.x >= 0 && pill.x <= width && pill.y >= 0 && pill.y <= height);
    await page.waitForTimeout(1500);
    await shot(page, `${size}_1_ready.png`);

    // 2. The steering wheel, where the app says it shows.
    const handle = (await until(page, () => {
      const g = window.brickworksGrab || {};
      return (g.handles || []).find((h) => h.play === "steering") || null;
    }, "the steering wheel's handle", 120));
    say(`the steering wheel's handle at ${handle.x}, ${handle.y}, its column at ${handle.pivot_x}, ${handle.pivot_y} (#${handle.id} ${handle.part})`);
    const yawBefore = await yaw(page);
    const points = arc(handle, finger ? -50 : 50, 12);
    await startGaps(page);
    let most = 0;
    if (finger && slow > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: slow });
    if (finger) {
      await touch("touchStart", handle);
      await page.waitForTimeout(120);
      for (const at of points) {
        await touch("touchMove", at);
        await page.waitForTimeout(90);
        most = Math.max(most, Math.abs(Number((await grab(page)).angle) || 0));
      }
    } else {
      await page.mouse.move(handle.x, handle.y, { steps: 2 });
      await page.waitForTimeout(300);
      await page.mouse.down();
      for (const at of points) {
        await page.mouse.move(at.x, at.y);
        await page.waitForTimeout(90);
        most = Math.max(most, Math.abs(Number((await grab(page)).angle) || 0));
      }
    }
    await page.waitForTimeout(800);
    const mid = await grab(page);
    const midPlay = await play(page);
    if (finger) {
      const taken = (await share(page)).finger;
      check(`the finger was taken as the steering's, not the view's: "${taken}"`, taken === "part");
    }
    most = Math.max(most, Math.abs(Number(mid.angle) || 0));
    check(`the steering turned ${most.toFixed(1)}° on its column: ${mid.what || mid.said}`,
      mid.grabbing === true && most >= 10);
    check(`the pill says what is turning: "${midPlay.says}"`, Boolean(midPlay.says) && midPlay.says !== ready.says);
    check(`the view did not turn with it (yaw ${yawBefore.toFixed(2)} → ${(await yaw(page)).toFixed(2)})`,
      Math.abs((await yaw(page)) - yawBefore) < 0.01);
    await shot(page, `${size}_2_turned.png`);
    if (finger) await touch("touchEnd", null);
    else await page.mouse.up();
    const gaps = await readGaps(page);
    if (finger && slow > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
    const after = await until(page, () => {
      const g = window.brickworksGrab || {};
      return !g.grabbing && !g.swinging ? g : null;
    }, "let go", 60);
    say(`drag frames${finger && slow > 1 ? `, the CPU slowed ${slow} times` : ""}: the app's own work ${after.mean_ms} ms a frame on average, ${after.worst_ms} ms at worst, `
      + `over ${after.frames}; the page's frames ${gaps.median} ms median, ${gaps.mean} mean, ${gaps.worst} worst `
      + `(${gaps.frames} frames); its worst following ${after.worst_follow_ms} ms (${after.worst_follow_said}), `
      + `weighing ${after.worst_weigh_ms} ms; checking its way while the finger rested ${after.worst_pause_ms} ms `
      + `at worst, and let go ${after.worst_settle_ms} ms (said, not judged)`);
    check(`the app's own work in a drag frame stays under ${workLimit} ms (${after.worst_ms} ms worst)`,
      Number(after.frames) > 0 && Number(after.worst_ms) < workLimit);

    // 3. Let go: kept for this visit, nothing written.
    const kept = await until(page, () => {
      const p = ((window.brickworksShare || {}).view || {}).play || {};
      return p.played && p.reset ? p : null;
    }, "Reset offered", 60).catch(() => null);
    check(`let go, Reset is offered (${kept ? kept.says : "not offered"})`, Boolean(kept));
    check("the store writes nothing", (await share(page)).read_only === true);
    await page.waitForTimeout(800);
    await shot(page, `${size}_3_let_go.png`);
    check("the link's model is as it was (asked for again: the same text)", (await fetched()) === served);

    // 4. Reset.
    const reset = await until(page, () => (window.brickworksControls || {}).view_reset || null,
      "Reset on the page", 30).catch(() => null);
    check(`Reset is inside the page (${reset ? `${reset.x}, ${reset.y}` : "not found"})`,
      Boolean(reset) && reset.x >= 0 && reset.x <= width && reset.y >= 0 && reset.y <= height);
    // The pill at its widest, Reset in it, clear of the view cube.
    const placed = await controls(page);
    const wide = placed.view_play;
    const cube = Object.entries(placed).filter(([name]) => name.startsWith("cube_")).map(([, at]) => at.x);
    const pillRight = wide ? wide.x + wide.w / 2 : Infinity;
    check(`the pill (to ${Math.round(pillRight)}) is clear of the view cube (from ${cube.length ? Math.min(...cube) : "?"})`,
      Boolean(wide) && cube.length > 0 && pillRight < Math.min(...cube) - 20);
    if (reset) {
      if (finger) await page.touchscreen.tap(reset.x, reset.y);
      else await page.mouse.click(reset.x, reset.y);
    }
    const back = await until(page, () => {
      const p = ((window.brickworksShare || {}).view || {}).play || {};
      return !p.played && !p.reset ? p : null;
    }, "put back", 60).catch(() => null);
    check(`Reset puts it back as it was built: "${back ? back.says : "not put back"}"`, Boolean(back));
    await page.waitForTimeout(800);
    await shot(page, `${size}_4_reset.png`);
    await context.close();
  }

  // The gallery's page, its list played.
  for (const size of wanted) await galleryCards(size, SIZES[size]);
  // The gallery, on a deployment: its card says what moves, and Technic or
  // mechanism finds it.
  if (published) {
    if (published.moves === null || published.moves === undefined) {
      say("what moves was not kept: supabase/play.sql is not applied here, so the gallery is not asked");
    } else {
      check(`what moves was kept with it: ${JSON.stringify(published.moves)}`,
        JSON.stringify(published.moves) === JSON.stringify(["steering"]));
      const list = await fetch(`${site}/api/share?op=list&tests=1&technic=1&q=${encodeURIComponent("Play flow racer")}`,
        { headers }).then((r) => r.json()).catch(() => ({}));
      const card = (list.models || []).find((one) => one.id === id);
      check(`Technic or mechanism finds it, its card saying ${JSON.stringify(card ? card.moves : null)}`,
        Boolean(card) && (card.moves || []).includes("steering"));
    }
  }
  check(`no script errors (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 5)) console.log(`        ${e}`);
} catch (trouble) {
  check(`the flow ran: ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await browser.close();
  if (probe) {
    await fetch(`${site}/api/share?op=unpublish&id=${id}`, { method: "POST",
      headers: { ...headers, authorization: `Bearer ${token}` } }).catch(() => {});
    check(`the probe account deleted, and its link with it (${probe})`, await deleteAccount(probe));
  }
}
writeFileSync(path.join(out, "play.json"), JSON.stringify({ failed }, null, 1));
console.log(failed ? `\n${failed} FAILED`
  : "\na shared model's steering turns by its wheel, by mouse and by finger, and Reset puts it back");
process.exit(failed ? 1 : 0);
