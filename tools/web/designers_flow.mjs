// A designer's page, and their own numbers, in real browsers: the profile of
// somebody with models in the gallery leads with what those models earned
// (builds finished and remixes first, then Tested, comments, models,
// followers), each the sum of what its cards say; the models by Top builds,
// each card with its own builds, remixes and comments and never its views;
// the photos other people posted of their builds. And the designer, signed
// in, sees on their own page and on Account how each model they shared is
// doing over the last 30 days, which nobody else is shown and no cache keeps.
//
//   node --env-file=.env tools/web/relay_server.mjs 9267 --hold=model_opens &
//   node --env-file=.env tools/web/designers_flow.mjs --url=http://127.0.0.1:9267 --out=shots/designers
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/designers_flow.mjs --url=<preview> --out=DIR
//
// Until supabase/designers.sql is applied the local relay holds it in memory
// (--hold=model_opens, tools/web/designers_stand_in.mjs) over the live
// project's tables; on a deployment everything is asked of its API alone,
// with the bypass headers: /api/share and /api/people, nothing else.
// Throwaway accounts at Resend test addresses, so every model here is a test
// model, which only a page asked with tests=1 shows; deleted at the end with
// their models. Nothing is emailed to anybody: a test account's day's email
// is a dry run.
//
//   1. Ada lists a castle (Tested) and a barn, and shares a secret by link.
//      Built on 3, 1 and 1 devices; opened by 4, 1 and 2 visitors. Bob
//      remixes the castle, comments on it and on the barn, and posts a photo
//      of his build of the castle; Ada answers his comment (not counted).
//   2. A visitor, signed out, at 1280 and 390 px: Designer; one row of
//      numbers, 4 builds finished, 1 remix, 2 models, no followers said,
//      each the sum of the cards (and 1 Tested, 2 comments, as the cards
//      say); the castle first; its card "3 built · 1 remix · 1 comment" and
//      Tested, no views anywhere; Bob's photo under Built by others, on the
//      Builds tab; Start with their most built; no numbers of Ada's own,
//      and the page as served has none either.
//   3. Bob, signed in, at 1280 and 390 px: the same page, none of Ada's
//      numbers; asked for them by her handle the API says only that they are
//      not his; asked plainly, it answers his own models, none of hers. He
//      follows her: her followers say 1.
//   4. Ada, signed in, on her own page at 1280 and 390 px: How your models
//      are doing, the castle first, its 4 opens, 3 builds, 1 remix, 1
//      comment, and who built it (Bob, with his photo), and the secret shared
//      by link among them; on Account (/profile) the same.
//   5. Never kept: every answer of ?op=designs says private, no-store, signed
//      in or not; the same address asked by Ada and at once by Bob answers
//      each their own; signed out 401; a handle that is not one 400; the
//      profile's page the same bytes whoever asks.
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
const site = String(args.url || "http://127.0.0.1:9267").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/designers"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const { modelHash } = await import(path.join(root, "api/_directory.js"));
const { encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-designers-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-designers-bob-${rand}@resend.dev`;
const ADA = `bwd-ada-${rand}`;
const BOB = `bwd-bob-${rand}`;
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 designers/${rand}`;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");

/// [count] 2 x 4 bricks, each its own step, carrying its steps.
function model(name, count, colours = [4, 1, 14]) {
  const lines = [`0 ${name}`, `0 Name: designers_${rand}.ldr`, "0 Author: Designers Flow",
    `0 !BRICKWORKS PAGES {"v":1,"steps":${count}}`];
  for (let n = 0; n < count; n++) {
    lines.push(`1 ${colours[n % colours.length]} ${(n % 10) * 80} ${-24 * Math.floor(n / 10)} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  }
  lines.push(`0 // designers flow ${rand} ${name}`);
  return `${lines.join("\r\n")}\r\n`;
}

/// The app's finding of [text] as the Share panel sends it: all four passed.
const finding = (text, count) => ({ v: 1, app: "0.3.0", model: modelHash(text), steps: count, parts: count,
  tests: Object.fromEntries(["stands", "steps", "parts", "whole"].map((name) => [name,
    { ok: true, why: "Checked by the designers flow's model" }])) });

/// A small photo of a build, as a phone would send one.
function photo() {
  const width = 320;
  const height = 240;
  const data = Buffer.alloc(width * height * 4);
  for (let at = 0; at < data.length; at += 4) {
    const x = (at / 4) % width;
    const red = x > 80 && x < 240;
    data[at] = red ? 200 : 40; data[at + 1] = red ? 24 : 90; data[at + 2] = red ? 32 : 160; data[at + 3] = 255;
  }
  return encode({ width, height, data }, 85).data;
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, phone = false, dark = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
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

const shot = (page, name, full = true) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// One request to the deployment's API: {status, body, headers}.
async function api(pathname, { method = "GET", token, body, extra = {} } = {}, again = true) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const said = { status: reply.status, headers: reply.headers, body: await reply.json().catch(() => ({})) };
  // The sign-in service not reached in time (api/_auth.js): once more.
  if (said.status === 503 && again && /sign-in service/.test(String(said.body.error || ""))) {
    await new Promise((done) => setTimeout(done, 1500));
    return api(pathname, { method, token, body, extra }, false);
  }
  return said;
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

/// The pictures [selector] finds, each scrolled to as a person would and
/// waited for: they load lazily, when near the screen.
async function pictures(page, selector) {
  const count = await page.locator(selector).count();
  for (let at = 0; at < count; at++) await page.locator(selector).nth(at).scrollIntoViewIfNeeded().catch(() => {});
  await until(page, (wanted) => [...document.querySelectorAll(wanted)].every((img) => img.complete && img.naturalWidth > 0),
    `the pictures ${selector}`, 30, selector).catch(() => false);
  await page.evaluate(() => window.scrollTo(0, 0));
}

/// [id] built to its last step on [n] devices, as the step player says so.
async function built(id, n) {
  let counted = 0;
  for (let at = 0; at < n; at++) {
    const one = await api(`/api/share?op=built&id=${id}`, { method: "POST", body: { device: randomBytes(16).toString("hex") },
      extra: { "user-agent": PERSON, "sec-fetch-site": "same-origin" } });
    if (one.body.counted === true) counted += 1;
  }
  return counted;
}

/// [id]'s page opened by [n] visitors, each its own browser, as the page
/// itself says so (web/share-page.js).
async function opened(id, n) {
  let counted = 0;
  for (let at = 0; at < n; at++) {
    const one = await api(`/api/share?op=seen&id=${id}`, { method: "POST",
      extra: { "user-agent": `${PERSON} visitor/${at}`, "sec-fetch-site": "same-origin" } });
    if (one.body.counted === true) counted += 1;
  }
  return counted;
}

/// The designer's page as drawn: the band, the cards, the strip, the panel.
const pageDrawn = (page) => page.evaluate(() => {
  // The profile's one row of numbers (api/people.js numbersHtml).
  const tiles = Object.fromEntries([...document.querySelectorAll(".profile .numbers li")].map((li) => [li.dataset.stat,
    { n: li.querySelector("b")?.textContent || "", text: li.textContent.replace(/\s+/g, " ").trim(), shown: !li.hidden }]));
  const cards = [...document.querySelectorAll(".models .model")].map((a) => ({ id: a.dataset.id,
    builds: Number(a.dataset.builds), remixes: Number(a.dataset.remixes), comments: Number(a.dataset.comments),
    said: a.querySelector("small")?.textContent || "", tested: Boolean(a.querySelector(".tested")) }));
  const mine = document.getElementById("designs-mine");
  return {
    eyebrow: document.querySelector(".profile-head [data-role]")?.textContent || "",
    order: Object.keys(tiles), tiles, cards,
    strip: [...document.querySelectorAll(".builds-of figure.build")].map((f) => ({ id: f.id,
      text: f.textContent.replace(/\s+/g, " ").trim(), by: f.querySelector("figcaption a[href^='/u/']")?.getAttribute("href") || "",
      loaded: Boolean(f.querySelector("img")?.complete && f.querySelector("img")?.naturalWidth > 0) })),
    start: document.querySelector(".start-with")?.textContent.replace(/\s+/g, " ").trim() || "",
    build: document.querySelector(".start-with a.cta")?.getAttribute("href") || "",
    mineShown: Boolean(mine && !mine.hidden), mineText: mine?.textContent || "",
    designs: document.documentElement.dataset.designs || "",
    views: /\bviews?\b/.test([...document.querySelectorAll(".models .model small")].map((s) => s.textContent).join(" ")),
  };
});

/// The designer's own numbers as drawn, in [box].
const mineDrawn = (page, box) => page.evaluate((id) => {
  const panel = document.getElementById(id);
  return {
    shown: Boolean(panel && !panel.hidden), state: document.documentElement.dataset.designs || "",
    heading: panel?.querySelector("h2")?.textContent || "", note: panel?.querySelector(".private")?.textContent || "",
    totals: Object.fromEntries([...(panel?.querySelectorAll(".mine-totals li") || [])].map((li) => [li.dataset.earned,
      li.querySelector("b")?.textContent || ""])),
    rows: [...(panel?.querySelectorAll(".design-row") || [])].map((li) => ({ id: li.dataset.id,
      meta: li.querySelector(".design-meta")?.textContent || "",
      n: Object.fromEntries([...li.querySelectorAll("dd[data-kind]")].map((dd) => [dd.dataset.kind, dd.querySelector("b")?.textContent || ""])),
      builders: li.querySelector(".design-builders p")?.textContent.replace(/\s+/g, " ").trim() || "",
      who: [...li.querySelectorAll(".design-builders figcaption a")].map((a) => a.getAttribute("href")),
      loaded: [...li.querySelectorAll(".design-builders img, .pic img")].every((img) => img.complete && img.naturalWidth > 0) })),
  };
}, box);

let ada = null;
let bob = null;
const made = [];
try {
  console.log(`against ${site}`);
  // --- 1. Ada's models, and what came of them -------------------------------
  console.log("Ada lists a castle and a barn, and shares a secret by link; Bob builds, remixes, comments");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const profiles = [await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Designs" } }),
    await api("/api/people?op=profile", { method: "POST", token: bob.access_token, body: { handle: BOB, name: "Bob Builds" } })];
  check(`profiles made: /u/${ADA}, /u/${BOB} (${profiles.map((one) => one.status).join(", ")})`, profiles.every((one) => one.status === 200));
  const NAMES = { castle: `Designers Castle ${rand}`, barn: `Designers Barn ${rand}`, secret: `Designers Secret ${rand}` };
  const ids = {};
  for (const key of ["barn", "secret", "castle"]) {
    const text = model(NAMES[key], 3, key === "barn" ? [15] : [4, 1, 14]);
    const one = await api("/api/share", { method: "POST", token: ada.access_token, body: {
      name: NAMES[key], author: "Ada Designs", model: text, image: picture, listed: key !== "secret",
      ...(key === "castle" ? { tested: finding(text, 3) } : {}) } });
    ids[key] = one.body.id;
    made.push([one.body.id, () => ada]);
    check(`${key} at /m/${one.body.id}: ${one.status}${key === "castle" ? `, Tested ${one.body.tested?.passed}` : ""}`,
      one.status === 201 && Boolean(one.body.id) && (key !== "castle" || one.body.tested?.passed === true));
    await new Promise((done) => setTimeout(done, 300));
  }
  const builds = { castle: await built(ids.castle, 3), barn: await built(ids.barn, 1), secret: await built(ids.secret, 1) };
  const opens = { castle: await opened(ids.castle, 4), barn: await opened(ids.barn, 1), secret: await opened(ids.secret, 2) };
  check(`builds finished ${JSON.stringify(builds)}, opened ${JSON.stringify(opens)}`,
    builds.castle === 3 && builds.barn === 1 && builds.secret === 1 && opens.castle === 4 && opens.barn === 1 && opens.secret === 2);
  const remix = await api("/api/share", { method: "POST", token: bob.access_token, body: {
    name: `Designers Castle, taller ${rand}`, author: "Bob Builds", model: model(`Designers Castle taller ${rand}`, 4),
    image: picture, listed: true, remixed_from: ids.castle } });
  made.push([remix.body.id, () => bob]);
  check(`Bob's remix of the castle: ${remix.status} /m/${remix.body.id}`, remix.status === 201 && remix.body.remixed_from === ids.castle);
  const said = [
    await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: ids.castle, version: 1, body: "Built it with my daughter: the tower is the best part." } }),
    await api("/api/people?op=comment", { method: "POST", token: ada.access_token,
      body: { model: ids.castle, version: 1, body: "Thank you! The flag comes next." } }),
    await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
      body: { model: ids.barn, version: 1, body: "A white barn is a brave choice." } }),
  ];
  check(`Bob comments on the castle and the barn, Ada answers on the castle (${said.map((one) => one.status).join(", ")})`,
    said.every((one) => one.status === 201));
  const jpeg = photo();
  const start = await api("/api/people?op=photo_start", { method: "POST", token: bob.access_token,
    body: { model: ids.castle, type: "image/jpeg", size: jpeg.length } });
  if (start.status === 200) await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: jpeg });
  const kept = await api("/api/people?op=photo", { method: "POST", token: bob.access_token,
    body: { model: ids.castle, ticket: start.body.ticket, words: "Ours, on the kitchen table" } });
  check(`Bob's photo of his castle: ${start.status}, ${kept.status} ${kept.body.id}`, start.status === 200 && kept.status === 201);

  // The JSON a page is drawn from: what her models earned, and each card's.
  const json = await api(`/api/people?op=profile&handle=${ADA}&tests=1`);
  const d = json.body.designer || {};
  check(`?op=profile: ${JSON.stringify({ models: d.models, builds: d.builds, remixes: d.remixes, comments: d.comments, tested: d.tested, followers: d.followers })}`,
    d.models === 2 && d.builds === 4 && d.remixes === 1 && d.comments === 2 && d.tested === 1 && d.followers === 0);
  check(`...its cards by Top builds, with their comments: ${(json.body.models || []).map((one) => `${one.id === ids.castle ? "castle" : "barn"} ${one.builds}/${one.remixes}/${one.comments}`).join(", ")}`,
    (json.body.models || []).map((one) => one.id).join(",") === `${ids.castle},${ids.barn}`
      && json.body.models[0].comments === 1 && json.body.models[1].comments === 1);

  // --- 2. A visitor, signed out -------------------------------------------
  console.log("a visitor, signed out");
  for (const [width, height, phone] of [[1280, 900, false], [390, 844, true]]) {
    const visitor = await context({ width, height, phone });
    const page = await visitor.newPage();
    listen(page, `visitor at ${width} px`);
    await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.designs, "designs.js said");
    const drawn = await pageDrawn(page);
    if (width === 1280) {
      // One row of numbers, builds finished and remixes first; a count of
      // none hidden. Tested and comments are each card's.
      check(`"${drawn.eyebrow}": ${drawn.order.filter((k) => drawn.tiles[k].shown).map((k) => drawn.tiles[k].text).join(" · ")}`,
        drawn.eyebrow === "Designer" && drawn.order.join(",") === "builds,remixes,models,likes,followers,following"
        && drawn.tiles.builds.n === "4" && drawn.tiles.remixes.n === "1" && drawn.tiles.models.n === "2"
        && !drawn.tiles.followers.shown && drawn.tiles.followers.text === "0 followers");
      const sum = (kind) => drawn.cards.reduce((total, one) => total + one[kind], 0);
      check(`each the sum of the cards: builds ${sum("builds")}, remixes ${sum("remixes")}, comments ${sum("comments")}, Tested ${drawn.cards.filter((one) => one.tested).length}`,
        String(sum("builds")) === drawn.tiles.builds.n && String(sum("remixes")) === drawn.tiles.remixes.n
          && sum("comments") === d.comments && drawn.cards.filter((one) => one.tested).length === d.tested);
      check(`the castle first, its card "${drawn.cards[0]?.said}", Tested; the barn's "${drawn.cards[1]?.said}"`,
        drawn.cards[0]?.id === ids.castle && drawn.cards[0].said === "3 built · 1 remix · 1 comment" && drawn.cards[0].tested
          && drawn.cards[1]?.id === ids.barn && drawn.cards[1].said === "1 built · 1 comment" && !drawn.cards[1].tested);
      check("no card says its views", !drawn.views);
      check(`"${drawn.start}" → ${drawn.build}`, /Start with their most built: Designers Castle .*, 3 builds finished, Tested\. Build it/.test(drawn.start)
        && drawn.build === `/app?view=${ids.castle}`);
      // Photos of builds are the Builds tab's.
      await page.click('.profile .tabs a[data-tab="builds"]');
      await page.waitForLoadState("load");
      await pictures(page, ".builds-of figure.build img");
      const built = await pageDrawn(page);
      check(`Built by others: "${built.strip[0]?.text}", by ${built.strip[0]?.by}, its picture loaded`, built.strip.length === 1
        && built.strip[0].id === `photo-${kept.body.id}` && built.strip[0].by === `/u/${BOB}` && /kitchen table/.test(built.strip[0].text)
        && built.strip[0].loaded);
      await shot(page, "1_visitor-1280-builds.png");
      await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.designs, "designs.js said");
    }
    check(`at ${width} px, none of Ada's own numbers (${drawn.designs}), and nothing sideways`,
      !drawn.mineShown && drawn.mineText === "" && drawn.designs === "signed-out" && !(await sideways(page)));
    await shot(page, `${width === 1280 ? "1" : "2"}_visitor-${width}.png`);
    await visitor.close();
  }
  const served = await fetch(`${site}/u/${ADA}?tests=1`, { headers });
  const servedText = await served.text();
  check("the page as served has no numbers of hers but what the cards say", !/Only you see|design-row|mine-totals/.test(servedText)
    && servedText.includes('id="designs-mine"'));

  // --- 3. Bob, signed in ------------------------------------------------------
  console.log("Bob, signed in, on Ada's page");
  for (const [width, height, phone] of [[1280, 900, false], [390, 844, true]]) {
    const bobs = await context({ as: bob, width, height, phone });
    const page = await bobs.newPage();
    listen(page, `Bob at ${width} px`);
    await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.designs, "designs.js said");
    await until(page, () => !document.querySelector("button[data-follow]")?.hidden, "Follow");
    const drawn = await pageDrawn(page);
    check(`at ${width} px Bob sees her page, none of her own numbers (${drawn.designs}), nothing sideways`,
      !drawn.mineShown && drawn.mineText === "" && drawn.designs === "not-mine" && drawn.tiles.builds.n === "4"
        && !(await sideways(page)));
    if (width === 1280) {
      await page.click("button[data-follow]");
      await until(page, () => document.querySelector("button[data-follow]")?.textContent === "Following", "Following");
      const tile = await page.evaluate(() => {
        const li = document.querySelector("[data-followers]");
        return { text: li?.textContent.replace(/\s+/g, " ").trim(), big: li?.querySelector("b")?.textContent };
      });
      check(`he follows her: the tile says "${tile.text}", its number still large`, tile.text === "1 follower" && tile.big === "1");
    }
    await shot(page, `${width === 1280 ? "3" : "4"}_bob-${width}.png`);
    await bobs.close();
  }
  // Bob's own page: a designer's too (his remix is in the gallery), and his
  // photo of her castle under Built, as builds_flow has it.
  const bobsPage = await (await fetch(`${site}/u/${BOB}?tests=1`, { headers })).text();
  const bobsBuilds = await (await fetch(`${site}/u/${BOB}?tab=builds&tests=1`, { headers })).text();
  check("Bob's own page: a designer's too, for his remix, and his photo of her castle under Built", /<span data-role>Designer<\/span>/.test(bobsPage)
    && bobsBuilds.includes('class="builds-made"') && bobsBuilds.includes(`id="photo-${kept.body.id}"`));
  const asHers = await api(`/api/people?op=designs&handle=${ADA}`, { token: bob.access_token });
  check(`Bob asks for Ada's by her handle: ${asHers.status} ${JSON.stringify(asHers.body)}`,
    asHers.status === 200 && JSON.stringify(asHers.body) === '{"mine":false}');
  const his = await api("/api/people?op=designs", { token: bob.access_token });
  const hisIds = (his.body.models || []).map((one) => one.id);
  check(`asked plainly, his own: ${hisIds.join(", ")}, none of hers`, his.status === 200 && his.body.mine === true
    && hisIds.length === 1 && hisIds[0] === remix.body.id && !Object.values(ids).some((id) => hisIds.includes(id))
    && !JSON.stringify(his.body).includes(ids.castle.slice(0, 10)));

  // --- 4. Ada, on her own page and on Account ---------------------------------
  console.log("Ada, signed in, on her own page and on Account");
  const expect = (rows) => {
    const castle = rows.find((one) => one.id === ids.castle) || { n: {} };
    return rows[0]?.id === ids.castle && rows.length === 3 && rows.some((one) => one.id === ids.secret && /Shared by link/.test(one.meta))
      && castle.n.opens === "4" && castle.n.builds === "3" && castle.n.remixes === "1" && castle.n.comments === "1"
      && /Who built it: 1 person posted 1 photo/.test(castle.builders) && castle.who.includes(`/u/${BOB}`)
      && rows.every((one) => one.loaded);
  };
  for (const [width, height, phone] of [[1280, 900, false], [390, 844, true]]) {
    // The site is dark unless the system asks for light: hers at 1280 in
    // dark, at 390 in light.
    const hers = await context({ as: ada, width, height, phone, dark: width === 1280 });
    const page = await hers.newPage();
    listen(page, `Ada at ${width} px`);
    await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    await until(page, () => ["ready", "trouble", "not-mine", "not-yet"].includes(document.documentElement.dataset.designs), "her numbers");
    await pictures(page, "#designs-mine .design-builders img, #designs-mine .design-row .pic img");
    const mine = await mineDrawn(page, "designs-mine");
    const castle = mine.rows.find((one) => one.id === ids.castle) || { n: {} };
    check(`at ${width} px her own page: "${mine.heading}" (${mine.state}), totals ${JSON.stringify(mine.totals)}`,
      mine.shown && mine.state === "ready" && mine.heading === "How your models are doing" && /Only you see this/.test(mine.note)
        && mine.totals.opens === "7" && mine.totals.builds === "5" && mine.totals.remixes === "1" && mine.totals.comments === "2");
    check(`...the castle first, ${JSON.stringify(castle.n)}, "${castle.builders}", the secret among them; nothing sideways`,
      expect(mine.rows) && !(await sideways(page)));
    await shot(page, `${width === 1280 ? "5" : "6"}_ada_own-${width}.png`);
    await page.goto(`${site}/profile`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.profile === "ready", "her Account");
    await pictures(page, "#designs .design-builders img, #designs .design-row .pic img");
    const account = await mineDrawn(page, "designs");
    check(`at ${width} px on Account: "${account.heading}", the same rows (${account.rows.map((one) => one.id).join(", ")})`,
      account.shown && account.heading === "Your models, as a designer" && expect(account.rows) && !(await sideways(page)));
    await page.evaluate(() => document.getElementById("designs").scrollIntoView());
    await shot(page, `${width === 1280 ? "7" : "8"}_ada_account-${width}.png`);
    await hers.close();
  }

  // --- 5. Never kept, and nobody else's ---------------------------------------
  console.log("never kept, and nobody else's");
  const signedOut = await api("/api/people?op=designs");
  const forged = await api("/api/people?op=designs", { token: "not.a.token" });
  const badHandle = await api("/api/people?op=designs&handle=NO!", { token: ada.access_token });
  const hersNow = await api("/api/people?op=designs", { token: ada.access_token });
  const hersAgain = await api("/api/people?op=designs", { token: ada.access_token });
  const bobsAfter = await api("/api/people?op=designs", { token: bob.access_token });
  const all = [signedOut, forged, badHandle, hersNow, hersAgain, bobsAfter, asHers, his];
  check(`signed out ${signedOut.status}, a forged sign-in ${forged.status}, a handle that is not one ${badHandle.status}`,
    signedOut.status === 401 && forged.status === 401 && badHandle.status === 400);
  check(`every answer says ${[...new Set(all.map((one) => one.headers.get("cache-control")))].join(" | ")}`,
    all.every((one) => one.headers.get("cache-control") === "private, no-store"));
  check(`and none came from the CDN (x-vercel-cache: ${[...new Set(all.map((one) => one.headers.get("x-vercel-cache") || "none"))].join(", ")})`,
    all.every((one) => !/HIT|STALE/i.test(one.headers.get("x-vercel-cache") || "")));
  const hersIds = (hersAgain.body.models || []).map((one) => one.id).sort();
  check(`the same address, Ada then Bob at once: hers ${hersIds.length} models, his ${(bobsAfter.body.models || []).length}, each their own`,
    hersIds.join(",") === Object.values(ids).sort().join(",") && (bobsAfter.body.models || []).length === 1
      && bobsAfter.body.models[0].id === remix.body.id);
  const asAda = await (await fetch(`${site}/u/${ADA}?tests=1`, { headers: { ...headers, authorization: `Bearer ${ada.access_token}` } })).text();
  const asNobody = await (await fetch(`${site}/u/${ADA}?tests=1`, { headers })).text();
  check("her page's bytes are the same signed in as hers or not", asAda === asNobody);
  // Vercel's CDN keeps s-maxage for itself and hands a browser what is left
  // (share_probe reads it the same way); on a deployment the CDN answering
  // a second asking is the proof. Only the local relay shows s-maxage.
  const local = /127\.0\.0\.1|localhost/.test(site);
  const shared = await fetch(`${site}/u/${ADA}`, { headers });
  const shown = shared.headers.get("cache-control") || "";
  const sharedBody = await shared.text();
  const again = local ? "" : (await fetch(`${site}/u/${ADA}`, { headers })).headers.get("x-vercel-cache") || "none";
  check(`without tests, kept by the CDN as before (${shown}${again ? `; asked again, ${again}` : ""}) and none of her test models in it`,
    /public/.test(shown) && /max-age=0/.test(shown) && (local ? /s-maxage=30/.test(shown) : /HIT|STALE/.test(again))
      && !sharedBody.includes(ids.castle));
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const [id, who] of made.reverse()) {
    if (id && who()) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who().access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED, ${passed} ok`
  : `designers: what a designer's models earned, and their own numbers for them alone (${passed} checks, all ok)`);
process.exit(failed ? 1 : 0);
