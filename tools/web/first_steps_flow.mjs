// A first visit and a first sign-in (docs/SOCIAL.md U10), in real browsers
// at 390 and 1280 px, light and dark: what somebody new to Brickworks meets.
//
//   node tools/web/first_steps_flow.mjs --out=DIR                    # the stand-in, nothing leaves this machine
//   node --env-file=.env tools/web/relay_server.mjs 8870 &
//   node --env-file=.env tools/web/first_steps_flow.mjs --url=http://127.0.0.1:8870 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/first_steps_flow.mjs --url=<preview> --out=DIR
//
// With no --url, the checkout's pages and api/ on tools/web/design_stand_in.mjs,
// as the live gallery was on 2026-10-22 (its seven models, all the studio's)
// with the house's profile that supabase/house.sql writes, held in memory:
//
//   1. A first visit: the feed suggests the house to follow and shows its
//      models as Latest; every card in the feed and the gallery links to
//      /u/brickworks and carries the Assistant mark (house.sql's tag);
//      that page says whose account it is and that its
//      models were made with the assistant, and has its banner and three pinned.
//   2. A first sign-in from the feed's Sign in: the code, the age question,
//      then First steps: Make your profile (the handle made from the name as
//      it is typed, the avatar from the handle), What do you build? (a kind
//      chosen puts its models first), the house to follow and six models;
//      Follow, then See your feed: the house's models as posts.
//   3. The fewest taps: Skip, Skip, Follow, See your feed, a filled feed.
//   4. Signed in to do something (Follow on the house's page): First steps
//      end with Done, not the feed, and the follow goes on after them.
//
// With --url, the same on the live project with throwaway accounts at
// Resend test addresses, deleted at the end with their model: Ada, a
// designer with a listed castle (a test model, shown only with ?tests=1);
// Bob signs in from the feed's dialog (one code sent to a test address that
// delivers nowhere, then one minted here), answers the age question, makes
// his profile and follows Ada from First steps; Cy, signed in elsewhere and
// never asked, meets the question on /profile and reaches a filled feed in
// four taps, with nothing new on the avatar for Ada's castle, listed before
// the follow (walk180, W7), and one once she lists a tower after.
//
// Pictures in --out: each step at both widths, in the theme it ran in and
// the other.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const standIn = !args.url;
const stand = standIn ? await import("./design_stand_in.mjs") : null;
const session = standIn ? null : await import("./session.mjs");
const site = standIn ? stand.ORIGIN : String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/first_steps"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
// Test models are shown only to a page asked with tests=1: on the live
// project the flow's own designer's are.
const T = standIn ? "" : "?tests=1";
const HOUSE = "brickworks";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const browser = await launch({ signedOut: true });
if (standIn) stand.liveCommunity(true);

/// A browser of [width] in [theme]: the stand-in's site with a new account
/// ([fresh], kept by the stand-in as it goes), or the deployment's, signed
/// in as [as] when given.
async function context({ width = 1280, theme = "dark", fresh = null, as = null } = {}) {
  const phone = width < 600;
  const made = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (standIn) {
    await stand.serveSite(made, { web: path.join(root, "web"), api: path.join(root, "api"), state: fresh ? { fresh } : {} });
  }
  if (as) {
    await made.addInitScript(([name, value]) => {
      try {
        if (!sessionStorage.getItem("flow.seeded") && !localStorage.getItem(name)) localStorage.setItem(name, value);
        sessionStorage.setItem("flow.seeded", "1");
      } catch {}
    }, [session.STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}
const fresh = () => ({ aged: false, profile: null, follows: new Set() });

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

/// A picture of the page, or of the open dialog, in its theme and the other.
async function shots(page, name, theme) {
  const other = theme === "dark" ? "light" : "dark";
  for (const [shown, last] of [[theme, false], [other, true]]) {
    await page.emulateMedia({ colorScheme: shown });
    await page.waitForTimeout(150);
    const open = await page.$("dialog[open]");
    await (open ? open.screenshot({ path: path.join(out, `${name}-${shown}.png`), timeout: 60000 })
      : page.screenshot({ path: path.join(out, `${name}-${shown}.png`), fullPage: true, timeout: 90000 }))
      .catch((trouble) => console.log(`  --    no picture ${name}-${shown}: ${String(trouble).split("\n")[0]}`));
    if (last) await page.emulateMedia({ colorScheme: theme });
  }
}
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(250);
  }
}

async function api(pathname, { method = "GET", token, body, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

/// First steps as drawn: which step, its count, and what it offers.
const stepsDrawn = (page) => page.evaluate(() => {
  const dialog = document.querySelector("dialog.first-steps[open]");
  if (!dialog) return { open: false };
  return { open: true, step: dialog.dataset.step || "", count: dialog.querySelector(".eyebrow")?.textContent || "",
    title: dialog.querySelector("h2")?.textContent || "",
    designers: [...dialog.querySelectorAll(".person-row")].map((row) => row.dataset.handle),
    models: [...dialog.querySelectorAll(".models .model")].map((card) => card.dataset.id),
    kinds: [...dialog.querySelectorAll(".kinds button.pill")].map((pill) => pill.dataset.kind),
    feed: dialog.querySelector("#first-feed")?.getAttribute("href") || "", done: Boolean(dialog.querySelector("#first-done")),
    handle: dialog.querySelector("#first-handle")?.value ?? null,
    avatar: (dialog.querySelector(".face-row .avatar")?.textContent || "").trim(),
    address: dialog.querySelector(".face-row p")?.textContent || "",
    tooWide: dialog.scrollWidth > dialog.clientWidth + 1 };
});

/// The feed as drawn: its posts, and whether Latest stands in for them.
const feedDrawn = (page) => page.evaluate(() => ({
  state: document.documentElement.dataset.feed || "",
  rows: [...document.querySelectorAll("#rows .feed-row")].map((li) => ({ kind: li.dataset.kind,
    who: li.querySelector("a.who")?.getAttribute("href") || "", card: li.querySelector("article.model")?.dataset.id || "" })),
  designers: [...document.querySelectorAll("#people .person-row")].map((li) => li.dataset.handle),
  latest: [...document.querySelectorAll("#latest-models .model")].map((card) => ({ id: card.dataset.id,
    who: card.querySelector("a.who")?.getAttribute("href") || "" })),
  latestShown: !document.getElementById("latest").hidden,
}));

/// Signs in from the dialog that is open: the address, Email me a code, the
/// code, Sign in. The stand-in takes any code; a deployment one minted here.
async function signIn(page, email) {
  await page.waitForSelector("dialog.sign-in[open]", { timeout: 15000 });
  await page.fill("dialog.sign-in input", email);
  await page.click('dialog.sign-in button[type="submit"]');
  await until(page, () => /The code sent to/.test(document.querySelector("dialog.sign-in label")?.textContent || ""), "a code asked for");
  await page.fill("dialog.sign-in input", standIn ? "123456" : await session.mintCode(email));
  await page.click('dialog.sign-in button[type="submit"]');
}

/// The age question, answered: 30 years old.
async function answerAge(page) {
  await page.waitForSelector("dialog.age[open]", { timeout: 30000 });
  await page.selectOption("#age-month", "3");
  await page.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
  await page.click("#age-go");
}

/// Waits for First steps at [step] and says what it shows.
async function atStep(page, step, label) {
  await until(page, (want) => document.querySelector("dialog.first-steps[open]")?.dataset.step === want, `First steps at ${step} (${label})`, 30, step);
  return stepsDrawn(page);
}

// --- the live project: Ada, a designer with a castle --------------------------
const accounts = [];
let ada = null;
let castle = "";
let designer = HOUSE;
async function makeAda() {
  const email = `delivered+bw-first-ada-${rand}@resend.dev`;
  accounts.push(email);
  ada = await session.mintSession(email);
  designer = `bwfs-ada-${rand}`;
  const made = await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: designer, name: "Ada First" } });
  const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
  const name = `First Steps Castle ${rand}`;
  const model = `0 ${name}\r\n0 Name: first.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
    + `1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // first steps flow ${rand}\r\n`;
  const shared = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name, author: "Ada First", model, image: picture, listed: true, kind: "castle" } });
  castle = shared.body.id || "";
  // One build of it finished, so Top builds puts her among the first designers.
  const built = castle ? await api(`/api/share?op=built&id=${castle}`, { method: "POST", body: { device: randomBytes(16).toString("hex") },
    extra: { "user-agent": `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`,
      "sec-fetch-site": "same-origin" } }) : { body: {} };
  check(`Ada, a designer: her profile ${made.status}, her castle in the gallery ${shared.status} /m/${castle}, a build of it `
    + `${built.body.counted}`, made.status === 200 && shared.status === 201 && Boolean(castle) && built.body.counted === true);
}

try {
  if (!standIn) await makeAda();

  // --- 1. a first visit ---------------------------------------------------------
  console.log("a first visit");
  for (const [width, theme] of [[390, "light"], [1280, "dark"]]) {
    const visitor = await context({ width, theme });
    const page = await visitor.newPage();
    listen(page, `visitor ${width}`);
    await page.goto(`${site}/feed${T}`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.feed === "signed-out" && !document.getElementById("designers").hidden,
      "the signed-out feed with designers to follow");
    const drawn = await feedDrawn(page);
    check(`feed at ${width}: ${designer} suggested to follow (${drawn.designers.join(", ")}), Latest ${drawn.latest.length} cards`,
      drawn.designers.includes(designer) && drawn.latestShown && drawn.latest.length > 0);
    if (standIn) {
      check(`...every Latest card links to the house's profile (${drawn.latest.filter((one) => one.who === `/u/${HOUSE}`).length} of ${drawn.latest.length})`,
        drawn.latest.length === 7 && drawn.latest.every((one) => one.who === `/u/${HOUSE}`));
    }
    check("...nothing sideways", !(await sideways(page)));
    await shots(page, `1_feed-${width}`, theme);
    if (standIn) {
      await page.goto(`${site}/gallery`, { waitUntil: "load" });
      await until(page, () => document.querySelectorAll("#models .model").length >= 7, "the gallery's cards");
      const cards = await page.evaluate(() => [...document.querySelectorAll("#models .model")].map((card) => ({ id: card.dataset.id,
        who: card.querySelector("a.who")?.getAttribute("href") || "", face: Boolean(card.querySelector(".who .avatar")),
        made: card.dataset.made || "", mark: card.querySelector(".marks .pill.made")?.textContent || "" })));
      check(`gallery at ${width}: every card links to a profile, with its avatar (${cards.filter((one) => one.who === `/u/${HOUSE}` && one.face).length} of ${cards.length})`,
        cards.length === 7 && cards.every((one) => one.who === `/u/${HOUSE}` && one.face));
      check(`...and every card says it was made with the assistant (${cards.filter((one) => one.made === "assistant" && one.mark === "Assistant").length} of ${cards.length})`,
        cards.every((one) => one.made === "assistant" && one.mark === "Assistant"));
      await shots(page, `1_gallery-${width}`, theme);
      await page.goto(`${site}/u/${HOUSE}`, { waitUntil: "load" });
      const house = await page.evaluate(() => ({ name: document.querySelector(".profile-head h1")?.textContent || "",
        role: document.querySelector(".profile-head [data-role]")?.textContent || "",
        bio: document.querySelector(".person .bio")?.textContent || "",
        pinned: [...document.querySelectorAll(".pinned .model")].map((card) => card.dataset.id),
        banner: document.querySelector(".banner img")?.getAttribute("src") || "",
        models: document.querySelectorAll('[data-panel="models"] .model').length,
        follow: Boolean(document.querySelector(".profile-head button[data-follow]")) }));
      check(`/u/${HOUSE} at ${width}: "${house.name}" (${house.role}), its words say whose it is and that the assistant made its models, `
        + `the castle across the top, ${house.pinned.length} pinned, ${house.models} models`,
      house.name === "Brickworks" && /studio's own account/.test(house.bio) && /designed with the assistant/.test(house.bio)
        && house.banner === "/m/kfpYMjke5U.cutout.png" && house.pinned.join() === "EzEXhtXE2C,8eb6GRvnSV,cGHqpHnEFZ" && house.models === 7
        && house.follow && !(await sideways(page)));
      await shots(page, `1_house-${width}`, theme);
    }
    await visitor.close();
  }

  // --- 2. a first sign-in, every step --------------------------------------------
  console.log("a first sign-in");
  const runs = standIn ? [[390, "dark"], [1280, "light"]] : [[390, "dark"]];
  for (const [width, theme] of runs) {
    const label = `${width} ${theme}`;
    const them = fresh();
    const email = standIn ? "new-builder@example.com" : `delivered+bw-first-bob-${rand}@resend.dev`;
    if (!standIn) accounts.push(email);
    const browserOf = await context({ width, theme, fresh: them });
    const page = await browserOf.newPage();
    listen(page, `first sign-in ${label}`);
    await page.goto(`${site}/feed${T}`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.feed === "signed-out", "the signed-out feed");
    await page.click("#sign-in");
    await signIn(page, email);
    await answerAge(page);
    let drawn = await atStep(page, "profile", label);
    check(`${label}: after the age question, First steps: "${drawn.count}", "${drawn.title}"`,
      drawn.count === "First steps · 1 of 3" && drawn.title === "Make your profile" && !drawn.tooWide);
    await shots(page, `2_profile-${width}`, theme);
    const name = standIn ? "Sam Okafor" : `Bob ${rand}`;
    await page.fill("#first-name", name);
    drawn = await stepsDrawn(page);
    const handle = standIn ? "sam-okafor" : `bob-${rand}`;
    check(`...the handle made from the name as it is typed (${drawn.handle}), the avatar from it ("${drawn.avatar}"), `
      + `its page "${drawn.address}"`, drawn.handle === handle && drawn.avatar === name[0] && drawn.address === `brickworks.diy/u/${handle}`);
    await page.click("#first-make");
    drawn = await atStep(page, "kinds", label);
    check(`...made, and on: "${drawn.count}", "${drawn.title}", ${drawn.kinds.length} kinds as pills`,
      drawn.count === "First steps · 2 of 3" && drawn.kinds.includes("castle") && drawn.kinds.length >= 8);
    if (standIn) check(`...the stand-in kept the profile: @${them.profile?.handle}`, them.profile?.handle === handle);
    else {
      const made = await api(`/api/people?op=profile&handle=${handle}`);
      check(`...the profile is on the live project: ${made.status} "${made.body.name}"`, made.status === 200 && made.body.name === name);
    }
    await page.click('dialog.first-steps .kinds button[data-kind="castle"]');
    check("...a kind chosen is pressed", await page.evaluate(() => document.querySelector('.kinds button[data-kind="castle"]')
      .getAttribute("aria-pressed") === "true"));
    await shots(page, `2_kinds-${width}`, theme);
    await page.click("#first-next");
    drawn = await atStep(page, "start", label);
    const castles = await page.evaluate(() => [...document.querySelectorAll("dialog.first-steps .models .model")]
      .map((card) => card.querySelector("a.open")?.getAttribute("href") || ""));
    check(`...step 3: ${drawn.designers.join(", ")} to follow, ${drawn.models.length} models (${drawn.models.slice(0, 3).join(", ")}), `
      + `See your feed → ${drawn.feed}`, drawn.count === "First steps · 3 of 3" && drawn.designers.includes(designer)
      && drawn.designers.length <= 3 && drawn.models.length >= 1 && drawn.models.length <= 6 && drawn.feed === `/feed${T}` && !drawn.tooWide);
    if (standIn) {
      check(`...six models, the castles first: ${drawn.models.join(", ")}`, drawn.models.length === 6
        && ["kfpYMjke5U", "EzEXhtXE2C"].every((id) => drawn.models.slice(0, 2).includes(id)));
    } else {
      check(`...her castle among them, castles first: ${castles[0]}`, drawn.models.includes(castle) && castles.length > 0);
    }
    await shots(page, `2_start-${width}`, theme);
    const follow = `dialog.first-steps .person-row[data-handle="${designer}"] button[data-follow]`;
    await page.click(follow);
    await until(page, (at) => document.querySelector(at)?.getAttribute("aria-pressed") === "true", "Following", 20, follow);
    check(`...Follow pressed: "${await page.textContent(follow)}"`, (await page.textContent(follow)) === "Following");
    await shots(page, `2_followed-${width}`, theme);
    await page.click("#first-feed");
    await page.waitForURL(`**/feed${T}`, { timeout: 20000 });
    await until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelectorAll("#rows .feed-row").length > 0,
      `the feed, filled (${label})`);
    const feed = await feedDrawn(page);
    const theirs = feed.rows.filter((one) => one.who === `/u/${designer}`);
    check(`...See your feed: ${feed.rows.length} posts, ${theirs.length} of them ${designer}'s with their card, no Latest`,
      theirs.length > 0 && theirs.every((one) => one.card) && !feed.latestShown && (!standIn || theirs.length === 7)
      && (standIn || theirs.some((one) => one.card === castle)) && !(await sideways(page)));
    await shots(page, `2_feed-${width}`, theme);
    await browserOf.close();
  }

  // --- 3. the fewest taps ------------------------------------------------------------
  console.log("the fewest taps to a filled feed");
  {
    const them = fresh();
    const width = standIn ? 390 : 1280;
    const theme = standIn ? "light" : "light";
    let cy = null;
    if (!standIn) {
      const email = `delivered+bw-first-cy-${rand}@resend.dev`;
      accounts.push(email);
      cy = await session.mintSession(email, { age: false });
    }
    const browserOf = await context({ width, theme, fresh: them, as: cy });
    const page = await browserOf.newPage();
    listen(page, "fewest taps");
    if (standIn) {
      await page.goto(`${site}/feed`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.feed === "signed-out", "the signed-out feed");
      await page.click("#sign-in");
      await signIn(page, "cy@example.com");
    } else {
      // Signed in elsewhere and never asked: /profile asks, then First steps.
      await page.goto(`${site}/profile${T}`, { waitUntil: "load" });
    }
    await answerAge(page);
    await atStep(page, "profile", "fewest");
    let taps = 0;
    const tap = async (selector) => {
      taps += 1;
      await page.click(selector);
    };
    await tap("#first-skip");
    await atStep(page, "kinds", "fewest");
    await tap("#first-skip");
    const drawn = await atStep(page, "start", "fewest");
    const follow = `dialog.first-steps .person-row[data-handle="${designer}"] button[data-follow]`;
    await tap(follow);
    await until(page, (at) => document.querySelector(at)?.getAttribute("aria-pressed") === "true", "Following", 20, follow);
    // A new follow's backlog is not new (walk180, W7: a new account that
    // followed the house here had 7 on its avatar at once). Ada's castle was
    // listed before Cy followed her, and Cy has never opened the feed.
    if (cy) {
      const counted = await api("/api/people?op=feed_count", { token: cy.access_token });
      check(`...nothing new on Cy's avatar for her castle, listed before the follow: count ${counted.body.count}, `
        + `feed ${counted.body.feed}`, counted.status === 200 && counted.body.count === 0 && counted.body.feed === 0);
    }
    await tap("#first-feed");
    await page.waitForURL(`**/feed${T}`, { timeout: 20000 });
    await until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelectorAll("#rows .feed-row").length > 0,
      "the feed, filled");
    const feed = await feedDrawn(page);
    check(`at ${width}: Skip, Skip, Follow, See your feed: ${taps} taps to ${feed.rows.length} posts of ${designer}'s `
      + `(suggested ${drawn.designers.join(", ")})`, taps <= 4 && feed.rows.length > 0 && feed.rows.every((one) => one.who === `/u/${designer}`));
    await shots(page, `3_feed-${width}`, theme);
    if (cy) {
      // What she lists after the follow is new.
      const name = `First Steps Tower ${rand}`;
      const model = `0 ${name}\r\n0 Name: tower.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
        + `1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n0 // first steps flow ${rand}\r\n`;
      const shared = await api("/api/share", { method: "POST", token: ada.access_token, body: { name, author: "Ada First",
        model, image: readFileSync(path.join(root, "web/share.png")).toString("base64"), listed: true, kind: "castle" } });
      const counted = await api("/api/people?op=feed_count", { token: cy.access_token });
      check(`...and her tower, listed after it, is: /m/${shared.body.id || "?"} ${shared.status}, count ${counted.body.count}, `
        + `feed ${counted.body.feed}`, shared.status === 201 && counted.body.count === 1 && counted.body.feed === 1);
    }
    await browserOf.close();
  }

  // --- 4. signed in to do something ---------------------------------------------------
  if (standIn) {
    console.log("signed in to follow, from the house's page");
    const them = fresh();
    const browserOf = await context({ width: 1280, theme: "dark", fresh: them });
    const page = await browserOf.newPage();
    listen(page, "pending");
    await page.goto(`${site}/u/${HOUSE}`, { waitUntil: "load" });
    const button = ".profile-head button[data-follow]";
    await until(page, (at) => document.querySelector(at) && !document.querySelector(at).hidden, "Follow on the house's page", 20, button);
    await page.click(button);
    await signIn(page, "dee@example.com");
    await answerAge(page);
    await atStep(page, "profile", "pending");
    await page.click("#first-skip");
    await atStep(page, "kinds", "pending");
    await page.click("#first-skip");
    const drawn = await atStep(page, "start", "pending");
    check(`signed in to follow: First steps end with Done (${drawn.done}), not the feed (${drawn.feed || "none"})`, drawn.done && !drawn.feed);
    await shots(page, "4_start_pending-1280", "dark");
    await page.click("#first-done");
    await until(page, (at) => document.querySelector(at)?.getAttribute("aria-pressed") === "true", "the follow, after First steps", 20, button);
    check(`...closed, and the follow went on: "${await page.textContent(button)}", on ${new URL(page.url()).pathname}`,
      (await page.textContent(button)) === "Following" && new URL(page.url()).pathname === `/u/${HOUSE}` && them.follows.has(HOUSE));
    await browserOf.close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const one of errors.slice(0, 5)) console.log(`        ${one}`);
  if (castle && ada) await api(`/api/share?op=unpublish&id=${castle}`, { method: "POST", token: ada.access_token }).catch(() => {});
  for (const email of accounts) await session.deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `first steps: ${failed} FAILED`
  : "first steps: a first visit meets a designer to follow, a first sign-in makes a profile and fills the feed: ok");
process.exit(failed ? 1 : 0);
