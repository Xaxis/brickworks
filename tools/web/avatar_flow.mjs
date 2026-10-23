// Your own picture as your avatar, and your likes on your profile
// (docs/SOCIAL.md D11, U5, U6; supabase/avatars.sql), as a person meets
// them, in a real browser at 390 and 1280 px, light and dark.
//
//   node tools/web/avatar_flow.mjs [--out=DIR]                          this checkout, the stand-in's people
//   node --env-file=.env tools/web/relay_server.mjs 8871 --hold=profile_avatars,profile_choices &
//   node --env-file=.env tools/web/avatar_flow.mjs --url=http://127.0.0.1:8871 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/avatar_flow.mjs --url=<preview> --out=DIR
//
// Locally (no --url) nothing leaves this machine: design_stand_in.mjs's
// people. Robin and Priya chose pictures; nobody else did. Robin's picture
// is on their profile's head, on their cards in the gallery, beside their
// name on a model's page and their replies, in Sam's feed; Jo's and Sam's
// avatars are the tiles made from their handles. Robin shows the models
// they liked: a Likes tab of three cards; Sam does not, and has none.
// Then Sam chooses a picture in Edit profile: the circle opens on it,
// the picture is dragged and zoomed, and what is sent is a square JPEG,
// 120 to 400 pixels a side, whose middle is where the circle was put.
//
// With --url: throwaway accounts at Resend test addresses on that site's
// project, deleted by the end. Ada makes a profile and lists a model, Bob
// follows her. Before avatars.sql (a deployment of today) every avatar is
// the tile, Edit profile offers no picture, and asking for one or for
// Likes says it is not open yet. Held by the relay (or once applied): Ada
// chooses a picture in Edit profile, crops it, and it is on her profile,
// her card, her model's page, her comment, Bob's feed and her own header;
// what is refused is refused (signed out, no profile, too big, not a
// picture, too small); she shows her likes and the Likes tab has her
// liked model, she hides them and it is gone; Bob reports her profile and
// the site's owner takes the picture out on /admin, its file deleted;
// she chooses another and takes it off herself; and deleting her account
// deletes its file. A picture taken out or taken off answers 404 at its
// address within PICTURE_KEPT seconds (api/_photo.js: the CDN keeps it
// that long at most), asked every second until then.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { decodePicture, PICTURE_KEPT } from "../../api/_photo.js";
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
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const site = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "shots/avatar";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const widths = [390, 1280];
const themes = ["light", "dark"];
const ID = /^[A-Za-z0-9]{10}$/;
const PICTURED = /^\/api\/people\?op=avatar&id=[A-Za-z0-9]{10}$/;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
}
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const until = (page, test, arg = null, timeout = 20000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);

const browser = await launch({ signedOut: true });

/// A page of the site at [width] in [theme], signed in with [session]
/// ([key, value, access]) or not.
async function open(pathname, { width = 1280, theme = "light", session = null, label, route = null }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api") });
  // After the stand-in's: the route made last is asked first.
  if (route) await route(context);
  if (session) {
    await context.addInitScript(([key, value, access]) => {
      try {
        if (!localStorage.getItem(key)) localStorage.setItem(key, value);
        if (access && !sessionStorage.getItem("brickworks.access")) sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, session);
  }
  const page = await context.newPage();
  page.on("dialog", (dialog) => dialog.accept().catch(() => {}));
  listen(page, label);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 60000 });
  return { page, context };
}

/// Every avatar in [scope] as drawn: [{pictured, loaded, round, size, where}].
async function avatars(page, scope = "body") {
  await page.evaluate(async () => {
    for (const img of document.querySelectorAll(".avatar img")) img.loading = "eager";
    await Promise.race([Promise.all([...document.querySelectorAll(".avatar img")].map((img) => img.decode().catch(() => {}))),
      new Promise((done) => setTimeout(done, 8000))]);
  });
  return page.evaluate((at) => [...document.querySelectorAll(`${at} .avatar`)].filter((one) => one.getClientRects().length)
    .map((one) => {
      const img = one.querySelector("img");
      const style = getComputedStyle(one);
      const where = one.closest("[id], .model, .comment, .feed-row, .shared-by, .profile-head, .site-head")
      return { pictured: Boolean(img), loaded: Boolean(img && img.complete && img.naturalWidth > 0),
        src: img ? img.getAttribute("src") : "", round: style.borderTopLeftRadius === "50%" || parseFloat(style.borderTopLeftRadius) >= one.offsetWidth / 2,
        size: Math.round(one.getBoundingClientRect().width), letter: img ? "" : one.textContent.trim(),
        where: where ? (where.id || where.className.split(" ")[0]) : "" };
    }), scope);
}

/// The square [bytes] (a JPEG) decoded: {side, at(x, y) -> [r, g, b]}.
async function square(bytes) {
  const image = await decodePicture(bytes, "image/jpeg", 4 * 1048576);
  return { width: image.width, height: image.height,
    at: (fx, fy) => {
      const x = Math.min(image.width - 1, Math.round(fx * image.width));
      const y = Math.min(image.height - 1, Math.round(fy * image.height));
      return Array.from(image.data.slice((y * image.width + x) * 4, (y * image.width + x) * 4 + 3));
    } };
}
// The portrait's face (design_stand_in.mjs PORTRAIT): 233, 190, 160.
const skin = ([r, g, b]) => Math.abs(r - 233) < 30 && Math.abs(g - 190) < 30 && Math.abs(b - 160) < 30;

/// In Edit profile: choose the portrait, place the face in the circle
/// (dragged with the mouse or a finger, zoomed with the button), and use
/// it. What was sent, as the page sent it, or null.
async function cropAndUse(page, label) {
  await page.setInputFiles("#avatar-file", { name: "me.jpg", mimeType: "image/jpeg", buffer: stand.PORTRAIT });
  const opened = await until(page, () => document.querySelector("dialog#crop-dialog[open]") && document.querySelector("#crop")?.dataset.zoom);
  if (!check(`${label}: the circle opens on the picture chosen`, opened)) return false;
  // The face is right of the middle (58% of the width): dragged left until
  // it is in the circle's middle, then zoomed in once.
  const box = await page.locator("#crop").boundingBox();
  const perCss = 640 / box.width;
  const fit = 560 / 540;
  const shift = (0.58 * 720 * fit - 360 * fit) / perCss;
  const [x0, y0] = [box.x + box.width / 2, box.y + box.height / 2];
  if (await page.evaluate(() => matchMedia("(pointer: coarse)").matches)) {
    // A finger: the page's own pointer events, as a touch sends them.
    await page.locator("#crop").dispatchEvent("pointerdown", { pointerId: 7, pointerType: "touch", clientX: x0, clientY: y0, isPrimary: true });
    for (let step = 1; step <= 8; step += 1) {
      await page.locator("#crop").dispatchEvent("pointermove", { pointerId: 7, pointerType: "touch",
        clientX: x0 - (shift * step) / 8, clientY: y0, isPrimary: true });
    }
    await page.locator("#crop").dispatchEvent("pointerup", { pointerId: 7, pointerType: "touch", clientX: x0 - shift, clientY: y0 });
  } else {
    await page.mouse.move(x0, y0);
    await page.mouse.down();
    await page.mouse.move(x0 - shift, y0, { steps: 8 });
    await page.mouse.up();
  }
  await page.click('[data-zoom="in"]');
  check(`${label}: zoomed in by the button (${await page.locator("#crop").getAttribute("data-zoom")})`,
    Number(await page.locator("#crop").getAttribute("data-zoom")) > 1.2);
  return true;
}

// ---------------------------------------------------------------------------
// Here, with the stand-in's people.

async function local() {
  console.log("1. Robin's picture, wherever Robin is; the tiles of everybody else");
  for (const width of widths) {
    for (const theme of themes) {
      const tag = `${width} ${theme}`;
      let { page, context } = await open(`/u/${stand.HANDLE}`, { width, theme, label: `Robin ${tag}` });
      let seen = await avatars(page, ".profile-head");
      check(`Robin's page ${tag}: the head's avatar is their picture, loaded and round (${seen[0]?.size} px)`,
        seen[0]?.pictured && seen[0]?.loaded && seen[0]?.round && PICTURED.test(seen[0].src));
      seen = await avatars(page, ".follows");
      check(`Robin's page ${tag}: whom Robin follows, Priya with her picture and Mika with a tile`,
        seen.some((one) => one.pictured && one.loaded) && seen.some((one) => !one.pictured && one.letter === "M"));
      await shot(page, `local_robin_${width}_${theme}.png`);
      await context.close();

      ({ page, context } = await open("/gallery", { width, theme, label: `gallery ${tag}` }));
      await until(page, () => document.querySelectorAll(".models .model").length > 3);
      const cards = await page.evaluate(() => [...document.querySelectorAll(".models .model")].map((card) => ({
        by: card.querySelector(".who span:not(.avatar)")?.textContent || "", pictured: Boolean(card.querySelector(".who .avatar img")) })));
      const robins = cards.filter((one) => one.by === "Robin Castell");
      const mikas = cards.filter((one) => one.by === "Mika Tanaka");
      check(`gallery ${tag}: Robin's ${robins.length} cards with their picture, Mika's ${mikas.length} with the tile`,
        robins.length > 0 && robins.every((one) => one.pictured) && mikas.length > 0 && mikas.every((one) => !one.pictured));
      seen = await avatars(page, ".models");
      check(`gallery ${tag}: every picture on a card loaded`, seen.filter((one) => one.pictured).every((one) => one.loaded));
      await shot(page, `local_gallery_${width}_${theme}.png`);
      await context.close();
    }
  }
  const sam = (() => {
    const kept = stand.signedInStorage();
    return [STORAGE_KEY, JSON.stringify(kept.session), JSON.stringify(kept.access)];
  })();
  for (const width of widths) {
    const { page, context } = await open(`/m/${stand.MODEL_ID}`, { width, theme: "dark", session: sam, label: `model ${width}` });
    await until(page, () => document.querySelectorAll(".comment").length > 2, null, 30000);
    const seen = await avatars(page, "main");
    const by = seen.find((one) => one.where === "shared-by");
    check(`model page ${width}: its designer beside its name with their picture`, by?.pictured && by?.loaded);
    const comments = await page.evaluate(() => [...document.querySelectorAll(".comment")].map((one) => ({
      who: one.querySelector(".comment-head a, .who a, a")?.textContent?.trim() || "",
      pictured: Boolean(one.querySelector(":scope > .avatar img, .avatar img")) })));
    check(`model page ${width}: Robin's and Priya's comments with their pictures, Jo's with the tile`,
      comments.some((one) => /Robin/.test(one.who) && one.pictured) && comments.some((one) => /Priya/.test(one.who) && one.pictured)
      && comments.some((one) => /Jo/.test(one.who) && !one.pictured));
    const header = await avatars(page, ".site-head");
    check(`model page ${width}: Sam's own avatar in the header, the tile (Sam chose none)`,
      header.length > 0 && header.every((one) => !one.pictured && one.letter === "S"));
    await page.locator(".comment").first().scrollIntoViewIfNeeded();
    await shot(page, `local_model_${width}_dark.png`);
    await context.close();
  }
  for (const width of widths) {
    const { page, context } = await open("/feed", { width, theme: "light", session: sam, label: `feed ${width}` });
    await until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelectorAll(".feed-row").length > 0);
    const seen = await avatars(page, "#rows, .feed-rows, main");
    check(`feed ${width}: a post by somebody with a picture shows it (${seen.filter((one) => one.pictured).length} of ${seen.length})`,
      seen.some((one) => one.pictured && one.loaded) && seen.some((one) => !one.pictured));
    await shot(page, `local_feed_${width}_light.png`);
    await context.close();
  }

  console.log("2. Likes: Robin chose to show them; Sam did not");
  for (const width of widths) {
    for (const theme of themes) {
      const tag = `${width} ${theme}`;
      let { page, context } = await open(`/u/${stand.HANDLE}?tab=likes`, { width, theme, label: `Robin's likes ${tag}` });
      const said = await page.evaluate(() => ({
        tabs: [...document.querySelectorAll(".work .tabs a")].map((a) => [a.dataset.tab, a.querySelector(".n")?.textContent || "",
          a.getAttribute("aria-current") === "page"]),
        panel: document.querySelector(".tab-panel")?.dataset.panel, cards: [...document.querySelectorAll(".tab-panel .model a.open")]
          .map((a) => a.textContent.trim()) }));
      check(`Robin's Likes ${tag}: the tab shown, counted 3, its three cards newest first (${said.cards.join(", ")})`,
        said.panel === "likes" && said.tabs.some(([id, n, on]) => id === "likes" && n === "3" && on)
        && said.cards.join("|") === "Gatehouse Starter|Pocket Mech|Lunar Rover");
      await page.locator(".work").scrollIntoViewIfNeeded();
      await shot(page, `local_likes_${width}_${theme}.png`);
      await context.close();
      ({ page, context } = await open("/u/sam-builds?tab=likes", { width, theme, label: `Sam ${tag}` }));
      const sams = await page.evaluate(() => ({ tabs: [...document.querySelectorAll(".work .tabs a")].map((a) => a.dataset.tab),
        panel: document.querySelector(".tab-panel")?.dataset.panel }));
      check(`Sam's page ${tag}: no Likes tab, and ?tab=likes opens another (${sams.panel})`,
        !sams.tabs.includes("likes") && sams.panel !== "likes");
      await context.close();
    }
  }

  console.log("3. Sam chooses a picture: the circle, dragged and zoomed, and the square it sends");
  for (const width of widths) {
    for (const theme of themes) {
      const tag = `${width} ${theme}`;
      let sent = null;
      const { page, context } = await open("/profile", { width, theme, session: sam, label: `Sam ${tag}`,
        route: (made) => made.route((url) => url.pathname === "/api/people" && url.searchParams.get("op") === "avatar", async (route) => {
          if (route.request().method() !== "POST") return route.fallback();
          sent = JSON.parse(route.request().postData() || "{}");
          return route.fulfill({ status: 200, contentType: "application/json",
            body: JSON.stringify({ ready: true, picture: "/api/people?op=avatar&id=FacePriya1", removed: false }) });
        }) });
      await until(page, () => document.documentElement.dataset.profile === "ready");
      await page.click("#edit");
      await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
      check(`Sam ${tag}: Edit profile offers Choose a picture, beside the tile`, await page.isVisible("#avatar-choose")
        && !(await page.isVisible("#avatar-remove")) && (await avatars(page, "#edit-dialog"))[0]?.pictured === false);
      await shot(page, `local_edit_${width}_${theme}.png`);
      if (await cropAndUse(page, `Sam ${tag}`)) {
        await shot(page, `local_crop_${width}_${theme}.png`);
        await page.click('[data-crop="use"]');
        await until(page, () => document.querySelector("#avatar-edit img"));
        const made = sent && sent.type === "image/jpeg" ? await square(Buffer.from(String(sent.picture || ""), "base64")).catch(() => null) : null;
        check(`Sam ${tag}: sent a square JPEG of ${made?.width} x ${made?.height}, 120 to 400 a side`,
          made && made.width === made.height && made.width >= 120 && made.width <= 400);
        check(`Sam ${tag}: its middle is the face put in the circle (${made?.at(0.5, 0.5)})`, made && skin(made.at(0.5, 0.5)));
        check(`Sam ${tag}: the picture at once, in Edit profile and on the page's head, with Remove the picture`,
          (await avatars(page, "#edit-dialog"))[0]?.pictured && (await avatars(page, ".profile-head"))[0]?.pictured
          && await page.isVisible("#avatar-remove"));
        await shot(page, `local_chosen_${width}_${theme}.png`);
      }
      // Too big, and not a picture: said in the dialog, nothing sent.
      sent = null;
      await page.setInputFiles("#avatar-file", { name: "huge.jpg", mimeType: "image/jpeg", buffer: Buffer.alloc(9 * 1048576, 1) });
      const big = await until(page, () => /at most 8 MB/.test(document.getElementById("avatar-note")?.textContent || ""), null, 5000);
      await page.setInputFiles("#avatar-file", { name: "notes.txt", mimeType: "text/plain", buffer: Buffer.from("hello") });
      const words = await until(page, () => /not a JPEG, a PNG or a WebP/.test(document.getElementById("avatar-note")?.textContent || ""), null, 5000);
      check(`Sam ${tag}: 9 MB and a text file refused in words, nothing sent`, big && words && sent === null);
      await context.close();
    }
  }
}

// ---------------------------------------------------------------------------
// On a site and its live database, with throwaway accounts.

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const type = reply.headers.get("content-type") || "";
  return { status: reply.status, type, json: type.includes("json") ? await reply.json().catch(() => null) : null,
    bytes: type.startsWith("image/") ? Buffer.from(await reply.arrayBuffer()) : null };
}

/// Picture [address], taken out or taken off when [since] (ms): asked every
/// second until it answers 404, for the PICTURE_KEPT seconds the CDN may
/// keep it and 2 more for the asking. {status, waited} in seconds.
async function goneBy(address, since) {
  for (;;) {
    const { status } = await api(address);
    const waited = (Date.now() - since) / 1000;
    if (status === 404 || waited > PICTURE_KEPT + 2) return { status, waited: waited.toFixed(1) };
    await new Promise((done) => setTimeout(done, 1000));
  }
}

/// What the relay holds of the avatars bucket, or null where nothing is held.
const heldFiles = async () => (remote ? fetch(`${site}/__held_storage/list/avatars`, { headers })
  .then((a) => (a.ok && /json/.test(a.headers.get("content-type") || "") ? a.json() : null)).catch(() => null) : null);

async function deployed() {
  const rand = randomBytes(4).toString("hex");
  const adaEmail = `delivered+bw-avatar-ada-${rand}@resend.dev`;
  const bobEmail = `delivered+bw-avatar-bob-${rand}@resend.dev`;
  const ADA = `avatar-ada-${rand}`;
  const BOB = `avatar-bob-${rand}`;
  let ada = null;
  let bob = null;
  let model = "";
  const asAda = () => [STORAGE_KEY, JSON.stringify(ada.kept), JSON.stringify({ token: ada.access_token,
    until: Date.now() + 50 * 60 * 1000, email: ada.kept.email })];
  const asBob = () => [STORAGE_KEY, JSON.stringify(bob.kept), JSON.stringify({ token: bob.access_token,
    until: Date.now() + 50 * 60 * 1000, email: bob.kept.email })];
  try {
    console.log("1. Ada makes a profile and lists a model; Bob follows her");
    [ada, bob] = await Promise.all([mintSession(adaEmail), mintSession(bobEmail)]);
    let r = await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Avatar" } });
    check(`Ada's profile: ${r.status}`, r.status === 200);
    const before = await api("/api/people?op=avatar", { method: "POST", token: bob.access_token,
      body: { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" } });
    r = await api("/api/people?op=profile", { method: "POST", token: bob.access_token, body: { handle: BOB, name: "Bob Avatar" } });
    check(`Bob's profile: ${r.status}`, r.status === 200);
    r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `Avatar Castle ${rand}`, author: "Ada Avatar",
      model: readFileSync(path.join(root, "models", "castle.ldr"), "utf8"), image: readFileSync(path.join(root, "web/share.png")).toString("base64"),
      listed: true, kind: "castle", tags: "avatar flow", licence: "cc-by-4.0" } });
    model = r.json?.id || "";
    check(`listed her castle: ${r.status} ${model}`, r.status === 201 && ID.test(model));
    r = await api("/api/people?op=follow", { method: "POST", token: bob.access_token, body: { handle: ADA, on: true } });
    check(`Bob follows Ada: ${r.status}`, r.status === 200);
    const comment = await api("/api/people?op=comment", { method: "POST", token: ada.access_token,
      body: { model, version: 1, body: "Built to be built: the gate first." } });
    check(`Ada comments on her castle: ${comment.status}`, comment.status === 201);
    const me = await api("/api/people?op=me", { token: ada.access_token });
    const ready = me.json?.avatar?.ready === true;
    console.log(`  --    ${ready ? "avatars.sql is held here or applied" : "avatars.sql is not applied here"}`);

    if (!ready) {
      console.log("2. Before avatars.sql: the tile everywhere, and pictures and Likes not open yet");
      r = await api("/api/people?op=avatar", { method: "POST", token: ada.access_token,
        body: { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" } });
      check(`a picture: ${r.status} "${r.json?.error}"`, r.status === 503 && /not open on Brickworks yet/.test(r.json?.error || ""));
      r = await api("/api/people?op=likes_choice", { method: "POST", token: ada.access_token, body: { shows: true } });
      check(`showing her likes: ${r.status} "${r.json?.error}"`, r.status === 503 && /not open on Brickworks yet/.test(r.json?.error || ""));
      for (const width of widths) {
        for (const theme of themes) {
          const tag = `${width} ${theme}`;
          const { page, context } = await open("/profile", { width, theme, session: asAda(), label: `Ada ${tag}` });
          await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
          await page.click("#edit");
          await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
          check(`Ada ${tag}: Edit profile shows the tile and offers no picture yet`, !(await page.isVisible("#avatar-choose"))
            && (await avatars(page, "#edit-dialog"))[0]?.pictured === false);
          check(`Ada ${tag}: no Likes tab`, !(await page.isVisible('#tabs [data-tab="likes"]')));
          await shot(page, `before_edit_${width}_${theme}.png`);
          await context.close();
        }
      }
      const page = await api(`/u/${ADA}?tests=1&tab=likes`);
      check(`her page: ${page.status}, no Likes tab`, page.status === 200 || page.status === 0);
      return;
    }

    console.log("2. Refused: signed out, no profile, too big, not a picture, too small");
    check(`Bob before his profile: ${before.status} "${before.json?.error}"`, before.status === 409);
    const tiny = Buffer.from((await import("../../api/_jpeg.js")).encode({ data: new Uint8Array(100 * 100 * 4).fill(200),
      width: 100, height: 100 }, 90).data);
    for (const [what, token, body, status] of [
      ["signed out", null, { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" }, 401],
      ["3 MB", ada.access_token, { picture: Buffer.alloc(3 * 1048576, 7).toString("base64"), type: "image/jpeg" }, 413],
      ["not a picture", ada.access_token, { picture: Buffer.from("not a picture at all").toString("base64"), type: "image/jpeg" }, 415],
      ["100 x 100", ada.access_token, { picture: tiny.toString("base64"), type: "image/jpeg" }, 422],
    ]) {
      r = await api("/api/people?op=avatar", { method: "POST", token, body });
      check(`refused, ${what}: ${r.status} "${r.json?.error}"`, r.status === status);
    }

    console.log("3. Ada chooses a picture in Edit profile, and crops it to a circle");
    let picture = "";
    {
      const { page, context } = await open("/profile", { width: 1280, theme: "light", session: asAda(), label: "Ada edit" });
      await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
      await page.click("#edit");
      await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
      await shot(page, "edit_1280_light.png");
      if (await cropAndUse(page, "Ada 1280")) {
        await shot(page, "crop_1280_light.png");
        await page.click('[data-crop="use"]');
        check("Ada: her picture at once in Edit profile", await until(page, () => document.querySelector("#avatar-edit img")?.complete
          && document.querySelector("#avatar-edit img").naturalWidth > 0, null, 30000));
        await shot(page, "chosen_1280_light.png");
        await page.click("#cancel");
        check("Ada: on her page's head and in her header at once, no reload", await until(page, () =>
          document.querySelector(".profile-head .avatar img")?.naturalWidth > 0
          && document.querySelector(".site-head .avatar img")?.naturalWidth > 0, null, 20000));
      }
      await context.close();
      const mine = await api("/api/people?op=me", { token: ada.access_token });
      picture = String(mine.json?.avatar?.picture || "");
      check(`op=me: her picture ${picture}`, PICTURED.test(picture) && mine.json?.profile?.picture === picture);
      const file = await api(picture);
      const made = file.bytes ? await square(file.bytes).catch(() => null) : null;
      check(`the picture kept: ${file.status} ${file.type}, ${made?.width} x ${made?.height}, the face in its middle`,
        file.status === 200 && file.type === "image/jpeg" && made?.width === made?.height && made.width <= 400 && skin(made.at(0.5, 0.5)));
    }

    console.log("4. Her picture wherever she is: her page, her card, her model, her comment, Bob's feed");
    for (const width of widths) {
      for (const theme of themes) {
        const tag = `${width} ${theme}`;
        let { page, context } = await open(`/u/${ADA}?tests=1`, { width, theme, label: `her page ${tag}` });
        let seen = await avatars(page, "main");
        check(`her page ${tag}: the head's and her card's avatars are her picture, loaded`,
          seen.some((one) => one.where === "profile-head" || one.size >= 80) && seen.filter((one) => one.pictured).length >= 2
          && seen.filter((one) => one.pictured).every((one) => one.loaded && one.src === picture));
        await shot(page, `ada_${width}_${theme}.png`);
        await context.close();
        ({ page, context } = await open(`/m/${model}`, { width, theme, session: asBob(), label: `her model ${tag}` }));
        await until(page, () => document.querySelectorAll(".comment").length > 0, null, 30000);
        seen = await avatars(page, "main");
        check(`her model ${tag}: beside her name and her comment, her picture (${seen.filter((one) => one.pictured).length})`,
          seen.filter((one) => one.pictured && one.loaded && one.src === picture).length >= 2);
        await shot(page, `model_${width}_${theme}.png`);
        await context.close();
        ({ page, context } = await open("/feed", { width, theme, session: asBob(), label: `Bob's feed ${tag}` }));
        await until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelector(".feed-row"), null, 30000);
        seen = await avatars(page, "main");
        check(`Bob's feed ${tag}: her post with her picture`, seen.some((one) => one.pictured && one.loaded && one.src === picture));
        const header = await avatars(page, ".site-head");
        check(`Bob's feed ${tag}: Bob's own header avatar, the tile`, header.length > 0 && header.every((one) => !one.pictured));
        await shot(page, `feed_${width}_${theme}.png`);
        await context.close();
      }
    }

    console.log("5. Likes: shown when she chooses, gone when she does not");
    r = await api(`/api/people?op=like&id=${model}`, { method: "POST", token: ada.access_token, body: { on: true } });
    check(`she likes her castle: ${r.status}`, r.status === 200);
    let likes = await api(`/api/people?op=likes&handle=${ADA}&tests=1`);
    check(`before she chooses, her likes are nobody's: ${likes.status}`, likes.status === 404);
    {
      const { page, context } = await open("/settings", { width: 390, theme: "dark", session: asAda(), label: "Ada settings" });
      await until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);
      check("Settings: Show the models I liked, off", await page.isVisible("#shows-likes") && !(await page.isChecked("#shows-likes")));
      await page.click("#shows-likes");
      check("Settings: on, and said so", await until(page, () => /Likes tab/.test(document.getElementById("likes-said")?.textContent || "")));
      await page.locator("#privacy-part").scrollIntoViewIfNeeded();
      await shot(page, "settings_390_dark.png");
      await page.reload({ waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);
      check("Settings: still on after a reload", await page.isChecked("#shows-likes"));
      await context.close();
    }
    for (const width of widths) {
      const { page, context } = await open(`/u/${ADA}?tests=1&tab=likes`, { width, theme: "light", label: `her likes ${width}` });
      const said = await page.evaluate(() => ({ panel: document.querySelector(".tab-panel")?.dataset.panel,
        n: document.querySelector('.tabs [data-tab="likes"] .n')?.textContent, cards: [...document.querySelectorAll(".tab-panel .model")].length }));
      check(`her Likes ${width}: the tab, counted ${said.n}, her castle's card`, said.panel === "likes" && said.n === "1" && said.cards === 1);
      await shot(page, `likes_${width}_light.png`);
      await context.close();
    }
    r = await api("/api/people?op=likes_choice", { method: "POST", token: ada.access_token, body: { shows: false } });
    const hidden = await api(`/u/${ADA}?tests=1&tab=likes`);
    const page = await fetch(`${site}/u/${ADA}?tests=1&tab=likes`, { headers }).then((a) => a.text());
    check(`hidden again: ${r.status}, no Likes tab, ?tab=likes another tab`, r.status === 200 && r.json?.shows_likes === false
      && hidden.status !== 500 && !/data-tab="likes"/.test(page) && !/data-panel="likes"/.test(page));
    likes = await api(`/api/people?op=likes&handle=${ADA}&tests=1`);
    check(`and her likes nobody's again: ${likes.status}`, likes.status === 404);

    console.log("6. Bob reports her profile; the site's owner takes the picture out");
    r = await api("/api/people?op=report", { method: "POST", token: bob.access_token, body: { handle: ADA, reason: "offensive" } });
    check(`reported: ${r.status}`, r.status === 200 || r.status === 201);
    if (process.env.MASTER_EMAIL) {
      const master = await mintSession(process.env.MASTER_EMAIL, { age: false });
      const { page, context } = await open("/admin", { width: 1280, theme: "light", label: "admin",
        session: [STORAGE_KEY, JSON.stringify(master.kept), JSON.stringify({ token: master.access_token,
          until: Date.now() + 50 * 60 * 1000, email: master.kept.email })] });
      const row = page.locator(`tr[data-picture="${ADA}"]`);
      const shown = await row.waitFor({ timeout: 30000 }).then(() => true, () => false);
      // Loaded, not only begun: on the relay, or past the CDN's 10 s, the
      // picture is read from storage first, and was still loading when
      // the row appeared.
      check("/admin: her report with her picture to look at", shown && await until(page, (handle) => {
        const img = document.querySelector(`tr[data-picture="${handle}"] img.reported-avatar`);
        return img?.complete && img.naturalWidth > 0;
      }, ADA));
      await row.scrollIntoViewIfNeeded().catch(() => {});
      await shot(page, "admin_1280_light.png");
      if (shown) {
        await row.locator("button", { hasText: "Take the picture out" }).click();
        check("/admin: the picture is out", await until(page, () => /picture is out/.test(document.getElementById("reports-note")?.textContent || "")));
      }
      const outAt = Date.now();
      await context.close();
      const after = await api(`/api/people?op=me`, { token: ada.access_token });
      const gone = await goneBy(picture, outAt);
      check(`her picture after: ${gone.status} in ${gone.waited} s (the CDN keeps it ${PICTURE_KEPT} s at most), op=me says taken out`,
        gone.status === 404 && after.json?.avatar?.picture === null && after.json?.avatar?.removed === true);
      const herPage = await fetch(`${site}/u/${ADA}?tests=1`, { headers }).then((a) => a.text());
      check("her page shows the tile again", !herPage.includes(picture) && /class="avatar huge c\d"/.test(herPage));
      const files = await heldFiles();
      if (files) check(`its file deleted: ${files.length} left in the bucket`, !files.some((one) => picture.endsWith(`${one.name.replace(".jpg", "")}`)));
    } else {
      console.log("  --    no MASTER_EMAIL here: the owner's removal is not run");
    }

    console.log("7. She chooses another, takes it off herself, chooses again, and deletes her account");
    r = await api("/api/people?op=avatar", { method: "POST", token: ada.access_token, body: { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" } });
    const second = String(r.json?.picture || "");
    check(`another: ${r.status} ${second}`, r.status === 200 && PICTURED.test(second) && second !== picture);
    r = await api("/api/people?op=avatar", { method: "POST", token: ada.access_token, body: { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" } });
    const third = String(r.json?.picture || "");
    const replaced = await api(second);
    check(`a third replaces it: ${r.status}, the second's file gone (${replaced.status})`, r.status === 200 && replaced.status === 404);
    let offAt = Date.now();
    {
      const { page, context } = await open("/profile", { width: 390, theme: "dark", session: asAda(), label: "Ada remove" });
      await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
      await page.click("#edit");
      await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
      await shot(page, "edit_390_dark.png");
      await page.click("#avatar-remove");
      check("Ada 390: Remove the picture, and the tile at once", await until(page, () => !document.querySelector("#avatar-edit img")
        && !document.querySelector(".profile-head .avatar img"), null, 20000));
      offAt = Date.now();
      await shot(page, "removed_390_dark.png");
      await context.close();
    }
    const off = await goneBy(third, offAt);
    check(`its file gone: ${off.status} in ${off.waited} s (the CDN keeps it ${PICTURE_KEPT} s at most)`, off.status === 404);
    r = await api("/api/people?op=avatar", { method: "POST", token: ada.access_token, body: { picture: stand.PORTRAIT.toString("base64"), type: "image/jpeg" } });
    const last = String(r.json?.picture || "");
    check(`one more, kept until the account goes: ${r.status}`, r.status === 200 && PICTURED.test(last));
    const deleted = await api("/api/account?op=delete", { method: "POST", token: ada.access_token, body: { confirm: adaEmail } });
    check(`Ada deletes her account: ${deleted.status}, ${deleted.json?.avatars} picture deleted with it`,
      deleted.status === 200 && deleted.json?.avatars === 1);
    const lastFile = await api(last);
    check(`its file after: ${lastFile.status}`, lastFile.status === 404);
    const files = await heldFiles();
    if (files) check(`the bucket holds nothing of hers: ${files.length} files`, files.length === 0);
    // Gone from the sign-in service: there is nobody at her address to delete.
    check("her account gone from the sign-in service", !(await deleteAccount(adaEmail)));
    ada = null;
  } finally {
    if (model && ada) await api(`/api/share?op=unpublish&id=${model}`, { method: "POST", token: ada.access_token }).catch(() => {});
    const gone = [ada ? await deleteAccount(adaEmail) : true, await deleteAccount(bobEmail)];
    check("the throwaway accounts deleted", gone.every(Boolean));
  }
}

try {
  console.log(`avatar flow: ${remote || `${root} (its web/ and api/, the stand-in's people)`}`);
  if (remote) await deployed();
  else await local();
} catch (trouble) {
  check(`ran: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await browser.close();
}
for (const one of [...new Set(errors)]) check(`no script error or refusal: ${one}`, false);
console.log(`${failed ? "FAIL" : "PASS"}: ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
