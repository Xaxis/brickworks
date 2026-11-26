// The owner's console, part C (web/admin.html #moderation, #challenges,
// #data, #switches, Site's Run now, People's export, sign-out and delete,
// Find; web/notice.js on every page; docs/ADMIN.md), in a real browser
// against a deployment, used as its owner uses it.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/console3_flow.mjs --url=<deployment> --out=shots/console3
//
//   1. The gate: every op part C added (data, find, challenge_view,
//      switches; unbar_model, notice_set, notice_clear, run_cron, export,
//      delete_account, sign_out) answers 401 signed out and 404 to an
//      account that is not the owner's, and nothing asked is done: the
//      throwaway a stranger asked to delete still there, no notice set.
//   2. Throwaways at resend.dev: D lists a model, makes a public list with
//      it, comments on it, and a visitor reports the model and the list;
//      S signs in.
//   3. The owner (MASTER_EMAIL's session minted, never its own sign-in) on
//      /admin?tests=1: Moderation's one queue with D's report, oldest
//      first, sifted by kind; Taken out; Challenges with its previews
//      (a set challenge and a year's plan, each as visitors will see it)
//      and a challenge's panel; Data's catalogue, OMR, database and
//      buckets, and why egress is not read here; Switches' variables by
//      name and never a value, and the settings.
//   4. Find: D's address, model, list and report from the console's bar;
//      its People link opens D's account. The list's report (lists1) in
//      the same queue, kind List, taken down by its own act: private, and
//      kept so.
//   5. Run now: the front's choice (gallery_feature, safe to run twice) run
//      from Site, its run written down by hand, and kept in the audit;
//      asked twice at once, one runs and the other is refused (409).
//   6. The notice (never on brickworks.diy: a check posts nothing there):
//      set in English and German, warn, with its preview, its words
//      written as markup; seen on a public page signed out in each
//      language, as words (no element made, nothing run), and dismissed;
//      cleared, and gone.
//   7. People: D's panel with its lists, comments, photos and entries;
//      Export downloads its rows as JSON; S signed out everywhere (its
//      refresh token refused after); D deleted by its address typed again
//      (a wrong one keeps the button asleep), gone from Supabase's
//      accounts, and the act in the audit with D's address.
//   8. Each new section, Find and D's panel at 390 and 1280, light and
//      dark, and the notice on a public page: pictures in --out.
//
// The throwaways are deleted at the end (D by the console itself), the
// reports deleted and the notice cleared. It passes when it ends
// "console3: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { answerAsks } from "./asks.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("console3_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const host = new URL(site).host;
// brickworks.diy's own visitors would see a check's notice: never set there.
const live = /^(?:www\.)?brickworks\.diy$/.test(host);
const out = args.out || "shots/console3";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const PUBLISHABLE = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-console3-${who}-${rand}@resend.dev`;
// A person's browser, one of its own each run: reports are counted by the
// browser and the address, a few an hour.
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
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const shot = async (page, name, full = true) => {
  // A whole page is drawn from its top, or the sticky bar is drawn where the page was scrolled to.
  if (full) await page.evaluate(() => scrollTo(0, 0)).catch(() => {});
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers, "user-agent": PERSON };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  // Reads past the CDN, which keeps some answers for up to a minute.
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });

/// [pathname] at [width] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { width = 1280, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, acceptDownloads: true, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  // The owner's account keeps a theme of its own (web/theme-account.js):
  // kept from here, so each picture is in the theme it is named for.
  await context.route(/\/theme-account\.js(?:\?.*)?$/, (route) => route.fulfill({ status: 200,
    contentType: "text/javascript", body: "export async function follow() {}" }));
  if (who) {
    const access = JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000, email: who.kept.email });
    await context.addInitScript(([key, value, token]) => {
      try {
        if (!localStorage.getItem(key)) {
          localStorage.setItem(key, value);
          sessionStorage.setItem("brickworks.access", token);
        }
      } catch { /* a browser that keeps nothing */ }
    }, [STORAGE_KEY, JSON.stringify(who.kept), access]);
  }
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  await answerAsks(page);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const go = async (page, hash) => {
  await page.evaluate((to) => { location.hash = to; }, hash);
  await page.waitForTimeout(300);
};
/// Whether a signed-out [pathname] shows the notice [words] (or none, when
/// null) within [seconds]: the CDN keeps the notice's answer a minute, and
/// the stale one once more while it asks again.
async function noticeOn(pathname, words, { seconds = 200, width = 1280, theme = "light" } = {}) {
  const where = await open(pathname, { width, theme, label: `notice ${pathname}` });
  const said = (page) => page.evaluate(() => document.querySelector("aside.site-notice .words")?.textContent ?? null);
  for (let at = Date.now(); Date.now() - at < seconds * 1000;) {
    if (await until(where.page, (want) => (document.querySelector("aside.site-notice .words")?.textContent ?? null) === want, words, 8000)) {
      return { ...where, ok: true, said: await said(where.page) };
    }
    await wait(7000);
    await where.page.reload({ waitUntil: "load" });
  }
  return { ...where, ok: false, said: await said(where.page) };
}

const made = [];
const ids = [];
let reportId = null;
let listMade = null;
let owner = null;
let noticeSet = false;
const secrets = [SECRET, process.env.RESEND_API_KEY, process.env.CRON_SECRET, process.env.OC_SIGNING_SECRET, process.env.OC_CONNECT_KEY,
  process.env.OC_PROJECT_KEY, process.env.VERCEL_BYPASS, process.env.ANTHROPIC_API_KEY].filter((one) => one && one.length >= 12);
try {
  // --- 1. The gate -----------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  const d = await mintSession(address("d"));
  made.push(address("d"));
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
  const noticeBefore = (await api("/api/plans?op=notice")).json?.notice ?? null;
  for (const [op, method, body] of [["data", "GET"], ["find", "GET"], ["challenge_view", "GET"], ["switches", "GET"],
    ["unbar_model", "POST"], ["notice_set", "POST", { words: { en: `A stranger's notice ${rand}` }, tone: "warn" }], ["notice_clear", "POST"],
    ["run_cron", "POST"], ["export", "POST"], ["delete_account", "POST", { confirm: d.kept.email }], ["sign_out", "POST"]]) {
    const query = `/api/admin?op=${op}&tests=1&account=${d.kept.user_id}&job=gallery_feature&id=AbCdEfGhIj&q=${rand}&challenge=1`;
    const signedOut = await api(query, { method, body });
    const other = await api(query, { method, token: stranger.access_token, body });
    check(`${method} ${op}: signed out ${signedOut.status}, anybody else ${other.status}`, signedOut.status === 401 && other.status === 404);
  }
  const dStill = await as(`/api/admin?op=person&tests=1&account=${d.kept.user_id}`);
  check(`...nothing done for them: D still there (${dStill.status}), the notice as it was`, dStill.status === 200
    && dStill.json?.email === d.kept.email
    && JSON.stringify((await api("/api/plans?op=notice")).json?.notice ?? null) === JSON.stringify(noticeBefore));

  // --- 2. Throwaways -----------------------------------------------------------------
  console.log("2. Throwaways: D with a model, a list and a comment, reported; S signed in");
  const model = `0 Console3 Tower ${rand}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n`;
  const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
  const shared = await api("/api/share", { method: "POST", token: d.access_token, body: { name: `Console3 Tower ${rand}`,
    author: "Console Three", model, image: picture, listed: true } });
  if (shared.json?.id) ids.push(shared.json.id);
  check(`D listed a model: ${shared.json?.id || shared.status}`, Boolean(shared.json?.id));
  const list = await api("/api/people?op=collection", { method: "POST", token: d.access_token,
    body: { name: `Console3 List ${rand}`, public: true } });
  const listId = list.json?.id || list.json?.collection?.id || null;
  const into = listId ? await api("/api/people?op=collect", { method: "POST", token: d.access_token,
    body: { collection: listId, model: ids[0], on: true } }) : { status: 0 };
  check(`...a public list with it: ${listId || list.status} (${into.status})`, Boolean(listId) && into.status < 300);
  listMade = listId;
  const comment = await api("/api/people?op=comment", { method: "POST", token: d.access_token,
    body: { model: ids[0], version: 1, body: `A note on the tower ${rand}` } });
  check(`...a comment on it: ${comment.status}`, comment.status === 201);
  const reported = await api("/api/people?op=report", { method: "POST", body: { model: ids[0], reason: "spam", note: `Console3 ${rand}` } });
  reportId = reported.json?.id ?? reported.json?.report ?? null;
  check(`...and a visitor reported the model: ${reported.status}`, reported.status >= 200 && reported.status < 300);
  const listReported = await api("/api/people?op=report", { method: "POST", body: { collection: listId, reason: "spam", note: `Console3 list ${rand}` } });
  check(`...and the list: ${listReported.status}`, listReported.status >= 200 && listReported.status < 300);
  const s = await mintSession(address("s"), { welcome: false });
  made.push(address("s"));

  // --- 3. The new sections ----------------------------------------------------------
  console.log("3. Moderation, Challenges, Data, Switches");
  let { page, context } = await open("/admin?tests=1", { width: 1280, who: owner, label: "owner" });
  check("the console shown to the owner, Find in its bar", await shown(page) && await until(page, () => !document.getElementById("find").hidden));
  await go(page, "moderation/queue");
  const reportRow = page.locator("#reports tr").filter({ has: page.locator(`a[href="/m/${ids[0]}"]`) }).first();
  check("Moderation's queue: D's report, its kind and what was said", await reportRow.waitFor({ timeout: 30000 }).then(() => true, () => false)
    && /spam/.test(await reportRow.innerText()) && await reportRow.getAttribute("data-kind") === "model");
  const order = await page.evaluate(() => [...document.querySelectorAll("#reports tr[data-kind]")].map((tr) => tr.querySelector("td.when")
    ?.dataset.value || "").filter(Boolean));
  check(`...oldest first (${order.length} with times)`, order.every((at, i) => i === 0 || Date.parse(order[i - 1]) <= Date.parse(at)));
  await page.click('#report-kinds button[data-value="takedown"]');
  check("...sifted by kind: Takedown hides it", await until(page, (id) => document.querySelector(`#reports a[href="/m/${id}"]`)
    ?.closest("tr").hidden === true, ids[0], 10000));
  await page.click('#report-kinds button[data-value="model"]');
  check("...Model shows it again", await until(page, (id) => document.querySelector(`#reports a[href="/m/${id}"]`)
    ?.closest("tr").hidden === false, ids[0], 10000));
  await page.click('#report-kinds button[data-value=""]').catch(() => {});
  await shot(page, "3-moderation-queue-1280.png", false);
  await go(page, "moderation/barred");
  check("Taken out: the accounts and the models, each with its rows or its words", await until(page, () =>
    !document.getElementById("barred").closest("[data-tab]").hidden
    && (document.querySelectorAll("#barred tr").length > 0 || document.getElementById("barred-note").textContent.length > 0)
    && (document.querySelectorAll("#barred-models tr").length > 0 || document.getElementById("barred-models-note").textContent.length > 0)));

  await go(page, "challenges");
  check("Challenges: the running one's card and every challenge, rows or words", await until(page, () =>
    document.getElementById("challenge-now-h").textContent.length > 0
    && (document.querySelectorAll("#challenges tr").length > 0 || document.getElementById("challenges-note").textContent.length > 0)));
  await page.fill('#challenge-form [name="title"]', `Lighthouses ${rand}`);
  await page.fill('#challenge-form [name="brief"]', "A lighthouse with a working lamp.");
  check("...the set form's preview: its title and brief as visitors will see them", await until(page, (title) =>
    document.querySelector("#challenge-preview h4")?.textContent === title
    && /working lamp/.test(document.getElementById("challenge-preview").textContent), `Lighthouses ${rand}`));
  const firstMonth = page.locator("#year-months fieldset").first();
  await firstMonth.locator("input").fill(`Harbours ${rand}`);
  await firstMonth.locator("textarea").fill("Boats, cranes and a quay.");
  check("...the year's preview: the month's theme and the day visitors are told", await until(page, (title) =>
    [...document.querySelectorAll("#year-preview li")].some((li) => li.textContent.includes(title) && /told/i.test(li.textContent)),
  `Harbours ${rand}`));
  await shot(page, "3-challenges-previews-1280.png", true);
  // Nothing set: the forms emptied again.
  await page.fill('#challenge-form [name="title"]', "");
  await page.fill('#challenge-form [name="brief"]', "");
  await firstMonth.locator("input").fill("");
  await firstMonth.locator("textarea").fill("");
  const oneChallenge = await page.evaluate(() => document.querySelector("#challenges tr[data-challenge]")?.dataset.challenge || null);
  if (oneChallenge) {
    await page.click(`#challenges tr[data-challenge="${oneChallenge}"] a`);
    check(`...a challenge's panel (#challenges/${oneChallenge}): its facts and what visitors see`, await until(page, () =>
      document.querySelector("dialog.sheet[open]")?.dataset.kind === "challenge"
      && document.querySelector("#sheet-body .facts")));
    await shot(page, "3-challenge-panel-1280.png", false);
    await page.keyboard.press("Escape");
  } else {
    console.log("  --    no challenge of the checks' own here: its panel not opened");
  }
  const viewBad = await as("/api/admin?op=challenge_view&tests=1&challenge=x");
  check(`op=challenge_view of no number: ${viewBad.status}`, viewBad.status === 400);

  await go(page, "data");
  const data = (await as("/api/admin?op=data&tests=1")).json || {};
  check(`op=data: ${data.facts?.catalogue?.sets ?? "no"} sets, ${data.usage?.buckets?.length ?? "no"} buckets, database ${data.usage?.database
    ?? "not read"} bytes, egress read ${data.egress?.read}`, data.usage?.database > 0 && data.usage?.buckets?.length > 0
    && data.egress?.read === false && Boolean(data.egress?.why));
  check("Data: the catalogue, the database, the buckets and its biggest tables drawn", await until(page, () =>
    /\d/.test(document.getElementById("n-db").textContent) && document.querySelectorAll("#buckets tr th").length > 0
    && document.querySelectorAll("#db-tables tr th").length > 0
    && (document.querySelectorAll("#omr tr").length > 0)));
  const dataSaid = await page.evaluate(() => ({ sets: document.getElementById("n-sets").textContent,
    rb: document.getElementById("n-rebrickable-said").textContent, egress: document.getElementById("egress-said").textContent,
    to: document.querySelector("#egress-said a")?.href || "" }));
  check(`...sets "${dataSaid.sets}", Rebrickable "${dataSaid.rb}"; egress: "${dataSaid.egress.slice(0, 90)}…" with Supabase's link`,
    dataSaid.egress.length > 20 && /^https:\/\/supabase\.com\//.test(dataSaid.to));

  await go(page, "switches");
  const sw = await as("/api/admin?op=switches&tests=1");
  const swText = JSON.stringify(sw.json || {});
  check(`op=switches: ${sw.json?.variables?.length} variables by name, ${sw.json?.settings?.length ?? "no"} settings; no value among `
    + `${secrets.length} secrets this machine holds`, sw.json?.variables?.length > 10 && secrets.every((one) => !swText.includes(one)));
  check("Switches: every variable a row of Set or Not set, CRON_SECRET's among them", await until(page, () => {
    const rows = [...document.querySelectorAll("#variables tr[data-variable]")];
    return rows.length > 10 && rows.some((tr) => tr.dataset.variable === "CRON_SECRET")
      && rows.every((tr) => [...tr.querySelectorAll("td")].slice(0, 3).every((td) => /^(Set|Not set|not known)$/.test(td.textContent.trim())));
  }));
  const html = await page.content();
  check("...and no value of them anywhere in the page", secrets.every((one) => !html.includes(one)));
  check("...the settings kept, each by scope", await until(page, () => document.querySelectorAll("#settings tr[data-setting]").length > 0
    || document.getElementById("settings-note").textContent.length > 0));

  // --- 4. Find -------------------------------------------------------------------
  console.log("4. Find");
  await page.fill("#find-q", rand);
  check("Find: D's account, model, list and report", await until(page, ([who, model]) => {
    const list = document.getElementById("find-list");
    if (list.hidden) return false;
    const heads = [...list.querySelectorAll("h3")].map((h) => h.textContent);
    return ["People", "Models", "Lists", "Reports"].every((one) => heads.includes(one))
      && [...list.querySelectorAll("a")].some((a) => a.textContent.includes(who))
      && list.querySelector(`a[href="/m/${model}"]`);
  }, [d.kept.email, ids[0]], 20000));
  await shot(page, "4-find-1280.png", false);
  await page.click(`#find-list a[href="#people/${d.kept.user_id}"]`);
  check("...its People link opens D's account", await until(page, (email) => document.querySelector("dialog.sheet[open]")?.dataset.kind === "person"
    && document.getElementById("sheet-title").textContent === email, d.kept.email));
  check("...with its lists, comments, photos and challenge entries", await until(page, (name) => {
    const t = document.getElementById("sheet-body").textContent;
    return t.includes(name) && /Lists \(1\)/.test(t) && /Comments \(1\)/.test(t) && /Photos of builds \(0\)/.test(t)
      && /Challenge entries \(0\)/.test(t);
  }, `Console3 List ${rand}`));
  await page.keyboard.press("Escape");

  // A list's report (lists1) in the same queue, with its own act.
  await go(page, "moderation/queue");
  const listRow = page.locator('#reports tr[data-kind="list"]').filter({ has: page.locator(`a[href="/c/${listMade}"]`) }).first();
  check("the list's report in the queue: kind List, its name, public, Take the list down", await listRow.waitFor({ timeout: 30000 })
    .then(() => true, () => false) && await listRow.innerText().then((text) => text.includes(`Console3 List ${rand}`) && /public/.test(text)
    && /Take the list down/.test(text)));
  await listRow.locator("button", { hasText: "Take the list down" }).click();
  check("...taken down: its report settled and out of the queue", await until(page, (id) => !document.querySelector(`#reports a[href="/c/${id}"]`),
    listMade, 30000));
  const down = await fetch(`${SUPABASE}/rest/v1/model_collections?id=eq.${listMade}&select=public,taken_down_at`,
    { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } }).then((reply) => reply.json()).catch(() => []);
  check(`...the list private and kept so: ${JSON.stringify(down[0] || null)}`, down[0]?.public === false && Boolean(down[0]?.taken_down_at));

  // --- 5. Run now ------------------------------------------------------------------
  console.log("5. Run now");
  const runsOf = async () => ((await as("/api/admin?op=site&tests=1")).json?.crons || []).find((one) => one.job === "gallery_feature");
  const before = await runsOf();
  check(`gallery_feature: Run now offered (${before?.run_now?.slice(0, 50)}…); the beta's round never (${
    ((await as("/api/admin?op=site&tests=1")).json?.crons || []).find((one) => one.job === "beta_daily")?.run_not})`, Boolean(before?.run_now));
  await go(page, "site");
  const runButton = page.locator('#crons tr[data-job="gallery_feature"] button', { hasText: "Run now" });
  await runButton.waitFor({ timeout: 30000 });
  await runButton.click();
  check("Run now: it ran, said so", await until(page, () => /ran in [\d.]+ s/.test(document.getElementById("site-note").textContent), null, 300000));
  const after = await runsOf();
  check(`...its run written down: ${after?.runs?.[0]?.at} by ${after?.runs?.[0]?.holder}, ${after?.runs?.[0]?.outcome} (before ${
    before?.runs?.[0]?.at || "none"})`, Boolean(after?.runs?.[0]) && after.runs[0].at !== before?.runs?.[0]?.at
    && after.runs[0].holder === "by-hand" && ["done", "unchanged"].includes(after.runs[0].outcome));
  check("...and in Site's table", await until(page, () => /by-hand/.test(document.querySelector('#crons tr[data-job="gallery_feature"]')
    ?.textContent || "")));
  const ranKept = (await as("/api/admin?op=audit&tests=1&act=run_cron")).json?.rows?.[0];
  check(`...kept in the audit: ${ranKept?.op} ${ranKept?.target} ${ranKept?.status}`, ranKept?.target === "gallery_feature" && ranKept?.status === 200);
  // Twice at once (two tabs): one runs, the other is refused, never run beside it.
  const twice = await Promise.all([1, 2].map(() => as("/api/admin?op=run_cron&tests=1&job=gallery_feature", { method: "POST" })));
  const statuses = twice.map((one) => one.status).sort();
  check(`...twice at once: ${statuses.join(" and ")} (${twice.find((one) => one.status === 409)?.json?.error || "none refused"})`,
    statuses[0] === 200 && statuses[1] === 409);

  // --- 6. The notice ------------------------------------------------------------------
  console.log("6. The notice");
  if (live) {
    console.log("  --    brickworks.diy: no notice set by a check; its answer read only");
    const asked = await api("/api/plans?op=notice");
    check(`/api/plans?op=notice answers: ${asked.status}`, asked.status === 200 && "notice" in (asked.json || {}));
  } else {
    await go(page, "switches");
    // Its words look like markup on purpose: every page shows them as words and runs nothing.
    const english = `Down for upkeep at 02:00 UTC, check ${rand} <b>bold</b> & <img src=x onerror="window.noticeRan=1">.`;
    const german = `Wartung um 02:00 UTC, Prüfung ${rand}.`;
    await page.fill('#notice-form [name="en"]', english);
    await page.click("#notice-form details.more-langs summary");
    await page.fill('#notice-form [name="de"]', german);
    await page.click('#notice-tone button[data-value="warn"]');
    check("the notice's preview: its words, warn, as visitors will see it", await until(page, (words) => {
      const card = document.querySelector("#notice-preview .site-notice");
      return card?.classList.contains("warn") && card.querySelector(".words").textContent === words
        && card.querySelector(".words").children.length === 0 && window.noticeRan === undefined
        && /Deutsch/.test(document.getElementById("notice-preview").textContent);
    }, english));
    await shot(page, "6-notice-form-1280.png", false);
    await page.click('#notice-form button[type="submit"]');
    noticeSet = await until(page, () => /Shown on every page/.test(document.getElementById("notice-note").textContent), null, 30000);
    check(`set: "${await page.textContent("#notice-note")}"`, noticeSet);
    // The notice is not in the studio (/app loads no notice.js): the console says so (c3review).
    check("...the form and its answer say every page of the site, not the studio", /not the studio/.test(await page.textContent("#notice-note"))
      && /not the studio/.test(await page.textContent("#notice-form")));
    check("...the history and the Overview say it", await until(page, (words) => [...document.querySelectorAll("#notices tr")]
      .some((tr) => tr.textContent.includes(words) && /showing/.test(tr.textContent)), english));
    const set = await noticeOn("/gallery", english);
    check(`seen on /gallery signed out: "${set.said}"`, set.ok);
    // Its own direction, and no other language named on an English page.
    const tongue = (page) => page.evaluate(() => {
      const words = document.querySelector("aside.site-notice .words");
      return words ? `dir=${words.getAttribute("dir")} lang=${words.getAttribute("lang")}` : "none";
    });
    const enTongue = await tongue(set.page);
    check(`...its words: ${enTongue}`, enTongue === "dir=auto lang=null");
    check("...its markup shown as words: no element made of it, nothing run", await set.page.evaluate(() =>
      document.querySelector("aside.site-notice .words")?.children.length === 0 && !document.querySelector("aside.site-notice img, aside.site-notice b")
      && window.noticeRan === undefined));
    // The card rises into place: judge and draw it once it has.
    const risen = (page) => until(page, () => document.querySelector("aside.site-notice.shown")).then(async (ok) => (await wait(400), ok));
    check("...warn, at the window's foot, nothing in the page moved", await risen(set.page) && await set.page.evaluate(() => {
      const card = document.querySelector("aside.site-notice.shown");
      const box = card.getBoundingClientRect();
      return card.classList.contains("warn") && getComputedStyle(card).position === "fixed" && getComputedStyle(card).opacity === "1"
        && box.bottom <= innerHeight && box.top > innerHeight / 2;
    }));
    await shot(set.page, "6-notice-gallery-1280-light.png", false);
    await set.page.click("aside.site-notice button");
    check("...its × hides it", await until(set.page, () => !document.querySelector("aside.site-notice")));
    await set.page.reload({ waitUntil: "load" });
    await wait(3000);
    check("...and it stays hidden on the next page in that browser", await set.page.evaluate(() => !document.querySelector("aside.site-notice")));
    await set.context.close();
    const de = await noticeOn("/de/gallery", german, { width: 390, theme: "dark" });
    check(`seen on /de/gallery in German, at 390 dark: "${de.said}"`, de.ok && await risen(de.page) && !await sideways(de.page));
    const deTongue = await tongue(de.page);
    check(`...the German its page's own: ${deTongue}`, deTongue === "dir=auto lang=null");
    await shot(de.page, "6-notice-de-gallery-390-dark.png", false);
    await de.context.close();
    const fr = await noticeOn("/fr/gallery", english, { seconds: 60, width: 390, theme: "light" });
    check(`...and in English on /fr/gallery, where no French was typed: "${fr.said}"`, fr.ok && await risen(fr.page));
    const frTongue = await tongue(fr.page);
    check(`...named as English there, for a screen reader: ${frTongue}`, frTongue === "dir=auto lang=en");
    await shot(fr.page, "6-notice-fr-gallery-390-light.png", false);
    await fr.context.close();
    await page.click("#notice-clear");
    const cleared = await until(page, () => /Cleared/.test(document.getElementById("notice-note").textContent), null, 30000);
    check(`cleared: "${await page.textContent("#notice-note")}"`, cleared);
    if (cleared) noticeSet = false;
    const gone = await noticeOn("/gallery", null);
    check("...and gone from /gallery", gone.ok);
    await gone.context.close();
    const kept = (await as("/api/admin?op=audit&tests=1&kind=setting&target=notice")).json?.rows || [];
    check(`...both kept in the audit: ${kept.slice(0, 2).map((row) => `${row.op} ${row.status}`).join(", ")}`,
      kept[0]?.op === "notice_clear" && kept[0]?.status === 200 && kept[1]?.op === "notice_set" && kept[1]?.status === 200);
  }

  // --- 7. People: export, sign out, delete ---------------------------------------------
  console.log("7. People: export, sign out everywhere, delete");
  await go(page, `people/${d.kept.user_id}`);
  check("D's panel open at its own address", await until(page, (email) => document.getElementById("sheet-title").textContent === email, d.kept.email));
  const [download] = await Promise.all([page.waitForEvent("download", { timeout: 60000 }),
    page.locator("#sheet-body button", { hasText: "Export their data" }).click()]);
  const file = JSON.parse(readFileSync(await download.path(), "utf8"));
  check(`Export: ${download.suggestedFilename()}: ${file.rows} rows of ${Object.keys(file.tables || {}).join(", ")}`,
    file.email === d.kept.email && file.tables?.shared_models?.some((one) => one.id === ids[0])
    && file.tables?.model_collections?.length === 1 && !JSON.stringify(file).includes(SECRET));
  check("...the console says the file holds the owner's own notes", await until(page, () =>
    /private notes on them too.*feedback\.note, beta_applications\.note and signals/.test(document.getElementById("sheet-body").textContent)));
  await go(page, `people/${s.kept.user_id}`);
  await until(page, (email) => document.getElementById("sheet-title").textContent === email, s.kept.email);
  await page.locator("#sheet-body button", { hasText: "Sign out everywhere" }).click();
  check("S signed out everywhere: said", await until(page, () => /Signed out: [1-9]\d* sign-in/.test(document.getElementById("sheet-body").textContent)));
  const refresh = await fetch(`${SUPABASE}/auth/v1/token?grant_type=refresh_token`, { method: "POST",
    headers: { apikey: PUBLISHABLE, "content-type": "application/json" }, body: JSON.stringify({ refresh_token: s.kept.refresh_token }) });
  check(`...its sign-in no longer renews: ${refresh.status}`, refresh.status >= 400 && refresh.status < 500);

  // Deleting an account asks a sign-in of the last five minutes (signin7,
  // api/_oc.js stepUp): the owner signs in again first, as the console says.
  await context.close();
  ({ page, context } = await open("/admin?tests=1", { width: 1280, label: "owner again",
    who: await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false }) }));
  check("the console shown to the owner again", await shown(page));

  await go(page, `people/${d.kept.user_id}`);
  await until(page, (email) => document.getElementById("sheet-title").textContent === email, d.kept.email);
  await page.click("#sheet-body details.danger-zone summary");
  check("Delete: the dialog says it is irreversible", await until(page, () => /irreversible/.test(document.querySelector("#sheet-body details.danger-zone")
    ?.textContent || "")));
  const button = page.locator("#sheet-body details.danger-zone button", { hasText: "Delete the account" });
  await page.fill("#delete-confirm", d.kept.email.replace("console3", "console4"));
  check("...another address keeps the button asleep", await button.isDisabled());
  await page.fill("#delete-confirm", d.kept.email.toUpperCase());
  await page.fill("#delete-why", "Asked by email (the console's check)");
  check("...its own, in any case, wakes it", !await button.isDisabled());
  await shot(page, "7-delete-1280.png", false);
  await button.click();
  check("...deleted: the panel closes, People says so", await until(page, (email) => !document.querySelector("dialog.sheet[open]")
    && document.getElementById("people-note").textContent.includes(`Deleted ${email}`), d.kept.email, 60000));
  const there = await fetch(`${SUPABASE}/auth/v1/admin/users/${d.kept.user_id}`, { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  check(`...gone from Supabase's accounts: ${there.status}`, there.status === 404);
  const theModel = await api(`/api/share?op=file&id=${ids[0]}`);
  check(`...its model gone with it: ${theModel.status}`, theModel.status === 404 || theModel.status === 410);
  const deleted = (await as(`/api/admin?op=audit&tests=1&act=delete_account&kind=account&target=${d.kept.user_id}`)).json?.rows?.[0];
  check(`...kept in the audit by its address: ${deleted?.detail?.said?.email} ${deleted?.status}, why "${deleted?.detail?.asked?.reason}"`,
    deleted?.status === 200 && deleted?.detail?.said?.email === d.kept.email && /Asked by email/.test(deleted?.detail?.asked?.reason || ""));
  await go(page, "audit");
  check("...and in the Audit log, by its address", await until(page, (email) => [...document.querySelectorAll("#audit tr[data-audit]")]
    .some((tr) => /Deleted an account/.test(tr.textContent) && tr.textContent.includes(email)), d.kept.email));
  await context.close();

  // --- 8. Pictures --------------------------------------------------------------------
  console.log("8. Pictures");
  const SECTIONS = [["moderation/queue", () => document.querySelectorAll("#reports tr").length > 0
    || /Nothing is reported/.test(document.getElementById("reports-note").textContent)],
    ["moderation/barred", () => (document.querySelectorAll("#barred tr").length > 0 || /Nobody is taken out/.test(document.getElementById("barred-note").textContent))
      && (document.querySelectorAll("#barred-models tr").length > 0 || /No model is taken out/.test(document.getElementById("barred-models-note").textContent))],
    ["challenges", () => document.getElementById("challenge-now-h").textContent.length > 0],
    ["data", () => document.querySelectorAll("#buckets tr th").length > 0],
    ["switches", () => document.querySelectorAll("#variables tr[data-variable]").length > 0],
    ["site", () => document.querySelectorAll('#crons tr[data-job] button, #crons tr[data-job] small').length > 0],
    ["overview", () => document.querySelectorAll("#needs li").length > 0 || /Nothing needs you/.test(document.getElementById("needs-said").textContent)]];
  for (const [width, theme] of [[1280, "light"], [1280, "dark"], [390, "light"], [390, "dark"]]) {
    const where = await open("/admin?tests=1", { width, theme, who: owner, label: `pictures ${width} ${theme}` });
    await shown(where.page);
    for (const [hash, ready] of SECTIONS) {
      await go(where.page, hash);
      const drawn = await until(where.page, ready);
      const wide = await sideways(where.page);
      check(`${hash} at ${width} ${theme}: drawn, nothing sideways`, drawn && !wide);
      await shot(where.page, `8-${hash.replace("/", "-")}-${width}-${theme}.png`);
    }
    await where.page.fill("#find-q", "resend.dev");
    check(`Find at ${width} ${theme}`, await until(where.page, () => !document.getElementById("find-list").hidden
      && document.querySelectorAll("#find-list a").length > 0, null, 20000) && !await sideways(where.page));
    await shot(where.page, `8-find-${width}-${theme}.png`, false);
    await where.page.keyboard.press("Escape");
    await go(where.page, `people/${s.kept.user_id}`);
    check(`S's panel at ${width} ${theme}`, await until(where.page, () => document.querySelector("dialog.sheet[open] details.danger-zone")));
    await where.page.click("#sheet-body details.danger-zone summary");
    await where.page.locator("#sheet-body details.danger-zone").scrollIntoViewIfNeeded();
    await shot(where.page, `8-person-${width}-${theme}.png`, false);
    await where.context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
  // The notice cleared if the run stopped between Show it and Clear it.
  if (noticeSet && owner) {
    const back = await api("/api/admin?op=notice_clear&tests=1", { method: "POST", token: owner.access_token });
    console.log(`  --    the notice cleared: ${back.status}`);
  }
  const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  if (ids.length) await fetch(`${SUPABASE}/rest/v1/reports?model=in.(${ids.join(",")})`, { method: "DELETE", headers: secret }).catch(() => {});
  if (listMade) await fetch(`${SUPABASE}/rest/v1/reports?collection=eq.${listMade}`, { method: "DELETE", headers: secret }).catch(() => {});
  let gone = 0;
  for (const email of made) {
    // D was deleted by the console: nothing left of it to find.
    if (await deleteAccount(email).catch(() => false) || (email === address("d") && !(await deleteAccount(email).catch(() => true)))) gone += 1;
  }
  check(`the throwaways deleted, and everything of theirs with them (${gone} of ${made.length})`, gone === made.length);
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`console3: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "console3: all ok" : "console3: FAILED");
process.exit(failed === 0 ? 0 : 1);
