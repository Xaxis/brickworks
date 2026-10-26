// A feed you look at (docs/SOCIAL.md U9), in real browsers: /feed signed
// out shows Latest on Brickworks (the newest models, as the gallery's
// cards) and designers to follow; signed in and following nobody, the
// same under "You follow nobody yet"; Follow pressed on a designer among
// the suggestions, the next load is their posts, each with its picture: a
// new model and a new version as the gallery's card, a photo of a build as
// the photo. At 390 and 1280 px, light and dark.
//
//   node --env-file=.env tools/web/relay_server.mjs 8840 &
//   node --env-file=.env tools/web/feed_flow.mjs --url=http://127.0.0.1:8840 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/feed_flow.mjs --url=<preview> --out=DIR
//
// Against the live project, with throwaway accounts at Resend test
// addresses, deleted at the end with their models: Ada designs a tower
// (one build finished, so Top builds puts her first among the designers),
// then its version 2, and posts a photo of her build of it; Bob, new,
// follows nobody until he follows her from the feed's suggestions. Their
// models are test models, which only a page asked with ?tests=1 shows.
//
//   1. A visitor: the sign-in ask, Latest with Ada's tower among its cards
//      and every picture drawn, Ada among the designers to follow.
//   2. Bob, following nobody: "You follow nobody yet", Latest, Ada to
//      follow, and not himself.
//   3. Follow pressed beside Ada: Following.
//   4. The next load: her version, her photo and her model as posts, newest
//      first, each with its picture drawn (at 390 too), its words and its
//      links, none New (made before he last opened it); no Latest, and Ada
//      no longer suggested.
//   5. The API: latest kept by the CDN for everybody, never with tests=1.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
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
const site = String(args.url || "http://127.0.0.1:8840").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/feed"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const { encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-feed-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-feed-bob-${rand}@resend.dev`;
const ADA = `bwf-ada-${rand}`;
const BOB = `bwf-bob-${rand}`;
const TOWER = `Feed Flow Tower ${rand}`;
// A browser on this site, as the build counter asks (api/share.js built).
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name, extra = "") => `0 ${name}\r\n0 Name: feed.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n${extra}0 // feed flow ${rand} ${name}\r\n`;

function photo() {
  const width = 320;
  const height = 240;
  const data = Buffer.alloc(width * height * 4);
  for (let at = 0; at < data.length; at += 4) {
    const y = Math.floor(at / 4 / width);
    const red = y > 60 && y < 180;
    data[at] = red ? 200 : 30; data[at + 1] = red ? 40 : 120; data[at + 2] = red ? 40 : 90; data[at + 3] = 255;
  }
  return encode({ width, height, data }, 85).data;
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, theme = "dark" } = {}) {
  const phone = width < 500;
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, colorScheme: theme,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try {
        if (!sessionStorage.getItem("flow.seeded") && !localStorage.getItem(name)) localStorage.setItem(name, value);
        sessionStorage.setItem("flow.seeded", "1");
      } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), fullPage: true, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function api(pathname, { method = "GET", token, body, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, cache: reply.headers.get("cache-control") || "", cdn: reply.headers.get("x-vercel-cache") || "",
    body: await reply.json().catch(() => ({})) };
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// Every picture on the page drawn, scrolled to so a lazy one loads: how
/// many there are and which are not drawn.
async function picturesDrawn(page, where) {
  const count = await page.evaluate((at) => document.querySelectorAll(`${at} img`).length, where);
  for (let n = 0; n < count; n += 1) {
    await page.evaluate(([at, k]) => document.querySelectorAll(`${at} img`)[k]?.scrollIntoView({ block: "center" }), [where, n]);
    await page.waitForFunction(([at, k]) => document.querySelectorAll(`${at} img`)[k]?.complete, [where, n], { timeout: 20000 })
      .catch(() => null);
  }
  await page.evaluate(() => scrollTo(0, 0));
  return page.evaluate((at) => ({ count: document.querySelectorAll(`${at} img`).length,
    missing: [...document.querySelectorAll(`${at} img`)].filter((img) => !img.complete || !img.naturalWidth)
      .map((img) => img.getAttribute("src")) }), where);
}

/// The feed as drawn: its posts, the suggestions, and which parts show.
const feedDrawn = (page) => page.evaluate(() => ({
  state: document.documentElement.dataset.feed || "",
  rows: [...document.querySelectorAll("#rows .feed-row")].map((li) => ({ kind: li.dataset.kind, isNew: li.classList.contains("new"),
    what: (li.querySelector(".what")?.textContent || "").replace(/\s+/g, " ").trim(),
    go: li.querySelector("a.go")?.getAttribute("href") || "", who: li.querySelector("a.who")?.getAttribute("href") || "",
    avatar: Boolean(li.querySelector(".post-head .avatar")), said: li.querySelector(":scope > q")?.textContent || "",
    card: li.querySelector("article.model")?.dataset.id || "", photo: li.querySelector(".feed-photo img")?.getAttribute("src") || "",
    picture: li.querySelector("img")?.getAttribute("src") || "" })),
  designers: [...document.querySelectorAll("#people .person-row")].map((li) => li.dataset.handle),
  designersShown: !document.getElementById("designers").hidden,
  latest: [...document.querySelectorAll("#latest-models .model")].map((card) => card.dataset.id),
  latestShown: !document.getElementById("latest").hidden,
  ask: !document.getElementById("signed-out").hidden, nobody: !document.getElementById("nobody").hidden,
  quiet: !document.getElementById("quiet").hidden,
}));

let ada = null;
let bob = null;
const made = [];
try {
  // --- Ada's tower, its build, its version 2, her photo of it -------------
  console.log("Ada designs a tower");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const adaProfile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Feed" } });
  const bobProfile = await api("/api/people?op=profile", { method: "POST", token: bob.access_token, body: { handle: BOB, name: "Bob Feed" } });
  check(`profiles: ${adaProfile.status}, ${bobProfile.status}`, adaProfile.status === 200 && bobProfile.status === 200);
  const tower = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: TOWER, author: "Ada Feed", model: model(TOWER), image: picture, listed: true } });
  const id = tower.body.id;
  made.push([id, ada]);
  check(`her tower in the gallery: ${tower.status} /m/${id}`, tower.status === 201 && Boolean(id));
  const built = await api(`/api/share?op=built&id=${id}`, { method: "POST", body: { device: randomBytes(16).toString("hex") },
    extra: { "user-agent": PERSON, "sec-fetch-site": "same-origin" } });
  check(`a build of it finished: ${JSON.stringify(built.body)}`, built.body.counted === true);
  await new Promise((done) => setTimeout(done, 1200));
  const jpeg = photo();
  const start = await api("/api/people?op=photo_start", { method: "POST", token: ada.access_token,
    body: { model: id, type: "image/jpeg", size: jpeg.length } });
  if (start.status === 200) await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: jpeg });
  const kept = await api("/api/people?op=photo", { method: "POST", token: ada.access_token,
    body: { model: id, ticket: start.body.ticket, words: "Built it on the kitchen table" } });
  check(`her photo of her build: ${start.status}, ${kept.status}`, start.status === 200 && kept.status === 201);
  await new Promise((done) => setTimeout(done, 1200));
  const two = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { id, name: TOWER, author: "Ada Feed", note: "A taller roof", model: model(TOWER, "1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n"),
      image: picture, listed: true } });
  check(`its version ${two.body.version}: ${two.status}`, two.body.version === 2);

  // --- 1. a visitor --------------------------------------------------------
  console.log("a visitor");
  for (const [width, height, theme] of [[390, 844, "light"], [1280, 900, "dark"]]) {
    const visitor = await context({ width, height, theme });
    const page = await visitor.newPage();
    listen(page, `visitor ${width}`);
    await page.goto(`${site}/feed?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.feed === "signed-out", "the signed-out feed");
    const drawn = await feedDrawn(page);
    const pictures = await picturesDrawn(page, "#latest-models");
    check(`signed out at ${width} ${theme}: the ask ${drawn.ask}, Latest ${drawn.latest.length} cards with her tower `
      + `${drawn.latest.includes(id)}, ${pictures.count} pictures, not drawn ${pictures.missing.length}`,
    drawn.ask && drawn.latestShown && drawn.latest.length >= 1 && drawn.latest.includes(id) && pictures.count >= 1
      && pictures.missing.length === 0);
    check(`...designers to follow: ${drawn.designers.slice(0, 5).join(", ")}; nothing sideways`,
      drawn.designersShown && drawn.designers.includes(ADA) && !(await sideways(page)));
    await shot(page, `1_signed_out-${width}-${theme}.png`);
    await visitor.close();
  }

  // --- 2. Bob, following nobody -------------------------------------------
  console.log("Bob, following nobody");
  const bobSite = await context({ as: bob, width: 390, height: 844, theme: "dark" });
  const bobPage = await bobSite.newPage();
  listen(bobPage, "Bob");
  await bobPage.goto(`${site}/feed?tests=1`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.feed === "ready", "Bob's feed");
  await until(bobPage, () => !document.getElementById("designers").hidden, "the designers to follow");
  let drawn = await feedDrawn(bobPage);
  const bobPictures = await picturesDrawn(bobPage, "#latest-models");
  check(`"You follow nobody yet" ${drawn.nobody}, no posts (${drawn.rows.length}), Latest ${drawn.latest.length} cards, `
    + `${bobPictures.missing.length} pictures not drawn`, drawn.nobody && !drawn.quiet && drawn.rows.length === 0 && drawn.latestShown
    && drawn.latest.includes(id) && bobPictures.missing.length === 0);
  check(`Ada to follow, not Bob himself: ${drawn.designers.join(", ")}`, drawn.designers.includes(ADA) && !drawn.designers.includes(BOB));
  await shot(bobPage, "2_nobody-390-dark.png");
  const wide = await context({ as: bob, width: 1280, height: 900, theme: "light" });
  const widePage = await wide.newPage();
  listen(widePage, "Bob at 1280");
  await widePage.goto(`${site}/feed?tests=1`, { waitUntil: "load" });
  await until(widePage, () => document.documentElement.dataset.feed === "ready" && !document.getElementById("designers").hidden,
    "Bob's feed at 1280");
  const rail = await widePage.evaluate(() => {
    const box = document.getElementById("designers").getBoundingClientRect();
    const main = document.querySelector(".feed-main").getBoundingClientRect();
    return { beside: box.left > main.right, top: Math.round(box.top) };
  });
  check(`at 1280 the designers beside the feed (${JSON.stringify(rail)}), nothing sideways`, rail.beside && !(await sideways(widePage)));
  await shot(widePage, "2_nobody-1280-light.png");

  // --- 3. Follow Ada from the suggestions -----------------------------------
  console.log("Bob follows Ada from the suggestions");
  const button = `#people .person-row[data-handle="${ADA}"] button[data-follow]`;
  await bobPage.click(button);
  // Following is drawn at once and its words once the server answers (site275):
  // the button is pressed again when it has.
  await until(bobPage, (at) => document.querySelector(at)?.getAttribute("aria-pressed") === "true"
    && !document.querySelector(at).disabled, "Following, answered", 20, button);
  const said = await bobPage.evaluate((at) => ({ text: document.querySelector(at)?.textContent,
    told: document.querySelector(at)?.parentElement.querySelector(".said")?.textContent.trim() }), button);
  check(`pressed: "${said.text}", "${said.told}"`, said.text === "Following" && /in your feed/.test(said.told || ""));
  const follows = await api(`/api/people?op=follows&handle=${ADA}`, { token: bob.access_token });
  check(`...and he follows her: ${follows.body.you_follow}`, follows.body.you_follow === true);
  await shot(bobPage, "3_followed-390-dark.png");

  // --- 4. the next load: her posts ------------------------------------------
  console.log("the next load");
  for (const [page, width, theme] of [[bobPage, 390, "dark"], [widePage, 1280, "light"]]) {
    await page.goto(`${site}/feed?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelectorAll("#rows .feed-row").length > 0,
      `the posts at ${width}`);
    drawn = await feedDrawn(page);
    const kinds = drawn.rows.map((one) => one.kind).join(", ");
    check(`at ${width}: posts newest first: ${kinds}`, kinds === "version, photo, model");
    const [version, snap, listedRow] = drawn.rows;
    check(`"${version?.what}" → ${version?.go}, "${version?.said}", her card ${version?.card === id}`,
      /^Ada Feed shared version 2 of “Feed Flow Tower/.test(version?.what || "") && version?.go === `/m/${id}/v/2`
        && version?.said === "A taller roof" && version?.card === id && version?.who === `/u/${ADA}` && version?.avatar);
    check(`"${snap?.what}" → ${snap?.go}, the photo ${snap?.photo}`, /^Ada Feed posted a photo of their build of “Feed Flow Tower/.test(snap?.what || "")
      && snap?.go === `/m/${id}#photo-${kept.body.id}` && snap?.photo.endsWith(`op=photo_file&id=${kept.body.id}`)
      && snap?.said === "Built it on the kitchen table");
    check(`"${listedRow?.what}" → ${listedRow?.go}, her card`, /^Ada Feed shared a new model “Feed Flow Tower/.test(listedRow?.what || "")
      && listedRow?.go === `/m/${id}` && listedRow?.card === id);
    const pictures = await picturesDrawn(page, "#rows");
    check(`every post shows its picture: ${drawn.rows.filter((one) => one.picture).length} of ${drawn.rows.length}, `
      + `${pictures.count} drawn, not drawn ${pictures.missing.join(" ") || "none"}`,
    drawn.rows.every((one) => one.picture) && pictures.missing.length === 0);
    check(`no "follow nobody" (${drawn.nobody}), no Latest (${drawn.latestShown}), Ada no longer suggested (${drawn.designers.join(", ") || "none"}), nothing sideways`,
      !drawn.nobody && !drawn.quiet && !drawn.latestShown && !drawn.designers.includes(ADA) && !(await sideways(page)));
    // New is what came since he last opened his feed: she made these before
    // he opened it following nobody, so following her makes none New.
    check(`none marked New (${drawn.rows.filter((one) => one.isNew).length}): made before he last opened his feed`,
      drawn.rows.every((one) => !one.isNew));
    await shot(page, `4_posts-${width}-${theme}.png`);
    await page.emulateMedia({ colorScheme: theme === "dark" ? "light" : "dark" });
    await shot(page, `4_posts-${width}-${theme === "dark" ? "light" : "dark"}.png`);
  }
  // A post's name opens the thing.
  await widePage.click(`#rows .feed-row[data-kind="version"] a.go`);
  await widePage.waitForURL(`**/m/${id}/v/2`, { timeout: 20000 });
  check(`the version's name opens ${new URL(widePage.url()).pathname}`, new URL(widePage.url()).pathname === `/m/${id}/v/2`);
  await bobSite.close();
  await wide.close();

  // --- 5. the API -------------------------------------------------------------
  // Vercel's CDN keeps s-maxage for itself and hands a browser what is left
  // (public, max-age=0): on a deployment the CDN answering again is the proof,
  // as challenges_flow and share_probe have it.
  const local = /127\.0\.0\.1|localhost/.test(site);
  const open = await api("/api/people?op=latest");
  const again = local ? null : await api("/api/people?op=latest");
  const asked = await api("/api/people?op=latest&tests=1");
  check(`latest: ${open.status} kept by the CDN ("${open.cache}"${local ? "" : `; asked again: ${again.cdn || "none"}`}); with tests=1 never ("${asked.cache}"), her tower in it `
    + `${(asked.body.models || []).some((one) => one.id === id)} and not without (${(open.body.models || []).some((one) => one.id === id)})`,
  open.status === 200 && (local ? /s-maxage=30/.test(open.cache) : /HIT|STALE/.test(again.cdn)) && /no-store/.test(asked.cache)
    && (asked.body.models || []).some((one) => one.id === id) && !(open.body.models || []).some((one) => one.id === id)
    && Array.isArray(open.body.designers) && Array.isArray(open.body.photos));
  const theirs = (asked.body.designers || []).find((one) => one.handle === ADA);
  check(`Ada among the designers by Top builds: ${JSON.stringify(theirs)}`, theirs?.score >= 3 && theirs.models?.[0]?.id === id);
  const signedOutFeed = await api("/api/people?op=feed");
  check(`the feed itself signed out: ${signedOutFeed.status}`, signedOutFeed.status === 401);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const one of errors.slice(0, 5)) console.log(`        ${one}`);
  for (const [id, who] of made) {
    if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
  }
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `feed: ${failed} FAILED` : "feed: Latest signed out and following nobody, a follow from the suggestions, posts with pictures: ok");
process.exit(failed ? 1 : 0);
