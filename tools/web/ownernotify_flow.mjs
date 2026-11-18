// The owner's notifications (web/admin.html › Notifications, web/admin-notify.js,
// api/_notify.js; docs/OWNER_NOTIFY.md), in a real browser against a
// deployment, used as the owner uses it, in the checks' own pool
// (/admin?tests=1), whose mail goes only to Resend's test inbox. Never
// against brickworks.diy: it refuses that address.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/ownernotify_flow.mjs --url=<deployment> --out=shots/ownernotify
//
// Or the whole section before supabase/owner_notify.sql is applied, its
// tables held on this machine (tools/web/held_tables.mjs):
//
//   node --env-file=.env tools/web/relay_server.mjs 10681 \
//     --hold=owner_notify_settings,owner_notify_mails,owner_notify_events,owner_notify_errors
//   node --env-file=.env tools/web/ownernotify_flow.mjs --url=http://127.0.0.1:10681 --out=shots/ownernotify
//
//   1. The gate: every op answers 401 signed out and 404 to an account that
//      is not the owner's; the cron's op 401 without its secret; a one-click
//      link a POST, and 404 unsigned.
//   2. Before the file the section says so, still lists each kind and what
//      cannot be mailed from here, and a change answers 503 with why. It
//      ends "ownernotify: all ok (before the file)".
//   3. With the tables: each kind turned off and on, to the digest and
//      back, a threshold kept and a wrong one refused in words; quiet hours,
//      their times, the digest's time, the time zone and the cap, each kept
//      as it changes (read back from the API); Pause all in the headline.
//   4. Send a test, and a kind's test; where the tables are held here, that
//      mail's own one-click link opened signed out turns that kind off, its
//      key gone from the address.
//   5. Another address: a code sent to a resend.dev address, a wrong code
//      refused, and back to the account's own, the code dropped.
//   6. Check now; Sent lists what was mailed, and Read it shows its words.
//   7. Each tab at 1280 and 430, light and dark, never wider than the
//      screen, every row's acts on it.
//
// It passes when it ends "ownernotify: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("ownernotify_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
if (/^https?:\/\/(www\.)?brickworks\.diy(\/|$)/i.test(site)) {
  console.error("ownernotify_flow: never against brickworks.diy: its settings are the owner's own. Give a preview's address.");
  process.exit(2);
}
const out = args.out || "shots/ownernotify";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-ownernotify-${who}-${rand}@resend.dev`;

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
const shot = async (page, name, full = true) => {
  if (full) await page.evaluate(() => scrollTo(0, 0)).catch(() => {});
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: reply.status, json };
}

const browser = await launch({ signedOut: true });

async function open(pathname, { width = 1280, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 900 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
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
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const go = async (page, hash) => {
  await page.evaluate((to) => { location.hash = to; }, hash);
  await page.waitForTimeout(300);
};
const saidIn = (page, id, pattern) => until(page, ([where, source]) => new RegExp(source).test(document.getElementById(where)?.textContent || ""),
  [id, pattern.source], 20000);

const made = [];
let owner = null;
let settingsAtStart = null;
try {
  // --- 1. The gate -------------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
  const OPS = [["notify", "GET"], ["notify_set", "POST"], ["notify_address", "POST"], ["notify_confirm", "POST"],
    ["notify_test", "POST"], ["notify_flush", "POST"]];
  let gate = 0;
  for (const [op, method] of OPS) {
    for (const tests of ["&tests=1", ""]) {
      const query = `/api/admin?op=${op}${tests}`;
      const body = method === "POST" ? { cap: 1, address: address("y"), code: "123456" } : undefined;
      const signedOut = await api(query, { method, body });
      const other = await api(query, { method, token: stranger.access_token, body });
      if (signedOut.status === 401 && other.status === 404) gate += 1;
      else console.log(`        ${method} ${op}${tests}: signed out ${signedOut.status}, anybody else ${other.status}`);
    }
  }
  check(`each of the ${OPS.length} ops, both pools: signed out 401, any other account 404 (${gate} of ${OPS.length * 2})`,
    gate === OPS.length * 2);
  const cron = await api("/api/plans?op=owner_notify");
  check(`the cron's run without its secret: ${cron.status}`, cron.status === 401);
  const offGet = await api(`/api/plans?op=notify_off&event=signup&pool=t&token=${"0".repeat(32)}`);
  const offBad = await api("/api/plans?op=notify_off", { method: "POST", body: { event: "signup", pool: "t", token: "0".repeat(32) } });
  check(`a one-click link: GET ${offGet.status}, unsigned POST ${offBad.status}`, offGet.status === 405 && offBad.status === 404);

  const first = await as("/api/admin?op=notify&tests=1");
  check(`the owner reads Notifications: ${first.status}`, first.status === 200 && first.json?.catalog?.length === 8);
  const ready = first.json?.applied === true;
  settingsAtStart = ready ? first.json.settings : null;

  if (!ready) {
    // --- 2. Before the file ------------------------------------------------------------
    console.log("2. Before supabase/owner_notify.sql");
    check(`the read says the file is missing: "${first.json?.said}"`, /owner_notify\.sql/.test(first.json?.said || ""));
    const change = await as("/api/admin?op=notify_set&tests=1", { method: "POST", body: { cap: 3 } });
    check(`a change before it answers 503, saying why: ${change.status}`, change.status === 503 && /owner_notify\.sql/.test(change.json?.error || ""));
    for (const width of [1280, 430]) {
      for (const theme of ["light", "dark"]) {
        const where = await open("/admin?tests=1#notifications/settings", { width, theme, who: owner, label: `before ${width} ${theme}` });
        await shown(where.page);
        const said = await until(where.page, () => !document.getElementById("notify-not-yet").hidden
          && /owner_notify\.sql/.test(document.getElementById("notify-not-yet").textContent)
          && document.querySelectorAll("#notify-events > li").length === 8
          && document.querySelectorAll("#notify-not-here > li").length === 4, null, 30000);
        check(`at ${width} ${theme}: says the file is not applied, lists the 8 kinds and the 4 not mailed from here`, said);
        check(`...no wider than the screen at ${width}`, !(await sideways(where.page)));
        await shot(where.page, `0-before-${width}-${theme}.png`);
        await go(where.page, "notifications/sent");
        await shot(where.page, `0-before-sent-${width}-${theme}.png`);
        check(`...Sent no wider than the screen at ${width}`, !(await sideways(where.page)));
        await where.context.close();
      }
    }
  } else {
    const read = () => as("/api/admin?op=notify&tests=1").then((got) => got.json);
    const owned = await open("/admin?tests=1#notifications/settings", { who: owner, label: "owner" });
    const page = owned.page;
    await shown(page);
    check("the section drawn: 8 kinds, 4 not mailed from here", await until(page, () => document.querySelectorAll("#notify-events > li").length === 8
      && document.querySelectorAll("#notify-not-here > li").length === 4));

    // --- 3. Each kind and the settings -----------------------------------------------------
    console.log("3. The settings, each kept as it changes");
    const row = (event) => page.locator(`#notify-events > li[data-event="${event}"]`);
    await page.locator("#notify-on-signup").click();
    let ok = await saidIn(page, "notify-said-signup", /A new sign-up: off\./);
    check("A new sign-up turned off, said and kept", ok && (await read()).settings.events.signup.on === false);
    await page.locator("#notify-on-signup").click();
    ok = await saidIn(page, "notify-said-signup", /A new sign-up: on\./);
    check("...and on again", ok && (await read()).settings.events.signup.on === true);
    const digest = row("feedback").getByRole("button", { name: "Daily digest", exact: true });
    await digest.click();
    ok = await saidIn(page, "notify-said-feedback", /in the daily digest/);
    let when = (await read()).settings.events.feedback.when;
    const pressed = await until(page, () => document.querySelector('#notify-events > li[data-event="feedback"] button[data-value="digest"]')
      ?.getAttribute("aria-pressed") === "true", null, 10000);
    check(`feedback to the daily digest: "${await page.textContent("#notify-said-feedback")}", kept ${when}, pressed ${pressed}`,
      ok && when === "digest" && pressed);
    await row("feedback").getByRole("button", { name: "At once", exact: true }).click();
    ok = await saidIn(page, "notify-said-feedback", /at once\./);
    when = (await read()).settings.events.feedback.when;
    check(`...and back to at once: "${await page.textContent("#notify-said-feedback")}", kept ${when}`, ok && when === "now");
    const threshold = row("errors").locator('input[data-field="threshold"]');
    await threshold.fill("7");
    await threshold.dispatchEvent("change");
    ok = await saidIn(page, "notify-said-errors", /Server errors: 7 errors in an hour\./);
    check("the errors' threshold kept at 7", ok && (await read()).settings.events.errors.threshold === 7);
    await threshold.fill("0");
    await threshold.dispatchEvent("change");
    ok = await saidIn(page, "notify-said-errors", /is a number from 1 to/);
    check("a threshold of 0 refused in words, the field put back", ok && await threshold.inputValue() === "7"
      && (await read()).settings.events.errors.threshold === 7);
    await page.locator("#notify-quiet-on").check();
    ok = await saidIn(page, "notify-form-said", /Quiet from/);
    check("quiet hours on, kept", ok && (await read()).settings.quiet.on === true);
    await page.selectOption("#notify-quiet-from", "21:30");
    ok = await saidIn(page, "notify-form-said", /from 21:30/);
    check("...from 21:30, kept", ok && (await read()).settings.quiet.from === "21:30");
    await page.locator("#notify-quiet-on").uncheck();
    await saidIn(page, "notify-form-said", /No quiet hours/);
    await page.selectOption("#notify-digest-at", "07:30");
    ok = await saidIn(page, "notify-form-said", /The digest goes at 07:30/);
    check("the digest at 07:30, kept", ok && (await read()).settings.digest_at === "07:30");
    await page.selectOption("#notify-tz", "Europe/London");
    ok = await saidIn(page, "notify-form-said", /Europe\/London/);
    check("the time zone Europe/London, kept", ok && (await read()).settings.tz === "Europe/London");
    await page.fill("#notify-cap", "4");
    await page.locator("#notify-cap").dispatchEvent("change");
    ok = await saidIn(page, "notify-form-said", /At most 4 mails an hour/);
    check("at most 4 mails an hour, kept", ok && (await read()).settings.cap === 4);
    await page.fill("#notify-cap", "99");
    await page.locator("#notify-cap").dispatchEvent("change");
    ok = await saidIn(page, "notify-form-said", /At most 1 to 60 mails an hour/);
    check("a cap of 99 refused in words", ok && (await read()).settings.cap === 4);
    const headline = () => page.evaluate(() => `${document.getElementById("notify-headline")?.textContent || ""}; `
      + `${document.getElementById("notify-form-said")?.textContent || ""}`);
    await page.locator("#notify-paused").check();
    ok = await saidIn(page, "notify-headline", /Paused/);
    let keptNow = (await read()).settings;
    check(`Pause all: kept, and the headline says so ("${await headline()}", paused ${keptNow?.paused})`, ok && keptNow?.paused === true);
    await page.locator("#notify-paused").uncheck();
    ok = await saidIn(page, "notify-headline", /Mailing/);
    keptNow = (await read()).settings;
    check(`...and off again ("${await headline()}", paused ${keptNow?.paused})`, ok && keptNow?.paused === false);
    // Two changes in flight, answered out of order (onfix: a field left by
    // the press on Pause all saved again, and its late answer drew the
    // settings from before the pause): what was written last is shown.
    let release = () => {};
    const held = new Promise((resolve) => { release = resolve; });
    const setOp = /\/api\/admin\?(?:.*&)?op=notify_set(?:&|$)/;
    await page.route(setOp, async (route) => {
      if ("cap" in (route.request().postDataJSON?.() || {})) {
        const answer = await route.fetch();
        await held;
        return route.fulfill({ response: answer });
      }
      return route.continue();
    });
    await page.fill("#notify-cap", "5");
    await page.locator("#notify-cap").dispatchEvent("change");
    await page.locator("#notify-paused").check();
    const pausedFirst = await saidIn(page, "notify-headline", /Paused/);
    release();
    await page.waitForTimeout(1500);
    keptNow = (await read()).settings;
    check(`two changes answered out of order: the later one still shown ("${await headline()}", paused ${keptNow?.paused}, cap `
      + `${keptNow?.cap})`, pausedFirst && /Paused/.test(await headline()) && await page.locator("#notify-paused").isChecked()
      && keptNow?.paused === true && keptNow?.cap === 5);
    await page.unroute(setOp);
    await page.locator("#notify-paused").uncheck();
    await saidIn(page, "notify-headline", /Mailing/);

    // --- 4. Tests, and a mail's own off link ---------------------------------------------------
    console.log("4. Send a test, and its off link");
    await page.locator("#notify-test").click();
    ok = await saidIn(page, "notify-acted", /“A test from Brickworks' notifications”, to de•••@resend\.dev/);
    check(`Send a test: "${(await page.textContent("#notify-acted")).slice(0, 120)}"`, ok);
    await row("feedback").getByRole("button", { name: "Send a test of “A bug report or feedback”" }).click();
    ok = await saidIn(page, "notify-said-feedback", /\[Test\] Bug report/);
    check(`a kind's test: "${(await page.textContent("#notify-said-feedback")).slice(0, 120)}"`, ok);
    const kept = await fetch(`${site}/__held/owner_notify_mails`, { headers }).then((reply) => (reply.ok ? reply.json() : null), () => null);
    if (Array.isArray(kept)) {
      const mail = kept.filter((one) => one.kind === "test" && one.event === "feedback").at(-1);
      const link = /(\/admin\?tests=1#notifications\/off\/feedback\/t\/[0-9a-f]{32})/.exec(mail?.body || "")?.[1];
      check("the test mail carries its own one-click off link", Boolean(link));
      if (link) {
        const stranger2 = await open(link.replace(/^https?:\/\/[^/]+/, ""), { label: "off link" });
        const turned = await until(stranger2.page, () => /mails are off/.test(document.body.textContent || ""), null, 30000);
        const at = stranger2.page.url();
        check(`opened signed out: "${turned ? "“A bug report or feedback” mails are off" : "nothing said"}", the key gone from the address`,
          turned && !/[0-9a-f]{32}/.test(at) && /#notifications\/settings$/.test(at));
        await shot(stranger2.page, "4-off-link-signed-out.png");
        await stranger2.context.close();
        check("...and that kind is off", (await read()).settings.events.feedback.on === false);
        await page.reload({ waitUntil: "load" });
        await shown(page);
        await until(page, () => document.querySelectorAll("#notify-events > li").length === 8);
        await page.locator("#notify-on-feedback").check();
        await saidIn(page, "notify-said-feedback", /A bug report or feedback: on\./);
      }
    } else {
      console.log("        (its tables are the project's here: the off link is proven by tests/test_owner_notify.py)");
    }

    // --- 5. Another address --------------------------------------------------------------
    console.log("5. Another address");
    const codes = async () => ((await read()).mails || []).filter((one) => one.kind === "confirm").length;
    const codesBefore = await codes();
    await page.locator("#notify-other").click();
    // As a person does: the address typed into the focused field, a zero-width space pasted with it, and Enter.
    await page.locator("#notify-new-address").focus();
    await page.keyboard.type(`${address("notes")}\u200B`);
    await page.keyboard.press("Enter");
    ok = await saidIn(page, "notify-address-said", /A code went to de•••@resend\.dev/);
    await page.waitForTimeout(1500);
    const codesSent = (await codes()) - codesBefore;
    check(`Enter in the address: one code sent (${codesSent}), mail staying where it was`, ok && codesSent === 1
      && !(await page.isHidden("#notify-confirm")) && (await read()).address.pending === "de•••@resend.dev"
      && await page.evaluate(() => document.activeElement?.id) === "notify-code");
    await page.keyboard.type("000000");
    await page.keyboard.press("Enter");
    ok = await saidIn(page, "notify-address-said", /That is not the code\./);
    check("a wrong code refused in words", ok && (await read()).address.own === true);
    await page.locator("#notify-own").click();
    ok = await saidIn(page, "notify-address-said", /your account's own/);
    const after = await read();
    check("back to the account's own: the code dropped", ok && after.address.own === true && after.address.pending === null
      && await page.isHidden("#notify-confirm"));

    // --- 6. Check now, Sent and Read it ----------------------------------------------------
    console.log("6. Check now, and Sent");
    await page.locator("#notify-flush").click();
    ok = await saidIn(page, "notify-acted", /Nothing to mail now|mails?:/);
    check(`Check now: "${(await page.textContent("#notify-acted")).slice(0, 120)}"`, ok);
    await go(page, "notifications/sent");
    ok = await until(page, () => [...document.querySelectorAll("#notify-sent tr")].filter((one) => /Mailed/.test(one.textContent)).length >= 2);
    check("Sent lists the two tests mailed", ok);
    await page.locator("#notify-sent").getByRole("button", { name: "Read it" }).first().click();
    ok = await until(page, () => !document.getElementById("notify-mail").hidden && /notifications/.test(document.getElementById("notify-mail-body").textContent));
    check(`Read it shows the mail's words: "${(await page.textContent("#notify-mail-subject")).slice(0, 80)}"`, ok);
    await owned.context.close();

    // --- 7. Each tab at 1280 and 430, light and dark ----------------------------------------------
    console.log("7. Each tab at 1280 and 430, light and dark");
    for (const width of [1280, 430]) {
      for (const theme of ["light", "dark"]) {
        const where = await open("/admin?tests=1#notifications/settings", { width, theme, who: owner, label: `${width} ${theme}` });
        await shown(where.page);
        await until(where.page, () => document.querySelectorAll("#notify-events > li").length === 8);
        let wide = await sideways(where.page);
        if (width === 430 && theme === "light") {
          // A press on a phone says what it did where it was pressed, the list being taller than the screen.
          const box = where.page.locator("#notify-on-first_model");
          await box.scrollIntoViewIfNeeded();
          await box.tap();
          const said = await saidIn(where.page, "notify-said-first_model", /A first model published: off\./);
          const seen = await where.page.evaluate(() => {
            const at = document.getElementById("notify-said-first_model").getBoundingClientRect();
            return at.top >= 0 && at.bottom <= innerHeight;
          });
          check("at 430: a tap on a kind's switch says so on its row, in view", said && seen);
          await box.tap();
          await saidIn(where.page, "notify-said-first_model", /A first model published: on\./);
        }
        await shot(where.page, `7-settings-${width}-${theme}.png`);
        await go(where.page, "notifications/sent");
        await until(where.page, () => document.querySelectorAll("#notify-sent tr").length >= 1);
        wide ||= await sideways(where.page);
        const off = await where.page.evaluate(() => [...document.querySelectorAll("#notify-sent td.acts button")]
          .filter((one) => one.offsetParent && one.getBoundingClientRect().right > innerWidth + 1).length);
        wide ||= off > 0;
        await shot(where.page, `7-sent-${width}-${theme}.png`);
        check(`at ${width} ${theme}: both tabs drawn, none wider than the screen, every row's act on it`, !wide);
        await where.context.close();
      }
    }
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
  if (owner && settingsAtStart) {
    // The checks' pool put back as it was found.
    const { tz, quiet, digest_at: digestAt, cap, paused, events } = settingsAtStart;
    await api("/api/admin?op=notify_set&tests=1", { method: "POST", token: owner.access_token,
      body: { tz, quiet, digest_at: digestAt, cap, paused, events } });
  }
  let gone = 0;
  for (const email of made) if (await deleteAccount(email).catch(() => false)) gone += 1;
  check(`the throwaway deleted (${gone} of ${made.length})`, gone === made.length);
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`ownernotify: ${passed} ok, ${failed} failed`);
const before = failed === 0 && !settingsAtStart;
console.log(failed === 0 ? `ownernotify: all ok${before ? " (before the file)" : ""}` : "ownernotify: FAILED");
process.exit(failed === 0 ? 0 : 1);
