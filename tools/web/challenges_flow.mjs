// The monthly challenge, in real browsers: the site's owner sets one on
// /admin with three rules (at most 30 parts, only the parts of set 6075-2,
// Tested); a designer enters a model from its page, built by hand, and is
// told in words which rule each of her others breaks; another enters his
// with the assistant; people vote once in each group, never for their own,
// and nobody under 13; when it ends the most voted in each wins, and her
// designer page and the model's card say so.
//
//   node --env-file=.env tools/web/relay_server.mjs 9271 --hold=challenges &
//   node --env-file=.env tools/web/challenges_flow.mjs --url=http://127.0.0.1:9271 --held --out=shots/challenges
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/challenges_flow.mjs --url=<preview> --out=DIR
//
// Until supabase/challenges.sql is applied the local relay holds it in memory
// (--hold=challenges, tools/web/challenges_stand_in.mjs) over the live
// project's tables, and --held says so: the feed, which the database makes
// from its own entries, is then not asked; on a deployment everything is asked of its API alone,
// with the bypass headers: /api/share, /api/people and /api/admin, nothing
// else. The challenge is a test one (/admin?tests=1), which only a page
// asked with tests=1 shows, so no visitor ever sees it; throwaway accounts at
// Resend test addresses, so every model here is a test model; deleted at the
// end with their models. Nothing is emailed to anybody.
//
//   1. The owner, on /admin?tests=1 at 1280 and 390 px: sets the challenge
//      with its three rules; another on the same days is refused, one at a
//      time.
//   2. Ada shares a house (12 yellow 1 x 2 bricks, in the set, Tested), a
//      tower (red, not in the set), a hall (40 red bricks) and a plain one
//      (not Tested); Bob shares a shed (yellow 1 x 4 bricks, Tested).
//   3. Ada on the house's page, at 390 px: Enter this month's challenge, its
//      rules in the dialog, By hand, Enter it: it is in. On the tower's
//      page the dialog says the set's rule, naming the red brick; the hall
//      is refused for its parts and the set, the plain one for Tested, each
//      in words. Bob enters his shed with the assistant from /challenge's
//      own Enter a model, at 1280 px: his models in the gallery to choose
//      from; the page then shows that group, his shed marked Your entry.
//      Cy, under 13, is refused.
//      Ed, who follows Ada, finds it in his feed at 390 (light) and 1280
//      (dark): "Ada entered “the house” in the challenge “…”, built by hand".
//   4. /challenge signed out at 1280 (light) and 390 (dark), laid out as
//      the best contest pages are (challengepage, tools/web/challenge_page.mjs
//      judges it): the status Open, a live countdown that counts, the day
//      it is of how many, the numbers, Enter a model beside Share, the
//      three rules, the groups as tabs with their counts (the house under
//      Built by hand, the shed under Built with the assistant, a tab and the
//      arrow keys between them), each the gallery's card with Vote at its
//      foot; Vote and Enter a model each ask to sign in; and the gallery's
//      front says it in one line.
//   5. Ed, signed in at 390 (light) and 1280 (dark), votes for both, each
//      asked once in a dialog: each card is marked Your vote and the line
//      over the cards names it. Bob votes for the house and is refused a
//      second in its group; his own shed says Your entry; Ada may not vote
//      for her own, nor Cy at all, and the page tells Cy why.
//   6. The owner ends it on /admin: /challenge shows the winners first, over
//      the entries, the house by hand with 2 votes and the shed with the
//      assistant with 1, each entry's votes; Ada's designer page has the win as the first of her
//      achievements under her numbers (the house and its 2 votes on hover,
//      docs/SOCIAL.md U13), and the house's card there and in the gallery
//      says it won.
//
// Between months (supabase/challenge_year.sql, docs/SOCIAL.md U12): in 1 the
// owner also sets a year of themes, three months from next month, and reads
// them back, the first told at once and the others from a month before each
// opens; in 4 the hub says the first as Coming next and never names the
// others, whose pages are refused; in 6, once it ends, the hub shows the
// first theme, or the owner's real challenge when one is open, and lists it
// first under Past challenges as a card, both winners' pictures and names,
// its name a link to its own page, which shows the winners and votes. Before that file is applied, the
// year's form says it is not open yet, and 6 reads the hub as before.
//
// Who won is told (supabase/challenge_notices.sql, docs/SOCIAL.md section
// 7, item 3): in 6 Ed, who voted and entered nothing, has it in his
// Notifications, a group of the challenge's own, at 390 px (dark); its row
// opens the challenge's page, and the group is read after. Bob and Ada,
// who entered, hear it under their models instead. Before that file,
// nobody has such a group.
// Then its link: /challenge?id=N has this challenge's own title, words and
// winner's picture in its head, under the page's security policy.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { drawn, judged } from "./challenge_page.mjs";
import { deleteAccount, mintSession, answerAge, STORAGE_KEY } from "./session.mjs";
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
const site = String(args.url || "http://127.0.0.1:9271").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/challenges"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
// Against a relay that holds the challenges in memory: the feed is the database's.
const held = Boolean(args.held);
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const { modelHash } = await import(path.join(root, "api/_directory.js"));
const rand = randomBytes(4).toString("hex");
const emails = { ada: `delivered+bw-challenges-ada-${rand}@resend.dev`, bob: `delivered+bw-challenges-bob-${rand}@resend.dev`,
  cy: `delivered+bw-challenges-cy-${rand}@resend.dev`, ed: `delivered+bw-challenges-ed-${rand}@resend.dev` };
const ADA = `bwc-ada-${rand}`;
const BOB = `bwc-bob-${rand}`;
const TITLE = `Yellow castle week ${rand}`;
const SET = "6075-2";

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

/// [count] of [part] in [colour], each its own step, carrying its steps.
function model(name, count, part, colour) {
  const lines = [`0 ${name}`, `0 Name: challenges_${rand}.ldr`, "0 Author: Challenges Flow",
    `0 !BRICKWORKS PAGES {"v":1,"steps":${count}}`];
  for (let n = 0; n < count; n++) {
    lines.push(`1 ${colour} ${(n % 6) * 80} ${-24 * Math.floor(n / 6)} 0 1 0 0 0 1 0 0 0 1 ${part}.dat`);
    lines.push("0 STEP");
  }
  lines.push(`0 // challenges flow ${rand} ${name}`);
  return `${lines.join("\r\n")}\r\n`;
}

/// The app's finding of [text] as the Share panel sends it: all four passed.
const finding = (text, count) => ({ v: 1, app: "0.3.0", model: modelHash(text), steps: count, parts: count,
  tests: Object.fromEntries(["stands", "steps", "parts", "whole"].map((name) => [name,
    { ok: true, why: "Checked by the challenges flow's model" }])) });

const browser = await launch({ signedOut: true });

// Every renewal of a session the pages asked Supabase for, by page, with its
// answer. Supabase renews only so many sessions from one address (150 in
// five minutes, 30 at once), shared by every flow on this machine; each
// signed-in page renewed three or four times over (the header, the theme,
// the page's own, and the admin page at every call), 34 in one run, and
// m145's and m146's ran out: End it now, and Cy's page, drawn signed out.
const renewals = new Map();
const labels = new WeakMap();

async function context({ as = null, width = 1280, height = 900, phone = false, dark = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  made.on("response", (reply) => {
    if (!/\/auth\/v1\/token\?grant_type=refresh_token/.test(reply.url())) return;
    const page = reply.request().frame()?.page();
    const who = (page && labels.get(page)) || "a page";
    renewals.set(who, [...(renewals.get(who) || []), reply.status()]);
  });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, who) {
  labels.set(page, who);
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
async function pictures(page, selector = ".model img") {
  const count = await page.locator(selector).count();
  for (let at = 0; at < count; at++) await page.locator(selector).nth(at).scrollIntoViewIfNeeded().catch(() => {});
  await until(page, (wanted) => [...document.querySelectorAll(wanted)].every((img) => img.complete && img.naturalWidth > 0),
    `the pictures ${selector}`, 30, selector).catch(() => false);
  await page.evaluate(() => window.scrollTo(0, 0));
  // Decoded, as well as loaded: a picture is drawn a moment after it arrives.
  await page.waitForTimeout(800);
}


let master = null;
const who = {};
const made = [];
const ids = {};
try {
  console.log(`against ${site}`);
  master = await mintSession(process.env.MASTER_EMAIL);
  // Any test challenge a flow left open ends first: one at a time.
  const before = await api("/api/admin?tests=1", { token: master.access_token });
  for (const one of (before.body.challenges || []).filter((c) => c.test && c.state !== "ended")) {
    await api(`/api/admin?op=end_challenge&challenge=${one.id}&tests=1`, { method: "POST", token: master.access_token });
  }
  check(`the admin page's challenges are open here (${before.status}, ${Array.isArray(before.body.challenges) ? "listed" : `not open: "${before.body.error}"`})`,
    before.status === 200 && Array.isArray(before.body.challenges));

  // --- 1. The owner sets it ------------------------------------------------
  console.log("the owner sets the challenge on /admin");
  const today = new Date().toISOString().slice(0, 10);
  // A week, inside this month, so a year of themes from next month is free
  // and its first is told at once (a month before it opens).
  const monthEnd = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() + 1, 0)).toISOString().slice(0, 10);
  const week = new Date(Date.now() + 6 * 864e5).toISOString().slice(0, 10);
  const last = week < monthEnd ? week : monthEnd;
  const THEMES = [`Year ${rand} one`, `Year ${rand} two`, `Year ${rand} three`];
  let year = false;
  // Which of the year's themes is told already: each from 31 days before it
  // opens (api/admin.js's lead_days, "a month before"). On the last day of a
  // month before a month of 30 days, as 2026-10-31, the second is told at
  // once with the first; the third never is.
  let toldYet = [true, false, false];
  for (const [width, height, phone] of [[390, 844, true], [1280, 900, false]]) {
    const adminContext = await context({ as: master, width, height, phone, dark: true });
    const admin = await adminContext.newPage();
    listen(admin, `admin at ${width} px`);
    admin.on("dialog", (dialog) => dialog.accept());
    await admin.goto(`${site}/admin?tests=1#gallery/challenges`, { waitUntil: "load" });
    await until(admin, () => !document.getElementById("view").classList.contains("hide"), "the admin page", 60);
    if (width === 1280) {
      await admin.fill('#challenge-form input[name="title"]', TITLE);
      await admin.fill('#challenge-form textarea[name="brief"]', "Build a small yellow house from the parts of the Castle set, "
        + "in under 30 parts, and have the app test it.");
      // Each day as the site asks a date: day, month and year dropdowns.
      for (const [date, iso] of [["starts_on", today], ["ends_on", last]]) {
        const [year, month, day] = iso.split("-").map(Number);
        await admin.selectOption(`#challenge-form select[name="${date}_day"]`, String(day));
        await admin.selectOption(`#challenge-form select[name="${date}_month"]`, String(month));
        await admin.selectOption(`#challenge-form select[name="${date}_year"]`, String(year));
      }
      await admin.check('#challenge-form input[name="has_most"]');
      await admin.fill('#challenge-form input[name="most_parts"]', "30");
      await admin.check('#challenge-form input[name="has_set"]');
      await admin.fill('#challenge-form input[name="set_number"]', SET);
      await admin.check('#challenge-form input[name="tested"]');
      await admin.click('#challenge-form button[type="submit"]');
      await until(admin, (title) => [...document.querySelectorAll("#challenges tr[data-state]")]
        .some((tr) => tr.textContent.includes(title)), "the challenge listed", 30, TITLE);
      const row = await admin.evaluate((title) => {
        const tr = [...document.querySelectorAll("#challenges tr[data-state]")].find((one) => one.textContent.includes(title));
        return { state: tr.dataset.state, text: tr.textContent.replace(/\s+/g, " "), id: tr.dataset.challenge,
          note: document.getElementById("challenge-note").textContent };
      }, TITLE);
      ids.challenge = Number(row.id);
      check(`set: "${row.note}"; listed ${row.state}: ${row.text.slice(0, 160)}`, row.state === "open"
        && /at most 30 parts; set 6075-2, Castle; Tested/.test(row.text) && /with set 6075-2 \(Castle, \d+ lots\)/.test(row.note));
      await admin.evaluate(() => document.getElementById("challenges").scrollIntoView());
      await shot(admin, "1_admin_set-1280.png", false);

      // A year of themes, from the month after this one: three months of it.
      year = await admin.evaluate(() => document.getElementById("year-not-yet")?.hidden === true);
      if (!year) {
        const form = await admin.evaluate(() => ({ said: !document.getElementById("year-not-yet")?.hidden,
          disabled: document.querySelector('#year-form button[type="submit"]')?.disabled }));
        check(`before challenge_year.sql: the year's form says it is not open yet (${JSON.stringify(form)})`, form.said && form.disabled);
      } else {
        const next = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() + 1, 1));
        const months = [0, 1, 2].map((n) => new Date(Date.UTC(next.getUTCFullYear(), next.getUTCMonth() + n, 1)).toISOString().slice(0, 7));
        toldYet = months.map((month) => Date.parse(`${month}-01T00:00:00Z`) - 31 * 864e5 <= Date.now());
        const first = await admin.evaluate(() => document.querySelector("#year-months fieldset")?.dataset.month);
        check(`the year's form starts at the month after this challenge: ${first}`, first === months[0]);
        for (const [at, title] of THEMES.entries()) {
          await admin.fill(`#year-months input[name="theme_${at}_title"]`, title);
          await admin.fill(`#year-months textarea[name="theme_${at}_brief"]`, `The brief of ${title}.`);
        }
        await admin.click('#year-form button[type="submit"]');
        await until(admin, (titles) => titles.every((one) => [...document.querySelectorAll("#challenges tr[data-state]")]
          .some((tr) => tr.textContent.includes(one))) || document.querySelector("#year-note.bad"), "the year listed", 30, THEMES);
        const back = await admin.evaluate((titles) => ({ note: document.getElementById("year-note").textContent,
          rows: titles.map((one) => [...document.querySelectorAll("#challenges tr[data-state]")].find((tr) => tr.textContent.includes(one)))
            .map((tr) => tr ? { id: Number(tr.dataset.challenge), state: tr.dataset.state, text: tr.textContent.replace(/\s+/g, " ") } : null) }), THEMES);
        ids.year = back.rows.map((one) => one?.id);
        check(`the year set: "${back.note}"; read back: ${back.rows.map((one) => one && one.text.slice(0, 80)).join(" | ")}`,
          /^Set: 3 themes, from 1 /.test(back.note) && back.rows.every((one, at) => one && one.state === "upcoming"
            && /to come, told from /.test(one.text) === !toldYet[at]));
        const listed = await api("/api/admin?tests=1", { token: master.access_token });
        const rows = THEMES.map((one) => (listed.body.challenges || []).find((c) => c.title === one));
        check(`...and the admin's answer: each its month and when it is told (${rows.map((one) => one && `${one.starts_on}…${one.ends_on}`).join(", ")})`,
          rows.every((one, at) => one && one.starts_on === `${months[at]}-01` && one.announced_at && one.state === "upcoming")
          && rows.every((one, at) => one && (Date.parse(one.announced_at) <= Date.now()) === toldYet[at]));
        await admin.evaluate(() => document.getElementById("year-form").scrollIntoView());
        await shot(admin, "1b_admin_year-1280.png", false);
      }
    } else {
      const days = await admin.evaluate(() => ({ boxes: document.querySelectorAll('#challenge-form input[type="date"]').length,
        dropdowns: [...document.querySelectorAll("#challenge-form fieldset.date select")].map((one) => one.name) }));
      check(`at 390 px the admin page's challenge form is there, its days as dropdowns (${days.dropdowns.join(", ")}), nothing sideways`,
        await admin.locator("#challenge-form").isVisible() && days.boxes === 0 && days.dropdowns.length === 6
          && !(await sideways(admin)));
      await admin.evaluate(() => document.getElementById("challenge-form").scrollIntoView());
      await shot(admin, "1_admin_form-390.png", false);
    }
    await adminContext.close();
  }
  const overlap = await api("/api/admin?op=challenge&tests=1", { method: "POST", token: master.access_token,
    body: { title: "Another", brief: "Brief", starts_on: last, ends_on: last } });
  check(`another on the same days: ${overlap.status} "${overlap.body.error}"`, overlap.status === 409
    && overlap.body.error.includes(TITLE));
  const stranger = await api("/api/admin?op=challenge&tests=1", { method: "POST", token: (who.bob = await mintSession(emails.bob)).access_token,
    body: { title: "Mine", brief: "Brief", starts_on: today, ends_on: today } });
  check(`anybody else asking to set one: ${stranger.status}`, stranger.status === 404);

  // --- 2. Their models -----------------------------------------------------
  console.log("Ada shares four models, Bob one");
  who.ada = await mintSession(emails.ada);
  who.ed = await mintSession(emails.ed);
  who.cy = await mintSession(emails.cy, { age: false });
  const profiles = [await api("/api/people?op=profile", { method: "POST", token: who.ada.access_token, body: { handle: ADA, name: "Ada Challenges" } }),
    await api("/api/people?op=profile", { method: "POST", token: who.bob.access_token, body: { handle: BOB, name: "Bob Challenges" } })];
  check(`profiles: /u/${ADA}, /u/${BOB} (${profiles.map((one) => one.status).join(", ")})`, profiles.every((one) => one.status === 200));
  const follows = await api("/api/people?op=follow", { method: "POST", token: who.ed.access_token, body: { handle: ADA, on: true } });
  check(`Ed follows Ada: ${follows.status}`, follows.status === 200);
  const MODELS = {
    house: ["ada", `Challenge House ${rand}`, 12, "3004", 14, true],
    tower: ["ada", `Challenge Tower ${rand}`, 12, "3004", 4, true],
    hall: ["ada", `Challenge Hall ${rand}`, 40, "3004", 4, true],
    plain: ["ada", `Challenge Plain ${rand}`, 12, "3004", 14, false],
    shed: ["bob", `Challenge Shed ${rand}`, 10, "3010", 14, true],
    cys: ["cy", `Challenge by Cy ${rand}`, 6, "3004", 14, false],
  };
  for (const [key, [owner, name, count, part, colour, tested]] of Object.entries(MODELS)) {
    const text = model(name, count, part, colour);
    const one = await api("/api/share", { method: "POST", token: who[owner].access_token, body: {
      name, author: owner === "cy" ? undefined : owner === "ada" ? "Ada Challenges" : "Bob Challenges", model: text, image: picture,
      listed: owner !== "cy", ...(tested ? { tested: finding(text, count) } : {}) } });
    ids[key] = one.body.id;
    made.push([one.body.id, owner]);
    check(`${key} at /m/${one.body.id}: ${one.status}${tested ? `, Tested ${one.body.tested?.passed}` : ""}`,
      one.status === 201 && Boolean(one.body.id) && (!tested || one.body.tested?.passed === true));
    await new Promise((done) => setTimeout(done, 300));
  }
  // Cy's row says under 13 once his model is shared, as an account's from
  // before 2026-11-03 can: nothing new is shared by one now (api/_trust.js).
  await answerAge(who.cy.kept.user_id, emails.cy, false);

  // --- 3. Entering ---------------------------------------------------------
  console.log("Ada enters the house from its page; the others are refused in words");
  {
    const hers = await context({ as: who.ada, width: 390, height: 844, phone: true });
    const page = await hers.newPage();
    listen(page, "Ada at 390 px");
    await page.goto(`${site}/m/${ids.tower}`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challengeEntry, "Enter on the tower's page");
    await page.click("button[data-enter]");
    await page.waitForSelector("dialog.enter[open]");
    await page.check('dialog.enter input[value="hand"]');
    await page.click('dialog.enter button[type="submit"]');
    await until(page, () => document.documentElement.dataset.challengeRefused, "the tower refused");
    const refused = await page.evaluate(() => ({ refused: document.documentElement.dataset.challengeRefused,
      rules: [...document.querySelectorAll("dialog.enter [data-rule]")].map((li) => [li.dataset.rule, li.textContent]) }));
    check(`the tower: ${refused.refused}, ${JSON.stringify(refused.rules)}`, refused.refused === "rules"
      && refused.rules.length === 1 && refused.rules[0][0] === "set" && /3004 in Red \(it needs 12, the set has 0\)/.test(refused.rules[0][1]));
    await shot(page, "2_enter_refused-390.png", false);
    await page.goto(`${site}/m/${ids.house}`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challengeEntry, "Enter on the house's page");
    const line = await page.evaluate(() => document.getElementById("challenge-entry")?.textContent.replace(/\s+/g, " ") || "");
    check(`the house's page, for Ada: "${line}"`, line.includes(TITLE) && /Enter this month’s challenge/.test(line));
    await page.click("button[data-enter]");
    await page.waitForSelector("dialog.enter[open]");
    const dialog = await page.evaluate(() => ({ title: document.querySelector("dialog.enter h2")?.textContent,
      rules: [...document.querySelectorAll("dialog.enter ul li")].map((li) => li.textContent) }));
    check(`the dialog: "${dialog.title}", ${dialog.rules.length} rules`, dialog.title === `Enter “${TITLE}”` && dialog.rules.length === 3);
    await page.check('dialog.enter input[value="hand"]');
    await shot(page, "3_enter_dialog-390.png", false);
    check("nothing sideways with the dialog open", !(await sideways(page)));
    await page.click('dialog.enter button[type="submit"]');
    await until(page, () => document.documentElement.dataset.challengeEntry === "entered", "the house entered");
    const after = await page.evaluate(() => ({ dialog: document.querySelector("dialog.enter p")?.textContent,
      line: document.getElementById("challenge-entry")?.textContent.replace(/\s+/g, " ") }));
    check(`entered: "${after.dialog}"; the page: "${after.line}"`, /It is in, built by hand/.test(after.dialog || "")
      && /In this month’s challenge, .*, built by hand\. Take it out/.test(after.line || ""));
    await shot(page, "4_entered-390.png", false);
    await hers.close();
  }
  const hall = await api("/api/people?op=enter", { method: "POST", token: who.ada.access_token, body: { model: ids.hall, way: "hand" } });
  check(`the hall: ${hall.status} ${JSON.stringify((hall.body.broken || []).map((one) => one.rule))}: "${hall.body.error}"`,
    hall.status === 422 && (hall.body.broken || []).map((one) => one.rule).join(",") === "parts,set"
      && /It has 40 parts: this challenge allows at most 30/.test(hall.body.error));
  const plain = await api("/api/people?op=enter", { method: "POST", token: who.ada.access_token, body: { model: ids.plain, way: "hand" } });
  check(`the plain one: ${plain.status} ${JSON.stringify((plain.body.broken || []).map((one) => one.rule))}`,
    plain.status === 422 && (plain.body.broken || []).map((one) => one.rule).join(",") === "tested");
  const again = await api("/api/people?op=enter", { method: "POST", token: who.ada.access_token, body: { model: ids.house, way: "assistant" } });
  const notHers = await api("/api/people?op=enter", { method: "POST", token: who.ada.access_token, body: { model: ids.shed, way: "hand" } });
  const cys = await api("/api/people?op=enter", { method: "POST", token: who.cy.access_token, body: { model: ids.cys, way: "hand" } });
  const noWay = await api("/api/people?op=enter", { method: "POST", token: who.bob.access_token, body: { model: ids.shed, way: "robot" } });
  const signedOut = await api("/api/people?op=enter", { method: "POST", body: { model: ids.shed, way: "hand" } });
  check(`the house again ${again.status}, Bob's shed by Ada ${notHers.status}, `
    + `Cy ${cys.status} "${cys.body.error?.slice(0, 50)}", a way that is neither ${noWay.status}, signed out ${signedOut.status}`,
  again.status === 409 && notHers.status === 403 && cys.status === 422 && /13 and over/.test(cys.body.error || "")
    && noWay.status === 400 && signedOut.status === 401);
  // Bob enters from /challenge itself (challengepage, 2026-11-13): Enter a
  // model in its head, his models in the gallery to choose from, With the
  // assistant, Enter it; the page then shows that group with the shed in it.
  {
    const bobs = await context({ as: who.bob, width: 1280, height: 900 });
    const page = await bobs.newPage();
    listen(page, "Bob entering");
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challenge === "open", "the challenge for Bob");
    await page.click("#enter");
    await page.waitForSelector("dialog.enter-pick[open]");
    const offered = await page.evaluate(() => ({ title: document.querySelector("dialog.enter-pick h2")?.textContent,
      models: [...document.querySelectorAll('dialog.enter-pick input[name="model"]')].map((one) => one.value) }));
    check(`Bob's Enter a model: "${offered.title}", his models ${JSON.stringify(offered.models)}`, offered.title === `Enter “${TITLE}”`
      && offered.models.length === 1 && offered.models[0] === ids.shed);
    await page.check(`dialog.enter-pick input[value="${ids.shed}"]`);
    await page.check('dialog.enter-pick input[value="assistant"]');
    await shot(page, "4a_enter_from_challenge-1280.png", false);
    await page.click('dialog.enter-pick button[type="submit"]');
    await until(page, () => document.documentElement.dataset.challengeEntered || document.documentElement.dataset.challengeRefused,
      "the shed entered");
    const after = await page.evaluate(() => ({ entered: document.documentElement.dataset.challengeEntered || "",
      said: document.querySelector("dialog.enter-pick p")?.textContent || "" }));
    await page.click("dialog.enter-pick .cta");
    const d = await drawn(page);
    const shownWay = d.tabs.find((one) => one.selected)?.way;
    const shed = (d.groups.assistant?.entries || []).find((one) => one.id === ids.shed);
    check(`...entered: "${after.said}"; the page shows ${shownWay}, the shed ${JSON.stringify(shed)}`, after.entered === ids.shed
      && /^It is in, built with the assistant/.test(after.said) && shownWay === "assistant" && d.groups.assistant.shown
      && shed && shed.marks.includes("Your entry") && !shed.button);
    const twice = await api("/api/people?op=enter", { method: "POST", token: who.bob.access_token, body: { model: ids.shed, way: "assistant" } });
    check(`...and the shed asked again by the API: ${twice.status}`, twice.status === 409);
    await bobs.close();
  }
  const notYours = await api(`/api/people?op=challenge_entry&id=${ids.house}`, { token: who.bob.access_token });
  check(`the house's entry asked by Bob: ${JSON.stringify(notYours.body)}`, notYours.status === 200 && JSON.stringify(notYours.body) === '{"mine":false}');

  // --- Ed's feed: somebody he follows entered ------------------------------
  if (held) console.log("  --    the feed is made from the database's own entries, which this relay holds in memory: not asked");
  else {
  console.log("Ed's feed says Ada entered the house");
  const entered = `Ada Challenges entered “Challenge House ${rand}” in the challenge “${TITLE}”, built by hand`;
  for (const [width, height, phone, dark] of [[390, 844, true, false], [1280, 900, false, true]]) {
    const eds = await context({ as: who.ed, width, height, phone, dark });
    const page = await eds.newPage();
    listen(page, `Ed's feed at ${width} px`);
    await page.goto(`${site}/feed`, { waitUntil: "load" });
    await until(page, () => document.querySelector('.feed-row[data-kind="challenge"]'), "the entry in Ed's feed");
    const rows = await page.evaluate(() => [...document.querySelectorAll('.feed-row[data-kind="challenge"]')].map((row) => ({
      text: row.querySelector(".what")?.textContent.replace(/\s+/g, " ").replace(/New$/, "").trim(),
      href: row.querySelector("a.go")?.getAttribute("href") })));
    check(`Ed's feed at ${width} px: ${JSON.stringify(rows)}`, rows.length === 1 && rows[0].text === entered
      && rows[0].href === `/m/${ids.house}` && !(await sideways(page)));
    await page.evaluate(() => document.querySelector('.feed-row[data-kind="challenge"]')?.scrollIntoView({ block: "center" }));
    await shot(page, `4b_feed_ed-${width}.png`, false);
    await eds.close();
  }
  const fed = await api("/api/people?op=feed", { token: who.ed.access_token });
  const told = (fed.body.rows || []).filter((one) => one.kind === "challenge");
  check(`...the API: ${told.length} entry, by ${told[0]?.by?.handle}, not Bob's shed (he is not followed)`,
    told.length === 1 && told[0].by?.handle === ADA && told[0].link.endsWith(`/m/${ids.house}`));
  }

  // --- 4. /challenge signed out ----------------------------------------------
  console.log("/challenge, signed out");
  for (const [width, height, phone, dark] of [[1280, 900, false, false], [390, 844, true, true]]) {
    const visitor = await context({ width, height, phone, dark });
    const page = await visitor.newPage();
    listen(page, `visitor at ${width} px`);
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(page, () => ["open", "upcoming", "ended", "none", "broken", "not-yet"].includes(document.documentElement.dataset.challenge), "the challenge drawn");
    const d = await drawn(page);
    check(`at ${width} px: "${d.title}", ${d.state}, ${d.rules.length} rules`, d.title === TITLE && d.state === "open"
      && d.rules.length === 3 && /Only parts of set 6075-2, Castle/.test(d.rules[1]));
    // The page as the best contest pages are (challengepage): its status, a
    // live countdown, its numbers, Enter beside Share, the groups as tabs
    // with their counts, Vote on each card.
    for (const [what, ok] of judged(d, { state: "open", groups: { hand: 1, assistant: 1 }, signedIn: false })) check(`...${what}`, ok);
    const hand = d.groups.hand || { entries: [] };
    const helped = d.groups.assistant || { entries: [] };
    check(`...Built by hand: ${hand.entries.map((one) => one.id).join(",")}; with the assistant: ${helped.entries.map((one) => one.id).join(",")}; `
      + `over them "${d.voteSaid}"`, hand.entries[0]?.id === ids.house && hand.entries[0].card && helped.entries[0]?.id === ids.shed
      && /Votes stay hidden until it ends/.test(d.voteSaid));
    check(`...nothing sideways at ${width} px`, !(await sideways(page)));
    // The countdown runs: a second later its seconds are not what they were.
    const ticks = await page.evaluate(async () => {
      const read = () => document.querySelector('#countdown b[data-unit="seconds"]')?.textContent;
      const first = read();
      await new Promise((done) => setTimeout(done, 1300));
      return [first, read()];
    });
    check(`...the countdown counts down: ${ticks.join(" then ")}`, ticks[0] !== ticks[1]);
    if (width === 1280) {
      // The other group's tab, by the pointer and back by the keyboard.
      await page.click("#tab-assistant");
      const other = await drawn(page);
      const asked = page.url().replace(site, "");
      await page.keyboard.press("ArrowLeft");
      const back = await drawn(page);
      check(`...the tab Built with the assistant shows the shed (${asked}); the left arrow, Built by hand again (${page.url().replace(site, "")})`,
        other.groups.assistant.shown && !other.groups.hand.shown && other.tabs[1].selected && /[?&]group=assistant/.test(asked)
        && back.groups.hand.shown && back.tabs[0].selected && !/group=/.test(page.url())
        && await page.evaluate(() => document.activeElement?.id === "tab-hand"));
    }
    if (year) {
      const next = await page.evaluate(() => ({ shown: !document.getElementById("next").hidden,
        title: document.getElementById("next-title").textContent, days: document.getElementById("next-days").textContent,
        text: document.body.textContent }));
      check(`...Coming next: "${next.title}", "${next.days}"; the year's others named nowhere`, next.shown && next.title === THEMES[0]
        && /^Opens on 1 .*, until \d+ /.test(next.days) && !next.text.includes(THEMES[1]) && !next.text.includes(THEMES[2]));
    }
    await pictures(page);
    await shot(page, `5_challenge_visitor-${width}.png`);
    // Share (docs/SOCIAL.md section 7): the site's sheet on the challenge's
    // own page, so a link posted now opens this one after the next begins.
    await page.click("#share");
    await until(page, () => document.querySelector("dialog.share-sheet[open]"), "its share sheet");
    const sheet = await page.evaluate(() => ({ link: document.getElementById("share-link")?.value || "",
      heading: document.getElementById("share-h")?.textContent || "", focused: document.activeElement?.id || "",
      to: [...document.querySelectorAll("dialog.share-sheet a[data-to]")].map((a) => [a.dataset.to, a.href]) }));
    const reddit = new URL(sheet.to.find(([to]) => to === "reddit")?.[1] || "http://none/");
    check(`...Share opens "${sheet.heading}" on ${sheet.link.replace(site, "")}; Reddit's title "${reddit.searchParams.get("title")}"; `
      + `Post it to ${sheet.to.map(([to]) => to).join(", ")}`, sheet.heading === `Share ${TITLE}` && sheet.focused === "share-link"
      && sheet.link === `${site}/challenge?id=${ids.challenge}&tests=1` && reddit.searchParams.get("url") === sheet.link
      && new RegExp(`^${TITLE}: a Brickworks building challenge, \\d+ \\w+ \\d{4} to \\d+ \\w+ \\d{4}$`).test(reddit.searchParams.get("title") || "")
      && sheet.to.map(([to]) => to).join() === "reddit,bluesky,x,facebook,email");
    await shot(page, `5_challenge_share-${width}.png`, false);
    await page.keyboard.press("Escape");
    if (width === 390) {
      await page.click(`.model[data-entry="${ids.house}"] .vote-line button.vote`);
      const asked = await page.waitForSelector("dialog.sign-in[open]", { timeout: 10000 }).then(() => true).catch(() => false);
      check("Vote, signed out, asks to sign in", asked);
    } else {
      await page.click("#enter");
      const asked = await page.waitForSelector("dialog.sign-in[open]", { timeout: 10000 }).then(() => true).catch(() => false);
      check("Enter a model, signed out, asks to sign in", asked);
    }
    await visitor.close();
  }
  // Vercel's CDN keeps s-maxage for itself and hands a browser what is left
  // (public, max-age=0): on a deployment the CDN answering the same question
  // again is the proof, as share_probe has it.
  const local = /127\.0\.0\.1|localhost/.test(site);
  const asked = `/api/people?op=challenge&cdn=${rand}`;
  const cached = await api(asked);
  const kept = cached.headers.get("cache-control") || "";
  const cdn = local ? "" : (await api(asked)).headers.get("x-vercel-cache") || "none";
  check(`a visitor's answer is kept briefly by the CDN, not a browser (${kept}${local ? "" : `; asked again: ${cdn}`}) `
    + `and has no test challenge (${cached.body.challenge?.test ?? "none"})`,
  /public/.test(kept) && /max-age=0/.test(kept) && (local ? /s-maxage=30/.test(kept) : /HIT|STALE/.test(cdn))
    && cached.body.challenge?.title !== TITLE);
  if (year) {
    const told = await api(`/api/people?op=challenge&id=${ids.year[0]}&tests=1`);
    const later = toldYet.indexOf(false);
    const untold = await api(`/api/people?op=challenge&id=${ids.year[later]}&tests=1`);
    const visitorAsks = await api(`/api/people?op=challenge&id=${ids.year[0]}`);
    check(`the first theme's own page ${told.status} (${told.body.challenge?.state}), the ${["first", "second", "third"][later]}'s ${untold.status} (not told yet), `
      + `the first asked without tests=1 ${visitorAsks.status}`, told.status === 200 && told.body.challenge?.state === "upcoming"
      && told.body.challenge?.title === THEMES[0] && untold.status === 404 && visitorAsks.status === 404);
  }
  {
    const visitor = await context({ width: 1280, height: 900 });
    const page = await visitor.newPage();
    listen(page, "gallery");
    await page.goto(`${site}/gallery?tests=1`, { waitUntil: "load" });
    // The shelves come before the first page, which draws the line with it.
    await until(page, () => document.documentElement.dataset.shelves && document.documentElement.dataset.gallery === "ready",
      "the gallery's front");
    const line = await page.evaluate(() => ({ shown: !document.getElementById("challenge-line").hidden,
      text: document.getElementById("challenge-line").textContent, href: document.querySelector("#challenge-line a")?.getAttribute("href") }));
    check(`the gallery's front: "${line.text}" → ${line.href}`, line.shown && line.text.startsWith(`This month’s challenge: ${TITLE}, open until`)
      && line.href === "/challenge?tests=1");
    await shot(page, "6_gallery_line-1280.png", false);
    await visitor.close();
  }

  // --- 5. Votes ------------------------------------------------------------
  console.log("Ed votes in both groups; Bob for the house; nobody for their own, nor under 13");
  for (const [width, height, phone, dark] of [[390, 844, true, false], [1280, 900, false, true]]) {
    const eds = await context({ as: who.ed, width, height, phone, dark });
    const page = await eds.newPage();
    listen(page, `Ed at ${width} px`);
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challenge === "open", "the challenge for Ed");
    if (width === 390) {
      for (const [way, id] of [["hand", ids.house], ["assistant", ids.shed]]) {
        if (way === "assistant") await page.click("#tab-assistant");
        await page.click(`.model[data-entry="${id}"] .vote-line button.vote`);
        // A vote cannot be moved: asked once, in a dialog, before it is cast.
        await page.waitForSelector("dialog.vote-confirm[open]");
        const asked = await page.evaluate(() => document.querySelector("dialog.vote-confirm h2")?.textContent || "");
        if (way === "hand") await shot(page, "7a_vote_confirm-390.png", false);
        await page.click("dialog.vote-confirm .cta:not(.ghost)");
        // Told once the server has it: the card is marked at once, before.
        await until(page, ([one, name]) => document.querySelector(`.model[data-entry="${one}"]`)?.classList.contains("voted")
          && (document.getElementById("said")?.textContent || "").startsWith(`Your vote is for “Challenge ${name}`), "Your vote", 30,
        [id, way === "hand" ? "House" : "Shed"]);
        const said = await page.evaluate(() => ({ line: document.getElementById("vote-said")?.textContent.replace(/\s+/g, " ").trim(),
          told: document.getElementById("said")?.textContent }));
        check(`Ed votes in ${way}: asked "${asked}"; over the cards "${said.line}"; told "${said.told}"`,
          /^Vote for “Challenge (House|Shed) .*”\?$/.test(asked) && /^Your vote in this group is for “Challenge (House|Shed) /.test(said.line || ""));
      }
    }
    const d = await drawn(page);
    // At 390 he voted in the assistant's group last, so its tab is the one chosen.
    for (const [what, ok] of judged(d, { state: "open", groups: { hand: 1, assistant: 1 }, signedIn: true,
      voted: { hand: ids.house, assistant: ids.shed }, shown: width === 390 ? "assistant" : "hand" })) check(`Ed at ${width} px: ${what}`, ok);
    check(`...nothing sideways at ${width} px`, !(await sideways(page)));
    await pictures(page);
    await shot(page, `7_challenge_ed-${width}.png`);
    await eds.close();
  }
  const bobVote = await api("/api/people?op=vote", { method: "POST", token: who.bob.access_token, body: { challenge: ids.challenge, model: ids.house } });
  const bobAgain = await api("/api/people?op=vote", { method: "POST", token: who.bob.access_token, body: { challenge: ids.challenge, model: ids.house } });
  const bobOwn = await api("/api/people?op=vote", { method: "POST", token: who.bob.access_token, body: { challenge: ids.challenge, model: ids.shed } });
  const adaOwn = await api("/api/people?op=vote", { method: "POST", token: who.ada.access_token, body: { challenge: ids.challenge, model: ids.house } });
  const cyVote = await api("/api/people?op=vote", { method: "POST", token: who.cy.access_token, body: { challenge: ids.challenge, model: ids.house } });
  const notIn = await api("/api/people?op=vote", { method: "POST", token: who.ed.access_token, body: { challenge: ids.challenge, model: ids.tower } });
  const nobody = await api("/api/people?op=vote", { method: "POST", body: { challenge: ids.challenge, model: ids.house } });
  check(`Bob for the house ${bobVote.status}, again ${bobAgain.status}, for his own ${bobOwn.status}; Ada for her own ${adaOwn.status}; `
    + `Cy ${cyVote.status}; the tower, not in it, ${notIn.status}; signed out ${nobody.status}`,
  bobVote.status === 200 && bobAgain.status === 409 && bobOwn.status === 422 && adaOwn.status === 422 && cyVote.status === 422
    && /13 and over/.test(cyVote.body.error || "") && notIn.status === 404 && nobody.status === 401);
  {
    const bobs = await context({ as: who.bob, width: 1280, height: 900 });
    const page = await bobs.newPage();
    listen(page, "Bob");
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challenge === "open", "the challenge for Bob");
    const d = await drawn(page);
    for (const [what, ok] of judged(d, { state: "open", groups: { hand: 1, assistant: 1 }, signedIn: true,
      voted: { hand: ids.house }, mine: [ids.shed] })) check(`Bob: ${what}`, ok);
    await bobs.close();
    const cyc = await context({ as: who.cy, width: 390, height: 844, phone: true });
    const cyPage = await cyc.newPage();
    listen(cyPage, "Cy");
    await cyPage.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(cyPage, () => document.documentElement.dataset.challenge === "open", "the challenge for Cy");
    const c = await drawn(cyPage);
    const buttons = Object.values(c.groups).flatMap((g) => g.entries.map((one) => one.button)).filter(Boolean);
    check(`Cy, under 13: no vote buttons${buttons.length ? ` (${JSON.stringify(buttons)}: drawn as for a visitor)` : ""}, and once "${c.why[0]}"`, c.why.length === 1 && /13 and over/.test(c.why[0])
      && !buttons.length);
    await pictures(cyPage);
    await shot(cyPage, "8_challenge_cy-390.png");
    await cyc.close();
  }
  const mine = await api("/api/people?op=challenge&tests=1", { token: who.ed.access_token });
  check(`Ed's answer: his votes ${JSON.stringify(mine.body.you?.voted)}, never kept (${mine.headers.get("cache-control")}), no votes counted yet`,
    mine.body.you?.voted?.hand === ids.house && mine.body.you?.voted?.assistant === ids.shed
      && mine.headers.get("cache-control") === "private, no-store"
      && mine.body.challenge.groups.every((g) => g.entries.every((one) => one.votes === null)));

  // --- 6. It ends --------------------------------------------------------------
  console.log("the owner ends it; the winners");
  // A sign-in of its own: the first one's refresh token was renewed by the
  // pages that used it, and a renewed one used again ends the session.
  master = await mintSession(process.env.MASTER_EMAIL);
  {
    const adminContext = await context({ as: master, width: 1280, height: 900, dark: true });
    const admin = await adminContext.newPage();
    listen(admin, "admin, ending");
    admin.on("dialog", (dialog) => dialog.accept());
    await admin.goto(`${site}/admin?tests=1#gallery/challenges`, { waitUntil: "load" });
    await until(admin, () => !document.getElementById("view").classList.contains("hide"), "the admin page", 60);
    const pressed = Date.now();
    await admin.click(`#challenges tr[data-challenge="${ids.challenge}"] button`);
    // What the owner sees: the row ended, or the page's words for why not.
    const ended = await until(admin, (id) => document.querySelector(`#challenges tr[data-challenge="${id}"]`)?.dataset.state === "ended"
      || document.querySelector("#challenge-note.bad, #gate-note.bad")?.textContent, "the challenge ended", 30, ids.challenge);
    if (ended !== true) throw new Error(`the challenge ended: the page said "${ended}"`);
    check(`End it now: ended, shown in ${((Date.now() - pressed) / 1000).toFixed(1)} s`, true);
    await adminContext.close();
  }
  // The hub, asked with tests=1, shows an open challenge before a coming
  // one, a real one too: since 2026-10-25 the owner's year has one open
  // nearly every day, and the hub shows it, not the first test theme.
  const real = (await api("/api/people?op=challenge")).body?.challenge;
  const hubWanted = real?.state === "open" ? { title: real.title, state: "open" } : { title: THEMES[0], state: "upcoming" };
  for (const [width, height, phone, dark] of [[1280, 900, false, false], [390, 844, true, true]]) {
    const visitor = await context({ width, height, phone, dark });
    const page = await visitor.newPage();
    listen(page, `winners at ${width} px`);
    await page.goto(`${site}/challenge?tests=1`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.challenge, "the challenge drawn");
    if (year) {
      // The hub shows the first theme now (or the real one open), and this
      // one under Past challenges with its winners; its name opens its own page.
      const h = await drawn(page);
      const card = h.past.find((one) => one.id === String(ids.challenge));
      const pictured = await page.evaluate((id) => [...document.querySelectorAll(`#past article[data-past="${id}"] .frame img`)]
        .map((img) => img.getAttribute("src")), ids.challenge);
      // Past challenges as a grid of cards (challengepage): each its name, a
      // link to its own page, its days and entries, and its winners named
      // under their pictures.
      check(`at ${width} px the hub shows "${h.title}" (${h.state}); under Past challenges, first, ${JSON.stringify(card)}, pictures ${pictured.join(" ")}`,
        h.title === hubWanted.title && h.state === hubWanted.state && h.past[0]?.id === String(ids.challenge)
        && card.href === `/challenge?id=${ids.challenge}&tests=1` && /2 entries/.test(card.days)
        && card.won.length === 2 && card.won[0].id === ids.house && card.won[0].text === `“Challenge House ${rand}” by Ada Challenges, by hand`
        && card.won[1].id === ids.shed && card.won[1].text === `“Challenge Shed ${rand}” by Bob Challenges, with the assistant`
        && pictured.join() === `/m/${ids.house}.png,/m/${ids.shed}.png`);
      await pictures(page);
      await page.evaluate(() => document.getElementById("past").scrollIntoView());
      await shot(page, `9a_challenge_past-${width}.png`, false);
      await page.click(`#past article[data-past="${ids.challenge}"] h3 a`);
      await page.waitForLoadState("load");
      await until(page, () => document.documentElement.dataset.challenge === "ended", "its own page");
      const crumbs = await page.evaluate(() => document.getElementById("crumbs")?.hidden === false
        && document.querySelector("#crumbs a")?.getAttribute("href") === "/challenge");
      check(`...its own page, ${page.url().replace(site, "")}, under the crumbs to the hub`, crumbs && page.url().endsWith(`/challenge?id=${ids.challenge}&tests=1`));
    }
    const d = await drawn(page);
    // Ended: the winners celebrated first, over the entries, each entry's
    // votes said, and no Vote anywhere.
    for (const [what, ok] of judged(d, { state: "ended", groups: { hand: 1, assistant: 1 },
      winners: [[ids.house, "hand", 2], [ids.shed, "assistant", 1]] })) check(`at ${width} px: ${what}`, ok);
    check(`...nothing sideways at ${width} px`, !(await sideways(page)));
    await pictures(page);
    await shot(page, `9_challenge_winners-${width}.png`);
    await visitor.close();
  }
  {
    // Who won, told to whoever voted and entered nothing (supabase/
    // challenge_notices.sql, docs/SOCIAL.md section 7, item 3): Ed hears
    // it in his Notifications, a group of the challenge's own, "a model
    // you voted for won"; Bob voted and entered, so hears it under his
    // shed instead, and Ada, who only entered, the same. A challenge that
    // is not there is refused once the file is applied; before it, reading
    // one keeps nothing.
    const nobody = await api("/api/people?op=notifications_read", { method: "POST", token: who.ed.access_token,
      body: { challenge: Number.MAX_SAFE_INTEGER } });
    const told = nobody.status === 404;
    const badly = await api("/api/people?op=notifications_read", { method: "POST", token: who.ed.access_token, body: { challenge: "x" } });
    check(`a challenge that is not there, read: ${nobody.status} ${JSON.stringify(nobody.body)}; no number: ${badly.status}`,
      (told ? nobody.body.error === "There is no such challenge." : nobody.status === 200 && nobody.body.kept === false)
      && badly.status === 400 && badly.body.error === "say which challenge, by its number");
    const groupOf = async (person) => ((await api("/api/people?op=notifications", { token: person.access_token })).body.groups || [])
      .find((one) => one.challenge === ids.challenge) || null;
    // The database tells who won from its own challenges, which a relay
    // holding them in memory has none of: asked of a deployment only, as
    // the feed is.
    if (held) console.log("  --    who won is told by the database from its own challenges, which this relay holds in memory: not asked");
    else {
    const [eds, bobs, adas] = [await groupOf(who.ed), await groupOf(who.bob), await groupOf(who.ada)];
    check(`Ed's notifications: ${eds ? `"${eds.name}", ${eds.rows.map((row) => `${row.kind}: ${row.line}`).join(" | ")}` : "no group"}; `
      + `Bob's ${bobs ? "has" : "has none"}, Ada's ${adas ? "has" : "has none"}`, !bobs && !adas && (told
      ? eds?.name === `Challenge: ${TITLE}` && eds.unread && eds.picture === null && eds.rows.length === 1
        && eds.rows[0].kind === "challenge_won" && eds.rows[0].line === `“${TITLE}” has ended, and a model you voted for won`
        && eds.link.endsWith(`/challenge?id=${ids.challenge}&tests=1`) && eds.rows[0].link === eds.link
      : !eds));
    if (told) {
      const edsPage = await context({ as: who.ed, width: 390, height: 844, phone: true, dark: true });
      const page = await edsPage.newPage();
      listen(page, "Ed's notifications");
      await page.goto(`${site}/notifications`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.notifications === "ready", "his notifications");
      const card = (id) => page.evaluate((one) => {
        const item = document.querySelector(`#groups .notice[data-challenge="${one}"]`);
        return item && { name: item.querySelector("h2 a")?.textContent || "", unread: item.classList.contains("unread"),
          brick: Boolean(item.querySelector(".pic.challenge .icon")), line: item.querySelector(".lines .what")?.textContent || "",
          icon: Boolean(item.querySelector(".lines a .icon")), href: item.querySelector(".lines a")?.getAttribute("href") || "" };
      }, id);
      const before = await card(ids.challenge);
      check(`...on his page at 390 px: ${JSON.stringify(before)}, nothing sideways`,
        before?.name === `Challenge: ${TITLE}` && before.unread && before.brick && before.icon
        && before.line.startsWith(`“${TITLE}” has ended, and a model you voted for won`)
        && before.href === `/challenge?id=${ids.challenge}&tests=1` && !(await sideways(page)));
      await shot(page, "9b_challenge_heard-390.png", false);
      await page.click(`#groups .notice[data-challenge="${ids.challenge}"] .lines a`);
      await page.waitForURL(/\/challenge\?id=/, { timeout: 15000 });
      await until(page, () => document.documentElement.dataset.challenge === "ended", "the challenge it opened");
      const opened = page.url().endsWith(`/challenge?id=${ids.challenge}&tests=1`);
      await page.goBack({ waitUntil: "load" });
      await page.reload({ waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.notifications === "ready", "his notifications again");
      const after = await card(ids.challenge);
      const kept = await groupOf(who.ed);
      check(`...its row opens the challenge's own page (${opened}); back, the group read (${!after?.unread}), and kept so (${kept && !kept.unread})`,
        opened && after && !after.unread && kept && !kept.unread);
      await edsPage.close();
    }
    }
  }
  {
    const visitor = await context({ width: 390, height: 844, phone: true });
    const page = await visitor.newPage();
    listen(page, "Ada's page");
    await page.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
    // Her win is the first of her achievements under her numbers
    // (api/people.js achievementsOf, docs/SOCIAL.md U13): what it won, the
    // model and its votes on hover, a link to it; then the rest she earned:
    // her levels once supabase/achievements.sql is there (the answer's
    // levels), Challenger among them; else the marks of before.
    const levelled = Array.isArray((await api(`/api/people?op=profile&handle=${ADA}&tests=1`)).body?.levels);
    const won = await page.evaluate((id) => ({ wins: [...document.querySelectorAll('.awards li[data-award="won"] a')].map((a) => ({
      said: a.textContent.replace(/\s+/g, " ").trim(), title: a.title, href: a.getAttribute("href") })),
      awards: [...document.querySelectorAll(".awards li")].map((li) => li.dataset.award).join(","),
      card: [...document.querySelectorAll(`.model[data-id="${id}"] small.won`)].map((s) => s.textContent) }), ids.house);
    check(`Ada's designer page: ${JSON.stringify(won)}`, won.wins.length === 1 && won.wins[0].said === `Won “${TITLE}”, by hand`
      && won.wins[0].title === `Challenge House ${rand}: 2 votes` && won.wins[0].href === `/m/${ids.house}`
      // Challenger counts entries in the database's own table, which a relay
      // holding the challenges in memory leaves empty: asked of a deployment.
      && (levelled ? (held ? /^won,designer,/.test(won.awards) : /^won,designer,(.+,)?challenger$/.test(won.awards))
        && won.awards.split(",").includes("tested") : won.awards === "won,tested,listed")
      && won.card.length === 1 && won.card[0] === `Won “${TITLE}”, by hand`);
    check("...nothing sideways at 390 px", !(await sideways(page)));
    await pictures(page);
    await page.evaluate(() => document.querySelector(".awards")?.scrollIntoView());
    await shot(page, "10_designer_won-390.png");
    await visitor.close();
  }
  const list = await api("/api/share?op=list&tests=1&sort=newest");
  const card = (list.body.models || []).find((one) => one.id === ids.house);
  check(`the house's card in the gallery: ${JSON.stringify(card?.won?.map((one) => one.title))}`,
    Boolean(card) && card.won?.length === 1 && card.won[0].title === TITLE && card.won[0].way === "hand");
  const visitorList = await api("/api/share?op=list&sort=newest");
  check("a visitor's gallery has no test model, and no win of a test challenge", !(visitorList.body.models || []).some((one) => one.id === ids.house));
  {
    // Its own link preview (docs/SOCIAL.md section 7, item 3): /challenge?id=N
    // is the page with this challenge's title, words, address and its first
    // winner's picture in its head, under the site's own security policy;
    // asked without tests=1 a test challenge is not there, and the head is
    // the page's own.
    const raw = async (pathname) => {
      const reply = await fetch(`${site}${pathname}`, { headers });
      return { status: reply.status, csp: reply.headers.get("content-security-policy") || "", html: await reply.text() };
    };
    const tag = (html, name) => (html.match(new RegExp(`<meta (?:name|property)="${name}" content="([^"]*)">`)) || [])[1] || "";
    const [own, plain, visitor] = [await raw(`/challenge?id=${ids.challenge}&tests=1`), await raw("/challenge?tests=1"),
      await raw(`/challenge?id=${ids.challenge}`)];
    const pictured = [ids.house, ids.shed].find((id) => (list.body.models || []).find((one) => one.id === id)?.image);
    check(`its link's head: "${tag(own.html, "og:title")}", ${tag(own.html, "og:url").replace(site, "")}, `
      + `${tag(own.html, "og:image").replace(site, "")}, ${tag(own.html, "robots")}; `
      + `the page's policy ${local ? "(the deployment's header; none here)" : own.csp === plain.csp && Boolean(own.csp)}`,
      own.status === 200 && tag(own.html, "og:title") === `${TITLE} · Brickworks challenge`
      && tag(own.html, "twitter:title") === tag(own.html, "og:title")
      && tag(own.html, "og:url") === `${site}/challenge?id=${ids.challenge}&amp;tests=1`
      && tag(own.html, "og:description").endsWith(": see who won.") && tag(own.html, "robots") === "noindex"
      && tag(own.html, "og:image") === (pictured ? `${site}/m/${pictured}.png` : `${site}/share.png`)
      && (local || (Boolean(own.csp) && own.csp === plain.csp)) && own.html.split("</head>")[1] === plain.html.split("</head>")[1]);
    check(`...a visitor's, without tests=1: "${tag(visitor.html, "og:title")}"`,
      visitor.status === 200 && tag(visitor.html, "og:title") === tag(plain.html, "og:title") && !visitor.html.includes(TITLE));
  }
  const ended = await api("/api/admin?tests=1", { token: master.access_token });
  const row = (ended.body.challenges || []).find((one) => one.id === ids.challenge);
  check(`the admin's list: ${row?.state}, entries ${JSON.stringify(row?.entries)}, votes ${JSON.stringify(row?.votes)}, winners ${row?.winners?.length}`,
    row?.state === "ended" && row.entries.hand === 1 && row.entries.assistant === 1 && row.votes.hand === 2 && row.votes.assistant === 1
      && row.winners.length === 2);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const id of master ? [ids.challenge, ...(ids.year || [])].filter(Boolean) : []) {
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
{
  // Once a page; one refused for the rate and asked again is the site's
  // answer to a busy address, said here and not held against it.
  const all = [...renewals.values()].flat();
  const many = [...renewals].filter(([, said]) => said.filter((status) => status === 200).length > 1)
    .map(([who, said]) => `${who} ${said.length}`);
  const refused = all.filter((status) => status !== 200);
  check(`each signed-in page renewed its session once: ${all.filter((status) => status === 200).length} for ${renewals.size} pages`
    + `${many.length ? `; more than once: ${many.join(", ")}` : ""}${refused.length ? `; refused, then asked again: ${refused.join(", ")}` : ""}`,
  !many.length);
}
console.log(failed ? `${failed} FAILED, ${passed} ok`
  : `challenges: set, entered, voted and won, every rule checked on the stored model (${passed} checks, all ok)`);
process.exit(failed ? 1 : 0);
