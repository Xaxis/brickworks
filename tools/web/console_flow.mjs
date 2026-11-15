// The owner's console (web/admin.html, docs/ADMIN.md), in a real browser
// against a deployment, used as its owner uses it.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/console_flow.mjs --url=<deployment> --out=shots/console
//
//   1. The gate: every op the console added (overview, people, person,
//      audit, switches, beta_switch, beta_waitlist) answers 401 signed out
//      and 404 to an account that is not the owner's, and nothing asked of
//      it is done; the page says so to each.
//   2. Throwaways at resend.dev: M lists two models and one is reported;
//      A, B and C join the beta and apply for a month of Pro.
//   3. The owner (MASTER_EMAIL, its session minted as moderation_flow's and
//      beta_flow's owner is, never a sign-in of the owner's own) on
//      /admin?tests=1, the checks' own: the Overview's needs, numbers and
//      switches.
//   4. Gallery: In the gallery, M's first model, Take out, and it leaves
//      the gallery; Reported, M's report, Let it go; every other tab opens
//      with its rows or its own words.
//   5. People: M found by search, the panel opened, Take out the account,
//      every model of it out of the gallery; Let back in, and M lists again.
//   6. Beta: A approved (unless billing here is test: approving one of the
//      checks' own then gives a month at Admission's test mode, which no
//      check here may ask), C put on the waitlist, B declined; as each of
//      them hears it; the testers listed.
//   7. The switch: Off, on this deployment alone: its op=beta, beta_spots
//      and /beta say off, brickworks.diy's as it was; Open again, and they
//      follow.
//   8. Feedback opens. The Audit log: every act above, newest first, each
//      on what it acted on, with its outcome; filtered by act; an act's
//      panel.
//   9. /beta-admin answers 308 to /admin#beta, and /beta-admin?tests=1
//      lands on the console's Beta with the checks' own pool.
//  10. Every section at 390 and 1280, light and dark: pictures in --out.
//  11. The account menu's Admin (bugbar, 2026-11-13), right after the
//      gate: the owner's laptop menu and phone Menu have it at their foot
//      above Sign out, and it opens the console; on the next page it is
//      there before the server has answered (kept with who you are). A
//      throwaway has none in either menu nor anywhere in the page, and
//      op=feed_count's body has no admin key; signed out, none either.
//
// The throwaways are deleted at the end with everything of theirs, the
// beta's switch here put back as it was, and the checks' pool of spots
// given back what A took. It passes when it ends "console: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("console_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const host = new URL(site).host;
const out = args.out || "shots/console";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-console-${who}-${rand}@resend.dev`;
// A person's browser, one of its own each run: reports are counted by the
// browser and the address, a few an hour.
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${rand}`;
const started = new Date().toISOString();

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
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body, origin = site } = {}) {
  const sent = { ...(origin === site ? headers : {}), "user-agent": PERSON };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  // Reads past the CDN, which keeps some answers for up to a minute.
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(origin + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// One of the database's functions, as the server calls it.
async function rpc(name, body) {
  const reply = await fetch(`${SUPABASE}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" }, body: JSON.stringify(body) });
  if (!reply.ok) throw new Error(`rpc ${name}: ${reply.status}`);
  return reply.json();
}

// The beta as this deployment says it, and as brickworks.diy does: beta_spots
// is kept by the CDN a minute (fresh= asks past it), op=beta never; each
// instance keeps a switch it read SECONDS (api/_settings.js), so a switch is
// heard everywhere SECONDS after it was flipped.
const spots = (origin) => api("/api/plans?op=beta_spots", { origin }).then((r) => r.json?.beta ?? null);
const heard = (origin) => api("/api/plans?op=beta", { origin }).then((r) => r.json?.beta ?? null);
const follows = async (mode) => {
  await wait(16000);
  for (let at = Date.now(); Date.now() - at < 60000; await wait(3000)) {
    const [one, two] = await Promise.all([spots(site), heard(site)]);
    if (one === mode && two === mode) return true;
  }
  return false;
};

const browser = await launch({ signedOut: true });

/// [pathname] at [width] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { width = 1280, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  // The owner's account keeps a theme of its own (web/theme-account.js),
  // which a signed-in page takes up over the browser's: kept from here, so
  // each picture is in the theme it is named for, and nothing is sent to
  // the account.
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
  page.on("dialog", (dialog) => dialog.accept());
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}

/// The console shown, past its gate.
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const go = async (page, hash) => {
  await page.evaluate((to) => { location.hash = to; }, hash);
  await page.waitForTimeout(300);
};

const made = [];
const ids = [];
let switchBefore = null;
let flipped = false;
let poolBefore = null;
let owner = null;
const house = `0 Console House ${rand}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n`;
const shed = `0 Console Shed ${rand}\r\n1 14 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat\r\n`;
const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
const form = { build: "A small harbour with a working crane, a lighthouse and a tug that floats.", ai: "claude",
  background: "lego", background_line: "Twenty years of town sets", link: "", terms: true, emails: true };
try {
  // --- 1. The gate ---------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  const OPS = [["GET", "overview"], ["GET", "people"], ["GET", `person&account=${stranger.kept.user_id}`], ["GET", "audit"],
    ["GET", "switches"], ["POST", "beta_switch"], ["POST", `beta_waitlist&account=${stranger.kept.user_id}`]];
  const gate = [];
  for (const [method, op] of OPS) {
    const body = method === "POST" ? { mode: "off" } : undefined;
    const out1 = await api(`/api/admin?op=${op}`, { method, body });
    const out2 = await api(`/api/admin?op=${op}`, { method, body, token: stranger.access_token });
    gate.push(`${op.split("&")[0]} ${out1.status}/${out2.status}`);
    check(`${method} ${op.split("&")[0]}: signed out ${out1.status}, anybody else ${out2.status}`, out1.status === 401 && out2.status === 404);
  }
  {
    const { page, context } = await open("/admin", { width: 1280, label: "signed out" });
    await until(page, () => !/Checking/.test(document.getElementById("gate-note")?.textContent || ""));
    const said = await page.textContent("#gate-note");
    check(`signed out, the page says: "${said}"`, /not signed in/.test(said) && await page.evaluate(() => document.getElementById("view").hidden));
    await context.close();
  }
  {
    const { page, context } = await open("/admin", { width: 1280, who: stranger, label: "stranger" });
    await until(page, () => !/Checking/.test(document.getElementById("gate-note")?.textContent || ""));
    const said = await page.textContent("#gate-note");
    check(`anybody else, the page says: "${said}"`, /cannot see this page/.test(said));
    await shot(page, "1-gate-1280.png", false);
    await context.close();
  }

  // --- 11. The account menu's Admin ---------------------------------------------------
  console.log("11. The account menu's Admin: the owner's alone");
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  {
    // The menu as it is drawn once the server has said who you are.
    const menuOf = async (page, phone) => {
      await until(page, () => document.querySelector(".site-head .account-btn .avatar img, .site-head .account-btn .avatar")
        && JSON.parse(localStorage.getItem("brickworks.me") || "null")?.me !== undefined, null, 30000);
      await page.click(phone ? ".site-head .menu > summary" : ".site-head .account-menu > summary");
      await page.waitForTimeout(400);
      return page.evaluate((onPhone) => {
        const list = document.querySelector(onPhone ? ".site-head .menu .menu-list" : ".site-head .account-menu .menu-list");
        const link = list?.querySelector('a[href="/admin"]');
        const items = [...(list?.children || [])];
        return { link: Boolean(link), words: link?.textContent.trim() || "", icon: Boolean(link?.querySelector("svg.icon use")),
          aboveSignOut: Boolean(link) && items.indexOf(link.closest(".menu-owner")) === items.length - 2
            && items[items.length - 1]?.matches(".sign-out"),
          anywhere: document.querySelectorAll('a[href="/admin"], [data-place="admin"], .menu-owner').length };
      }, phone);
    };
    for (const [width, theme] of [[1280, "light"], [390, "dark"]]) {
      const phone = width < 600;
      const { page, context } = await open("/gallery", { width, theme, who: owner, label: `owner menu ${width}` });
      const menu = await menuOf(page, phone);
      check(`the owner's ${phone ? "phone Menu" : "account menu"} at ${width}: "${menu.words}", its gauge, at the foot above Sign out`,
        menu.link && menu.words === "Admin" && menu.icon && menu.aboveSignOut);
      await shot(page, `11-owner-menu-${width}-${theme}.png`, false);
      await page.click(phone ? '.site-head .menu a[href="/admin"]' : '.site-head .account-menu a[href="/admin"]');
      check(`...and it opens the console at ${width}`, await until(page, () => location.pathname === "/admin") && await shown(page));
      if (!phone) {
        // The next page draws it from what was kept, the server not yet answered.
        await page.route(/\/api\/people\?op=feed_count/, () => null);
        await page.goto(`${site}/faq`, { waitUntil: "domcontentloaded" });
        const kept = await until(page, () => document.querySelector('.site-head .account-menu a[href="/admin"]'), null, 10000);
        check("on the next page it is there before the server has answered (kept with who you are)", kept);
        await page.unroute(/\/api\/people\?op=feed_count/);
      }
      await context.close();
    }
    const plain = await api("/api/people?op=feed_count", { token: stranger.access_token });
    check(`a throwaway's op=feed_count has no admin key: ${JSON.stringify(Object.keys(plain.json || {}).sort())}`,
      plain.status === 200 && plain.json?.signed_in === true && !("admin" in (plain.json || {})));
    const mine = await api("/api/people?op=feed_count", { token: owner.access_token });
    check(`the owner's op=feed_count says admin: ${mine.json?.admin}`, mine.status === 200 && mine.json?.admin === true);
    for (const [width, theme] of [[1280, "dark"], [390, "light"]]) {
      const phone = width < 600;
      const { page, context } = await open("/gallery", { width, theme, who: stranger, label: `stranger menu ${width}` });
      const menu = await menuOf(page, phone);
      check(`a throwaway's ${phone ? "phone Menu" : "account menu"} at ${width}: no Admin, nothing of it in the page (${menu.anywhere})`,
        !menu.link && menu.anywhere === 0);
      await shot(page, `11-throwaway-menu-${width}-${theme}.png`, false);
      await context.close();
    }
    {
      const { page, context } = await open("/gallery", { width: 390, label: "signed out menu" });
      await page.click(".site-head .menu > summary");
      await page.waitForTimeout(400);
      const anywhere = await page.evaluate(() => document.querySelectorAll('a[href="/admin"], [data-place="admin"], .menu-owner').length);
      check(`signed out: no Admin in Menu nor the page (${anywhere})`, anywhere === 0);
      await context.close();
    }
  }

  // --- 2. Throwaways -------------------------------------------------------------
  console.log("2. Throwaways: a builder with two models, three applicants");
  const set = await api("/api/admin?op=switches&tests=1", { token: owner.access_token });
  switchBefore = set.json?.beta || null;
  const billing = set.json?.billing?.mode;
  const approving = billing !== "test";
  check(`the switches: the beta ${switchBefore?.mode} (from ${switchBefore?.source}, scope ${switchBefore?.scope}, `
    + `${switchBefore?.ready ? "the switch open" : "the switch NOT open: console.sql not applied"}), billing ${billing}`,
  Boolean(switchBefore?.mode) && switchBefore?.scope === host);
  // Off here, as a release's preview may be: opened for the run by the
  // switch itself, and put back off at the end.
  if (switchBefore?.mode === "off" && switchBefore?.ready) {
    const opened = await api("/api/admin?op=beta_switch&tests=1", { method: "POST", token: owner.access_token, body: { mode: "open" } });
    flipped = opened.status === 200;
    check(`the beta off here: opened for the run (${opened.status}), and heard`, flipped && await follows("open"));
  }
  const m = await mintSession(address("m"));
  made.push(address("m"));
  for (const [name, text] of [[`Console House ${rand}`, house], [`Console Shed ${rand}`, shed]]) {
    const r = await api("/api/share", { method: "POST", token: m.access_token, body: { name, author: "Console Builder", model: text, image: picture, listed: true } });
    if (r.json?.id) ids.push(r.json.id);
  }
  check(`M listed two models: ${ids.join(", ")}`, ids.length === 2);
  const [first, second] = ids;
  const reported = await api("/api/people?op=report", { method: "POST", body: { model: second, reason: "spam" } });
  check(`M's second model reported: ${reported.status}`, reported.status >= 200 && reported.status < 300);
  const applicants = {};
  for (const who of ["a", "b", "c"]) {
    const one = await mintSession(address(who), { welcome: false });
    made.push(address(who));
    applicants[who] = one;
    const joined = await api("/api/plans?op=beta_join", { method: "POST", token: one.access_token, body: { via: "site" } });
    const applied = await api("/api/plans?op=beta", { method: "POST", token: one.access_token, body: form });
    check(`${who.toUpperCase()} joined (${joined.status}) and applied: ${applied.status} ${applied.json?.application?.status || applied.json?.error}`,
      applied.status === 200 && applied.json?.application?.status === "new");
  }
  poolBefore = (await rpc("beta_queue", { p_status: "new", p_tests: true, p_limit: 1 }))?.pool?.given ?? null;

  // --- 3. The owner's Overview ----------------------------------------------------
  console.log("3. The owner's Overview");
  const { page, context } = await open("/admin?tests=1", { width: 1280, who: owner, label: "owner" });
  check("the console shown to the owner", await shown(page));
  check("the Overview: what needs you, with the applications", await until(page, () => document.querySelectorAll("#needs li").length > 0
    && /application/.test(document.getElementById("needs").textContent)));
  const stands = await page.evaluate(() => ({ accounts: document.getElementById("n-accounts").textContent,
    week: document.getElementById("n-week").textContent, switches: document.getElementById("switches").textContent,
    latest: document.querySelectorAll("#latest li").length }));
  check(`how things stand: ${stands.accounts} of the checks' accounts, ${stands.week} this week; the switches say the beta and billing`,
    /^\d[\d,]*$/.test(stands.accounts) && Number(stands.accounts.replace(/,/g, "")) >= 5 && /The beta/.test(stands.switches)
      && /Billing/.test(stands.switches));

  // --- 4. Gallery ----------------------------------------------------------------
  console.log("4. The Gallery: a model out, a report let go");
  await go(page, "gallery/listed");
  check("In the gallery: M's first model listed", await until(page, (id) => document.querySelector(`#gallery tr[data-model="${id}"]`), first));
  await page.fill('[data-search="gallery"]', rand);
  const searched = await page.evaluate(() => [...document.querySelectorAll("#gallery tr")].filter((tr) => !tr.hidden).length);
  check(`searched for this run's models: ${searched} shown`, searched === 2);
  await page.locator(`#gallery tr[data-model="${first}"] button`, { hasText: /^Take out$/ }).click();
  check("Take out: said, and out of the list", await until(page, (id) => /is out of the gallery/.test(document.getElementById("gallery-note").textContent)
    && !document.querySelector(`#gallery tr[data-model="${id}"]`), first));
  const listedNow = (await api(`/api/share?op=list&page=1&tests=1&q=${rand}`)).json?.models || [];
  check(`...and out of the gallery itself: ${listedNow.map((one) => one.id).join(", ")}`, !listedNow.some((one) => one.id === first)
    && listedNow.some((one) => one.id === second));
  await go(page, "gallery/reported");
  const reportRow = page.locator("#reports tr").filter({ has: page.locator(`a[href="/m/${second}"]`) }).first();
  check("Reported: M's second model, with what was said", await reportRow.waitFor({ timeout: 30000 }).then(() => true, () => false)
    && /spam/.test(await reportRow.innerText()));
  await reportRow.locator("button", { hasText: "Let it go" }).click();
  check("Let it go: the report leaves the queue", await until(page, (id) => /Let go/.test(document.getElementById("reports-note").textContent)
    && ![...document.querySelectorAll("#reports a")].some((a) => a.getAttribute("href") === `/m/${id}`), second));
  for (const [tab, body, none] of [["comments", "comments", "comments-note"], ["pick", "week", "pick-note"], ["challenges", "challenges", "challenge-note"],
    ["tested", "tested", "tested-note"], ["barred", "barred", "barred-note"]]) {
    await page.click(`a[data-tab-link="${tab}"]`);
    // The tab is shown by the address it sets, once the page hears it.
    await until(page, (id) => document.getElementById(id).closest("[data-tab]").hidden === false, body, 10000);
    const said = await page.evaluate(([id, note]) => ({ shown: !document.getElementById(id).closest("[data-tab]").hidden,
      rows: document.getElementById(id).rows.length, note: document.getElementById(note)?.textContent || "" }), [body, none]);
    check(`${tab}: shown, ${said.rows} rows${said.note ? ` ("${said.note.slice(0, 50)}")` : ""}`, said.shown && (said.rows > 0 || said.note.length > 0));
  }

  // --- 5. People -----------------------------------------------------------------
  console.log("5. People: an account out, and back");
  await go(page, "people");
  check("People: the checks' accounts listed", await until(page, () => document.querySelectorAll("#people tr[data-account]").length > 0));
  await page.fill("#people-q", address("m"));
  const found = await page.evaluate(() => [...document.querySelectorAll("#people tr[data-account]")].filter((tr) => !tr.hidden)
    .map((tr) => tr.innerText.replace(/\s+/g, " ")));
  check(`found by search: ${found.length} ("${(found[0] || "").slice(0, 90)}")`, found.length === 1 && found[0].includes(address("m")));
  await page.click(`#people tr[data-account="${m.kept.user_id}"] th a`);
  check("its panel: the account whole, its models", await until(page, (name) => document.querySelector("dialog.sheet[open]")
    && document.getElementById("sheet-body").textContent.includes(name), `Console Shed ${rand}`));
  check(`its address says which: ${new URL(page.url()).hash}`, new URL(page.url()).hash === `#people/${m.kept.user_id}`);
  await page.fill('#sheet-body input[name="reason"]', `console flow ${rand}`);
  await page.locator("#sheet-body button", { hasText: "Take out the account" }).click();
  check("Take out the account: said, and the panel says taken out", await until(page, () => /account is out/.test(document.getElementById("sheet-body").textContent)
    && /Taken out/.test(document.getElementById("sheet-body").textContent)
    && [...document.querySelectorAll("#sheet-body button")].some((b) => b.textContent === "Let back in")));
  const barredNow = (await api(`/api/share?op=list&page=1&tests=1&q=${rand}`)).json?.models || [];
  check(`...every model of it out of the gallery (${barredNow.length} left)`, barredNow.length === 0);
  const refusedList = await api("/api/share", { method: "POST", token: m.access_token,
    body: { name: `Console New ${rand}`, model: `0 New ${rand}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat\r\n`, image: picture, listed: true } });
  check(`...and it lists nothing new: ${refusedList.status}`, refusedList.status === 409);
  await shot(page, "5-person-out-1280.png", false);
  await page.locator("#sheet-body button", { hasText: "Let back in" }).click();
  check("Let back in: said, and the panel offers Take out again", await until(page, () => /Let back in/.test(document.getElementById("sheet-body").textContent)
    && [...document.querySelectorAll("#sheet-body button")].some((b) => b.textContent === "Take out the account")));
  const relisted = await api("/api/share", { method: "POST", token: m.access_token,
    body: { name: `Console Back ${rand}`, model: `0 Back ${rand}\r\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 3010.dat\r\n`, image: picture, listed: true } });
  if (relisted.json?.id) ids.push(relisted.json.id);
  check(`...and M lists again: ${relisted.status} ${relisted.json?.id || relisted.json?.error}`,
    [200, 201].includes(relisted.status) && Boolean(relisted.json?.id));
  await page.keyboard.press("Escape");
  check("Escape closes the panel, and the address goes back to People", await until(page, () => !document.querySelector("dialog.sheet[open]")
    && location.hash === "#people"));

  // --- 6. Beta -------------------------------------------------------------------
  console.log("6. The Beta: approve, waitlist, decline");
  await go(page, "beta");
  const card = (who) => page.locator("li.app", { hasText: address(who) });
  check("Months of Pro: the three applications", await until(page, (names) => names.every((one) => [...document.querySelectorAll("#apps li.app")]
    .some((li) => li.textContent.includes(one))), ["a", "b", "c"].map(address)));
  if (approving) {
    await card("a").locator("input[name=note]").fill("console flow approval");
    await card("a").getByRole("button", { name: `Approve ${address("a")}` }).click();
    check("Approve A: approved, the next spot", await until(page, () => /approved, spot \d+/.test(document.getElementById("said").textContent)));
  } else {
    console.log(`  --    Approve A not pressed: billing is test here, and approving one of the checks' own would give it a month at Admission`);
  }
  await card("c").locator("input[name=note]").fill("after the first wave");
  await card("c").getByRole("button", { name: `Waitlist ${address("c")}` }).click();
  check("Waitlist C: on the waitlist", await until(page, () => /on the waitlist/.test(document.getElementById("said").textContent)));
  await card("b").getByRole("button", { name: `Decline ${address("b")}` }).click();
  check("Decline B: declined", await until(page, () => /declined; email/.test(document.getElementById("said").textContent)));
  const states = Object.fromEntries(await Promise.all(["a", "b", "c"].map(async (who) => [who,
    (await api("/api/plans?op=beta", { token: applicants[who].access_token })).json?.application?.status])));
  check(`as each applicant now hears it: A ${states.a}, B ${states.b}, C ${states.c}`, states.a === (approving ? "approved" : "new")
    && states.b === "declined" && states.c === "waitlist");
  await page.click('a[data-tab-link="testers"]');
  check("Testers: A among them", await until(page, (one) => [...document.querySelectorAll("#testers tr.tester")]
    .some((tr) => tr.textContent.includes(one) && /Tester/.test(tr.textContent)), address("a")));

  // --- 7. The switch ---------------------------------------------------------------
  console.log("7. The beta's switch, on this deployment alone");
  await page.click('a[data-tab-link="applications"]');
  const liveBefore = [await spots("https://brickworks.diy"), await heard("https://brickworks.diy")].join("/");
  if (!switchBefore?.ready) {
    check("the switch: not open, supabase/console.sql is not applied here", false);
  } else {
    await page.click('#beta-switch button[data-beta="off"]');
    flipped = true;
    check("Off: the console says so", await until(page, () => /The beta is off here/.test(document.getElementById("beta-switch-note").textContent)
      && document.getElementById("beta-mode").textContent === "off"));
    check("...this deployment's beta_spots and op=beta follow: off", await follows("off"));
    const live = [await spots("https://brickworks.diy"), await heard("https://brickworks.diy")].join("/");
    check(`...brickworks.diy's as it was: ${live}, before ${liveBefore}`, live === liveBefore);
    {
      // Signed out, /beta hears the beta from beta_spots, which the CDN
      // keeps a minute and then answers once more as it was while it asks
      // again: a visitor sees Coming soon within about a minute, so a new
      // visitor (the bar keeps what it heard ten minutes in a browser) comes
      // every ten seconds until one does, for two minutes at most.
      const at = Date.now();
      let said = "";
      for (;;) {
        const visitor = await open("/beta", { width: 1280, label: "beta off" });
        await until(visitor.page, () => document.documentElement.dataset.betaPage
          && document.getElementById("spots").textContent.trim(), null, 30000);
        said = (await visitor.page.textContent("#spots")).trim();
        const done = /^Coming soon/.test(said) || Date.now() - at > 120000;
        if (done) await shot(visitor.page, "7-beta-off-1280.png", false);
        await visitor.context.close();
        if (done) break;
        await wait(10000);
      }
      check(`...and its /beta says "${said}" (${Math.round((Date.now() - at) / 1000)} s after it was heard here)`, /^Coming soon/.test(said));
    }
    await shot(page, "7-switch-off-1280.png", false);
    await page.click('#beta-switch button[data-beta="open"]');
    check("Open again: the console says so", await until(page, () => /The beta is open here/.test(document.getElementById("beta-switch-note").textContent)));
    const reopened = await follows("open");
    check("...and beta_spots and op=beta follow: open", reopened);
    // Put back at the end unless it is as it was: a failed Open left this
    // preview's beta off for every check after it (2026-11-12).
    flipped = !reopened || switchBefore.mode !== "open";
  }

  // --- 8. Feedback and the audit ----------------------------------------------------
  console.log("8. Feedback, and the Audit log");
  await go(page, "feedback");
  check("Feedback: the inbox read", await until(page, () => /shown/.test(document.getElementById("fb-note").textContent)));
  await go(page, "audit");
  check("the Audit log: listed", await until(page, () => document.querySelectorAll("#audit tr[data-audit]").length > 0));
  const kept = (await api("/api/admin?op=audit&tests=1", { token: owner.access_token })).json?.rows || [];
  const mine = kept.filter((row) => Date.parse(row.at) >= Date.parse(started) - 120000 && row.scope === host);
  const one = (op, target, extra = () => true) => mine.find((row) => row.op === op && String(row.target) === String(target) && extra(row));
  const want = [
    ["unlist", "model", first], ["dismiss", "report", null], ["bar", "account", m.kept.user_id], ["unbar", "account", m.kept.user_id],
    ...(approving ? [["beta_decide", "account", applicants.a.kept.user_id, (row) => row.detail?.asked?.decision === "approve"]] : []),
    ["beta_waitlist", "account", applicants.c.kept.user_id], ["beta_decide", "account", applicants.b.kept.user_id,
      (row) => row.detail?.asked?.decision === "decline"],
    ...(switchBefore?.ready ? [["beta_switch", "setting", "beta", (row) => row.detail?.asked?.mode === "off"],
      ["beta_switch", "setting", "beta", (row) => row.detail?.asked?.mode === "open"]] : []),
  ];
  for (const [op, kind, target, extra] of want) {
    const row = target === null ? mine.find((r) => r.op === op) : one(op, target, extra);
    check(`kept: ${op} on ${kind} ${target || "(the report)"}: ${row ? `#${row.id} ${row.status} by ${row.actor === process.env.MASTER_EMAIL ? "the owner" : row.actor}, a test's ${row.test}` : "NOT KEPT"}`,
      Boolean(row) && row.status === 200 && row.target_kind === kind && row.test === true);
  }
  check(`...newest first: ${mine.slice(0, 3).map((row) => row.op).join(", ")}`, mine.every((row, at) => at === 0 || mine[at - 1].id > row.id));
  const firstRow = await page.evaluate(() => document.querySelector("#audit tr[data-audit]")?.innerText.replace(/\s+/g, " ") || "");
  check(`the page's newest act: "${firstRow.slice(0, 100)}"`, switchBefore?.ready ? /Opened the beta/.test(firstRow) : firstRow.length > 0);
  await page.selectOption("#audit-act", "beta_decide");
  check("filtered by act: decisions alone", await until(page, () => {
    const rows = [...document.querySelectorAll("#audit tr[data-audit]")];
    return rows.length > 0 && rows.every((tr) => tr.dataset.op === "beta_decide");
  }));
  await page.locator("#audit tr[data-audit] button", { hasText: "Details" }).first().click();
  check("an act's panel: what was asked and answered", await until(page, () => document.querySelector("dialog.sheet[open]")
    && /Asked: decision/.test(document.getElementById("sheet-body").textContent)));
  await shot(page, "8-act-1280.png", false);
  await page.keyboard.press("Escape");
  await context.close();

  // --- 9. The old addresses -----------------------------------------------------------
  console.log("9. /beta-admin");
  const old = await fetch(`${site}/beta-admin`, { headers, redirect: "manual" });
  check(`/beta-admin answers ${old.status} to ${old.headers.get("location")}`, old.status === 308
    && /\/admin#beta$/.test(old.headers.get("location") || ""));
  {
    const landed = await open("/beta-admin?tests=1", { width: 1280, who: owner, label: "beta-admin" });
    check(`/beta-admin?tests=1 lands on the console's Beta with the checks' pool (${new URL(landed.page.url()).pathname}${new URL(landed.page.url()).search}${new URL(landed.page.url()).hash})`,
      await until(landed.page, () => document.querySelector('[data-section="beta"]')?.hidden === false
        && /checks' own pool/.test(document.getElementById("months").textContent), null, 60000));
    await landed.context.close();
  }

  // --- 10. Every section, at both sizes, in both themes -----------------------------
  console.log("10. Pictures");
  const SECTIONS = [["overview", () => document.querySelectorAll("#needs li").length > 0],
    ["people", () => document.querySelectorAll("#people tr[data-account]").length > 0],
    ["gallery/reported", () => document.querySelectorAll("#reports tr").length > 0 || document.getElementById("reports-note").textContent],
    ["gallery/challenges", () => document.querySelectorAll("#challenges tr").length > 0 || document.getElementById("challenge-note").textContent],
    ["beta", () => document.getElementById("months").textContent.length > 0],
    ["beta/testers", () => document.querySelectorAll("#testers tr.tester").length > 0],
    ["feedback", () => /shown/.test(document.getElementById("fb-note").textContent)],
    ["audit", () => document.querySelectorAll("#audit tr[data-audit]").length > 0]];
  for (const [width, theme] of [[1280, "light"], [1280, "dark"], [390, "light"], [390, "dark"]]) {
    const where = await open("/admin?tests=1", { width, theme, who: owner, label: `pictures ${width} ${theme}` });
    await shown(where.page);
    for (const [hash, ready] of SECTIONS) {
      await go(where.page, hash);
      const drawn = await until(where.page, ready);
      const wide = await sideways(where.page);
      check(`${hash} at ${width} ${theme}: drawn, nothing sideways`, drawn && !wide);
      await shot(where.page, `10-${hash.replace("/", "-")}-${width}-${theme}.png`);
    }
    if (width === 390) {
      await go(where.page, `people/${m.kept.user_id}`);
      await until(where.page, () => document.querySelector("dialog.sheet[open] .facts"));
      await shot(where.page, `10-person-${width}-${theme}.png`, false);
    }
    await where.context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
  // The switch here as it was, if the flow stopped between Off and Open.
  if (flipped && owner && switchBefore?.mode) {
    const back = await api("/api/admin?op=beta_switch&tests=1", { method: "POST", token: owner.access_token, body: { mode: switchBefore.mode } });
    console.log(`  --    the switch put back to ${switchBefore.mode}: ${back.status}`);
  }
  const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  const again = await mintSession(address("m")).catch(() => null);
  if (again) {
    for (const id of ids) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: again.access_token });
    await fetch(`${SUPABASE}/rest/v1/act_log?who=eq.${again.kept.user_id}`, { method: "DELETE", headers: secret }).catch(() => {});
    await fetch(`${SUPABASE}/rest/v1/barred_accounts?account=eq.${again.kept.user_id}`, { method: "DELETE", headers: secret }).catch(() => {});
  }
  if (ids.length) {
    await fetch(`${SUPABASE}/rest/v1/barred_models?model=in.(${ids.join(",")})`, { method: "DELETE", headers: secret }).catch(() => {});
    await fetch(`${SUPABASE}/rest/v1/reports?model=in.(${ids.join(",")})`, { method: "DELETE", headers: secret }).catch(() => {});
  }
  let gone = 0;
  for (const email of made) if (await deleteAccount(email).catch(() => false)) gone += 1;
  check(`the throwaways deleted, and everything of theirs with them (${gone} of ${made.length})`, gone === made.length);
  // The checks' pool of spots as this run found it: A's spot given back.
  if (poolBefore !== null) await rpc("beta_test_pool", { p_given: poolBefore }).catch(() => {});
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`console: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "console: all ok" : "console: FAILED");
process.exit(failed === 0 ? 0 : 1);
