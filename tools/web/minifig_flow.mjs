// Make a minifig, as a person meets it (avatarkit, 2026-11-23), with a
// throwaway account (deleted at the end), on a local relay or a preview:
//
//   node --env-file=.env tools/web/relay_server.mjs 11851 --hold=profile_avatars,profile_choices &
//   node --env-file=.env tools/web/minifig_flow.mjs --url=http://127.0.0.1:11851 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/minifig_flow.mjs --url=<preview> --out=DIR
//
// Ada makes a profile, lists a model and comments on it. Edit profile shows
// her the minifig made from her handle and Make a minifig; the maker opens on
// it, she picks a face, long wavy hair in a colour, a print, colours and a
// background, Surprise me changes it, she picks again and saves. Her profile
// and her comment show it as her picture (each under 30 KB), a reload keeps
// it, and the maker opens on it again (its recipe kept, where the column is).
// Then she chooses a picture of her own instead, and removes it: the minifig
// made from her handle again. ?op=avatar&handle= draws that minifig as a
// JPEG. The whole of it at 1280 in dark, the maker at 390 in light; with
// --pictures, the maker, her profile, her comment, the gallery's cards and
// the home's feed at 1280 and 390, dark and light.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { PORTRAIT } from "./design_stand_in.mjs";
import { minifigLayers, minifigOf } from "../../web/card.js";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const work = process.env.BW_TREE || root;
const site = String(args.url || "").replace(/\/+$/, "");
if (!site) throw new Error("--url=<a relay>");
const out = path.resolve(String(args.out || "shots/minifig"));
const pictures = Boolean(args.pictures);
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
mkdirSync(out, { recursive: true });
let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1; else failed += 1;
  return ok;
};
const errors = [];
const listen = (page, who) => {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
};
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const shot = (page, name, clip = null) => page.screenshot({ path: path.join(out, name), timeout: 60000, ...(clip ? { clip } : {}) })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const minifigKey = (handle) => minifigLayers(minifigOf(handle)).map((file) => file.match(/(?:face|hair)-[\w-]+/)?.[0])
  .filter(Boolean).join(" ");
// An avatar's minifig layers or picture, read in the page: page.evaluate(faceOf, selector).
const faceOf = (selector) => {
  const one = document.querySelector(selector);
  if (!one) return null;
  const img = one.querySelector("img");
  return { minifig: one.classList.contains("minifig") ? (one.style.backgroundImage.match(/(?:face|hair)-[\w-]+/g) || []).join(" ") : "",
    layers: (one.style.backgroundImage.match(/\/minifig\/\d+\/[\w-]+\.webp/g) || []), pictured: Boolean(img),
    src: img?.getAttribute("src") || "", loaded: Boolean(img && img.complete && img.naturalWidth > 0) };
};

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const type = reply.headers.get("content-type") || "";
  return { status: reply.status, type, cache: reply.headers.get("cache-control") || "",
    json: type.includes("json") ? await reply.json().catch(() => null) : null,
    bytes: type.startsWith("image/") ? Buffer.from(await reply.arrayBuffer()) : null };
}

const browser = await launch({ signedOut: true });
async function open(pathname, { width = 1280, theme = "dark", session = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (session) {
    await context.addInitScript(([key, value, access]) => {
      try {
        if (!localStorage.getItem(key)) localStorage.setItem(key, value);
        if (access && !sessionStorage.getItem("brickworks.access")) sessionStorage.setItem("brickworks.access", access);
      } catch { /* nothing kept */ }
    }, session);
  }
  const page = await context.newPage();
  page.on("dialog", (dialog) => dialog.accept().catch(() => {}));
  listen(page, label);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 90000 });
  return { page, context };
}

const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-avatarkit-ada-${rand}@resend.dev`;
const ADA = `mfig-ada-${rand}`;
let ada = null;
const asAda = () => [STORAGE_KEY, JSON.stringify(ada.kept), JSON.stringify({ token: ada.access_token,
  until: Date.now() + 50 * 60 * 1000, email: ada.kept.email })];
// What she picks: [group, index in its list].
const PICKS = [["face", 4], ["hair", 1], ["hairColour", 4], ["print", 2], ["torso", 1], ["legs", 4], ["background", 5]];
const picked = { face: "3626cp87", hair: "40251", hairColour: 484, print: "973p18", torso: 1, legs: 0, background: 6 };

async function pick(page) {
  for (const [key, at] of PICKS) await page.locator(`fieldset[data-key="${key}"] label.minifig-tile`).nth(at).click();
}

try {
  console.log("1. Ada makes a profile, lists a model and comments on it");
  ada = await mintSession(adaEmail);
  let r = await api("/api/people?op=profile", { method: "POST", token: ada.access_token, body: { handle: ADA, name: "Ada Minifig" } });
  check(`her profile: ${r.status}`, r.status === 200);
  r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `Minifig Castle ${rand}`, author: "Ada Minifig",
    model: readFileSync(path.join(work, "models", "castle.ldr"), "utf8"), image: readFileSync(path.join(work, "web/share.png")).toString("base64"),
    listed: true, kind: "castle", tags: "minifig flow", licence: "cc-by-4.0" } });
  const model = r.json?.id || "";
  check(`listed her castle: ${r.status} ${model}`, r.status === 201);
  r = await api("/api/people?op=comment", { method: "POST", token: ada.access_token, body: { model, version: 1, body: "My minifig says hello." } });
  check(`commented: ${r.status}`, r.status === 201);
  const me = await api("/api/people?op=me", { token: ada.access_token });
  check(`avatars open here (${me.json?.avatar?.ready})`, me.json?.avatar?.ready === true);

  console.log("2. The default: the minifig made from her handle, as one JPEG at ?op=avatar&handle=");
  r = await api(`/api/people?op=avatar&handle=${ADA}`);
  writeFileSync(path.join(out, "handle_default.jpg"), r.bytes || Buffer.alloc(0));
  check(`?op=avatar&handle=: ${r.status} ${r.type}, ${r.bytes?.length} bytes, "${r.cache}"`,
    r.status === 200 && r.type === "image/jpeg" && r.bytes?.length > 2000 && r.bytes.length < 30 * 1024 && /max-age=86400/.test(r.cache));

  for (const [width, theme] of [[1280, "dark"], [390, "light"], ...(pictures ? [[1280, "light"], [390, "dark"]] : [])]) {
    const tag = `${width} ${theme}`;
    const first = width === 1280 && theme === "dark";
    const { page, context } = await open("/profile", { width, theme, session: asAda(), label: `Ada ${tag}` });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    let head = await page.evaluate(faceOf, "#avatar");
    if (first) {
      check(`${tag}: her profile's avatar is the minifig made from her handle ("${head?.minifig}"), ${head?.layers.length} layers at 256`,
        head?.minifig === minifigKey(ADA) && head.layers.every((one) => one.startsWith("/minifig/256/")) && !head.pictured);
      const layersOk = await page.evaluate(async (files) => (await Promise.all(files.map((f) => fetch(f).then((a) => a.ok && /webp/.test(a.headers.get("content-type") || ""))))).every(Boolean), head?.layers || []);
      check(`${tag}: every layer answers as a WebP`, layersOk);
    }
    await page.click("#edit");
    await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
    if (first) {
      const edit = await page.evaluate(() => ({ make: document.querySelector("#avatar-make")?.textContent,
        shown: !document.querySelector("#avatar-acts")?.hidden, said: document.querySelector("#avatar-said")?.textContent }));
      check(`${tag}: Edit profile offers "${edit.make}" beside Choose a picture ("${edit.said.slice(0, 60)}…")`,
        edit.shown && edit.make === "Make a minifig" && /minifig made from your handle/.test(edit.said));
    }
    await page.click("#avatar-make");
    const opened = await until(page, () => document.querySelector("dialog#minifig-dialog[open] .minifig-tile .avatar.minifig"));
    const drawn = await page.evaluate(() => ({
      groups: [...document.querySelectorAll("#minifig-choices fieldset")].map((f) => [f.dataset.key, f.querySelectorAll("input").length, f.hidden]),
      checked: [...document.querySelectorAll("#minifig-choices input:checked")].length,
      light: document.querySelectorAll("#minifig-light .avatar.minifig").length, dark: document.querySelectorAll("#minifig-dark .avatar.minifig").length,
      wide: document.querySelector("#minifig-dialog").scrollWidth > document.querySelector("#minifig-dialog").clientWidth + 1,
      save: (() => { const b = document.querySelector("#minifig-save").getBoundingClientRect(); return b.bottom <= innerHeight && b.top >= 0; })() }));
    check(`${tag}: the maker opened on her minifig: ${drawn.groups.map(([k, n]) => `${k} ${n}`).join(", ")}; ${drawn.light}+${drawn.dark} sizes; Save in view`,
      opened && drawn.groups.length === 7 && drawn.groups.find(([k]) => k === "face")[1] === 10 && drawn.groups.find(([k]) => k === "hair")[1] === 15
      && drawn.light === 3 && drawn.dark === 3 && !drawn.wide && drawn.save);
    await page.waitForTimeout(600);
    await shot(page, `maker_${width}_${theme}.png`);
    if (!first) { await context.close(); continue; }

    console.log("3. She picks, is surprised, picks again and saves");
    const start = await page.evaluate(faceOf, "#minifig-big");
    check(`the maker starts on the handle's minifig ("${start?.minifig}")`, start?.minifig === minifigKey(ADA));
    await pick(page);
    const mine = await page.evaluate(faceOf, "#minifig-big");
    const want = minifigLayers(picked, 256);
    check(`her picks drawn large: ${mine.layers.join(" ")}`, JSON.stringify(mine.layers) === JSON.stringify(want));
    check(`the hair colour shows for hair: ${await page.isVisible('fieldset[data-key="hairColour"]')}`, await page.isVisible('fieldset[data-key="hairColour"]'));
    await page.click("#minifig-surprise");
    const surprised = await page.evaluate(faceOf, "#minifig-big");
    check(`Surprise me changed it (${surprised.layers.length} layers)`, JSON.stringify(surprised.layers) !== JSON.stringify(want));
    await pick(page);
    await page.locator('fieldset[data-key="hair"] label.minifig-tile').nth(9).click();
    check(`a hat hides the hair colour`, !(await page.isVisible('fieldset[data-key="hairColour"]')));
    await page.locator('fieldset[data-key="hair"] label.minifig-tile').nth(1).click();
    await page.waitForTimeout(400);
    await shot(page, `maker_picked_${width}_${theme}.png`);
    const sent = page.waitForRequest((q) => q.url().includes("op=avatar") && q.method() === "POST", { timeout: 30000 }).catch(() => null);
    const answered = page.waitForResponse((a) => a.url().includes("op=avatar") && a.request().method() === "POST", { timeout: 60000 }).catch(() => null);
    await page.click("#minifig-save");
    const request = await sent;
    const body = request ? JSON.parse(request.postData() || "{}") : {};
    const answer = await answered;
    const json = answer ? await answer.json().catch(() => ({})) : {};
    check(`Save sent a ${Buffer.from(body.picture || "", "base64").length} byte PNG with its recipe`,
      body.type === "image/png" && Buffer.from(body.picture || "", "base64").subarray(1, 4).toString() === "PNG"
      && JSON.stringify(body.minifig) === JSON.stringify({ v: 1, ...picked }));
    check(`kept: ${answer?.status()} ${json.picture}, ${json.side} px, ${json.bytes} bytes, recipe ${json.minifig ? "kept" : "not kept (no column)"}`,
      answer?.status() === 200 && /op=avatar&id=/.test(json.picture || "") && json.side === 256 && json.bytes < 30 * 1024);
    await until(page, () => document.querySelector("#avatar img")?.complete);
    head = await page.evaluate(faceOf, "#avatar");
    check(`her profile shows it as her picture at once (${head.src})`, head.pictured && head.src === json.picture);
    const kept = await api(json.picture || "/");
    writeFileSync(path.join(out, "saved_minifig.jpg"), kept.bytes || Buffer.alloc(0));
    check(`the kept picture: ${kept.status} ${kept.type}, ${kept.bytes?.length} bytes`, kept.status === 200 && kept.bytes?.length < 30 * 1024);
    await page.keyboard.press("Escape").catch(() => {});
    await page.reload({ waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    await until(page, () => document.querySelector("#avatar img")?.complete);
    head = await page.evaluate(faceOf, "#avatar");
    check(`after a reload, still her minifig picture`, head.pictured && head.loaded && head.src === json.picture);
    await shot(page, `profile_${width}_${theme}.png`);
    await page.click("#edit");
    await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
    const again = await page.evaluate(() => document.querySelector("#avatar-make").textContent);
    if (json.minifig) {
      check(`Edit profile says "${again}"`, again === "Change your minifig");
      await page.click("#avatar-make");
      await until(page, () => document.querySelector("dialog#minifig-dialog[open] .minifig-tile .avatar.minifig"));
      const reopened = await page.evaluate(faceOf, "#minifig-big");
      check(`the maker opens on what she saved`, JSON.stringify(reopened.layers) === JSON.stringify(want));
      await page.click("#minifig-cancel");
    } else {
      check(`without the column, the maker still offers to make one ("${again}")`, again === "Make a minifig");
    }
    await page.keyboard.press("Escape").catch(() => {});
    await context.close();

    console.log("4. Her comment shows it");
    const m = await open(`/m/${model}`, { width, theme, label: "model page" });
    await until(m.page, () => document.querySelector(".comment .avatar img")?.complete, null, 60000);
    const commentFace = await m.page.evaluate(() => document.querySelector(".comment .avatar img")?.getAttribute("src"));
    check(`her comment's avatar is her minifig picture (${commentFace})`, commentFace === json.picture);
    await m.page.locator(".comment").first().scrollIntoViewIfNeeded().catch(() => {});
    await shot(m.page, `comment_${width}_${theme}.png`);
    await m.context.close();

    console.log("5. A picture of her own instead, then removed");
    const p = await open("/profile", { width, theme, session: asAda(), label: "upload" });
    await until(p.page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    await p.page.click("#edit");
    await until(p.page, () => document.querySelector("dialog#edit-dialog[open]"));
    await p.page.setInputFiles("#avatar-file", { name: "me.jpg", mimeType: "image/jpeg", buffer: PORTRAIT });
    await until(p.page, () => document.querySelector("dialog#crop-dialog[open]"));
    const uploaded = p.page.waitForResponse((a) => a.url().includes("op=avatar") && a.request().method() === "POST", { timeout: 60000 }).catch(() => null);
    await p.page.click('[data-crop="use"]');
    const up = await uploaded;
    const upJson = up ? await up.json().catch(() => ({})) : {};
    check(`her own picture kept: ${up?.status()} ${upJson.picture}, recipe ${JSON.stringify(upJson.minifig)}`,
      up?.status() === 200 && upJson.picture && upJson.picture !== json.picture && !upJson.minifig);
    const said = await p.page.evaluate(() => ({ make: document.querySelector("#avatar-make").textContent,
      remove: document.querySelector("#avatar-remove").textContent }));
    check(`Edit profile: "${said.make}", "${said.remove}"`, said.make === "Make a minifig" && said.remove === "Remove the picture");
    const removed = p.page.waitForResponse((a) => a.url().includes("op=avatar_remove"), { timeout: 60000 }).catch(() => null);
    await p.page.click("#avatar-remove");
    check(`removed: ${(await removed)?.status()}`, (await removed)?.status() === 200);
    await p.page.waitForTimeout(500);
    const back = await p.page.evaluate(faceOf, "#avatar-edit");
    check(`back to the minifig made from her handle ("${back?.minifig}")`, back?.minifig === minifigKey(ADA) && !back.pictured);
    await p.context.close();
  }

  console.log("6. Minifig avatars on the gallery's cards and the home's feed");
  for (const [width, theme] of pictures ? [[1280, "dark"], [1280, "light"], [390, "dark"], [390, "light"]] : [[1280, "dark"]]) {
    // A local relay serves the home only by its file name.
    const home = /^http:\/\/127\.0\.0\.1:/.test(site) ? "/index.html" : "/";
    for (const [where, wait, name] of [["/gallery", ".avatar.minifig", "gallery"], [home, ".avatar.minifig", "home"]]) {
      const { page, context } = await open(where, { width, theme, session: asAda(), label: `${name} ${width} ${theme}` });
      const seen = await until(page, (sel) => document.querySelector(sel), wait, 60000);
      const count = await page.evaluate(() => document.querySelectorAll(".avatar.minifig").length);
      check(`${name} ${width} ${theme}: ${count} minifig avatars`, seen && count > 0);
      await page.locator(".avatar.minifig").first().scrollIntoViewIfNeeded().catch(() => {});
      await page.waitForTimeout(800);
      await shot(page, `${name}_${width}_${theme}.png`);
      await context.close();
    }
  }
} finally {
  if (ada) check(`her account deleted`, await deleteAccount(adaEmail));
  await browser.close();
}
check(`no page errors (${errors.length}: ${errors.slice(0, 3).join(" | ")})`, errors.length === 0);
console.log(`minifig_flow: ${passed} passed, ${failed} failed; pictures in ${out}`);
process.exit(failed ? 1 : 0);
