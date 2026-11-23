// The weekly quick build, in real browsers (supabase/challenge_prompts.sql,
// api/_prompts.js): the owner sets one on /admin; the hourly run publishes
// its template as the house; publishing a copy of the template in the
// gallery enters it with no other act, and one tick keeps one out; its page
// shows every entry newest first, each turning in 3D on a tap; when it ends
// the run stacks them into one model that holds every part of them; two
// weeks in a row are a streak on the maker's profile.
//
//   node --env-file=.env tools/web/relay_server.mjs 11371 &
//   node --env-file=.env tools/web/prompts_flow.mjs --url=http://127.0.0.1:11371 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/prompts_flow.mjs --url=<preview> --out=DIR
//
// Needs supabase/challenge_prompts.sql applied: before it the console's list
// has no quick builds, which the flow says and stops (exit 2). Every prompt
// here is a test one (/admin?tests=1, ?tests=1 pages), seen by no visitor;
// the accounts are throwaways at Resend's test addresses, deleted at the
// end with their models, so every model is a test model. The hourly run is
// asked with the cron's key (CRON_SECRET) and ?tests=1, so it does only the
// test prompts' work. Nothing is emailed.
//
//   1. The owner, on /admin?tests=1 at 1280 px, sets a quick build: the
//      kind, a title and a brief, today the first day and a week its last.
//      Another on the same days is refused: one a week.
//   2. The run publishes its template as the house; again, it finds nothing
//      due. The page's Start opens /app?copy=<template>.
//   3. Ada and Ed each publish a copy of the template in the gallery: the
//      publish's answer says it was entered. Bob ticks it out (prompt_out):
//      kept out. Bob's unlisted copy is not entered, in words.
//   4. Its page at 390 (touch, light) and 1280 (dark): Start, the two
//      entries newest first (Ed's, then Ada's), Bob's nowhere; a tap on a
//      card's picture turns the model in 3D in its place. Its LCP and CLS
//      beside the month's page, timed at the same moments.
//   5. The hub (/challenge?tests=1) has This week's quick build with Start.
//      Ed's notifications have its group, "Quick build: …", with Start.
//   6. The owner ends it; the run stacks it: the stack's card on the page,
//      its parts the sum of the entries', its own page turns it in 3D.
//   7. A second week: Ada enters it too; her profile's Streak is reached,
//      two weeks in a row.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession } from "./session.mjs";
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
const site = String(args.url || "http://127.0.0.1:11371").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/prompts"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const { templateText } = await import(path.join(root, "api/_prompts.js"));
const rand = randomBytes(4).toString("hex");
const emails = { ada: `delivered+bw-prompts-ada-${rand}@resend.dev`, bob: `delivered+bw-prompts-bob-${rand}@resend.dev`,
  ed: `delivered+bw-prompts-ed-${rand}@resend.dev` };
const HANDLES = { ada: `bwp-ada-${rand}`, bob: `bwp-bob-${rand}`, ed: `bwp-ed-${rand}` };
const TITLE = `Quick week ${rand}`;
const SECOND = `Quick week two ${rand}`;
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];

/// One request to the site's API: {status, body}.
async function api(pathname, { method = "GET", token, body, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}
/// The hourly run, for the test prompts alone.
const run = () => api("/api/share?op=prompts&tests=1", { extra: { authorization: `Bearer ${process.env.CRON_SECRET || ""}` } });

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// A copy of a template's plate with [count] bricks on it, as the studio
/// saves one: the template's lines, then its own.
function copyOf(name, count, colour) {
  const lines = templateText({ seed: "flow", title: name, brief: "A flow's copy." }).split("\n")
    .filter((line) => line.startsWith("1 "));
  for (let n = 0; n < count; n++) {
    lines.push(`1 ${colour} ${-60 + (n % 4) * 40} ${-8 - 24 * Math.floor(n / 4)} -10 1 0 0 0 1 0 0 0 1 3004.dat`);
  }
  return `0 ${name}\r\n0 Name: prompts_${rand}.ldr\r\n0 Author: Prompts Flow\r\n`
    + `${lines.join("\r\n")}\r\n0 // prompts flow ${rand} ${name}\r\n`;
}

const browser = await launch({ signedOut: true });
async function context({ width = 1280, height = 900, phone = false, dark = false, as = null } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    const { STORAGE_KEY } = await import("./session.mjs");
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

/// What a page's first screen cost: its LCP and its layout shifts, from
/// the browser's own entries.
const watchPaint = () => {
  window.__lcp = 0;
  window.__cls = 0;
  new PerformanceObserver((list) => { for (const one of list.getEntries()) window.__lcp = one.startTime; })
    .observe({ type: "largest-contentful-paint", buffered: true });
  new PerformanceObserver((list) => {
    for (const one of list.getEntries()) if (!one.hadRecentInput) window.__cls += one.value;
  }).observe({ type: "layout-shift", buffered: true });
};

let master = null;
const who = {};
const made = [];
const ids = {};
const median = (list) => [...list].sort((a, b) => a - b)[Math.floor(list.length / 2)];
try {
  console.log(`against ${site}`);
  master = await mintSession(process.env.MASTER_EMAIL);
  const before = await api("/api/admin?tests=1", { token: master.access_token });
  if (before.status === 200 && before.body.prompts === null) {
    console.log("  --    not open here: supabase/challenge_prompts.sql is not applied (the console lists no quick builds)");
    await browser.close();
    process.exit(2);
  }
  check(`the console lists the quick builds (${before.status}, ${Array.isArray(before.body.prompts) ? before.body.prompts.length : "none"})`,
    before.status === 200 && Array.isArray(before.body.prompts));
  // A test one a flow left behind ends first: one a week.
  for (const one of (before.body.prompts || []).filter((p) => p.test && p.state !== "ended")) {
    await api(`/api/admin?op=end_challenge&challenge=${one.id}&tests=1`, { method: "POST", token: master.access_token });
  }
  const today = new Date().toISOString().slice(0, 10);
  const week = new Date(Date.now() + 6 * 864e5).toISOString().slice(0, 10);

  // --- 1. The owner sets it ------------------------------------------------
  console.log("1. the owner sets a quick build on /admin");
  {
    const adminContext = await context({ as: master, dark: true });
    const admin = await adminContext.newPage();
    listen(admin, "admin");
    admin.on("dialog", (dialog) => dialog.accept());
    await admin.goto(`${site}/admin?tests=1#gallery/challenges`, { waitUntil: "load" });
    await until(admin, () => !document.getElementById("view").classList.contains("hide"), "the admin page", 60);
    await admin.check('#challenge-form input[name="kind"][value="prompt"]');
    const form = await admin.evaluate(() => ({ rules: document.querySelector("#challenge-form fieldset.rules").hidden,
      template: !document.querySelector('#challenge-form input[name="template"]').closest("label").hidden,
      button: document.querySelector('#challenge-form button[type="submit"]').textContent }));
    check(`the kind changes the form: rules hidden ${form.rules}, a template asked ${form.template}, "${form.button}"`,
      form.rules && form.template && form.button === "Set the quick build");
    await admin.fill('#challenge-form input[name="title"]', TITLE);
    await admin.fill('#challenge-form textarea[name="brief"]', "A home for one minifigure on an 8×8 plate, within 10 bricks tall.");
    for (const [date, iso] of [["starts_on", today], ["ends_on", week]]) {
      const [year, month, day] = iso.split("-").map(Number);
      await admin.selectOption(`#challenge-form select[name="${date}_day"]`, String(day));
      await admin.selectOption(`#challenge-form select[name="${date}_month"]`, String(month));
      await admin.selectOption(`#challenge-form select[name="${date}_year"]`, String(year));
    }
    await admin.click('#challenge-form button[type="submit"]');
    const row = await until(admin, (title) => {
      const tr = [...document.querySelectorAll("#challenges tr[data-prompt]")].find((one) => one.textContent.includes(title));
      return tr ? { id: tr.dataset.prompt, state: tr.dataset.state, text: tr.textContent.replace(/\s+/g, " "),
        note: document.getElementById("challenge-note").textContent } : null;
    }, "the quick build listed", 30, TITLE);
    ids.first = Number(row.id);
    check(`set: "${row.note}"; listed ${row.state}: ${row.text.slice(0, 140)}`, row.state === "open" && /a quick build/.test(row.note));
    await shot(admin, "1_admin_set-1280.png");
    await adminContext.close();
    const again = await api("/api/admin?op=challenge&tests=1", { method: "POST", token: master.access_token,
      body: { kind: "prompt", title: `Another ${rand}`, brief: "B", starts_on: today } });
    check(`another the same week is refused: ${again.status} "${again.body.error}"`, again.status === 409);
  }

  // --- 2. The house's template ---------------------------------------------
  console.log("2. the hourly run publishes its template");
  {
    const first = await run();
    check(`the run (${first.status}): ${JSON.stringify(first.body).slice(0, 200)}`, first.status === 200);
    const page = await api(`/api/people?op=challenge&id=${ids.first}&tests=1`);
    ids.template = page.body.prompt?.template?.id;
    check(`its page names the template ${ids.template} and Start ${page.body.prompt?.start}`,
      page.status === 200 && /^[A-Za-z0-9]{10}$/.test(String(ids.template || "")) && page.body.prompt.start === `/app?copy=${ids.template}`);
    const second = await run();
    check(`again, nothing more for it: ${JSON.stringify(second.body?.did || []).slice(0, 160)}`, second.status === 200
      && !JSON.stringify(second.body?.did || []).includes(`"template"`));
    const of = await api(`/api/people?op=prompt_of&model=${ids.template}&tests=1`);
    check(`the studio's question about the template: ${JSON.stringify(of.body.prompt || null).slice(0, 160)}`,
      of.status === 200 && of.body.prompt?.id === ids.first && of.body.prompt?.template === ids.template);
  }

  // --- 3. Entering, as people publish ----------------------------------------
  console.log("3. publishing a copy in the gallery enters it");
  for (const name of ["ada", "bob", "ed"]) {
    who[name] = await mintSession(emails[name]);
    await api("/api/people?op=profile", { method: "POST", token: who[name].access_token,
      body: { handle: HANDLES[name], name: `${name[0].toUpperCase()}${name.slice(1)} Prompts` } });
  }
  const publish = async (owner, name, count, colour, extra = {}) => {
    const text = copyOf(name, count, colour);
    const one = await api("/api/share", { method: "POST", token: who[owner].access_token, body: {
      name, author: `${owner} Prompts`, model: text, image: picture, listed: true, remixed_from: ids.template,
      made_with: "hand", ...extra } });
    if (one.body.id) made.push([one.body.id, owner]);
    await new Promise((done) => setTimeout(done, 400));
    return one;
  };
  {
    const ada = await publish("ada", `Ada's nook ${rand}`, 6, 4);
    ids.ada = ada.body.id;
    check(`Ada publishes, nothing else: ${ada.status}, ${JSON.stringify(ada.body.prompt)}`,
      ada.status === 201 && ada.body.prompt?.entered === true && ada.body.prompt?.id === ids.first);
    await new Promise((done) => setTimeout(done, 1200));
    const ed = await publish("ed", `Ed's shed ${rand}`, 10, 14);
    ids.ed = ed.body.id;
    check(`Ed publishes: ${ed.status}, entered ${ed.body.prompt?.entered}`, ed.status === 201 && ed.body.prompt?.entered === true);
    const bob = await publish("bob", `Bob's own ${rand}`, 4, 1, { prompt_out: true });
    ids.bob = bob.body.id;
    check(`Bob ticks it out: ${bob.status}, ${JSON.stringify(bob.body.prompt)}`,
      bob.status === 201 && bob.body.prompt?.entered === false && bob.body.prompt?.kept_out === true);
    const hidden = await publish("bob", `Bob's unlisted ${rand}`, 3, 1, { listed: false });
    check(`Bob's unlisted copy is not entered, in words: "${hidden.body.prompt?.said}"`,
      hidden.status === 201 && hidden.body.prompt?.entered === false && Boolean(hidden.body.prompt?.said));
  }

  // --- 4. Its page -------------------------------------------------------------
  console.log("4. its page, Start, the entries, a card turning");
  for (const [width, height, phone, dark] of [[390, 844, true, false], [1280, 900, false, true]]) {
    const ctx = await context({ width, height, phone, dark });
    const page = await ctx.newPage();
    listen(page, `page at ${width}`);
    await page.goto(`${site}/challenge?id=${ids.first}&tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challenge === "prompt-open", "the quick build drawn", 40);
    const seen = await page.evaluate(() => ({
      start: document.getElementById("start").hidden ? "" : document.getElementById("start").getAttribute("href"),
      cards: [...document.querySelectorAll("#prompt-cards .model")].map((card) => card.querySelector(".words b")?.textContent || ""),
      how: !document.getElementById("prompt-how").hidden, empty: !document.getElementById("prompt-empty").hidden,
      sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
      month: !document.getElementById("entries").hidden || !document.getElementById("enter").hidden }));
    check(`at ${width}: Start ${seen.start}, cards ${JSON.stringify(seen.cards)}, how ${seen.how}, nothing sideways`,
      seen.start === `/app?copy=${ids.template}` && seen.cards.length === 2 && seen.cards[0].startsWith("Ed's shed")
      && seen.cards[1].startsWith("Ada's nook") && seen.how && !seen.empty && !seen.sideways && !seen.month);
    await shot(page, `4_page-${width}.png`, true);
    // A tap on the first card's picture: the model turns in its place.
    const card = page.locator("#prompt-cards .model a.picture").first();
    await card.scrollIntoViewIfNeeded();
    if (phone) await card.tap();
    else await card.click();
    const turned = await until(page, () => {
      const shell = document.querySelector("#prompt-cards .view3d");
      return shell && !shell.hidden && shell.dataset.state !== "loading" ? shell.dataset.state || "shown" : null;
    }, "the card in 3D", 60).catch((trouble) => `not: ${trouble.message}`);
    check(`at ${width}: the first card turns in 3D in its place (${turned})`, !/^not|failed/.test(String(turned)));
    await shot(page, `4_turning-${width}.png`);
    await ctx.close();
  }
  {
    // The first screen beside the month's, each at the same moments.
    const rounds = [];
    for (let at = 0; at < 3; at++) {
      for (const [width, height, phone] of [[390, 844, true], [1280, 900, false]]) {
        const pair = await Promise.all([`/challenge?id=${ids.first}&tests=1`, "/challenge"].map(async (address) => {
          const ctx = await context({ width, height, phone });
          const page = await ctx.newPage();
          await page.addInitScript(watchPaint);
          await page.goto(`${site}${address}`, { waitUntil: "load" });
          await page.waitForTimeout(2500);
          const said = await page.evaluate(() => ({ lcp: window.__lcp, cls: window.__cls }));
          await ctx.close();
          return said;
        }));
        rounds.push({ width, prompt: pair[0], month: pair[1] });
      }
    }
    for (const width of [390, 1280]) {
      const mine = rounds.filter((one) => one.width === width);
      const lcp = median(mine.map((one) => one.prompt.lcp));
      const theirs = median(mine.map((one) => one.month.lcp));
      const cls = Math.max(...mine.map((one) => one.prompt.cls));
      check(`at ${width}: LCP ${Math.round(lcp)} ms beside the month's ${Math.round(theirs)} ms, CLS at most ${cls.toFixed(3)}`,
        lcp <= Math.max(theirs * 1.15, theirs + 150) && cls < 0.1);
    }
  }

  // --- 5. The hub and the notice ------------------------------------------------
  console.log("5. the hub and Ed's notice");
  {
    const ctx = await context({ width: 1280, dark: false });
    const page = await ctx.newPage();
    listen(page, "hub");
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    const week = await until(page, () => {
      const box = document.getElementById("week");
      return box && !box.hidden ? { title: document.getElementById("week-title").textContent,
        start: document.getElementById("week-start").getAttribute("href") } : null;
    }, "This week's quick build on the hub", 30).catch(() => null);
    check(`the hub: ${JSON.stringify(week)}`, week?.title === TITLE && week?.start === `/app?copy=${ids.template}`);
    await shot(page, "5_hub-1280.png");
    await ctx.close();
    const heard = await api("/api/people?op=notifications", { token: who.ed.access_token });
    const group = (heard.body.groups || []).find((one) => Number(one.challenge) === ids.first);
    check(`Ed's notifications: ${JSON.stringify(group ? { name: group.name, start: group.start } : null)}`,
      group?.name === `Quick build: ${TITLE}` && String(group?.start || "").endsWith(`/app?copy=${ids.template}`));
    const phone = await context({ width: 390, height: 844, phone: true, dark: true, as: who.ed });
    const notices = await phone.newPage();
    listen(notices, "Ed's notifications");
    await notices.goto(`${site}/notifications?tests=1`, { waitUntil: "load" });
    const start = await until(notices, (template) => [...document.querySelectorAll("a.cta.small")]
      .find((a) => a.getAttribute("href")?.endsWith(`/app?copy=${template}`))?.textContent || null,
    "Start in the notice", 30, ids.template).catch(() => null);
    check(`its notice has ${start ? `"${start}"` : "no Start"}`, start === "Start");
    await shot(notices, "5_notice-390.png");
    await phone.close();
  }

  // --- 6. The stack ---------------------------------------------------------------
  console.log("6. it ends; the run stacks it");
  {
    const ended = await api(`/api/admin?op=end_challenge&challenge=${ids.first}&tests=1`, { method: "POST", token: master.access_token });
    check(`ended: ${ended.status}`, ended.status === 200);
    const stacked = await run();
    check(`the run (${stacked.status}): ${JSON.stringify(stacked.body?.did || []).slice(0, 200)}`, stacked.status === 200);
    const page = await api(`/api/people?op=challenge&id=${ids.first}&tests=1`);
    const stack = page.body.prompt?.stack;
    const parts = (page.body.prompt?.entries || []).reduce((sum, one) => sum + (Number(one.parts) || 0), 0);
    ids.stack = stack?.id;
    check(`the stack ${stack?.id} "${stack?.name}", ${stack?.parts} parts, its entries' ${parts}`,
      /^[A-Za-z0-9]{10}$/.test(String(stack?.id || "")) && Number(stack?.parts) === parts && parts > 0);
    const ctx = await context({ width: 1280, dark: true });
    const view = await ctx.newPage();
    listen(view, "the stack's page");
    await view.goto(`${site}/m/${ids.stack}?tests=1`, { waitUntil: "load" });
    const big = view.locator(".model-page a.picture[data-scene], a.picture[data-scene]").first();
    await big.click({ timeout: 30000 }).catch(() => {});
    const turned = await until(view, () => {
      const shell = document.querySelector(".view3d");
      return shell && !shell.hidden && shell.dataset.state !== "loading" ? shell.dataset.state || "shown" : null;
    }, "the stack in 3D", 90).catch((trouble) => `not: ${trouble.message}`);
    check(`the stack's page turns it in 3D (${turned})`, !/^not|failed/.test(String(turned)));
    await shot(view, "6_stack-1280.png");
    await ctx.close();
  }

  // --- 7. A second week: the streak --------------------------------------------
  console.log("7. a second week: Ada's streak");
  {
    const set = await api("/api/admin?op=challenge&tests=1", { method: "POST", token: master.access_token,
      body: { kind: "prompt", title: SECOND, brief: "A winter scene on an 8×8 plate.", starts_on: today } });
    ids.second = set.body.challenge;
    check(`the second set: ${set.status}`, set.status === 200 && Boolean(ids.second));
    await run();
    const page = await api(`/api/people?op=challenge&id=${ids.second}&tests=1`);
    const firstTemplate = ids.template;
    ids.template = page.body.prompt?.template?.id;
    check(`its own template ${ids.template}`, Boolean(ids.template) && ids.template !== firstTemplate);
    const ada = await publish("ada", `Ada's snow ${rand}`, 5, 15);
    check(`Ada enters the second: ${JSON.stringify(ada.body.prompt)}`, ada.body.prompt?.entered === true);
    const ctx = await context({ width: 390, height: 844, phone: true, as: who.ada });
    const mine = await ctx.newPage();
    listen(mine, "Ada's page");
    await mine.goto(`${site}/profile?tab=achievements&tests=1`, { waitUntil: "load" });
    const tile = await until(mine, () => {
      const li = document.querySelector('#achievements li[data-track="streak"]');
      return li ? { level: Number(li.dataset.level), name: li.querySelector("h3")?.textContent.trim() } : null;
    }, "the Streak tile", 40).catch(() => null);
    check(`Ada's Streak: ${JSON.stringify(tile)}`, tile?.level === 1 && tile?.name === "Streak · 2 weeks");
    await shot(mine, "7_streak-390.png");
    await ctx.close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const id of master ? [ids.first, ids.second].filter(Boolean) : []) {
    await api(`/api/admin?op=end_challenge&challenge=${id}&tests=1`, { method: "POST", token: master.access_token }).catch(() => {});
  }
  for (const [id, owner] of made.reverse()) {
    if (id && who[owner]) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who[owner].access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED, ${passed} ok`
  : `prompts: set, templated, entered by publishing, kept out, stacked and streaked (${passed} checks, all ok)`);
process.exit(failed ? 1 : 0);
