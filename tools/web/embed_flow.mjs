// The embed in 3D (docs/SOCIAL.md section 7, item 4): /m/<id>/embed in
// somebody else's page, its picture the way into the model in 3D in the
// frame, as on the model's page (web/start3d.js, viewer369's
// tools/viewer/inline.js).
//
//   node tools/web/embed_flow.mjs --out=DIR                      the stand-in's watchtower
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/embed_flow.mjs --url=<a deployment> --out=DIR
//
// In a real browser, the embed in a blog's page (an origin of its own) as
// the share sheet's code puts it there, 560 x 420 and allowed full screen:
//
//   1. A laptop (1280, light): before View in 3D, none of the 3D view's
//      code nor its model asked for, and what the frame did load said (its
//      scripts the theme's, embed.js and start3d.js, all small); the
//      picture a button, "View <name> in 3D, here", saying View in 3D; its
//      name the model's page and Build it the guided build, each a tab of
//      its own. Then View in 3D draws the model in the picture's place,
//      whole, in the frame; its tools named; a drag turns it, Reset the
//      view goes back; Full screen fills the screen and goes back to the
//      frame; Open in the app opens the app in a tab of its own, the frame
//      still the embed; Back to the picture puts the picture back.
//   2. The same in dark, drawn on dark's ground.
//   3. A phone (390, dark, touch), the frame its column wide in a page
//      longer than the screen: a swipe up the picture scrolls the blog and
//      asks for nothing; a swipe across it opens the model in 3D; a swipe
//      up that scrolls the blog and leaves the model as it was, until it is
//      taken hold of (a swipe across turns it).
//   4. The same phone, its model past what a phone turns smoothly (its
//      scene said to be 4.2 million triangles): it asks first, as the
//      page does, and its Open in the app is a tab of its own too; Turn it
//      anyway draws it.
//
// Throughout: nothing the frame's policy refused, no script errors, and
// the blog's page never moved off itself.
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
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const BLOG = "http://blog.test";

let failed = 0;
const check = (what, ok) => {
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
};
const shot = async (page, name) => { if (out) await page.screenshot({ path: path.join(out, name) }); };

// The model: the stand-in's watchtower, or a deployment's first.
let id = stand.MODEL_ID;
let remoteDb = "";
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* none: the stand-in's own */ }
  const listed = await (await fetch(`${remote}/api/share?op=list&page=1`, { headers })).json().catch(() => ({}));
  id = (listed.models || [])[0]?.id || "";
  if (!id) {
    check("the deployment's gallery has a model to embed", false);
    process.exit(1);
  }
}
const embedAt = `${base}/m/${id}/embed`;

const browser = await launch({ signedOut: true });
const errors = [];

/// A context with the blog's page in it, the embed's code as the share
/// sheet gives it, and [more] of the blog under it.
async function blogContext({ width, height, theme, phone = false, triangles = 0 }) {
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb });
  // The model's scene as the site gives it, its triangles said to be
  // [triangles] where asked: changed as the frame reads it, the stand-in's
  // and a deployment's alike.
  if (triangles) {
    await context.addInitScript((said) => {
      const asked = window.fetch;
      window.fetch = async (...given) => {
        const answer = await asked(...given);
        if (!/\/scene\.json$/.test(String(given[0]))) return answer;
        const scene = await answer.json();
        scene.triangles = Math.max(scene.triangles || 0, said);
        return new Response(JSON.stringify(scene), { status: answer.status, headers: answer.headers });
      };
    }, triangles);
  }
  // The app a tab of its own opens: not drawn here, only seen asked for.
  await context.route((url) => url.origin === new URL(base).origin && url.pathname === "/app",
    (route) => route.fulfill({ contentType: "text/html", body: "<!doctype html><title>The app</title>" }));
  await context.route((url) => url.origin === BLOG, (route) => route.fulfill({ contentType: "text/html; charset=utf-8",
    body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="margin:16px;font-family:sans-serif;background:#f6f3ec">
      <h2>My blog post</h2><p>Look what I built:</p>
      <iframe src="${embedAt}" width="560" height="420" style="border:0;max-width:100%" title="A Brickworks model" loading="lazy" allowfullscreen></iframe>
      ${"<p>More of the post, so the page is longer than the screen.</p>".repeat(60)}</body></html>` }));
  // What the frame's policy refused, as the frame hears it.
  await context.addInitScript(() => {
    window.refused = [];
    document.addEventListener("securitypolicyviolation", (e) => window.refused.push(`${e.violatedDirective} ${e.blockedURI}`));
  });
  return context;
}

async function openBlog(context, label) {
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => { if (m.type() === "error") errors.push(`${label}: ${m.text().slice(0, 200)}`); });
  await page.goto(`${BLOG}/post`, { waitUntil: "load", timeout: 60000 });
  const element = await page.waitForSelector("iframe", { timeout: 30000 });
  await element.scrollIntoViewIfNeeded();
  let frame = null;
  for (let n = 0; n < 60 && !frame; n++) {
    frame = await element.contentFrame();
    if (!frame || !(await frame.$(".embed a.picture").catch(() => null))) {
      frame = null;
      await page.waitForTimeout(500);
    }
  }
  await frame.waitForFunction(() => document.readyState === "complete" && document.querySelector(".embed a.picture[role=button]"),
    null, { timeout: 60000 });
  await page.evaluate(() => window.scrollTo(0, 0));
  return { page, frame, element };
}

/// The 3D view as the frame has it.
const state = (frame) => frame.evaluate(() => {
  const box = (el) => {
    if (!el || el.hidden) return null;
    const r = el.getBoundingClientRect();
    return [r.left, r.top, r.width, r.height].map((n) => Math.round(n));
  };
  const b = window.brickworks3d;
  return { picture: box(document.querySelector(".embed .picture")), shell: box(document.querySelector(".embed .view3d")),
    state: b?.state || "", full: Boolean(b?.full), how: b?.fullscreen || "", engaged: b?.engaged ? b.engaged() : null,
    touch: b?.touchAction ? b.touchAction() : "", angle: b?.angle ? b.angle() : null, sample: b?.sample ? b.sample() : null,
    errors: b?.errors || [], parts: b?.parts || 0, shown: b?.shown ? b.shown() : 0, viewport: [innerWidth, innerHeight],
    said: document.querySelector(".view3d-said")?.textContent || "", refused: window.refused || [],
    asked: performance.getEntriesByType("resource").map((r) => r.name).filter((n) => /viewer3d|three|scene\.json/.test(n)) };
});
const near = (a, b) => a && b && Math.abs(a.round - b.round) < 1e-3 && Math.abs(a.up - b.up) < 1e-3
  && Math.abs(a.distance - b.distance) < b.distance * 1e-3;
const drawn = (frame) => frame.waitForFunction(() => {
  const b = window.brickworks3d;
  return b && (b.timings.complete3d || b.state === "failed" || b.state === "big");
}, null, { timeout: 180000 }).then(() => true, () => false);
/// A finger's own touches on [page] (as model_page_flow.mjs drags), from
/// [a] to [b] in the blog's coordinates.
async function finger(page) {
  const cdp = await page.context().newCDPSession(page);
  const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
    touchPoints: points.map(([x, y], i) => ({ x, y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
  return {
    drag: async (a, b, steps = 12) => {
      await touch("touchStart", [a]);
      for (let n = 1; n <= steps; n++) {
        await touch("touchMove", [[a[0] + ((b[0] - a[0]) * n) / steps, a[1] + ((b[1] - a[1]) * n) / steps]]);
        await page.waitForTimeout(30);
      }
      await touch("touchEnd", []);
      await page.waitForTimeout(300);
    },
    done: () => cdp.detach(),
  };
}
/// The app asked for in a tab of its own by clicking [selector] in
/// [frame]: its address, and whether the frame stayed the embed.
async function appTab(page, frame, selector) {
  const opened = page.context().waitForEvent("page", { timeout: 15000 }).catch(() => null);
  await frame.click(selector);
  const tab = await opened;
  if (tab) await tab.waitForLoadState("domcontentloaded").catch(() => {});
  const url = tab ? tab.url() : "";
  if (tab) await tab.close();
  return { url: url.replace(base, ""), stayed: frame.url() === embedAt && !page.isClosed() && page.url() === `${BLOG}/post` };
}

try {
  // --- 1, 2. A laptop, light then dark -----------------------------------------------
  for (const theme of ["light", "dark"]) {
    const label = `laptop ${theme}`;
    console.log(`${label}: the embed in a blog, 560 x 420`);
    const context = await blogContext({ width: 1280, height: 900, theme });
    const { page, frame } = await openBlog(context, label);
    const before = await frame.evaluate(() => {
      const entries = performance.getEntriesByType("resource");
      const nav = performance.getEntriesByType("navigation")[0];
      const scripts = entries.filter((r) => r.initiatorType === "script" || /\.js$/.test(new URL(r.name).pathname));
      const a = (sel) => document.querySelector(sel);
      return { asked: entries.map((r) => r.name).filter((n) => /viewer3d|three|scene\.json/.test(n)), loaded: Boolean(window.brickworks3d),
        scripts: scripts.map((r) => `${new URL(r.name).pathname} ${r.decodedBodySize}`),
        scriptBytes: scripts.reduce((sum, r) => sum + r.decodedBodySize, 0),
        bytes: entries.reduce((sum, r) => sum + r.transferSize, 0) + (nav?.transferSize || 0),
        role: a(".embed a.picture").getAttribute("role"), name: a(".embed a.picture").getAttribute("aria-label"),
        go: a(".embed a.picture .go")?.textContent || "", base: a("base")?.target || "",
        build: a(".embed-bar a.cta")?.getAttribute("href") || "", page: a(".embed-bar a.words")?.getAttribute("href") || "",
        ground: getComputedStyle(document.body).backgroundColor };
    });
    if (theme === "light") {
      check(`none of the 3D view asked for before View in 3D (${before.asked.join(", ") || "none"}); the frame's scripts `
        + `${before.scripts.join(", ")} (${Math.round(before.scriptBytes / 1024)} KB), ${Math.round(before.bytes / 1024)} KB over the wire in all`,
      before.asked.length === 0 && !before.loaded && before.scriptBytes < 24 * 1024
        && ["/theme.js", "/embed.js", "/start3d.js"].every((one) => before.scripts.some((s) => s.startsWith(`${one} `)))
        && before.scripts.length === 3);
      check(`the picture a button, "${before.name}", saying ${before.go}; every link a tab of its own (base ${before.base})`,
        before.role === "button" && /^View .+ in 3D, here$/.test(before.name) && before.go === "View in 3D" && before.base === "_blank");
      check(`its name the model's page (${before.page.replace(base, "")}), Build it the guided build (${before.build.replace(base, "")})`,
        before.page === `${base}/m/${id}` && before.build === `${base}/app?view=${id}&build`);
    }
    const was = await state(frame);
    await frame.click(".embed a.picture .go");
    let came = await drawn(frame);
    const big = await state(frame);
    if (big.state === "big") {
      // A deployment's model may be past what this device turns smoothly.
      await frame.click(".view3d-said button");
      came = await drawn(frame);
    }
    await frame.waitForTimeout(600);
    const open = await state(frame);
    const tools = await frame.evaluate(() => ({
      named: [...document.querySelectorAll(".view3d-tools [data-act]")].map((t) => t.getAttribute("aria-label")),
      app: (() => { const a = document.querySelector(".view3d-app"); return a && !a.hidden ? `${a.textContent} ${a.getAttribute("href")}` : ""; })(),
      // The theme's ground, a gradient (site.css --picture-ground), as the picture's is.
      ground: getComputedStyle(document.querySelector(".embed .view3d")).backgroundImage,
      pictureGround: getComputedStyle(document.querySelector(".embed a.picture")).backgroundImage,
      // A picture drawn on a ground of its own (no cut-out) hands the view that ground, as on the page.
      own: document.querySelector(".embed .view3d").dataset.ground || "",
    }));
    await shot(page, `${theme}_1280_3d.png`);
    check(`${label}: View in 3D draws the model here (${open.state}): ${open.parts} parts, ${open.shown} shown, `
      + `${open.sample ? `${(open.sample.drawn * 100).toFixed(1)}% of the frame, ${open.sample.colours} colours${open.sample.cut ? ", cut off" : ""}` : "no frame"}`,
    came && open.state === "ready" && open.parts > 0 && open.shown === open.parts && open.sample && open.sample.drawn > 0.01
      && !open.sample.cut && !open.errors.length);
    check(`${label}: over the picture, edge to edge (${open.shell} over ${was.picture}), on ${tools.own ? "the ground its picture was drawn on" : "the picture's ground"} (${tools.ground})`,
      JSON.stringify(open.shell) === JSON.stringify(was.picture) && /gradient/.test(tools.ground)
        && (tools.own === "render" || tools.ground === tools.pictureGround));
    check(`${label}: its tools named: ${tools.named.join(", ")}; and ${tools.app}`,
      JSON.stringify(tools.named) === JSON.stringify(["Zoom out", "Zoom in", "Reset the view", "Full screen", "Back to the picture"])
        && tools.app === `Open in the app ${base}/app?view=${id}`);
    if (open.state !== "ready") { await context.close(); continue; }
    const home = open.angle;
    if (theme === "light") {
      const box = await (await page.$("iframe")).boundingBox();
      const at = (x, y) => [box.x + open.shell[0] + open.shell[2] * x, box.y + open.shell[1] + open.shell[3] * y];
      await page.mouse.move(...at(0.4, 0.5));
      await page.mouse.down();
      await page.mouse.move(...at(0.6, 0.45), { steps: 6 });
      await page.mouse.up();
      const dragged = await state(frame);
      await frame.click('.view3d-tools [data-act="reset"]');
      await frame.waitForTimeout(150);
      const reset = await state(frame);
      check(`${label}: a drag turns it (${home.round.toFixed(2)} to ${dragged.angle.round.toFixed(2)}), Reset the view goes back`,
        Math.abs(dragged.angle.round - home.round) > 0.05 && near(reset.angle, home));
      await frame.click('.view3d-tools [data-act="full"]');
      await frame.waitForFunction(() => window.brickworks3d.full, null, { timeout: 8000 }).catch(() => {});
      await page.waitForTimeout(600);
      const full = await state(frame);
      const screen = await page.evaluate(() => [innerWidth, innerHeight]);
      await shot(page, `${theme}_1280_3d_full.png`);
      check(`${label}: Full screen fills the screen (${full.shell} in ${screen}, the ${full.how}'s), the model whole in it`,
        full.full && full.how === "browser" && full.shell && full.shell[0] === 0 && full.shell[1] === 0
          && full.shell[2] >= screen[0] - 1 && full.shell[3] >= screen[1] - 1 && full.sample && full.sample.drawn > 0.01 && !full.sample.cut);
      await frame.click('.view3d-tools [data-act="full"]');
      await frame.waitForFunction(() => !window.brickworks3d.full && !document.fullscreenElement, null, { timeout: 8000 }).catch(() => {});
      await page.waitForTimeout(400);
      const back = await state(frame);
      check(`${label}: and back in the frame as it was (${back.shell})`, !back.full && JSON.stringify(back.shell) === JSON.stringify(was.picture));
      const tab = await appTab(page, frame, ".view3d-app");
      check(`${label}: Open in the app opens ${tab.url} in a tab of its own, the frame still the embed`,
        tab.url === `/app?view=${id}` && tab.stayed);
      await frame.click('.view3d-tools [data-act="close"]');
      await frame.waitForTimeout(200);
      const closed = await state(frame);
      check(`${label}: Back to the picture puts the picture back (${closed.state})`, closed.state === "closed" && closed.shell === null);
    } else {
      check(`${label}: on dark's ground, not light's (${before.ground})`, before.ground !== "rgb(255, 255, 255)");
    }
    const end = await state(frame);
    check(`${label}: nothing its policy refused (${end.refused.join("; ") || "none"})`, end.refused.length === 0);
    await context.close();
  }

  // --- 3. A phone: the blog scrolls, the model turns ---------------------------------
  {
    const label = "phone dark";
    console.log(`${label}: the embed its column wide, by touch`);
    const context = await blogContext({ width: 390, height: 844, theme: "dark", phone: true });
    const { page, frame } = await openBlog(context, label);
    const box = await (await page.$("iframe")).boundingBox();
    const was = await state(frame);
    const middle = [box.x + was.picture[0] + was.picture[2] / 2, box.y + was.picture[1] + was.picture[3] / 2];
    const hand = await finger(page);
    await hand.drag(middle, [middle[0], middle[1] - 260]);
    const scrolled = await page.evaluate(() => scrollY);
    const still = await state(frame);
    check(`${label}: a swipe up the picture scrolls the blog (${scrolled} px) and asks for nothing (${still.asked.length})`,
      scrolled > 100 && still.asked.length === 0 && !still.state);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(300);
    await hand.drag([middle[0] + 80, middle[1]], [middle[0] - 80, middle[1]]);
    let came = await drawn(frame);
    if ((await state(frame)).state === "big") {
      await frame.tap(".view3d-said button");
      came = await drawn(frame);
    }
    await frame.waitForTimeout(600);
    const open = await state(frame);
    await shot(page, "dark_390_3d.png");
    check(`${label}: a swipe across opens the model in 3D (${open.state}, ${open.sample ? `${(open.sample.drawn * 100).toFixed(1)}%` : "no frame"}), `
      + `not yet held (touch-action ${open.touch})`, came && open.state === "ready" && open.sample && open.sample.drawn > 0.01
      && open.engaged === false && open.touch === "pan-y");
    if (open.state === "ready") {
      const home = open.angle;
      await hand.drag(middle, [middle[0], middle[1] - 260]);
      const swiped = await state(frame);
      const y = await page.evaluate(() => scrollY);
      check(`${label}: a swipe up it scrolls the blog (${y} px) and leaves the model as it was`, y > 100 && near(swiped.angle, home));
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.waitForTimeout(300);
      await hand.drag([middle[0] + 80, middle[1]], [middle[0] - 80, middle[1]]);
      const turned = await state(frame);
      check(`${label}: a swipe across turns it (${home.round.toFixed(2)} to ${turned.angle?.round.toFixed(2)}), it is held now (touch-action ${turned.touch})`,
        turned.angle && Math.abs(turned.angle.round - home.round) > 0.05 && turned.engaged === true && turned.touch === "none");
    }
    await hand.done();
    const end = await state(frame);
    check(`${label}: nothing its policy refused (${end.refused.join("; ") || "none"})`, end.refused.length === 0);
    await context.close();
  }

  // --- 4. A phone, a model past what it turns smoothly ---------------------------------
  {
    const label = "phone, a big model";
    console.log(`${label}: its scene said to be 4.2 million triangles`);
    const context = await blogContext({ width: 390, height: 844, theme: "light", phone: true, triangles: 4.2e6 });
    const { page, frame } = await openBlog(context, label);
    await frame.tap(".embed a.picture .go");
    await drawn(frame);
    await frame.waitForTimeout(600);
    const asked = await state(frame);
    await shot(page, "light_390_big.png");
    check(`${label}: it asks first, as the page does ("${asked.said}")`, asked.state === "big"
      && /more than this device turns smoothly/.test(asked.said) && /Turn it anyway/.test(asked.said) && /Open in the app/.test(asked.said));
    const tab = await appTab(page, frame, ".view3d-said a.cta");
    check(`${label}: its Open in the app opens ${tab.url} in a tab of its own, the frame still the embed`,
      tab.url === `/app?view=${id}` && tab.stayed);
    await frame.tap(".view3d-said button");
    const came = await drawn(frame);
    await frame.waitForTimeout(600);
    const open = await state(frame);
    check(`${label}: Turn it anyway draws it (${open.state})`, came && open.state === "ready" && open.sample && open.sample.drawn > 0.01);
    check(`${label}: nothing its policy refused (${open.refused.join("; ") || "none"})`, open.refused.length === 0);
    await context.close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close();
}
for (const error of errors) console.log(`  page: ${error}`);
check(`no script errors (${errors.length})`, errors.length === 0);
console.log(failed ? `${failed} FAILED` : "embed: the model in 3D in somebody else's page, asked for only then, on a laptop and a phone");
process.exit(failed ? 1 : 0);
