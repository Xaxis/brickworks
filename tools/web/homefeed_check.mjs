// The home page's feed (homefeed, 2026-11-23; docs/SOCIAL.md section 11,
// docs/HOME.md), each post's own ways, in real browsers:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/homefeed_check.mjs --url=<preview or local> --out=DIR [--signed-in] [--try-start]
//
// Signed out, at a phone's 390 x 844 and a laptop's 1280 x 800:
//   1. The page as served, before any script: the feed's first posts in it
//      (a crawler reads them), each build's links to its page and the
//      studio's four verbs, one picture asked for at once and the rest lazy.
//   2. The first screen: the line that says what Brickworks is, Start
//      building, and the first post begun within 600 px on a phone; no tabs.
//   3. Each build's post: its picture, who made it with Follow, how it was
//      made as pills to the docs, like, comments and share, and Open in the
//      studio, Remix, Build it and Parts to the studio's own addresses.
//   4. Like, Add a comment and Follow, signed out: each asks to sign in on
//      the spot, over the page, which stays where it was; what was typed
//      in the comment is still there after.
//   5. 3D: the 3D button turns the model in its picture's place (three.js
//      asked for only then), Escape puts the picture back; on a laptop a
//      pointer resting on a picture turns it, and leaving puts it back.
//   6. Try it here: nothing of the studio asked for before the tap; the tap
//      puts the studio in the post (/app?view=<id>). With --try-start, the
//      studio there starts, on the engine without threads (the page is not
//      cross-origin isolated): a deployment with this unit's deploy.sh and
//      src/boot/shell.html, a preview, not a local copy over an older one.
// --signed-in (a deployment whose checks' accounts may post: a preview or
// this machine's relay; never brickworks.diy): Ann shares a model of her
// own (in the checks' pool, ?tests=1) and Bea, signed in:
//   7. sees no line, Share a build to /app?share, and the tabs For you,
//      Following and New, For you pressed, the arrows moving along them;
//   8. likes Ann's post (counted at once and by the server) and takes it
//      back; comments on it in place (its comment there and on the model);
//      follows Ann from it, and Following then shows Ann's model; New puts
//      Ann's newest first;
//   9. a visitor presses Like on Ann's post, signs in in the dialog that
//      opens, and is back where they were with the like made.
// Both accounts and Ann's model are deleted at the end.
//
// Pictures in --out. It passes when it ends "homefeed: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("homefeed_check: --url=<deployment> [--out=DIR] [--signed-in] [--try-start]");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
if (/^(?:www\.)?brickworks\.diy$/.test(new URL(site).host) && args["signed-in"]) {
  console.error("homefeed_check: --signed-in never on brickworks.diy");
  process.exit(2);
}
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const out = path.resolve(String(args.out || "shots/homefeed"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const browser = await launch({ signedOut: true });

async function open(where, { width = 1280, height = 800, session = null, theme = "light" } = {}) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (session) {
    await context.addInitScript(([name, value]) => {
      try {
        if (!localStorage.getItem(name)) localStorage.setItem(name, value);
      } catch { /* none kept */ }
    }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  }
  const page = await context.newPage();
  const asked = [];
  page.on("request", (request) => asked.push(request.url()));
  page.on("pageerror", (error) => errors.push(`${where}: ${error.message}`));
  await page.addInitScript(() => {
    window.__shifts = 0;
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.__shifts += entry.value;
      }).observe({ type: "layout-shift", buffered: true });
    } catch { /* none */ }
  });
  await page.goto(site + where, { waitUntil: "load", timeout: 60000 });
  await page.waitForFunction(() => document.documentElement.dataset.feedLive, null, { timeout: 45000 }).catch(() => null);
  return { context, page, asked };
}

async function until(page, test, what, seconds = 30, arg = null) {
  const got = await page.waitForFunction(test, arg, { timeout: seconds * 1000 }).then((one) => one.jsonValue(), () => null);
  if (got === null && what) throw new Error(`${what}: not within ${seconds} s`);
  return got;
}

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers, accept: "application/json" };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body ? JSON.stringify(body) : undefined });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name) }).catch(() => null);
const dialogOpen = (page) => until(page, () => Boolean(document.querySelector("dialog.sign-in[open]")), null, 10);
async function closeDialog(page) {
  await page.keyboard.press("Escape");
  await until(page, () => !document.querySelector("dialog.sign-in[open]") || null, null, 10);
}

/// The first build post's own parts, as drawn.
const buildPost = (page, id = "") => page.evaluate((wanted) => {
  const post = wanted ? document.querySelector(`#stream > .post.build[data-id="${wanted}"]`)
    : document.querySelector("#stream > .post.build");
  if (!post) return null;
  const href = (sel) => post.querySelector(sel)?.getAttribute("href") || "";
  return {
    id: post.dataset.id,
    picture: Boolean(post.querySelector(".post-pic img[width][height]")),
    who: post.querySelector(".post-who .who")?.textContent.trim() || "",
    follow: Boolean(post.querySelector("button[data-follow]")),
    made: [...post.querySelectorAll(".post-made a.pill")].map((one) => one.getAttribute("href")),
    like: post.querySelector("[data-like]")?.getAttribute("aria-pressed") || "",
    likes: post.querySelector("[data-like] .n")?.textContent.trim() || "0",
    say: Boolean(post.querySelector(".post-acts [data-say]")),
    share: Boolean(post.querySelector("[data-share]")),
    verbs: [href('[data-verb="open"]'), href('[data-verb="remix"]'), href('[data-verb="build"]'), href('[data-verb="parts"]')],
    page: href(".post-title a"),
    said: post.querySelector(".post-said")?.textContent.trim() || "",
  };
}, id);

const verbsRight = (one) => one && one.verbs[0] === `/app?view=${one.id}` && one.verbs[1] === `/app?copy=${one.id}`
  && one.verbs[2] === `/app?view=${one.id}&build` && /\/m\/[A-Za-z0-9]{10}#parts$/.test(one.verbs[3]);

const people = {};
let modelId = "";
try {
  // --- 1. As served ---------------------------------------------------------
  console.log(`homefeed: ${site}`);
  const served = await (await fetch(`${site}/`, { headers })).text();
  const feed = /<!--feed-->([\s\S]*?)<!--\/feed-->/.exec(served)?.[1] || "";
  const posts = [...feed.matchAll(/<article class="post (\w+)"/g)].map((one) => one[1]);
  const builds = [...feed.matchAll(/<article class="post build" data-kind="build" data-id="([A-Za-z0-9]{10})"/g)].map((one) => one[1]);
  check(`1. served: ${posts.length} posts in the page (${posts.join(", ")}), each build linked for a crawler`,
    posts.length >= 4 && builds.length >= 2 && builds.every((id) => feed.includes(`<a href="/m/${id}">`)
      && feed.includes(`href="/app?view=${id}"`) && feed.includes(`href="/app?copy=${id}"`)));
  check(`   one picture asked for at once, the rest lazy: ${(feed.match(/loading="eager"/g) || []).length} eager, `
    + `${(feed.match(/loading="lazy"/g) || []).length} lazy`, (feed.match(/loading="eager"/g) || []).length === 1);

  for (const [label, width, height] of [["phone", 390, 844], ["laptop", 1280, 800]]) {
    // --- 2. The first screen ------------------------------------------------
    const { context, page, asked } = await open("/", { width, height });
    const first = await page.evaluate(() => {
      const band = document.getElementById("home");
      const start = band?.querySelector('a[href^="/app"]');
      const post = document.querySelector("#stream > .post:not(.skeleton)");
      return { line: band?.querySelector(".lede, p")?.textContent.trim() || "", band: Boolean(band?.offsetHeight),
        start: start ? start.getBoundingClientRect().bottom <= innerHeight : false,
        first: post ? Math.round(post.getBoundingClientRect().top + scrollY) : -1,
        tabs: Boolean(document.getElementById("feed-tabs")?.offsetHeight), share: Boolean(document.getElementById("share-build")?.offsetHeight) };
    });
    check(`2. ${label}: the line "${first.line.slice(0, 60)}…", Start building in view, the first post at ${first.first} px, no tabs or Share`,
      first.band && first.start && first.first >= 0 && (width >= 600 || first.first <= 600) && !first.tabs && !first.share);
    await shot(page, `first-${label}.png`);

    // --- 3. A build's post --------------------------------------------------
    const one = await buildPost(page);
    check(`3. ${label}: "${one?.who}"'s post: picture ${one?.picture}, Follow ${one?.follow}, made ${one?.made.join(" ")}, `
      + `like/comments/share, verbs ${one?.verbs.join(" ")}`, Boolean(one) && one.picture && one.follow && one.made.length >= 1
      && one.made.every((href) => /^\/docs\/[a-z-]+$/.test(href)) && one.say && one.share && verbsRight(one));

    // --- 4. Signed out, each asks to sign in on the spot ------------------
    const id = one?.id || "";
    const at = await page.evaluate((wanted) => {
      document.querySelector(`#stream > .post.build[data-id="${wanted}"]`)?.scrollIntoView({ block: "center" });
      return Math.round(scrollY);
    }, id);
    await page.click(`#stream > .post.build[data-id="${id}"] [data-like]`);
    const likeAsks = await dialogOpen(page);
    await closeDialog(page);
    const after = await buildPost(page, id);
    check(`4. ${label}: Like asks to sign in (${Boolean(likeAsks)}), and closed changes nothing (${after?.like}, ${after?.likes} likes)`,
      Boolean(likeAsks) && after?.like === one.like && after?.likes === one.likes);
    await page.click(`#stream > .post.build[data-id="${id}"] .post-say`);
    const box = await until(page, (wanted) => document.activeElement?.id === `say-${wanted}` || null, null, 10, id);
    await page.keyboard.type(`What a build ${rand}`);
    await page.click(`#stream > .post.build[data-id="${id}"] .post-comments button[type="submit"]`);
    const sayAsks = await dialogOpen(page);
    await closeDialog(page);
    const kept = await page.inputValue(`#say-${id}`).catch(() => "");
    check(`   Add a comment opens its box in place (${Boolean(box)}), Comment asks to sign in (${Boolean(sayAsks)}), the words kept: "${kept}"`,
      Boolean(box) && Boolean(sayAsks) && kept === `What a build ${rand}`);
    await page.click(`#stream > .post.build[data-id="${id}"] button[data-follow]`);
    const followAsks = await dialogOpen(page);
    await closeDialog(page);
    const still = await page.evaluate(() => Math.round(scrollY));
    check(`   Follow asks to sign in (${Boolean(followAsks)}); the page stayed where it was (${at} then ${still})`,
      Boolean(followAsks) && Math.abs(still - at) <= 2);

    // --- 5. 3D ----------------------------------------------------------------
    const before3d = asked.filter((url) => /\/viewer3d\.js|\/scene\.json/.test(url)).length;
    await page.click(`#stream > .post.build[data-id="${id}"] [data-turn]`);
    const turned = await until(page, () => (window.brickworks3d?.state === "ready" ? document.documentElement.dataset.feedTurn || "?" : null),
      null, 60);
    const canvas = await page.evaluate(() => Boolean(document.querySelector("#stream .post-pic .view3d.shown canvas")));
    await shot(page, `turn-${label}.png`);
    await page.keyboard.press("Escape");
    const back = await until(page, () => (!document.querySelector("#stream .view3d") ? true : null), null, 10);
    check(`5. ${label}: nothing of 3D asked before (${before3d}); 3D turns it in place (${turned}, canvas ${canvas}); Escape puts the picture back (${Boolean(back)})`,
      before3d === 0 && turned === id && canvas && Boolean(back));
    if (width >= 600) {
      const second = await page.evaluate(() => [...document.querySelectorAll("#stream > .post.build")][1]?.dataset.id || "");
      await page.locator(`#stream > .post.build[data-id="${second}"] .post-pic img`).scrollIntoViewIfNeeded();
      await page.hover(`#stream > .post.build[data-id="${second}"] .post-pic img`);
      const hovered = await until(page, () => document.documentElement.dataset.feedTurn || null, null, 5);
      await page.mouse.move(2, 2);
      const left = await until(page, () => (!document.documentElement.dataset.feedTurn ? true : null), null, 5);
      check(`   a pointer resting on a picture turns it (${hovered}), leaving puts it back (${Boolean(left)})`, hovered === second && Boolean(left));
    }

    // --- 6. Try it here -------------------------------------------------------
    const tryId = await page.evaluate(() => document.querySelector("#stream [data-try]")?.dataset.try || "");
    if (!tryId) {
      check(`6. ${label}: a Try it here post in the first page`, false);
    } else {
      const studioBefore = asked.filter((url) => /\/app(?:\?|$)|\/b\/[^/]+\/|\/e\/[^/]+\//.test(new URL(url).pathname + new URL(url).search)).length;
      await page.locator("#stream [data-try]").scrollIntoViewIfNeeded();
      await page.click("#stream [data-try]");
      const framed = await until(page, () => document.querySelector("#stream [data-try-stage] iframe")?.getAttribute("src") || null, null, 10);
      check(`6. ${label}: nothing of the studio asked before the tap (${studioBefore}); the tap puts it in the post (${framed})`,
        studioBefore === 0 && framed === `/app?view=${tryId}`);
      if (args["try-start"]) {
        const engine = await until(page, () => {
          const frame = document.querySelector("#stream [data-try-stage] iframe");
          try {
            const there = frame.contentWindow;
            return there.location.pathname === "/app" && there.brickworksEngine
              ? { threads: there.brickworksEngine.threads, shared: there.brickworksEngine.shared } : null;
          } catch {
            return null;
          }
        }, null, 60);
        const started = await until(page, () => {
          const there = document.querySelector("#stream [data-try-stage] iframe")?.contentWindow;
          try {
            return there?.document.getElementById("boot")?.classList.contains("done") ? true : null;
          } catch {
            return null;
          }
        }, null, 240);
        await shot(page, `try-${label}.png`);
        check(`   with --try-start: the studio in the post starts on the engine without threads (${JSON.stringify(engine)}), its boot gone (${Boolean(started)})`,
          engine && engine.threads === false && engine.shared === false && Boolean(started));
      }
    }
    const moved = await page.evaluate(() => window.__shifts);
    check(`   ${label}: the page moved ${moved.toFixed(3)} with no press`, moved <= 0.01);
    await context.close();
  }

  // --- 7-9. Signed in -----------------------------------------------------------
  if (args["signed-in"]) {
    const emails = Object.fromEntries(["ann", "bea", "cy"].map((who) => [who, `delivered+bw-feed-${who}-${rand}@resend.dev`]));
    for (const who of ["ann", "bea"]) {
      people[who] = await mintSession(emails[who]);
      const made = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
        body: { handle: `hf-${who}-${rand}`, name: `${who === "ann" ? "Ann" : "Bea"} Feed` } });
      check(`${who}'s profile @hf-${who}-${rand}: ${made.status}`, made.status === 200);
    }
    const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
    const ldraw = `0 Feed tower\r\n0 Name: feed.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
      + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // homefeed check ${rand}\r\n`;
    const shared = await api("/api/share", { method: "POST", token: people.ann.access_token,
      body: { name: `Feed tower ${rand}`, author: "Ann Feed", model: ldraw, image: picture, listed: true } });
    modelId = shared.body.id || "";
    check(`Ann's tower /m/${modelId}: ${shared.status}`, shared.status === 201 && /^[A-Za-z0-9]{10}$/.test(modelId));

    // 7. The page as Bea has it.
    const { context, page } = await open("/?tests=1", { session: people.bea });
    const shown = await page.evaluate(() => ({
      band: Boolean(document.getElementById("home")?.offsetHeight),
      share: document.getElementById("share-build")?.offsetHeight ? document.getElementById("share-build").getAttribute("href") : "",
      tabs: [...document.querySelectorAll("#feed-tabs [role=tab]")].map((tab) => `${tab.textContent.trim()}${tab.getAttribute("aria-selected") === "true" ? "*" : ""}`),
    }));
    check(`7. signed in: no line (${!shown.band}), Share a build to ${shown.share}, tabs ${shown.tabs.join(" ")}`,
      !shown.band && shown.share === "/app?share" && shown.tabs.join() === "For you*,Following,New");
    await page.focus("#tab-foryou");
    await page.keyboard.press("ArrowRight");
    const arrowed = await until(page, () => (document.documentElement.dataset.feedTab === "following"
      && document.activeElement?.id === "tab-following" ? true : null), null, 30);
    check(`   the right arrow shows Following (${Boolean(arrowed)})`, Boolean(arrowed));
    await page.click("#tab-foryou");
    await until(page, () => (document.documentElement.dataset.feedTab === "foryou" && document.querySelector("#stream > .post.build") ? true : null),
      "For you drawn again", 30);
    await shot(page, "signed-in.png");

    // 8. Ann's post: like, comment, follow.
    const findAnn = async () => {
      for (let i = 0; i < 4; i += 1) {
        if (await page.$(`#stream > .post.build[data-id="${modelId}"]`)) return true;
        if (!(await page.isVisible("#feed-more"))) return false;
        await page.click("#feed-more");
        await page.waitForTimeout(1500);
      }
      return Boolean(await page.$(`#stream > .post.build[data-id="${modelId}"]`));
    };
    if (!check(`8. Ann's tower is in Bea's For you`, await findAnn())) throw new Error("no post of Ann's to press");
    const sel = `#stream > .post.build[data-id="${modelId}"]`;
    await page.locator(sel).scrollIntoViewIfNeeded();
    await page.click(`${sel} [data-like]`);
    const liked = await until(page, (s) => {
      const button = document.querySelector(`${s} [data-like]`);
      return button?.getAttribute("aria-pressed") === "true" && !button.disabled ? button.querySelector(".n")?.textContent.trim() || "?" : null;
    }, null, 20, sel);
    const heard = await api(`/api/share?op=list&page=1&sort=newest&mine=1&tests=1`, { token: people.bea.access_token });
    const there = (heard.body.models || []).find((m) => m.id === modelId);
    check(`   Like: pressed, ${liked} like; the server has it (${there?.liked}, ${there?.likes})`, liked === "1" && there?.liked === true && there?.likes === 1);
    await page.click(`${sel} [data-like]`);
    const unliked = await until(page, (s) => (document.querySelector(`${s} [data-like]`)?.getAttribute("aria-pressed") === "false"
      && !document.querySelector(`${s} [data-like]`).disabled ? true : null), null, 20, sel);
    check(`   pressed again, taken back (${Boolean(unliked)})`, Boolean(unliked));
    await page.click(`${sel} .post-say`);
    await page.fill(`#say-${modelId}`, `Lovely tower ${rand}`);
    await page.click(`${sel} .post-comments button[type="submit"]`);
    const listed = await until(page, (s) => [...document.querySelectorAll(`${s} .post-comments li`)].map((li) => li.textContent).join(" | ") || null,
      null, 30, sel);
    const comments = await api(`/api/people?op=comments&id=${modelId}`);
    check(`   a comment in place: "${listed}"; on the model too (${(comments.body.comments || []).length})`,
      String(listed).includes(`Lovely tower ${rand}`) && (comments.body.comments || []).some((one) => one.body === `Lovely tower ${rand}`));
    await page.click(`${sel} button[data-follow]`);
    const followed = await until(page, (s) => (document.querySelector(`${s} button[data-follow]`)?.getAttribute("aria-pressed") === "true" ? true : null),
      null, 20, sel);
    await page.click("#tab-following");
    const inFollowing = await until(page, (id) => (document.documentElement.dataset.feedTab === "following"
      && document.querySelector(`#stream > .post.build[data-id="${id}"]`) ? true : null), null, 30, modelId);
    check(`   Follow Ann from her post (${Boolean(followed)}); Following shows her tower (${Boolean(inFollowing)})`, Boolean(followed) && Boolean(inFollowing));
    await page.click("#tab-new");
    const newest = await until(page, () => (document.documentElement.dataset.feedTab === "new"
      ? document.querySelector("#stream > .post.build")?.dataset.id || "" : null), null, 30);
    check(`   New: Ann's tower first (${newest})`, newest === modelId);
    await context.close();

    // 9. A visitor signs in from a like and is back where they were.
    const visitor = await open("/?tests=1", { width: 1280, height: 800 });
    const vp = visitor.page;
    if (await findAnnIn(vp)) {
      await vp.locator(sel).scrollIntoViewIfNeeded();
      const atY = await vp.evaluate(() => Math.round(scrollY));
      await vp.click(`${sel} [data-like]`);
      await vp.locator("dialog.sign-in[open]").waitFor({ state: "visible", timeout: 20000 });
      await vp.fill("dialog.sign-in input", emails.cy);
      await vp.click('dialog.sign-in button[type="submit"]');
      await until(vp, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility() || null, "the code's boxes", 30);
      const code = await mintCode(emails.cy, { welcome: false });
      await vp.fill("dialog.sign-in .code-boxes input:first-child", code);
      await until(vp, () => (!document.querySelector("dialog.sign-in") ? true : null), "the sign-in done", 30);
      if (await until(vp, () => (document.querySelector("dialog.age[open]") ? true : null), null, 8)) {
        await vp.selectOption("#age-month", { index: 1 });
        await vp.selectOption("#age-year", "1990");
        await vp.click("#age-go");
      }
      const done = await until(vp, (s) => (document.querySelector(`${s} [data-like]`)?.getAttribute("aria-pressed") === "true" ? true : null), null, 30, sel);
      const nowY = await vp.evaluate(() => Math.round(scrollY));
      check(`9. a visitor's Like: signed in in the dialog, the like made (${Boolean(done)}), still at ${nowY} px (was ${atY})`,
        Boolean(done) && Math.abs(nowY - atY) <= 40);
      await shot(vp, "signed-in-from-like.png");
    } else {
      check("9. Ann's tower is in a visitor's feed", false);
    }
    await visitor.context.close();
    await deleteAccount(emails.cy).catch(() => {});

    async function findAnnIn(one) {
      for (let i = 0; i < 4; i += 1) {
        if (await one.$(sel)) return true;
        if (!(await one.isVisible("#feed-more"))) return false;
        await one.click("#feed-more");
        await one.waitForTimeout(1500);
      }
      return Boolean(await one.$(sel));
    }
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (modelId && people.ann) await api(`/api/share?op=unpublish&id=${modelId}`, { method: "POST", token: people.ann.access_token }).catch(() => {});
  await browser.close();
  for (const who of Object.keys(people)) await deleteAccount(`delivered+bw-feed-${who}-${rand}@resend.dev`).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "homefeed: all ok");
process.exit(failed ? 1 : 0);
