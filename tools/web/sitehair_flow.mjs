// Hair of your own on the site (sitehair, 2026-11-25): a mould made in the
// studio's minifig builder, worn in the site's minifig maker, on the avatar
// everywhere. Two throwaway accounts, deleted at the end with their moulds;
// never the site's owner, never brickworks.diy.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/sitehair_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/relay_server.mjs 12091 &
//   node --env-file=.env tools/web/sitehair_flow.mjs --url=http://127.0.0.1:12091 --out=DIR --probe
//
// 1. Ada makes a profile, lists a model and comments on it.
// 2. In the studio (the web build at /app, signed in), the figure builder's
//    Headgear, Make a mould… on its hair, a pull on the crown, Save mould: her
//    account lists it within a minute, for the headwear slot. Pictures. A
//    relay has no web build: --probe runs src/dev/sitehair_probe.gd, the
//    desktop studio headless, signed in as Ada against the relay (saved
//    signed in, signed out, then the sweep); --mould=FILE keeps a text the
//    app made (its BW_MOULD_OUT) as the app keeps one.
// 3. Bo, another throwaway, cannot list it, read it, wear it, or reach the
//    table with his own sign-in; signed out, nobody reads it.
// 4. A hostile mould is refused, in words: huge, NaN, a corner changed under
//    its id, an id not its own, a part inside it, no JSON, signed out.
// 5. Edit profile, Make a minifig, Hair and hats: Your own lists it, drawn
//    from its triangles; she wears it, in the colour of the hair it was
//    shaped from, and saves. The maker read its text once; opened again
//    after a reload, the browser's cache answers.
// 6. Her profile, her comment and her page show it, at 1280 and 390 (the
//    maker too), with the bytes each avatar view reads, and no mould read.
// 7. Worn, Bo and a signed-out visitor still cannot read its text (hairfix,
//    hairreview M1: an avatar is its picture); Bo's copy of the same text is
//    his own and hers is as it was.
// 8. Remove (hairfix, hairreview H2): at 390, one of hers not worn, from the
//    maker: asked first, gone from the list and the account. At 1280, the
//    one her avatar wears: her minifig and her saved avatar wear the hair it
//    was shaped from, and the maker opens again whole. Pictures.
// Pictures beside the studio's: beside_1280.png, beside_390.png.
import { clickStill, launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { HAIR, PLAIN } from "../../web/minifig-parts.js";
import { idOf } from "../../api/_moulds.js";
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
if (!site) throw new Error("--url=<a preview or a relay>");
const out = path.resolve(String(args.out || "shots/sitehair"));
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
mkdirSync(out, { recursive: true });
let failed = 0;
let passed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (ok) passed += 1; else failed += 1;
  return ok;
};
const errors = [];
const listen = (page, who) => {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())
        || (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text()))) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
};
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout, polling: 250 }).then(() => true, () => false);
const shots = {};
const shot = async (page, name, key = "") => {
  const file = path.join(out, name);
  await page.screenshot({ path: file, timeout: 90000 }).then(() => { if (key) shots[key] = file; })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};
const words = (json) => typeof json?.error === "string" && json.error.length > 20 && !/^\w*Error\b|stack|undefined|\[object/.test(json.error);

async function api(pathname, { method = "GET", token, body, raw } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  if (raw !== undefined) sent["content-type"] = "text/plain";
  const asked = () => fetch(site + pathname, { method, headers: sent,
    body: raw !== undefined ? raw : body === undefined ? undefined : JSON.stringify(body) });
  // Sent once more when a kept-alive socket died while the studio's probe
  // held the process (a relay closes an idle one after 5 s).
  const reply = await asked().catch((trouble) => {
    if (trouble instanceof TypeError) return asked();
    throw trouble;
  });
  const type = reply.headers.get("content-type") || "";
  return { status: reply.status, cache: reply.headers.get("cache-control") || "",
    json: type.includes("json") ? await reply.json().catch(() => null) : null };
}

const browser = await launch({ signedOut: true });
// A browser that keeps an HTTP cache, as a visitor's does: every route
// launch() makes (the visit counter's, the parts bucket's mirror,
// tools/web/page_routes.mjs) turns its pages' cache off, so this one routes
// nothing; the counter's host is not found, and it opens only her profile,
// which reads nothing from the bucket.
let keeping = null;
const keepingBrowser = async () => keeping || (keeping = await launch({ signedOut: true, realCounter: true, realStore: true,
  args: ["--host-resolver-rules=MAP overlook.technology ~NOTFOUND"] }));
async function open(pathname, { width = 1280, theme = "dark", session = null, label, using = browser, watch = null }) {
  const phone = width < 600;
  const context = await using.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
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
  if (watch) watch(page);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}
// What a page fetched: [{name, transfer, body}] of the resources whose
// address matches [pattern] (Resource Timing: a transfer of 0 with a body is
// the browser's own cache).
const fetched = (page, pattern) => page.evaluate((source) => performance.getEntriesByType("resource")
  .filter((one) => new RegExp(source).test(one.name))
  .map((one) => ({ name: one.name.replace(location.origin, ""), transfer: one.transferSize, body: one.decodedBodySize })), pattern);

const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-sitehair-ada-${rand}@resend.dev`;
const boEmail = `delivered+bw-sitehair-bo-${rand}@resend.dev`;
const ADA = `hair-ada-${rand}`;
const BO = `hair-bo-${rand}`;
let ada = null;
let bo = null;
const asAda = () => [STORAGE_KEY, JSON.stringify(ada.kept), JSON.stringify({ token: ada.access_token,
  until: Date.now() + 50 * 60 * 1000, email: ada.kept.email })];
const recipeIn = (page) => page.evaluate(() => JSON.parse(document.querySelector("#minifig-dialog").dataset.recipe || "null"));
const makerReady = (page) => until(page, () => ["ready", "failed"].includes(document.querySelector("dialog#minifig-dialog[open]")?.dataset.figure), null, 120000)
  .then(async (seen) => seen && (await page.evaluate(() => document.querySelector("#minifig-dialog").dataset.figure)) === "ready");
const listed = async (who) => (await api("/api/people?op=moulds", { token: who.access_token })).json?.moulds || [];

/// The studio's own: a mould made in the web build's figure builder, as
/// print_flow.mjs makes one, by where the app says its controls are.
async function studio() {
  if (args.probe) {
    // The desktop studio, headless, signed in as Ada against this relay:
    // its own save sends the mould (src/dev/sitehair_probe.gd).
    const file = path.join(out, "studio_mould.dat");
    const { runStudioProbe } = await import("./sitehair_studio.mjs");
    const ran = runStudioProbe({ work, site, token: ada.access_token, user: ada.kept.user_id, file });
    writeFileSync(path.join(out, "sitehair_probe.log"), `${ran.stdout}\n${ran.stderr}`);
    const said = String(ran.stdout).split("\n").filter((line) => /^(PASS|FAIL) /.test(line));
    for (const line of said) console.log(`        studio: ${line}`);
    check(`the studio saved her mould signed in, kept nothing signed out, asked before sending it, and replaced a remake: `
      + `${said.filter((l) => l.startsWith("PASS")).length} passed, exit ${ran.status}`,
      ran.status === 0 && said.length > 0 && !said.some((l) => l.startsWith("FAIL")));
    return /^0 Name: (\S+)\.dat$/m.exec(readFileSync(file, "utf8"))?.[1] || "";
  }
  if (args.mould) {
    const text = readFileSync(path.resolve(String(args.mould)), "utf8");
    const id = /^0 Name: (\S+)\.dat$/m.exec(text)?.[1] || "";
    // As the app sends one (src/account/moulds_on_account.gd send).
    const r = await api("/api/people?op=mould", { method: "POST", token: ada.access_token, body: { id, slot: "headwear", text } });
    check(`the mould the app made (${id}, ${text.length} bytes) kept as the app keeps one: ${r.status}`, r.status === 200);
    return id;
  }
  // A sign-in of the studio's own, as each device has one.
  const own = await mintSession(adaEmail);
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: "dark", extraHTTPHeaders: headers });
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch { /* nothing kept */ }
  }, [STORAGE_KEY, JSON.stringify(own.kept)]);
  const page = await context.newPage();
  listen(page, "studio");
  const controls = () => page.evaluate(() => window.brickworksControls || {}).catch(() => ({}));
  const custom = async () => (await page.evaluate(() => window.brickworksState || null).catch(() => null))?.custom || [];
  async function where(name, seconds = 120) {
    for (let n = 0; n < seconds * 2; n++) {
      const at = (await controls())[name];
      if (at) return at;
      await page.waitForTimeout(500);
    }
    await shot(page, `never_${name}.png`);
    throw new Error(`the studio never showed "${name}"`);
  }
  const click = (name) => clickStill(page, name, { find: (n) => where(n), after: 1500 });
  async function stroke(points) {
    await page.mouse.move(points[0][0], points[0][1]);
    await page.mouse.down();
    for (const [x, y] of points.slice(1)) await page.mouse.move(x, y, { steps: 6 });
    await page.mouse.up();
    await page.waitForTimeout(800);
  }
  try {
    await page.goto(`${site}/app`, { waitUntil: "domcontentloaded", timeout: 120000 });
    const up = await until(page, () => Object.keys(window.brickworksControls || {}).length > 5, null, 400000);
    check("the studio came up, signed in as Ada", up);
    await page.waitForTimeout(Number(args.load || 15000));
    await page.mouse.move(700, 120);
    await page.keyboard.press("m");
    await click("minifig_headwear");
    await click("minifig_make");
    const view = await where("mould_view");
    await page.waitForTimeout(6000);
    await click("mould_tool_pull");
    for (let n = 0; n < 4; n++) await stroke([[view.x - 40, view.y - 30], [view.x + 40, view.y - 40]]);
    await page.waitForTimeout(3000);
    await shot(page, "studio_mould_1280.png");
    const before = await custom();
    await click("mould_save");
    let id = "";
    for (let n = 0; n < 360 && !id; n++) {
      id = (await custom()).find((one) => /^bw-3901-m-[0-9a-f]{20}$/.test(one) && !before.includes(one)) || "";
      if (!id) await page.waitForTimeout(500);
    }
    check(`Save mould made her hair in the studio: ${id || "(none)"}`, Boolean(id));
    await page.waitForTimeout(5000);
    await shot(page, "studio_builder_1280.png", "studio");
    let row = null;
    for (let n = 0; n < 60 && id && !row; n++) {
      row = (await listed(ada)).find((one) => one.id === id) || null;
      if (!row) await page.waitForTimeout(1000);
    }
    check(`her account has it, unasked: ${JSON.stringify(row)}`, row?.slot === "headwear" && row?.base === "3901" && row?.triangles > 0);
    return id;
  } finally {
    await context.close();
  }
}

try {
  console.log("1. Ada makes a profile, lists a model and comments on it; Bo makes a profile");
  ada = await mintSession(adaEmail);
  bo = await mintSession(boEmail);
  for (const [who, handle, name] of [[ada, ADA, "Ada Hair"], [bo, BO, "Bo Hair"]]) {
    const r = await api("/api/people?op=profile", { method: "POST", token: who.access_token, body: { handle, name } });
    check(`${name}'s profile: ${r.status}`, r.status === 200);
  }
  let r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `Hair Castle ${rand}`, author: "Ada Hair",
    model: readFileSync(path.join(work, "models", "castle.ldr"), "utf8"), image: readFileSync(path.join(work, "web/share.png")).toString("base64"),
    listed: true, kind: "castle", tags: "sitehair flow", licence: "cc-by-4.0" } });
  const model = r.json?.id || "";
  check(`listed her castle: ${r.status} ${model}`, r.status === 201);
  r = await api("/api/people?op=comment", { method: "POST", token: ada.access_token, body: { model, version: 1, body: "My own hair says hello." } });
  check(`commented: ${r.status}`, r.status === 201);

  console.log("2. The studio: Make a mould… on her hair, Save mould");
  const id = await studio();
  const mine = (await listed(ada)).find((one) => one.id === id);
  check(`her list has it, without its text: ${JSON.stringify(mine)}`, Boolean(mine) && !("text" in mine));
  r = await api(`/api/people?op=mould&id=${id}`, { token: ada.access_token });
  const text = r.json?.text || "";
  check(`she reads its text: ${r.status}, ${text.length} bytes, "${r.cache}"`, r.status === 200 && text.includes(`0 Name: ${id}.dat`)
    && /private/.test(r.cache) && /immutable/.test(r.cache));

  console.log("3. Bo cannot reach it while nobody wears it");
  const his = await listed(bo);
  check(`Bo's list is his own (${his.length})`, his.length === 0);
  r = await api(`/api/people?op=moulds&account=${encodeURIComponent(ada.kept.user_id || "")}`, { token: bo.access_token });
  check(`asking for hers by account still lists his own (${r.json?.moulds?.length})`, r.status === 200 && r.json?.moulds?.length === 0);
  r = await api(`/api/people?op=mould&id=${id}`, { token: bo.access_token });
  check(`Bo reading it: ${r.status} "${r.json?.error}", "${r.cache}"`, r.status === 404 && words(r.json) && /no-store/.test(r.cache));
  r = await api(`/api/people?op=mould&id=${id}`);
  check(`signed out, reading it: ${r.status}`, r.status === 404);
  const picture = readFileSync(path.join(work, "web/share.png")).toString("base64");
  r = await api("/api/people?op=avatar", { method: "POST", token: bo.access_token, body: { picture, type: "image/png", minifig: { ...PLAIN, hd: id } } });
  check(`Bo wearing it: ${r.status} "${r.json?.error}"`, r.status === 403 && words(r.json));
  const rest = `${process.env.SUPABASE_URL || ""}/rest/v1/own_moulds`;
  if (process.env.SUPABASE_URL && process.env.SUPABASE_PUBLISHABLE_KEY) {
    const as = { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, authorization: `Bearer ${bo.access_token}` };
    const read = await fetch(`${rest}?select=id,text`, { headers: as });
    check(`Bo's own sign-in at the table: ${read.status}`, read.status === 401 || read.status === 403);
    const wrote = await fetch(rest, { method: "POST", headers: { ...as, "content-type": "application/json" },
      body: JSON.stringify({ account: ada.kept.user_id, id, slot: "headwear", base: "3901", name: "x", triangles: 1, bytes: 1, text: "x" }) });
    check(`Bo writing at the table: ${wrote.status}`, wrote.status === 401 || wrote.status === 403);
  }

  console.log("4. A hostile mould is refused, in words");
  const at = (one, two) => text.replace(/^3 16 (\S+)/m, `3 16 ${two ?? one}`);
  const hostile = [
    ["huge", { id, slot: "headwear", text: text + "0 // pad\n".repeat(240000) }, 413],
    ["NaN", { id, slot: "headwear", text: at("NaN") }, 400],
    ["a corner changed under its id", { id, slot: "headwear", text: text.replace(/^3 16 (\S+)/m, "3 16 1$1") }, 400],
    ["an id not its own", { id: id.replace(/.$/, (c) => (c === "0" ? "1" : "0")), slot: "headwear", text }, 400],
    ["a part inside it", { id, slot: "headwear", text: text.replace("0 // Faces", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 stud.dat") }, 400],
    ["no slot of a minifigure's", { id, slot: "pocket", text }, 400],
  ];
  for (const [what, body, status] of hostile) {
    r = await api("/api/people?op=mould", { method: "POST", token: ada.access_token, body });
    check(`${what}: ${r.status} "${String(r.json?.error).slice(0, 110)}"`, r.status === status && words(r.json));
  }
  r = await api("/api/people?op=mould", { method: "POST", token: ada.access_token, raw: "not a mould at all" });
  check(`no JSON: ${r.status} "${r.json?.error}"`, r.status === 400 && words(r.json));
  r = await api("/api/people?op=mould", { method: "POST", body: { id, slot: "headwear", text } });
  check(`signed out: ${r.status} "${r.json?.error}"`, r.status === 401);
  const still = await api(`/api/people?op=mould&id=${id}`, { token: ada.access_token });
  check("her mould is as it was", still.json?.text === text);
  {
    // A title whose 120th UTF-16 unit is half an emoji (hairreview M2):
    // kept, its list name cut at a whole character.
    const lines = text.split(id).join("\u0000").split("\n");
    lines[0] = `0 Minifig Hair Male, Custom Mould ${"a".repeat(87)}\u{1F525} quiff`;
    const holed = lines.join("\n");
    const other = idOf(holed.split("\u0000").join(""), "\u0000\u0000never\u0000", "3901");
    r = await api("/api/people?op=mould", { method: "POST", token: ada.access_token,
      body: { id: other, slot: "headwear", text: holed.split("\u0000").join(other) } });
    const name = (await listed(ada)).find((one) => one.id === other)?.name || "";
    check(`a title cut through an emoji: ${r.status}, its list name ${[...name].length} characters, whole `
      + `(${name.isWellFormed()})`, r.status === 200 && name.isWellFormed() && [...name].length <= 120);
    r = await api("/api/people?op=mould_remove", { method: "POST", token: ada.access_token, body: { id: other } });
    check(`removed again by its own op: ${r.status}`, r.status === 200 && r.json?.removed === true);
    r = await api("/api/people?op=mould_remove", { method: "POST", token: ada.access_token, body: { id: other } });
    check(`removed twice: ${r.status} "${r.json?.error}"`, r.status === 404 && words(r.json));
    r = await api("/api/people?op=mould_remove", { method: "POST", body: { id } });
    check(`removed signed out: ${r.status}`, r.status === 401);
    r = await api("/api/people?op=mould_remove", { method: "POST", token: bo.access_token, body: { id } });
    check(`Bo removing hers: ${r.status}, and hers is still there`, r.status === 404
      && (await listed(ada)).some((one) => one.id === id));
  }

  console.log("5. The site's maker: Your own, worn, saved");
  const base = HAIR.find(([one]) => one === "3901");
  let saved = null;
  for (const [width, theme] of [[1280, "dark"], [390, "light"]]) {
    const tag = `${width} ${theme}`;
    const { page, context } = await open("/profile", { width, theme, session: asAda(), label: `maker ${tag}` });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    const moulds = [];
    page.on("request", (q) => { if (/op=mould&/.test(q.url())) moulds.push(q.url()); });
    await page.click("#edit");
    await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
    await page.click("#avatar-make");
    check(`${tag}: the maker drew her figure`, await makerReady(page));
    await page.click("[role=tab][data-tab=hair]");
    const tile = `label.mf-tile.own:has(input[name=mf-hd][value='${id}'])`;
    const drawn = await until(page, (one) => {
      const img = document.querySelector(`img[data-own='${one}']`);
      return img && !img.hidden && img.complete && img.naturalWidth > 0;
    }, id, 60000);
    const listing = await page.evaluate((one) => ({
      group: [...document.querySelectorAll("#minifig-dialog fieldset[data-list=hd] legend")].map((l) => l.firstChild?.textContent.trim()),
      pill: Boolean(document.querySelector("#minifig-dialog [data-filter=own]")),
      first: Boolean(document.querySelector(`#minifig-dialog fieldset[data-list=hd] input[name=mf-hd][value="${one}"]`)?.closest("fieldset") === document.querySelector("#minifig-dialog fieldset[data-list=hd]")),
      // How much of its tile the picture covers: drawn from its triangles.
      cover: (() => {
        const img = document.querySelector(`img[data-own='${one}']`);
        if (!img?.naturalWidth) return 0;
        const c = document.createElement("canvas");
        c.width = img.naturalWidth; c.height = img.naturalHeight;
        const g = c.getContext("2d");
        g.drawImage(img, 0, 0);
        const d = g.getImageData(0, 0, c.width, c.height).data;
        let on = 0;
        for (let k = 3; k < d.length; k += 4) if (d[k] > 0) on += 1;
        return on / (c.width * c.height);
      })(),
    }), id);
    check(`${tag}: Hair and hats lists Your own first (${listing.group.join(", ")}), a filter for it, its tile drawn `
      + `from its triangles (${(listing.cover * 100).toFixed(0)}% of the tile)`,
      drawn && listing.group[0] === "Your own" && listing.pill && listing.first && listing.cover > 0.05);
    if (width === 1280) {
      await page.locator(tile).scrollIntoViewIfNeeded();
      // Worn in the figure's hair colour, as any hair is (web/minifig-maker.js
      // changed: "hair keeps the colour it had"); after a hat or none, in the
      // colour of the hair it was shaped from.
      const before = await recipeIn(page);
      const was = HAIR.find(([one]) => one === before?.hd)?.[1];
      const colour = !was || ["hat", "helmet", "headwear"].includes(was) ? base?.[2] : before.hc;
      await page.click(tile);
      await page.waitForTimeout(500);
      const worn = await recipeIn(page);
      check(`${tag}: she wears it in her figure's hair colour (${worn?.hd}, colour ${worn?.hc}; it had ${before?.hd} in ${before?.hc}, `
        + `its base comes in ${base?.[2]})`, worn?.hd === id && worn?.hc === colour);
      // The figure drawn again with it, nothing failing.
      await until(page, () => !document.querySelector("#minifig-note")?.textContent.trim(), null, 5000);
      const note = await page.evaluate(() => document.querySelector("#minifig-note")?.textContent.trim() || "");
      check(`${tag}: drawn on her figure, no part failing ("${note}")`, note === "" && (await page.evaluate(() => document.querySelector("#minifig-dialog").dataset.figure)) === "ready");
      // Each of her moulds read once, for its tile; the one worn among them.
      check(`${tag}: each mould's text read once (${moulds.length} for ${new Set(moulds).size})`,
        moulds.length === new Set(moulds).size && moulds.some((one) => one.includes(id)));
      await page.waitForTimeout(800);
      await shot(page, `maker_own_${width}_${theme}.png`, `maker_${width}`);
      const answered = page.waitForResponse((a) => a.url().includes("op=avatar") && a.request().method() === "POST", { timeout: 60000 }).catch(() => null);
      await page.click("#minifig-save");
      const answer = await answered;
      saved = answer ? await answer.json().catch(() => null) : null;
      check(`Save kept her minifig with her own hair: ${answer?.status()} ${saved?.picture}, recipe hd ${saved?.minifig?.hd}`,
        answer?.status() === 200 && saved?.minifig?.hd === id);
      await page.keyboard.press("Escape").catch(() => {});
    } else {
      await page.waitForTimeout(800);
      const worn = await recipeIn(page);
      check(`${tag}: it opens on her own hair`, worn?.hd === id);
      await shot(page, `maker_own_${width}_${theme}.png`, `maker_${width}`);
      await page.click("#minifig-cancel");
    }
    await context.close();
  }

  console.log("5b. In a browser that keeps a cache, as a visitor's does: a mould's text is read once");
  {
    // The maker's own request (mouldText: account.js call), on her profile,
    // then again after a reload. Not the maker itself: this browser reads
    // the parts bucket itself, so it draws nothing.
    const { page, context } = await open("/profile", { session: asAda(), label: "kept", using: await keepingBrowser() });
    const reads = [];
    for (let n = 0; n < 2; n++) {
      if (n) await page.reload({ waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
      const asked = await page.evaluate(async (one) => {
        const { call } = await import("/account.js");
        const answer = await call(`/api/people?op=mould&id=${encodeURIComponent(one)}`);
        return answer.status === 200 && typeof answer.body?.text === "string";
      }, id);
      reads.push(...(await fetched(page, "op=mould&")).map((one) => ({ ...one, asked })));
    }
    check(`its text read ${reads.map((one) => `${one.transfer} bytes`).join(", then ")} over the network `
      + `(${reads[1]?.body} bytes from the browser's cache the second time)`, reads.length === 2 && reads.every((one) => one.asked)
      && reads[0].transfer > 1000 && reads[1].transfer === 0 && reads[1].body === reads[0].body);
    await context.close();
  }

  console.log("6. Her profile, her comment and her page show it; what each avatar view reads");
  const pictureAt = (saved?.picture || "\u0000").replace(/[?&.]/g, "\\$&");
  for (const [width, theme] of [[1280, "dark"], [390, "light"]]) {
    const tag = `${width} ${theme}`;
    // Where each page shows her: her profile's own picture, her comment's
    // (on the model's Comments tab), her page's.
    for (const [where, label, session, shown] of [["/profile", "profile", asAda(), "#avatar img"],
      [`/m/${model}#comments`, "comment", null, ".comment .avatar img"], [`/u/${ADA}`, "page", null, ".avatar img"]]) {
      const cdn = [];
      const watch = (page) => page.on("response", (a) => {
        if (a.url().includes(saved?.picture || "\u0000")) cdn.push(a.headers()["x-vercel-cache"] || "no CDN");
      });
      const { page, context } = await open(where, { width, theme, session, label: `${label} ${tag}`, watch });
      const seen = await until(page, ([src, at]) => [...document.querySelectorAll(at)]
        .some((img) => img.getAttribute("src") === src && img.complete && img.naturalWidth > 0), [saved?.picture, shown], 60000);
      const pictures = await fetched(page, pictureAt);
      const moulds = await fetched(page, "op=moulds?|op=mould&");
      check(`${tag} ${label}: her avatar (${shown}) is her minifig with her own hair; the view read `
        + `${pictures.map((p) => `${p.transfer} bytes`).join(", ")} (${cdn.join(", ") || "-"}) and no mould (${moulds.length})`,
      seen && moulds.length === 0);
      await page.locator(shown).first().scrollIntoViewIfNeeded().catch(() => {});
      await page.waitForTimeout(600);
      await shot(page, `${label}_${width}_${theme}.png`, `${label}_${width}`);
      await context.close();
    }
  }
  {
    // Viewed twice: the second view's picture is the CDN's (a preview;
    // s-maxage, api/_photo.js PICTURE_CACHE), which reads no storage, and
    // neither view reads a mould.
    const cdn = [];
    const watch = (page) => page.on("response", (a) => {
      if (a.url().includes(saved?.picture || "\u0000")) cdn.push(a.headers()["x-vercel-cache"] || "no CDN");
    });
    const { page, context } = await open(`/m/${model}#comments`, { label: "comment twice", watch });
    const views = [];
    for (let n = 0; n < 2; n++) {
      if (n) await page.reload({ waitUntil: "load" });
      await until(page, (src) => [...document.querySelectorAll(".comment .avatar img")].some((img) => img.getAttribute("src") === src && img.complete),
        saved?.picture, 60000);
      views.push({ pictures: await fetched(page, pictureAt), moulds: (await fetched(page, "op=mould")).length });
    }
    const preview = /vercel\.app/.test(site);
    check(`her comment viewed twice: ${views.map((v) => `${v.pictures.map((p) => p.transfer).join("+")} bytes`).join(", then ")} `
      + `(${cdn.join(", then ")}), no mould read (${views.map((v) => v.moulds).join(", ")})`,
      views.every((v) => v.pictures.length > 0 && v.moulds === 0) && (!preview || cdn[cdn.length - 1] === "HIT"));
    await context.close();
  }

  console.log("7. Worn, its text is still hers alone; Bo's copy is his own");
  r = await api(`/api/people?op=mould&id=${id}`, { token: bo.access_token });
  check(`Bo reading the hair her avatar wears: ${r.status} "${r.json?.error}"`, r.status === 404);
  r = await api(`/api/people?op=mould&id=${id}`);
  check(`a visitor signed out: ${r.status}, "${r.cache}"`, r.status === 404 && /no-store/.test(r.cache));
  const was = (await listed(ada)).find((one) => one.id === id);
  r = await api("/api/people?op=mould", { method: "POST", token: bo.access_token, body: { id, slot: "headwear", text } });
  check(`Bo keeping the same text keeps his own copy: ${r.status}`, r.status === 200);
  const now = (await listed(ada)).find((one) => one.id === id);
  check(`hers is as it was (${now?.at})`, now?.at === was?.at && (await listed(bo)).length === 1);

  console.log("8. Remove, in the maker: one not worn at 390, the worn one at 1280");
  const removeIn = async (page, one) => {
    await page.click("[role=tab][data-tab=hair]");
    const tile = `label.mf-tile.own:has(input[name=mf-hd][value='${one}'])`;
    if (!(await page.locator(`${tile} input:checked`).count())) await page.click(tile);
    await until(page, () => Boolean(document.querySelector("#mf-own-remove")), null, 10000);
    await page.locator("#mf-own-remove").scrollIntoViewIfNeeded();
    const asked = page.waitForResponse((a) => a.url().includes("op=mould_remove"), { timeout: 30000 }).catch(() => null);
    await page.click("#mf-own-remove");
    const question = await until(page, () => Boolean(document.querySelector("dialog.ask[open]")), null, 10000);
    const said = await page.evaluate(() => document.querySelector("dialog.ask[open]")?.textContent.trim() || "");
    await page.locator("dialog.ask[open] .actions button").first().click();
    const answer = await asked;
    await until(page, () => Boolean(document.querySelector("#minifig-note")?.textContent.trim()), null, 10000);
    return { question, words: said, status: answer?.status(), body: answer ? await answer.json().catch(() => null) : null,
      note: await page.evaluate(() => document.querySelector("#minifig-note")?.textContent.trim() || ""),
      tile: await page.locator(tile).count(), recipe: await recipeIn(page) };
  };
  const others = (await listed(ada)).filter((one) => one.id !== id && /^bw-3901-m-/.test(one.id));
  if (others.length) {
    const one = others[0].id;
    const { page, context } = await open("/profile", { width: 390, theme: "light", session: asAda(), label: "remove 390 light" });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    await page.click("#edit");
    await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
    await page.click("#avatar-make");
    check("390: the maker drew her figure", await makerReady(page));
    const gone = await removeIn(page, one);
    check(`390: Remove asks first ("${gone.words.slice(0, 120)}"), then ${gone.status}: "${gone.note}"; its tile gone (${gone.tile}), `
      + `her figure wears ${gone.recipe?.hd}`, gone.question && gone.status === 200 && gone.tile === 0 && gone.recipe?.hd === "3901"
      && !(await listed(ada)).some((m) => m.id === one) && gone.body?.minifig === null);
    await shot(page, "remove_390_light.png", "remove_390");
    await page.click("#minifig-cancel");
    await context.close();
  } else {
    check("390: a second mould of hers to remove (the studio's probe made one)", false);
  }
  {
    const { page, context } = await open("/profile", { width: 1280, theme: "dark", session: asAda(), label: "remove 1280 dark" });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
    await page.click("#edit");
    await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
    await page.click("#avatar-make");
    check("1280: the maker opens on her own hair", await makerReady(page) && (await recipeIn(page))?.hd === id);
    const gone = await removeIn(page, id);
    const me = await api("/api/people?op=me", { token: ada.access_token });
    const avatar = me.json?.avatar || me.json?.profile?.avatar || null;
    check(`1280: the one her avatar wears removed: ${gone.status}, "${gone.note}"; her figure wears ${gone.recipe?.hd}, `
      + `her saved avatar ${gone.body?.minifig?.hd} (account: ${avatar?.minifig?.hd})`, gone.status === 200 && gone.recipe?.hd === "3901"
      && gone.body?.minifig?.hd === "3901" && (!avatar || avatar.minifig?.hd === "3901"));
    await shot(page, "remove_1280_dark.png", "remove_1280");
    await page.click("#minifig-cancel");
    await page.waitForTimeout(300);
    await page.click("#avatar-make");
    const whole = await makerReady(page);
    const note = await page.evaluate(() => document.querySelector("#minifig-note")?.textContent.trim() || "");
    check(`1280: opened again, it is whole, on the hair it was shaped from (${(await recipeIn(page))?.hd}, "${note}")`,
      whole && (await recipeIn(page))?.hd === "3901" && note === "");
    await page.click("#minifig-cancel");
    await context.close();
  }
} finally {
  for (const [who, email] of [[ada, adaEmail], [bo, boEmail]]) {
    if (who) check(`${email.split("+")[1].split("@")[0]}'s account deleted`, await deleteAccount(email));
  }
  if (ada?.kept.user_id && process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY) {
    const key = process.env.SUPABASE_SECRET_KEY;
    const left = await fetch(`${process.env.SUPABASE_URL}/rest/v1/own_moulds?account=in.(${ada.kept.user_id},${bo?.kept.user_id || ada.kept.user_id})&select=id`,
      { headers: { apikey: key, authorization: `Bearer ${key}` } }).then((a) => a.json()).catch(() => null);
    check(`their moulds went with them (${JSON.stringify(left)})`, Array.isArray(left) && left.length === 0);
  }
}

// Each picture beside the studio's.
for (const width of [1280, 390]) {
  const files = [shots.studio, shots[`maker_${width}`], shots[`profile_${width}`], shots[`comment_${width}`]].filter(Boolean);
  if (files.length < 2) continue;
  const page = await browser.newPage({ viewport: { width: 2400, height: 900 } });
  const cells = files.map((file) => `<figure><img src="data:image/png;base64,${readFileSync(file).toString("base64")}"><figcaption>${path.basename(file)}</figcaption></figure>`).join("");
  await page.setContent(`<style>body{margin:0;background:#222;color:#ddd;font:14px sans-serif;display:flex;gap:12px;padding:12px;align-items:flex-start}`
    + `figure{margin:0}img{height:${width === 1280 ? 420 : 820}px;display:block}</style>${cells}`);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out, `beside_${width}.png`), fullPage: true }).catch(() => {});
  await page.close();
}
await browser.close();
if (keeping) await keeping.close();
for (const line of errors.slice(0, 6)) console.log(`  error: ${line}`);
check(`no page errors (${errors.length})`, errors.length === 0);
writeFileSync(path.join(out, "summary.txt"), `sitehair_flow: ${passed} passed, ${failed} failed\n`);
console.log(`sitehair_flow: ${passed} passed, ${failed} failed; pictures in ${out}`);
process.exit(failed ? 1 : 0);
