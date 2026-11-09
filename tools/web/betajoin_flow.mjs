// Joining the beta is a step of signing up (betajoin, 2026-11-09), on the
// site, as a person meets it: the sign-in dialog's code accepted, then the
// welcome, Join or Not now, Settings' Beta row, and the owner's list of
// testers.
//
//   set -a; . ./.env; set +a
//   BRICKWORKS_BETA=open MASTER_EMAIL=delivered+bw-betajoin-owner@resend.dev \
//     node tools/web/relay_server.mjs 9960 --hold=feedback
//   node tools/web/relay_server.mjs 9961                       the beta off
//   node tools/web/betajoin_flow.mjs --url=http://127.0.0.1:9960 --owner=delivered+bw-betajoin-owner@resend.dev \
//     --off=http://127.0.0.1:9961 [--before=<the same off, served from the commit before>] --out=DIR
//
// --hold=feedback keeps supabase/beta.sql, feedback.sql and beta_join.sql in
// a Postgres of this machine's own until beta_join.sql is applied to the
// project (tools/web/feedback_stand_in.mjs); with it applied, any deployment
// with the beta open (tools/deploy.sh --unit --beta-open) does as well.
// Throwaway accounts at Resend test addresses, deleted at the end. The code
// is minted here and typed, as a person types the one emailed; /api/otp is
// answered in the browser, so no mail is sent.
//
//   1. A new account at 390 x 844: the code accepted (and the age question,
//      13 or over), then the welcome, light and dark: what Brickworks is,
//      that it is in beta, what a tester does and gets, Join the beta
//      testers first and Not now, nothing ticked. Join, one press: GET
//      op=beta says tester, the dialog thanks them in place, and First
//      steps follow. Settings' Beta row: tester since, and Leave the beta.
//   2. Another new account at 1280 x 800, dark: Not now, one press; not a
//      tester; signed in again by the dialog, never welcomed again;
//      Settings offers Join, and one press makes it a tester, and one more
//      leaves.
//   3. The owner's /beta-admin?tests=1: the testers, newest first, where
//      each joined from, and the month's queue under them.
//   4. --off, the beta off: a new account signed in by the dialog is not
//      welcomed, Settings has no Beta row, op=beta_join answers 403.
//   5. --before, the commit before, also off: every page reads as it did,
//      signed out and in.
//
// Pictures in --out. It passes when it ends "betajoin: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("betajoin_flow: --url=<a server with the beta open> [--owner=<its owner's test address>] [--off=URL] [--before=URL] [--out=DIR]");
  process.exit(2);
}
const trim = (url) => String(url).replace(/\/+$/, "");
const site = trim(args.url);
const out = args.out || "shots/betajoin";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-betajoin-${who}-${rand}@resend.dev`;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const until = (page, test, arg = null, timeout = 20000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const shot = async (page, name, locator = null) => {
  const where = path.join(out, name);
  await (locator ? page.locator(locator).screenshot({ path: where, timeout: 60000 })
    : page.screenshot({ path: where, timeout: 60000 }))
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};
/// A picture of [page] in light and in dark, as the visitor's system has it.
const both = async (page, name, locator = null) => {
  for (const theme of ["light", "dark"]) {
    await page.emulateMedia({ colorScheme: theme });
    await page.waitForTimeout(150);
    await shot(page, `${name}-${theme}.png`, locator);
  }
};

async function api(base, pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(base + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });
const made = [];

/// A page at [width] in [theme], signed out, or as [who] (a mintSession).
async function open(base, pathname, { width, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 800 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (who) {
    await context.addInitScript(([key, value]) => {
      try {
        if (!localStorage.getItem(key)) localStorage.setItem(key, value);
      } catch { /* a browser that keeps nothing */ }
    }, [STORAGE_KEY, JSON.stringify(who.kept)]);
  }
  // A code is "sent" here: the flow types the one it mints, as a person
  // types the one emailed, and no mail goes anywhere.
  await context.route("**/api/otp", (route) => route.fulfill({ status: 200, contentType: "application/json",
    body: JSON.stringify({ ok: true, expires_in_minutes: 10 }) }));
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  if (pathname) await page.goto(base + pathname, { waitUntil: "load", timeout: 60000 });
  return { page, context };
}

/// This page's session's token, as the site keeps it.
const tokenOf = (page) => page.evaluate(async () => (await import("/account.js")).token());

/// Signed in by the dialog on /profile, as a person signs in: the address,
/// Email me a code, the code typed, Sign in; the age question answered 13
/// or over when it is asked. Resolves with what came next: "welcome",
/// "steps" (First steps) or "none".
async function signInByDialog(base, page, email) {
  await page.goto(`${base}/profile`, { waitUntil: "load", timeout: 60000 });
  await page.click("#sign-in");
  await page.locator("dialog.sign-in[open]").waitFor({ state: "visible", timeout: 20000 });
  await page.fill("dialog.sign-in input", email);
  await page.click('dialog.sign-in button[type="submit"]');
  await until(page, () => document.querySelector("dialog.sign-in input")?.autocomplete === "one-time-code");
  const code = await mintCode(email);
  await page.fill("dialog.sign-in input", code);
  await page.click('dialog.sign-in button[type="submit"]');
  await until(page, () => !document.querySelector("dialog.sign-in"), null, 30000);
  const next = () => page.waitForFunction(() => (document.querySelector("dialog.age[open]") ? "age"
    : document.querySelector("dialog.beta-welcome[open]") ? "welcome"
      : document.querySelector("dialog.first-steps[open]") ? "steps" : null), null, { timeout: 8000 })
    .then((one) => one.jsonValue(), () => "none");
  let seen = await next();
  if (seen === "age") {
    await page.selectOption("#age-month", { index: 1 });
    await page.selectOption("#age-year", "1990");
    await page.click("#age-go");
    await until(page, () => !document.querySelector("dialog.age[open]"));
    seen = await next();
  }
  return seen;
}

/// What the welcome shows, as drawn.
const welcomeSaid = (page) => page.evaluate(() => {
  const dialog = document.querySelector("dialog.beta-welcome[open]");
  if (!dialog) return null;
  const join = document.getElementById("beta-join");
  const later = document.getElementById("beta-not-now");
  const actions = dialog.querySelector(".actions");
  const box = dialog.getBoundingClientRect();
  return {
    eyebrow: dialog.querySelector(".eyebrow")?.textContent.trim(), title: dialog.querySelector("h2")?.textContent.trim(),
    words: dialog.innerText.replace(/\s+/g, " ").trim(),
    first: actions?.firstElementChild?.id, join: join?.textContent.trim(), joinGhost: join?.classList.contains("ghost"),
    later: later?.textContent.trim(), laterGhost: later?.classList.contains("ghost"),
    ticks: dialog.querySelectorAll('input[type="checkbox"], input[type="radio"]').length,
    focused: document.activeElement?.id, terms: dialog.querySelector(".note a")?.getAttribute("href"),
    inside: box.left >= 0 && box.right <= innerWidth + 0.5 && box.bottom <= innerHeight + 0.5,
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    cut: [...dialog.querySelectorAll("button, p, h2")].filter((el) => el.offsetWidth && el.scrollWidth > el.clientWidth + 1).length,
    // Its own height: the dialog opens from 98% (site.css), so a rect
    // measured as it opens is 2% short.
    joinHeight: join?.offsetHeight || 0,
  };
});

/// Settings' Beta row, as drawn.
const rowSaid = (page) => page.evaluate(() => {
  const part = document.getElementById("beta-part");
  const shown = (id) => !document.getElementById(id)?.hidden;
  return { shown: Boolean(part) && !part.hidden, toc: shown("beta-toc"), said: document.getElementById("beta-said")?.textContent.trim(),
    month: shown("beta-month") ? document.getElementById("beta-month").textContent.trim() : "",
    join: shown("beta-join"), leave: shown("beta-leave"), hub: shown("beta-hub"),
    status: document.getElementById("beta-status")?.textContent.trim() };
});
const settingsReady = (page) => until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);

let on = false;
try {
  const signedOut = await api(site, "/api/plans?op=beta");
  on = signedOut.json?.beta === "open";
  console.log(`betajoin flow: ${site} (beta ${on ? "open" : signedOut.json?.beta || signedOut.status})`);
  check(`signed out, GET op=beta: ${JSON.stringify(signedOut.json)}`, on && signedOut.json.signed_in === false
    && typeof signedOut.json.spots?.left === "number");
  check(`signed out, op=beta_join: ${(await api(site, "/api/plans?op=beta_join", { method: "POST", body: {} })).status}`,
    (await api(site, "/api/plans?op=beta_join", { method: "POST", body: {} })).status === 401);

  // --- 1. A new account joins ---------------------------------------------------------
  console.log("1. A new account at 390, by the dialog, joins");
  {
    const email = address("a");
    made.push(email);
    const { page, context } = await open(site, null, { width: 390, label: "A" });
    const next = await signInByDialog(site, page, email);
    check(`the code is accepted, and the welcome shows: ${next}`, next === "welcome");
    const said = await welcomeSaid(page);
    check(`"${said?.eyebrow}", "${said?.title}"`, said?.eyebrow === "Open beta" && said?.title === "Welcome to Brickworks");
    check("...what Brickworks is, that it is in beta, what a tester does and gets",
      /A CAD for LEGO® models/.test(said?.words) && /open beta/.test(said?.words) && /month of Pro/.test(said?.words));
    check(`...Join first and the default, Not now beside it: ${said?.first}, "${said?.join}" / "${said?.later}"`,
      said?.first === "beta-join" && said.joinGhost === false && said.laterGhost === true && said.later === "Not now"
      && said.join === "Join the beta testers");
    check(`...nothing ticked: ${said?.ticks} boxes`, said?.ticks === 0);
    check(`...the focus on Join: ${said?.focused}`, said?.focused === "beta-join");
    check(`...the beta's terms linked: ${said?.terms}`, said?.terms === "/terms#beta");
    check(`...inside the window, nothing cut or sideways, a ${said?.joinHeight} px target`, said?.inside && !said.sideways
      && said.cut === 0 && said.joinHeight >= 44);
    await both(page, "1-welcome-390");
    const token = await tokenOf(page);
    const before = await api(site, "/api/plans?op=beta", { token });
    check(`before: tester ${before.json?.tester}, welcome ${before.json?.welcome}`, before.json?.tester === false && before.json?.welcome === true);
    await page.click("#beta-join");
    const joined = await until(page, () => document.querySelector("dialog.beta-welcome")?.dataset.step === "joined");
    const after = await api(site, "/api/plans?op=beta", { token });
    check(`Join, one press: GET op=beta says tester ${after.json?.tester}, ${after.json?.state}, joined ${after.json?.joined_at}`,
      joined && after.json?.tester === true && after.json?.state === "tester" && Boolean(after.json?.joined_at));
    const thanks = await page.evaluate(() => ({ title: document.querySelector("dialog.beta-welcome h2")?.textContent.trim(),
      words: document.querySelector("dialog.beta-welcome")?.innerText.replace(/\s+/g, " "),
      apply: document.querySelector('dialog.beta-welcome a[href$="/beta#apply"]')?.getAttribute("href"),
      focused: document.activeElement?.id }));
    check(`the thank-you: "${thanks.title}", telling us about you after (${thanks.apply}), the focus on ${thanks.focused}`,
      thanks.title === "You are a beta tester" && /Report a bug/.test(thanks.words) && thanks.apply === "/beta#apply"
      && thanks.focused === "beta-carry-on");
    await both(page, "2-joined-390");
    await page.click("#beta-carry-on");
    check("Carry on closes it, and First steps follow",
      await until(page, () => !document.querySelector("dialog.beta-welcome") && document.querySelector("dialog.first-steps[open]")));
    await page.keyboard.press("Escape");

    console.log("   Settings: tester since, and Leave");
    await page.goto(`${site}/settings`, { waitUntil: "load" });
    await settingsReady(page);
    let row = await rowSaid(page);
    check(`the Beta row: "${row.said}", Leave ${row.leave}, Beta hub ${row.hub}`, row.shown && row.toc
      && /^You have been a beta tester since .+\. Thank you\.$/.test(row.said) && row.leave && row.hub && !row.join);
    check(`...and the month: "${row.month.slice(0, 80)}"`, /For a month of Pro, tell us what you build/.test(row.month));
    await page.locator("#beta-part").scrollIntoViewIfNeeded();
    await both(page, "3-settings-tester-390", "#beta-part");
    await context.close();
  }

  // --- 2. Not now ---------------------------------------------------------------------
  console.log("2. A new account at 1280, dark, says Not now");
  {
    const email = address("b");
    made.push(email);
    const { page, context } = await open(site, null, { width: 1280, theme: "dark", label: "B" });
    const next = await signInByDialog(site, page, email);
    check(`the code is accepted, and the welcome shows: ${next}`, next === "welcome");
    const said = await welcomeSaid(page);
    check(`...inside the window, nothing cut or sideways (focus on ${said?.focused})`, said?.inside && !said.sideways
      && said.cut === 0 && said.focused === "beta-join");
    await both(page, "5-welcome-1280");
    await page.click("#beta-not-now");
    check("Not now closes it", await until(page, () => !document.querySelector("dialog.beta-welcome")));
    const token = await tokenOf(page);
    const now = await api(site, "/api/plans?op=beta", { token });
    check(`...not a tester: tester ${now.json?.tester}, ${now.json?.state}, welcome ${now.json?.welcome}`,
      now.json?.tester === false && now.json?.state === "not_now" && now.json?.welcome === false);
    await page.keyboard.press("Escape");
    await page.evaluate(async () => (await import("/account.js")).signOut());
    const again = await signInByDialog(site, page, email);
    check(`signed in again by the dialog, never welcomed again: ${again}`, again === "none" || again === "steps");
    await page.goto(`${site}/settings`, { waitUntil: "load" });
    await settingsReady(page);
    let row = await rowSaid(page);
    check(`Settings offers Join: "${row.said.slice(0, 60)}…"`, row.shown && row.join && !row.leave && !row.hub
      && /^Brickworks is in open beta\./.test(row.said));
    await page.locator("#beta-part").scrollIntoViewIfNeeded();
    await both(page, "6-settings-not-tester-1280", "#beta-part");
    await page.click("#beta-join");
    await until(page, () => /Joined/.test(document.getElementById("beta-status")?.textContent || ""));
    const joined = await api(site, "/api/plans?op=beta", { token: await tokenOf(page) });
    row = await rowSaid(page);
    check(`an existing account joins from Account, one press: tester ${joined.json?.tester}; "${row.said}"`,
      joined.json?.tester === true && row.leave && /beta tester since/.test(row.said));
    await both(page, "7-settings-joined-1280", "#beta-part");
    await page.click("#beta-leave");
    await until(page, () => /You left the beta/.test(document.getElementById("beta-status")?.textContent || ""));
    const left = await api(site, "/api/plans?op=beta", { token: await tokenOf(page) });
    row = await rowSaid(page);
    check(`...and leaves, one press: tester ${left.json?.tester}, ${left.json?.state}; "${row.status}"`,
      left.json?.tester === false && left.json?.state === "left" && row.join && !row.leave);
    await both(page, "8-settings-left-1280", "#beta-part");
    await context.close();
  }

  // --- 3. The owner's list ------------------------------------------------------------
  if (args.owner) {
    console.log("3. The owner's list of testers");
    const owner = await mintSession(String(args.owner));
    const { page, context } = await open(site, "/beta-admin?tests=1", { width: 1280, who: owner, label: "owner" });
    const shown = await until(page, () => document.getElementById("view")?.hidden === false
      && document.querySelectorAll("#testers .tester").length > 0, null, 30000);
    const listed = await page.evaluate(() => ({
      counts: ["n-testers", "n-welcome", "n-left", "n-not-now"].map((id) => document.getElementById(id)?.textContent.trim()),
      rows: [...document.querySelectorAll("#testers .tester")].map((one) => one.innerText.replace(/\s+/g, " ")),
      months: Boolean(document.getElementById("months-h")) && document.getElementById("n-spots-left")?.textContent.trim() }));
    const a = listed.rows.find((one) => one.includes(address("a")));
    const b = listed.rows.find((one) => one.includes(address("b")));
    check(`the testers listed (${listed.counts.join(", ")} testers, at sign-up, left, not now): A "${a}"`, shown
      && /Tester/.test(a || "") && /from the welcome at sign-up/.test(a || "") && listed.counts[0] === "1" && listed.counts[1] === "1");
    check(`...B, who left: "${b}"`, /Left/.test(b || "") && /from Settings/.test(b || "") && listed.counts[2] === "1");
    check(`...the month's queue under them: ${listed.months} spots left`, listed.months !== false && listed.months !== "");
    await both(page, "9-owner-testers-1280");
    await context.close();
  }

  // The welcome's words in a language: the German copy's.
  {
    const { page, context } = await open(site, "/de/settings", { width: 390, label: "de" });
    await page.evaluate(() => { import("/beta-welcome.js").then((one) => one.betaWelcome()); });
    await until(page, () => document.querySelector("dialog.beta-welcome[open]"));
    const said = await welcomeSaid(page);
    check(`in German: "${said?.title}", "${said?.join}", "${said?.later}"`, said?.title === "Willkommen bei Brickworks"
      && said.join === "Beta-Tester werden" && said.later === "Nicht jetzt" && said.cut === 0);
    await both(page, "10-welcome-de-390");
    await context.close();
  }

  // --- 4. The beta off ----------------------------------------------------------------
  if (args.off) {
    const offSite = trim(args.off);
    console.log(`4. The beta off (${offSite})`);
    const off = await api(offSite, "/api/plans?op=beta");
    check(`GET op=beta: ${JSON.stringify(off.json)}`, off.json?.beta === "off");
    const email = address("off");
    made.push(email);
    const { page, context } = await open(offSite, null, { width: 1280, label: "off" });
    const next = await signInByDialog(offSite, page, email);
    check(`a new account signed in by the dialog is not welcomed: ${next}`, next !== "welcome"
      && !(await page.$("dialog.beta-welcome")));
    await page.keyboard.press("Escape");
    await page.goto(`${offSite}/settings`, { waitUntil: "load" });
    await settingsReady(page);
    const row = await rowSaid(page);
    check(`Settings has no Beta row: shown ${row.shown}, in the contents ${row.toc}`, !row.shown && !row.toc);
    const token = await tokenOf(page);
    const join = await api(offSite, "/api/plans?op=beta_join", { method: "POST", token, body: { via: "settings" } });
    check(`op=beta_join refused: ${join.status} ${JSON.stringify(join.json)}`, join.status === 403 && join.json?.beta === "off");
    const account = await api(offSite, "/api/account", { token });
    check(`/api/account says nothing of a welcome: ${JSON.stringify(account.json?.beta)}`,
      JSON.stringify(account.json?.beta) === JSON.stringify({ tester: false, early: [] }));
    await shot(page, "11-settings-off-1280.png");

    // --- 5. As before ------------------------------------------------------------------
    if (args.before) {
      const beforeSite = trim(args.before);
      console.log(`5. Every page as before (${beforeSite})`);
      const read = async (base, pathname, who) => {
        const { page: one, context: its } = await open(base, pathname, { width: 1280, who, label: `as before ${pathname}` });
        await one.waitForLoadState("networkidle").catch(() => null);
        await one.waitForTimeout(1500);
        const text = await one.evaluate(() => document.body.innerText.replace(/[ \t]+/g, " ").replace(/\n+/g, "\n").trim());
        await its.close();
        return text;
      };
      const who = await mintSession(email);
      for (const [pathname, as] of [["/index.html", null], ["/de/", null], ["/settings", null], ["/settings", who], ["/de/settings", who],
        ["/beta", null], ["/profile", who], ["/beta-hub", who]]) {
        const [now, then] = [await read(offSite, pathname, as), await read(beforeSite, pathname, as)];
        const at = now.split("\n").findIndex((line, i) => line !== then.split("\n")[i]);
        check(`${pathname}${as ? " signed in" : ""} reads as before (${now.length} characters)${at < 0 ? ""
          : `: line ${at} "${now.split("\n")[at]}" was "${then.split("\n")[at]}"`}`, now === then);
      }
    }
    await context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  for (const email of made) await deleteAccount(email).catch(() => {});
  await browser.close();
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`betajoin: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "betajoin: all ok" : "betajoin: FAILED");
process.exit(failed === 0 ? 0 : 1);
