// A gallery that rewards designs that build, in real browsers: Top builds
// orders by builds finished, remixes and the Tested mark; the gallery's
// front has this week's pick, worked out from the past seven days, and a
// shelf of small builds; the site's owner chooses another pick on the admin
// page, and ends it; and a signed-in person with a collection sees how much
// of each model they own, what they can build now, and Parts I own.
//
//   node --env-file=.env tools/web/relay_server.mjs 9250 --hold=gallery_picks &
//   node --env-file=.env tools/web/discovery_flow.mjs --url=http://127.0.0.1:9250 --out=shots/discovery
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/discovery_flow.mjs --url=<preview> --out=DIR
//
// Until supabase/discovery.sql is applied, the local relay holds it in
// memory (--hold=gallery_picks, tools/web/discovery_stand_in.mjs); the
// models, their builds and their Tested marks are the live project's. On a
// deployment everything is read through its API: /api/share's list and
// shelves, /api/collection and /api/admin, with the bypass headers. Throwaway accounts at
// Resend test addresses, so every model here is a test model, which only a
// list asked with tests=1 shows: no visitor sees them, nor a pick made of
// one. Deleted at the end with their models; a choice made here is ended.
//
//   1. Ada lists four models. Tower: 3 bricks, red, blue and yellow,
//      Tested, built twice (11). Wall: 3 white bricks, built three times
//      (9). Hall: 210 bricks, built once (3). Shed: 3 red bricks, nothing
//      (0). And a fifth by link only.
//      Tower's Tested mark is the app's finding as the app sends it, made
//      here for this very file (api/_tested.js checks that it is); the
//      tests themselves are tested_flow's.
//   2. Top builds lists them Tower, Wall, Hall, Shed, and says how it
//      weighs them; Most built lists Wall first.
//   3. The gallery's front, signed out and signed in, at 1280 and 390 px:
//      this week's pick is Tower, "Built twice this week"; Small builds
//      has Tower, then Wall, and not Hall; nothing scrolls sideways. A
//      search hides the shelves.
//   4. The site's owner, on /admin: Make it the pick beside Shed; the
//      front's pick is Shed, "Chosen by Brickworks"; the model by link
//      only is refused, in words. End: Tower again.
//   5. Bob keeps a collection: a real set (10760-1, expanded through its
//      inventory), a set no inventory has, three red bricks, a blue, a
//      yellow and a white. Each card says what he has of it (Tower and
//      Shed every part, Wall 1 of 3, Hall 5 of 210); Parts I own puts
//      Tower and Shed first; the front's You can build now has them; a
//      visitor and Ada (no collection) are offered none of it.
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
const site = String(args.url || "http://127.0.0.1:9250").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/discovery"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
// A local relay holding discovery.sql answers /__held/gallery_picks; a
// preview, or a relay on the live project, does not. Said, not needed.
const held = await fetch(`${site}/__held/gallery_picks`, { headers }).then((reply) => reply.ok).catch(() => false);
const { modelHash } = await import(path.join(root, "api/_directory.js"));
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-discovery-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-discovery-bob-${rand}@resend.dev`;
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`;

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

/// A model of [count] 2 x 4 bricks stacked, each its own step, in
/// [colours] by turns, carrying its steps (the PAGES line a Tested finding
/// is of).
function model(name, count, colours = [4, 1, 14, 2]) {
  const lines = [`0 ${name}`, `0 Name: discovery_${rand}.ldr`, "0 Author: Discovery Flow",
    `0 !BRICKWORKS PAGES {"v":1,"steps":${count}}`];
  for (let n = 0; n < count; n++) {
    lines.push(`1 ${colours[n % colours.length]} ${(n % 10) * 80} ${-24 * Math.floor(n / 10)} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  }
  lines.push(`0 // discovery flow ${rand}`);
  return `${lines.join("\r\n")}\r\n`;
}

/// The app's finding of [text] as the Share panel sends it: all four
/// passed (api/_tested.js checkTested).
const finding = (text, count) => ({ v: 1, app: "0.3.0", model: modelHash(text), steps: count, parts: count,
  tests: Object.fromEntries(["stands", "steps", "parts", "whole"].map((name) => [name,
    { ok: true, why: "Checked by the discovery flow's model" }])) });

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, phone = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
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

const shot = (target, name, full = false) => target.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function api(pathname, { method = "GET", token, body, extra = {} } = {}, again = true) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const said = { status: reply.status, body: await reply.json().catch(() => ({})) };
  // The sign-in service not reached in time (api/_auth.js, before anything
  // is done): asked once more, as a person would press again.
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

/// The gallery's front as drawn: the pick, the small shelf, the score line.
const frontDrawn = (page) => page.evaluate(() => ({
  shelves: !document.getElementById("shelves").hidden,
  pick: document.getElementById("pick").hidden ? "" : document.querySelector("#pick-card .model")?.dataset.id || "",
  chosen: document.querySelector("#pick-card .model")?.dataset.chosen || "",
  why: document.querySelector("#pick-card .why")?.textContent || "",
  small: [...document.querySelectorAll("#small-models .model")].map((a) => a.dataset.id),
  grid: [...document.querySelectorAll("#models .model")].map((a) => a.dataset.id),
  score: document.getElementById("score-said").hidden ? "" : document.getElementById("score-said").textContent,
  ready: !document.getElementById("ready").hidden,
  readySaid: document.getElementById("ready-said").textContent,
  readyModels: [...document.querySelectorAll("#ready-models .model")].map((a) => a.dataset.id),
  owned: document.querySelectorAll(".model small.owned").length,
  // The list's cards and the pick that leads them (gallery.js drawShelves).
  shares: Object.fromEntries([...document.querySelectorAll("#feed .model[data-owned]")].map((a) => [a.dataset.id,
    `${a.dataset.owned} ${a.querySelector("small.owned")?.textContent || ""}`])),
  sorts: [...document.querySelectorAll("#sort option")].map((o) => o.value),
}));

let ada = null;
let bob = null;
const made = [];
const chosen = [];
let master = null;
try {
  console.log(`against ${site}${held ? ", discovery.sql held by the relay" : ""}`);
  // --- 1. Ada's models, built and Tested --------------------------------------
  console.log("Ada lists four models; some are built, one is Tested");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  const NAMES = { tower: `Discovery Tower ${rand}`, wall: `Discovery Wall ${rand}`, hall: `Discovery Hall ${rand}`,
    shed: `Discovery Shed ${rand}`, secret: `Discovery Secret ${rand}` };
  const SIZE = { tower: 3, wall: 3, hall: 210, shed: 3, secret: 3 };
  const COLOURS = { tower: [4, 1, 14], wall: [15], hall: [4, 1, 14, 2], shed: [4], secret: [4] };
  const ids = {};
  for (const key of ["hall", "shed", "wall", "tower", "secret"]) {
    const text = model(NAMES[key], SIZE[key], COLOURS[key]);
    const one = await api("/api/share", { method: "POST", token: ada.access_token, body: {
      name: NAMES[key], author: "Ada Discovery", model: text, image: picture, listed: key !== "secret",
      ...(key === "tower" ? { tested: finding(text, SIZE[key]) } : {}) } });
    ids[key] = one.body.id;
    made.push(one.body.id);
    if (key === "tower") {
      check(`Tower at /m/${ids.tower}, its finding kept as passed (${JSON.stringify(one.body.tested && { kept: one.body.tested.kept, passed: one.body.tested.passed })})`,
        one.status === 201 && one.body.tested?.kept === true && one.body.tested?.passed === true);
    } else {
      check(`${key} at /m/${one.body.id}: ${one.status}`, one.status === 201 && Boolean(one.body.id));
    }
    await new Promise((done) => setTimeout(done, 300));
  }
  const counts = { tower: await built(ids.tower, 2), wall: await built(ids.wall, 3), hall: await built(ids.hall, 1) };
  // Other flows list test models in the same project, and one run by
  // another agent is not this battery's to keep apart: designers_flow's
  // castle, built three times and Tested (16 this week), took the pick and
  // the top of You can build now mid-flow on m146's preview. As
  // gallery_order.mjs judges a place, these judge ours: this flow's models
  // in their order among the rest, and a pick not ours only when the rule
  // puts it above Tower's 11 this week.
  const ours = (list) => list.filter((id) => Object.values(ids).includes(id));
  const named = (id) => Object.keys(ids).find((key) => ids[key] === id) || id;
  const outscored = async (id) => {
    if (!id || Object.values(ids).includes(id)) return null;
    const pick = (await api("/api/share?op=shelves&tests=1")).body.pick;
    return pick?.model?.id === id && pick.chosen === false && Number(pick.week?.score) > 11 ? pick : null;
  };
  const another = (pick) => (pick ? `, another run's ${pick.model.name}, ${pick.week.score} this week over Tower's 11` : "");
  check(`builds finished, each on its own device: Tower ${counts.tower}, Wall ${counts.wall}, Hall ${counts.hall}`,
    counts.tower === 2 && counts.wall === 3 && counts.hall === 1);

  // --- 2. Top builds, through the list ----------------------------------------
  console.log("Top builds");
  const top = await api(`/api/share?op=list&tests=1&sort=top&q=${rand}`);
  const order = (top.body.models || []).map((one) => Object.keys(ids).find((key) => ids[key] === one.id));
  check(`Top builds: ${order.join(", ")}`, top.status === 200 && order.join(",") === "tower,wall,hall,shed");
  check(`...weighed as it says: ${JSON.stringify(top.body.score)}, and offered as "${(top.body.sorts || []).find((s) => s.id === "top")?.label}"`,
    top.body.score?.builds === 3 && top.body.score?.remixes === 2 && top.body.score?.tested === 5
      && (top.body.sorts || []).some((s) => s.id === "top" && s.label === "Top builds"));
  const most = await api(`/api/share?op=list&tests=1&sort=builds&q=${rand}`);
  check(`Most built, as before: ${(most.body.models || []).map((one) => Object.keys(ids).find((key) => ids[key] === one.id)).join(", ")}`,
    (most.body.models || [])[0]?.id === ids.wall);
  const visitorsTop = await api(`/api/share?op=list&sort=top&q=${rand}`);
  check(`a visitor's Top builds has none of these test models (${(visitorsTop.body.models || []).length})`,
    visitorsTop.status === 200 && (visitorsTop.body.models || []).length === 0);
  const bad = await api("/api/share?op=shelves&tests=maybe");
  check(`shelves asked with tests=maybe: ${bad.status}`, bad.status === 400);

  // The page, sorted by Top builds: the same order, and the line that says how.
  const desk = await context({ width: 1280, height: 900 });
  const deskPage = await desk.newPage();
  listen(deskPage, "visitor");
  await deskPage.goto(`${site}/gallery?tests=1&sort=top&q=${rand}`, { waitUntil: "load" });
  await until(deskPage, () => document.documentElement.dataset.gallery === "ready" && document.documentElement.dataset.shelves, "the gallery");
  let drawn = await frontDrawn(deskPage);
  check(`the page sorted by Top builds: ${drawn.grid.map((id) => Object.keys(ids).find((key) => ids[key] === id)).join(", ")}`,
    drawn.grid.join(",") === [ids.tower, ids.wall, ids.hall, ids.shed].join(","));
  check(`...says "${drawn.score}"`, drawn.score === "Top builds: a build finished counts 3, a remix 2 and the Tested mark 5. Views count for nothing.");
  check("...and a search hides the shelves", drawn.shelves === false);
  await shot(deskPage, "1_top_builds.png");

  // --- 3. The front: this week's pick and small builds --------------------------
  console.log("the gallery's front");
  const front = await api("/api/share?op=shelves&tests=1");
  const frontAbove = await outscored(front.body.pick?.model?.id);
  check(`the pick, worked out: ${named(front.body.pick?.model?.id)}, `
    + `${JSON.stringify(front.body.pick?.week)}${another(frontAbove)}`, front.status === 200 && (Boolean(frontAbove)
    || (front.body.pick?.model?.id === ids.tower
    && front.body.pick?.chosen === false && front.body.pick?.week?.builds === 2 && front.body.pick?.week?.tested === true
    && front.body.pick?.week?.score === 11)));
  const small = ours((front.body.small?.models || []).map((one) => one.id));
  check(`small builds: under ${front.body.small?.most + 1} parts, Tower then Wall first of ours, and not Hall (${(front.body.small?.models || []).length} on the shelf)`,
    small[0] === ids.tower && small[1] === ids.wall && !small.includes(ids.hall)
      && (front.body.small?.models || []).every((one) => one.parts <= 199));
  for (const [who, as] of [["signed out", null], ["signed in", bob]]) {
    for (const [width, height, phone] of [[1280, 900, false], [390, 844, true]]) {
      const made = await context({ as, width, height, phone });
      const page = await made.newPage();
      listen(page, `${who} ${width}`);
      await page.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.gallery === "ready" && document.documentElement.dataset.shelves === "ready", `the front, ${who}, ${width} px`);
      await page.waitForTimeout(400);
      drawn = await frontDrawn(page);
      drawn.small = ours(drawn.small);
      const drawnAbove = await outscored(drawn.pick);
      check(`${who} at ${width} px: ${who === "signed out" ? "no You can build now, no shares" : `You can build now asks for his collection: "${drawn.readySaid.slice(0, 60)}…"`}`,
        who === "signed out" ? !drawn.ready && drawn.owned === 0
          : drawn.ready && /Tell Brickworks what you own/.test(drawn.readySaid) && drawn.readyModels.length === 0);
      check(`${who} at ${width} px: the pick is Tower, "${drawn.why}"${another(drawnAbove)}; small builds start ${drawn.small.slice(0, 2).map(named).join(", ")}; nothing sideways`,
        drawn.shelves && (Boolean(drawnAbove) || (drawn.pick === ids.tower && drawn.why === "Built twice this week")) && drawn.chosen === "no"
          && drawn.small[0] === ids.tower && drawn.small[1] === ids.wall && !drawn.small.includes(ids.hall)
          && !(await sideways(page)));
      const tag = `${who === "signed out" ? "out" : "in"}-${width}`;
      await shot(page, `2_front_${tag}.png`, !phone);
      if (phone) {
        // The shelf scrolls sideways inside itself, and the page does not.
        await page.locator("#small").scrollIntoViewIfNeeded();
        await page.evaluate(() => { document.getElementById("small-models").scrollLeft = 600; });
        await page.waitForTimeout(300);
        const inside = await page.evaluate(() => document.getElementById("small-models").scrollLeft);
        check(`...at 390 px the small shelf scrolls inside itself (${inside} px) and the page still does not`,
          inside > 0 && !(await sideways(page)));
        await shot(page, `3_small_shelf_${tag}.png`);
      }
      if (who === "signed out" && width === 1280) {
        await page.click("#pick-card .model a.open");
        await page.waitForURL(`**/m/${drawn.pick}`, { timeout: 20000 });
        check(`the pick is a link: it opened ${new URL(page.url()).pathname}`, new URL(page.url()).pathname === `/m/${drawn.pick}`);
      }
      await made.close();
    }
  }

  // --- 4. The owner chooses the pick ------------------------------------------
  console.log("the site's owner chooses this week's pick, and ends it");
  master = await mintSession(process.env.MASTER_EMAIL);
  const adminContext = await context({ as: master, width: 1280, height: 900 });
  const admin = await adminContext.newPage();
  listen(admin, "admin");
  admin.on("dialog", (dialog) => dialog.accept());
  await admin.goto(`${site}/admin`, { waitUntil: "load" });
  await until(admin, () => !document.getElementById("view").classList.contains("hide"), "the admin page", 60);
  const button = admin.locator(`#gallery tr:has(a[href="/m/${ids.shed}"]) button`, { hasText: "Make it the pick" });
  check("Make it the pick beside Shed in the gallery's table", (await button.count()) === 1);
  await button.click();
  await until(admin, (id) => document.querySelector(`#choices tr[data-model="${id}"]`), "Shed among the choices", 30, ids.shed);
  const row = await admin.evaluate((id) => {
    const tr = document.querySelector(`#choices tr[data-model="${id}"]`);
    return { pick: tr.dataset.pick, text: tr.textContent.replace(/\s+/g, " ").trim() };
  }, ids.shed);
  chosen.push(Number(row.pick));
  check(`chosen for a week, and said not shown to visitors, being a test account's: "${row.text}"`,
    /a test account's/.test(row.text) && new RegExp(NAMES.shed).test(row.text));
  await shot(admin.locator("#pick-now"), "4_admin_pick_now.png");
  await shot(admin.locator("#choices").locator("xpath=ancestor::div[contains(@class,'card')]"), "5_admin_choices.png");
  const nowChosen = await api("/api/share?op=shelves&tests=1");
  check(`the front's pick is Shed now, chosen until ${nowChosen.body.pick?.until}`,
    nowChosen.body.pick?.model?.id === ids.shed && nowChosen.body.pick?.chosen === true
      && Math.abs(Date.parse(nowChosen.body.pick?.until) - Date.now() - 7 * 864e5) < 600000);
  const phone = await context({ width: 390, height: 844, phone: true });
  const phonePage = await phone.newPage();
  listen(phonePage, "visitor's phone");
  await phonePage.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
  await until(phonePage, () => document.documentElement.dataset.shelves === "ready", "the front with the chosen pick");
  drawn = await frontDrawn(phonePage);
  check(`...and says so on a phone: "${drawn.why}"`, drawn.pick === ids.shed && drawn.why === "Chosen by Brickworks"
    && drawn.chosen === "yes" && !(await sideways(phonePage)));
  await shot(phonePage, "6_front_chosen-390.png");
  const visitorsPick = await api("/api/share?op=shelves");
  check(`a visitor's front never shows it (${visitorsPick.body.pick?.model?.id || "no pick"})`,
    visitorsPick.status === 200 && visitorsPick.body.pick?.model?.id !== ids.shed);
  const refused = await api(`/api/admin?op=pick&id=${ids.secret}`, { method: "POST", token: master.access_token });
  check(`the model by link only may not be the pick: ${refused.status} "${refused.body.error}"`,
    refused.status === 422 && /Only a model in the gallery/.test(refused.body.error || ""));
  const stranger = await api(`/api/admin?op=pick&id=${ids.tower}`, { method: "POST", token: bob.access_token });
  check(`nobody else may choose: ${stranger.status}`, stranger.status === 404);
  const endButton = admin.locator(`#choices tr[data-model="${ids.shed}"] button`, { hasText: "End" });
  await endButton.click();
  await until(admin, (id) => !document.querySelector(`#choices tr[data-model="${id}"]`), "the choice ended", 30, ids.shed);
  chosen.length = 0;
  const after = await api("/api/share?op=shelves&tests=1");
  const afterAbove = await outscored(after.body.pick?.model?.id);
  check(`ended: the pick is Tower again, worked out (${after.body.pick?.chosen === false ? "worked out" : "chosen"}${another(afterAbove)})`,
    (Boolean(afterAbove) || after.body.pick?.model?.id === ids.tower) && after.body.pick?.chosen === false);
  await adminContext.close();

  // --- 5. Build with what I own -----------------------------------------------
  console.log("Bob keeps a collection, and the gallery says what he can build");
  const kept = await api("/api/collection", { method: "PUT", token: bob.access_token, body: {
    sets: [{ set: "10760-1", qty: 1, spares: false }, { set: "99999999-1", qty: 1, spares: false }],
    parts: [{ part: "3001", colour: 4, qty: 3 }, { part: "3001", colour: 1, qty: 1 }, { part: "3001", colour: 14, qty: 1 },
      { part: "3001", colour: 15, qty: 1 }] } });
  check(`his collection kept: ${kept.status}, ${kept.body.sets?.length} sets and ${kept.body.parts?.length} lots of loose parts`,
    kept.status === 200 && kept.body.sets?.length === 2 && kept.body.parts?.length === 4);
  const started = Date.now();
  const his = await api(`/api/share?op=list&tests=1&q=${rand}&mine=1`, { token: bob.access_token });
  const took = Date.now() - started;
  const shareOf = (key) => {
    const one = (his.body.models || []).find((m) => m.id === ids[key]);
    return one?.owned ? `${one.owned.have}/${one.owned.pieces}` : "none";
  };
  check(`each card says what he has: Tower ${shareOf("tower")}, Shed ${shareOf("shed")}, Wall ${shareOf("wall")}, Hall ${shareOf("hall")} (${took} ms, the pool counted first)`,
    his.status === 200 && shareOf("tower") === "3/3" && shareOf("shed") === "3/3" && shareOf("wall") === "1/3"
      && shareOf("hall") === "5/210");
  check(`his pool as the gallery counts it: ${JSON.stringify(his.body.mine)}, the set's parts in it and the unknown set said`,
    his.body.mine?.pieces > 6 && his.body.mine?.lots > 4 && his.body.mine?.unknown === 1);
  check(`...and Parts I own is offered him: ${(his.body.sorts || []).map((one) => one.label).join(", ")}`,
    (his.body.sorts || []).some((one) => one.id === "owned" && one.label === "Parts I own"));
  const owned = await api(`/api/share?op=list&tests=1&q=${rand}&mine=1&sort=owned`, { token: bob.access_token });
  const ownedOrder = (owned.body.models || []).map((one) => Object.keys(ids).find((key) => ids[key] === one.id));
  check(`Parts I own: ${ownedOrder.join(", ")}`, ownedOrder.join(",") === "tower,shed,wall,hall");
  const now = await api(`/api/share?op=list&tests=1&q=${rand}&mine=1&ready=1&sort=top`, { token: bob.access_token });
  check(`only what he can build now: ${(now.body.models || []).map((one) => Object.keys(ids).find((key) => ids[key] === one.id)).join(", ")}`,
    (now.body.models || []).map((one) => one.id).join(",") === [ids.tower, ids.shed].join(","));
  const nobody = await api(`/api/share?op=list&tests=1&q=${rand}&mine=1`);
  const signedOut = await api(`/api/share?op=list&tests=1&q=${rand}&sort=owned`, { token: bob.access_token });
  const plain = await api(`/api/share?op=list&tests=1&q=${rand}`, { token: bob.access_token });
  check(`his own and nobody else's: mine=1 signed out ${nobody.status}, Parts I own without mine=1 ${signedOut.status}, `
    + `a list without mine=1 has no shares (${(plain.body.models || []).filter((m) => m.owned).length})`,
    nobody.status === 401 && signedOut.status === 401 && (plain.body.models || []).every((m) => !m.owned));
  const shelf = await api("/api/share?op=shelves&tests=1&mine=1", { token: bob.access_token });
  const readyOurs = ours((shelf.body.ready?.models || []).map((one) => one.id));
  check(`You can build now, by Top builds: ${readyOurs.slice(0, 2).map(named).join(", ")} first of ours (${(shelf.body.ready?.models || []).length} on the shelf)`,
    readyOurs[0] === ids.tower && readyOurs[1] === ids.shed);
  for (const [width, height, phone] of [[1280, 900, false], [390, 844, true]]) {
    const made = await context({ as: bob, width, height, phone });
    const page = await made.newPage();
    listen(page, `Bob ${width}`);
    await page.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.gallery === "ready" && document.documentElement.dataset.shelves === "ready", `Bob's front, ${width} px`);
    await page.waitForTimeout(400);
    drawn = await frontDrawn(page);
    drawn.readyModels = ours(drawn.readyModels);
    check(`Bob at ${width} px: You can build now has ${drawn.readyModels.slice(0, 2).map(named).join(", ")}; "${drawn.readySaid.slice(0, 70)}…"; Tower's card "${(drawn.shares[ids.tower] || "").split(" ").slice(1).join(" ")}"; Parts I own under Sort; nothing sideways`,
      drawn.ready && drawn.readyModels[0] === ids.tower && drawn.readyModels[1] === ids.shed
        && /Every part of these is in your collection/.test(drawn.readySaid) && /1 set of yours has no parts list/.test(drawn.readySaid)
        && /You have every part/.test(drawn.shares[ids.tower] || "") && drawn.sorts.includes("owned") && !(await sideways(page)));
    await shot(page, `7_build_now-${width}.png`, !phone);
    if (phone) {
      await page.locator("#ready").scrollIntoViewIfNeeded();
      await shot(page, `8_build_now_shelf-${width}.png`);
    } else {
      await page.goto(`${site}/gallery?tests=1&sort=owned&q=${rand}`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.gallery === "ready", "Parts I own on the page");
      await page.waitForTimeout(300);
      drawn = await frontDrawn(page);
      check(`the page by Parts I own: ${drawn.grid.map((id) => Object.keys(ids).find((key) => ids[key] === id)).join(", ")}; Wall "${(drawn.shares[ids.wall] || "").split(" ").slice(1).join(" ")}", Hall "${(drawn.shares[ids.hall] || "").split(" ").slice(1).join(" ")}"`,
        drawn.grid.join(",") === [ids.tower, ids.shed, ids.wall, ids.hall].join(",")
          && /You have 1 of its 3 parts · 33%/.test(drawn.shares[ids.wall] || "")
          && /You have 5 of its 210 parts · 2%/.test(drawn.shares[ids.hall] || ""));
      await shot(page, "9_parts_i_own.png");
    }
    await made.close();
  }
  const adaPhone = await context({ as: ada, width: 390, height: 844, phone: true });
  const adaPage = await adaPhone.newPage();
  listen(adaPage, "Ada 390");
  await adaPage.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.shelves === "ready", "Ada's front");
  drawn = await frontDrawn(adaPage);
  check(`Ada, with no collection: asked to tell what she owns, no shares, no Parts I own`,
    drawn.ready && /Tell Brickworks what you own/.test(drawn.readySaid) && drawn.owned === 0 && !drawn.sorts.includes("owned"));
  await adaPage.locator("#ready").scrollIntoViewIfNeeded();
  await shot(adaPage, "10_no_collection-390.png");
  await adaPhone.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const one of chosen) {
    if (master) await api(`/api/admin?op=unpick&pick=${one}`, { method: "POST", token: master.access_token }).catch(() => {});
  }
  for (const id of made) {
    if (id && ada) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: ada.access_token }).catch(() => {});
  }
  if (bob) await api("/api/collection", { method: "DELETE", token: bob.access_token }).catch(() => {});
  await browser.close();
  for (const email of [adaEmail, bobEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED, ${passed} passed`
  : `discovery: Top builds, this week's pick, small builds, the owner's choice, and what you can build (${passed} passed)`);
process.exit(failed ? 1 : 0);
