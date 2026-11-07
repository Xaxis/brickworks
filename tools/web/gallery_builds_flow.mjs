// The gallery's Builds tab, /builds (docs/SOCIAL.md section 7, item 8;
// web/builds.html, api/_builds.js galleryBuilds), in real browsers against
// the real API and the live project's tables:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/gallery_builds_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/gallery_builds_flow.mjs --url=http://127.0.0.1:PORT --out=DIR   # a local relay
//
// Throwaway accounts at Resend test addresses, deleted at the end with what
// they made: Ann designs a model and lists it; Bo, Cy and Di build it and
// post five photos, in this order:
//
//   1. Bo's first          shown
//   2. Cy's first          hidden by Ann, the model's owner: left out
//   3. Bo's second         reported by Di, the report waiting: left out
//   4. Cy's second         shown
//   5. Di's                Di then answers under 13: left out
//
// Then, as anybody sees it:
//   - the API's Builds, newest first, has 4 then 1 of these, each with its
//     model's name and its builder's handle;
//   - at 1280 px, light, signed in as Bo: the page draws them in that order,
//     the tab marked, each card's photo loaded, its model a link to the
//     photo on its page, its builder a link to their profile; the model link
//     opens the model's page at that photo;
//   - at 390 px, dark, signed out: the same order, nothing wider than the
//     phone;
//   - with nothing to show (the API's answer emptied in the browser): the
//     empty tab says what a build is, I built it, and links to the gallery;
//   - the gallery's tabs and the LDraw library's have Builds, before
//     Collections.
//   - each card loads its photo's copy at most 480 px wide (socialtails,
//     2026-11-06), not the whole kept photo: the photos are 1,600 x 1,200,
//     their cards 480 x 360 at 1280 px and on the phone alike; the copy is
//     kept beside the photo when it is posted, and one taken away is made
//     again the first time a card asks; the model's page still shows the
//     photo whole.
//   - each throwaway account is deleted as a person deletes theirs
//     (api/account.js ?op=delete): every photo's file and its copy go.
// Pictures in --out. Without the tab (an older checkout) /builds is not
// there and the API has no op=builds: the flow fails.
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
if (!args.url) {
  console.error("gallery_builds_flow: --url=<a preview or a local relay> (it seeds the real project's tables)");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/gallery_builds"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const { encode } = await import(path.join(root, "api/_jpeg.js"));
const { decodePicture } = await import(path.join(root, "api/_photo.js"));
const rand = randomBytes(3).toString("hex");
const who = ["ann", "bo", "cy", "di"];
const emails = Object.fromEntries(who.map((one) => [one, `delivered+bw-gb-${one}-${rand}@resend.dev`]));
const handles = Object.fromEntries(who.map((one) => [one, `bwgb-${one}-${rand}`]));
const names = { ann: "Ann Builds", bo: "Bo Builds", cy: "Cy Builds", di: "Di Builds" };
const KEEP = `Builds Tab Keep ${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = `0 ${KEEP}\r\n0 Name: keep.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // gallery builds flow ${rand}\r\n`;

/// A photo of a build: a brick on a plain ground, in [colour], as large as
/// the server keeps one (api/_photo.js LONG_SIDE), so a card's copy is
/// smaller than it.
const PHOTO = { width: 1600, height: 1200 };
function photoOf(colour) {
  const { width, height } = PHOTO;
  const data = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const at = (y * width + x) * 4;
      const brick = x > 400 && x < 1200 && y > 500 && y < 900;
      const [r, g, b] = brick ? colour : [228, 226, 220];
      data[at] = r; data[at + 1] = g; data[at + 2] = b; data[at + 3] = 255;
    }
  }
  return encode({ width, height, data }, 85).data;
}

/// The files of the build photos bucket that start [prefix], read with the
/// secret key: [name].
async function stored(prefix) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/list/build-photos`, { method: "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify({ prefix: "", search: prefix, limit: 100 }) });
  if (!reply.ok) throw new Error(`storage build-photos: ${reply.status}`);
  return (await reply.json()).filter((one) => one.id && one.name.startsWith(prefix)).map((one) => one.name);
}

/// A photo as the site serves it ([size]: "card" or ""): its width and height, read from its bytes.
async function served(photo, size = "") {
  const reply = await fetch(`${site}/api/people?op=photo_file&id=${photo}${size ? `&size=${size}` : ""}&asked=${Date.now()}`, { headers });
  if (!reply.ok) return { status: reply.status };
  const image = await decodePicture(Buffer.from(await reply.arrayBuffer()), "image/jpeg");
  return { status: reply.status, width: image.width, height: image.height };
}

async function api(pathname, { method = "GET", token = "", body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})), cache: reply.headers.get("cache-control") || "" };
}

/// [one] posts a photo of [id] with [words]: its id.
async function post(session, id, words, colour) {
  const bytes = photoOf(colour);
  const start = await api("/api/people?op=photo_start", { method: "POST", token: session.access_token,
    body: { model: id, type: "image/jpeg", size: bytes.length } });
  if (start.status !== 200) throw new Error(`photo_start ${start.status} ${JSON.stringify(start.body)}`);
  const put = await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: bytes });
  if (!put.ok) throw new Error(`upload ${put.status}`);
  const made = await api("/api/people?op=photo", { method: "POST", token: session.access_token,
    body: { model: id, ticket: start.body.ticket, words } });
  if (made.status !== 200 && made.status !== 201) throw new Error(`photo ${made.status} ${JSON.stringify(made.body)}`);
  return String(made.body.photo?.id || made.body.id || "");
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, dark = false } = {}) {
  const phone = width < 600;
  const made = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, label) {
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// The Builds tab's cards of model [id] as drawn: each one's photo, links,
/// words and whether its picture loaded.
const cardsOf = (page, id) => page.evaluate((model) => [...document.querySelectorAll(`#models .build-card[data-model="${model}"]`)]
  .map((card) => {
    const img = card.querySelector(".frame img");
    return { id: card.dataset.id, open: card.querySelector("a.open")?.getAttribute("href") || "",
      name: card.querySelector("a.open")?.textContent.trim() || "", who: card.querySelector("a.who")?.getAttribute("href") || "",
      // Its words, as a screen reader has them: the avatar's letter is hidden.
      by: (card.querySelector(".who > span:not(.avatar)") || card.querySelector(".who"))?.textContent.trim() || "",
      said: card.querySelector(".said")?.textContent.trim() || "",
      loaded: Boolean(img && img.complete && img.naturalWidth > 0), alt: img?.alt || "",
      src: img?.getAttribute("src") || "", natural: img ? [img.naturalWidth, img.naturalHeight] : [0, 0] };
  }), id);

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

const sessions = {};
let id = "";
const photos = {};
try {
  console.log(`seeding: ${who.map((one) => handles[one]).join(", ")}`);
  for (const one of who) {
    sessions[one] = await mintSession(emails[one]);
    const made = await api("/api/people?op=profile", { method: "POST", token: sessions[one].access_token,
      body: { handle: handles[one], name: names[one] } });
    if (made.status !== 200) throw new Error(`${one}'s profile: ${made.status} ${JSON.stringify(made.body)}`);
  }
  const shared = await api("/api/share", { method: "POST", token: sessions.ann.access_token,
    body: { name: KEEP, author: names.ann, model, image: picture, listed: true, kind: "castle", tags: ["keep"] } });
  id = shared.body.id || "";
  check(`Ann lists ${KEEP} at /m/${id}`, shared.status === 201 && Boolean(id));
  photos.boFirst = await post(sessions.bo, id, "Bo's first, in red.", [200, 24, 32]);
  photos.cyHidden = await post(sessions.cy, id, "Cy's first, hidden by Ann.", [30, 90, 200]);
  photos.boReported = await post(sessions.bo, id, "Bo's second, reported.", [240, 190, 0]);
  photos.cyShown = await post(sessions.cy, id, "Cy's second: \"the moat\" <b>works</b>.", [20, 140, 60]);
  photos.diYoung = await post(sessions.di, id, "Di's, under 13 since.", [120, 40, 160]);
  check(`five photos posted (${Object.values(photos).join(", ")})`, Object.values(photos).every((one) => /^[A-Za-z0-9]{10}$/.test(one)));
  const kept = await stored(photos.boFirst);
  check(`Bo's first is kept with its card's copy beside it (${kept.join(", ")})`,
    kept.includes(`${photos.boFirst}.jpg`) && kept.includes(`${photos.boFirst}.card.jpg`));
  const hid = await api("/api/people?op=photo_hide", { method: "POST", token: sessions.ann.access_token,
    body: { photo: photos.cyHidden, on: true } });
  check(`Ann hides Cy's first (${hid.status})`, hid.status === 200);
  const reported = await api("/api/people?op=report", { method: "POST", token: sessions.di.access_token,
    body: { photo: photos.boReported, reason: "spam", note: `gallery builds flow ${rand}` } });
  check(`Di reports Bo's second (${reported.status})`, reported.status === 200 || reported.status === 201);
  // As an account answers under 13 (supabase/trust.sql): not shown in public.
  const young = await fetch(`${SUPABASE}/rest/v1/profiles?id=eq.${sessions.di.kept.user_id}`, { method: "PATCH",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json", prefer: "return=minimal" },
    body: JSON.stringify({ over_13: false, age_asked_at: new Date().toISOString() }) });
  check(`Di answers under 13 (${young.status})`, young.ok);
  const wanted = [photos.cyShown, photos.boFirst];

  // --- the API ----------------------------------------------------------------
  console.log("the API's Builds");
  const listed = await api("/api/people?op=builds&page=1&tests=1");
  const ours = (listed.body.photos || []).filter((one) => one.model === id);
  check(`newest first, the hidden, the reported and the under-13 builder's left out: ${JSON.stringify(ours.map((one) => one.id))}`,
    listed.status === 200 && JSON.stringify(ours.map((one) => one.id)) === JSON.stringify(wanted));
  check(`each names its model and its builder (${ours.map((one) => `${one.model_name}/${one.by?.handle}`).join(", ")})`,
    ours.length === 2 && ours.every((one) => one.model_name === KEEP) && ours[0].by?.handle === handles.cy
    && ours[1].by?.handle === handles.bo);
  const whole = (listed.body.photos || []).map((one) => Date.parse(one.at));
  check(`the whole page newest first (${whole.length} photos)`, whole.every((at, n) => n === 0 || whole[n - 1] >= at));

  // --- 1280, light, signed in -------------------------------------------------
  console.log("at 1280 px, light, signed in as Bo");
  {
    const made = await context({ as: sessions.bo });
    const page = await made.newPage();
    listen(page, "1280");
    const opened = await page.goto(`${site}/builds?tests=1`, { waitUntil: "domcontentloaded", timeout: 90000 });
    check(`/builds answers (${opened?.status()})`, opened?.status() === 200);
    await until(page, () => ["ready", "none", "broken"].includes(document.documentElement.dataset.builds), "the builds", 60);
    await until(page, () => [...document.querySelectorAll("#models .build-card img")].slice(0, 8).every((img) => img.complete), "the photos", 30)
      .catch(() => null);
    const cards = await cardsOf(page, id);
    check(`the tab draws Cy's second then Bo's first: ${JSON.stringify(cards.map((one) => one.id))}`,
      JSON.stringify(cards.map((one) => one.id)) === JSON.stringify(wanted));
    check(`each card's model a link to its photo on the model's page (${cards.map((one) => one.open).join(", ")})`,
      cards.length === 2 && cards.every((one) => one.open === `/m/${id}#photo-${one.id}` && one.name === KEEP));
    check(`each card's builder a link to their profile (${cards.map((one) => `${one.who} "${one.by}"`).join(", ")})`,
      cards[0]?.who === `/u/${handles.cy}` && cards[1]?.who === `/u/${handles.bo}` && cards[0]?.by === `Built by ${names.cy}`);
    check(`what they said, as words (${JSON.stringify(cards[0]?.said)})`, cards[0]?.said === "Cy's second: \"the moat\" <b>works</b>.");
    check(`their photos loaded, each named (${cards.map((one) => `${one.loaded} "${one.alt}"`).join(", ")})`,
      cards.every((one) => one.loaded && one.alt === `A build of ${KEEP} by ${one.id === photos.cyShown ? names.cy : names.bo}`));
    check(`each card loads the photo's copy, 480 px wide or less: ${cards.map((one) => `${one.natural.join(" x ")} (${one.src})`).join(", ")}`,
      cards.length === 2 && cards.every((one) => one.src.endsWith("&size=card") && one.natural[0] > 0 && one.natural[0] <= 480
        && one.natural[0] === 480 && one.natural[1] === 360));
    const tab = await page.evaluate(() => document.querySelector('#tabs [aria-current="page"]')?.textContent.trim());
    check(`the Builds tab is marked (${tab})`, tab === "Builds");
    await shot(page, "1_builds_1280_light_in.png");
    await page.click(`#models .build-card[data-id="${photos.cyShown}"] a.open`);
    await page.waitForURL((url) => url.pathname === `/m/${id}`, { timeout: 60000 }).catch(() => null);
    const there = await until(page, (photo) => Boolean(document.getElementById(`photo-${photo}`)), "the photo on its model's page", 60,
      photos.cyShown).catch(() => false);
    check(`its model link opens /m/${id} at the photo (${page.url().replace(site, "")})`, there && page.url().endsWith(`#photo-${photos.cyShown}`));
    // The model's page: its strip's thumb and its Builds the copy, the
    // picture's place the whole photo.
    const strip = await page.evaluate((photo) => {
      const thumb = document.querySelector(`#pictures a.thumb[href="#photo-${photo}"]`);
      const figure = document.querySelector(`#photo-${photo} img`);
      return { thumb: thumb?.querySelector("img")?.getAttribute("src") || "", picture: thumb?.dataset.picture || "",
        figure: figure?.getAttribute("src") || "", natural: figure ? [figure.naturalWidth, figure.naturalHeight] : [0, 0] };
    }, photos.cyShown);
    check(`on its page the strip's thumb is the copy (${strip.thumb}), its picture the whole photo (${strip.picture})`,
      strip.thumb.endsWith("&size=card") && /op=photo_file&(amp;)?id=[A-Za-z0-9]{10}$/.test(strip.picture.replace("&amp;", "&")));
    const whole = await served(photos.cyShown);
    const copy = await served(photos.cyShown, "card");
    check(`the photo whole is ${whole.width} x ${whole.height}, its copy ${copy.width} x ${copy.height}`,
      whole.width === PHOTO.width && whole.height === PHOTO.height && copy.width === 480 && copy.height === 360);
    await made.close();
  }

  // --- 390, dark, signed out --------------------------------------------------
  console.log("at 390 px, dark, signed out");
  {
    const made = await context({ width: 390, dark: true });
    const page = await made.newPage();
    listen(page, "390");
    await page.goto(`${site}/builds?tests=1`, { waitUntil: "domcontentloaded", timeout: 90000 });
    await until(page, () => ["ready", "none", "broken"].includes(document.documentElement.dataset.builds), "the builds", 60);
    const cards = await cardsOf(page, id);
    check(`the same two, in the same order (${JSON.stringify(cards.map((one) => one.id))})`,
      JSON.stringify(cards.map((one) => one.id)) === JSON.stringify(wanted));
    check("nothing wider than the phone", !(await sideways(page)));
    const dark = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    check(`drawn dark (${dark})`, /rgb\((\d+), (\d+), (\d+)\)/.test(dark) && Number(dark.match(/\d+/)[0]) < 40);
    await page.evaluate((photo) => document.querySelector(`#models .build-card[data-id="${photo}"]`)?.scrollIntoView({ block: "center" }),
      photos.cyShown);
    await page.waitForTimeout(400);
    await shot(page, "2_builds_390_dark_out.png");
    const small = await cardsOf(page, id);
    check(`on the phone too, each card's photo the copy (${small.map((one) => one.natural.join(" x ")).join(", ")})`,
      small.length === 2 && small.every((one) => one.src.endsWith("&size=card") && one.natural[0] === 480 && one.natural[1] === 360));

    // --- nothing to show ------------------------------------------------------
    console.log("with nothing to show");
    await page.route(/\/api\/people\?op=builds/, (route) => route.fulfill({ status: 200, contentType: "application/json",
      body: JSON.stringify({ page: 1, photos: [], more: false }) }));
    await page.goto(`${site}/builds`, { waitUntil: "domcontentloaded", timeout: 90000 });
    await until(page, () => ["ready", "none", "broken"].includes(document.documentElement.dataset.builds), "the builds", 60);
    const empty = await page.evaluate(() => {
      const box = document.getElementById("builds-empty");
      return { state: document.documentElement.dataset.builds, shown: Boolean(box && !box.hidden && box.offsetHeight > 0),
        words: box?.textContent.replace(/\s+/g, " ").trim() || "", link: box?.querySelector("a")?.getAttribute("href") || "",
        cards: document.querySelectorAll("#models .model, #models .skeleton").length };
    });
    check(`the empty tab says what a build is and how to add one ("${empty.words.slice(0, 120)}…")`,
      empty.state === "none" && empty.shown && /real bricks/.test(empty.words) && /I built it/.test(empty.words) && empty.cards === 0);
    check(`and links to the gallery (${empty.link})`, empty.link === "/gallery");
    await shot(page, "3_builds_390_dark_empty.png");
    await made.close();
  }

  // --- a photo kept before there were copies ---------------------------------
  console.log("a photo kept before there were copies");
  const dropped = await fetch(`${SUPABASE}/storage/v1/object/build-photos`, { method: "DELETE",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify({ prefixes: [`${photos.boFirst}.card.jpg`] }) });
  const without = await stored(photos.boFirst);
  check(`Bo's first with its copy taken away (${dropped.status}: ${without.join(", ")})`,
    dropped.ok && !without.includes(`${photos.boFirst}.card.jpg`));
  const remade = await served(photos.boFirst, "card");
  const back = await stored(photos.boFirst);
  check(`the first card to ask has a copy made, ${remade.width} x ${remade.height}, and kept (${back.join(", ")})`,
    remade.width === 480 && remade.height === 360 && back.includes(`${photos.boFirst}.card.jpg`));

  // --- a tab of the gallery ---------------------------------------------------
  console.log("a tab of the gallery");
  for (const at of ["/gallery", "/library"]) {
    const html = await (await fetch(`${site}${at}`, { headers })).text();
    const tabs = (html.match(/<nav class="tabs"[\s\S]*?<\/nav>/) || [""])[0];
    const links = [...tabs.matchAll(/<a href="([^"]+)"/g)].map((one) => one[1]);
    check(`${at}'s tabs have Builds before Collections (${links.join(" ")})`,
      links.includes("/builds") && links.indexOf("/builds") === links.indexOf("/collections") - 1);
  }
} catch (trouble) {
  check(`the flow ran to its end (${String(trouble.message || trouble).slice(0, 300)})`, false);
} finally {
  // Each deleted as a person deletes theirs, Ann first: her model's photos'
  // files and their copies go with her (api/account.js ?op=delete).
  for (const one of who) {
    const asked = sessions[one] ? await api("/api/account?op=delete", { method: "POST", token: sessions[one].access_token,
      body: { confirm: emails[one] } }).catch(() => ({ status: 0 })) : { status: 0 };
    if (asked.status !== 200) {
      console.log(`  --    ${emails[one]}: ?op=delete answered ${asked.status}, deleted by the admin API`);
      const gone = await deleteAccount(emails[one]).catch(() => false);
      if (!gone) console.log(`  --    ${emails[one]} was not deleted`);
    }
  }
  if (Object.keys(photos).length) {
    const left = (await Promise.all(Object.values(photos).filter(Boolean).map((one) => stored(one).catch(() => [`${one}?`])))).flat();
    check(`their accounts deleted, no photo's file nor copy is left (${left.join(", ") || "none"})`, left.length === 0);
  }
  await browser.close();
}
check(`no page errors${errors.length ? `: ${errors.slice(0, 4).join(" | ")}` : ""}`, errors.length === 0);
console.log(failed ? `gallery builds flow: ${failed} FAILED` : "gallery builds flow: passed");
process.exit(failed ? 1 : 0);
