// Paying for Pro, as a person meets it (docs/PLANS.md U3 and M7), in a real
// browser at 390 and 1280 px, light and dark, against a site and its live
// sign-in, with the stand-in Admission (tests/fixtures/billing/):
//
//   node tools/web/admission_stand_in.mjs 8891 --hook=http://127.0.0.1:8890/api/plans?op=webhook &
//   BRICKWORKS_BILLING=test ADMISSION_KEY=adm_test_00000000000000000000000000000000 \
//     ADMISSION_URL=http://127.0.0.1:8891 ADMISSION_WEBHOOK_SECRET=adm_whsec_standin0000000000000000000000 \
//     node --env-file=.env tools/web/relay_server.mjs 8890 --hold=plan_consents &
//   node --env-file=.env tools/web/billing_flow.mjs --url=http://127.0.0.1:8890 --stand-in=http://127.0.0.1:8891 --out=DIR
//
//   tools/deploy.sh --unit --billing-stand-in                     a preview with the stand-in in its functions
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/billing_flow.mjs --url=<that preview> --out=DIR
//
// A deployment with billing off (every release preview, and production
// until plans go live) is checked for that: signed in, /settings has no
// plan and asks nothing of plans, /api/people?op=me says nothing of
// billing, and each POST of paying is the interest form's, refused as it
// always was. With billing on, a throwaway account at a Resend test
// address, closed at the end whatever happened:
//
//   1. The API: Checkout refused without the renewal terms agreed, the
//      portal refused to an account that never paid, Admission's webhook
//      refused unsigned and heard signed.
//   2. /settings: the Plan row, Free, with Upgrade to Pro; axe finds
//      nothing serious in it.
//   3. The step before Checkout: what Pro adds, Yearly first, the terms
//      (price, renewal, cancel any time, who sells it), the box unticked
//      and Continue to checkout off until it is ticked; another interval
//      unticks it. Monthly, ticked, goes on to Stripe's Checkout (a page
//      stubbed here: checkout.stripe.test), for the month.
//   4. Back with Checkout closed: still Free, and said so.
//   5. At 390 px dark, ?upgrade=year opens the step on Yearly, nothing
//      sideways, and on to Checkout for the year.
//   6. With --stand-in (this machine's, which can be paid): paid, and the
//      webhook heard, the page says Pro and renews, Manage billing goes to
//      Stripe's portal; cancelled there, "Pro until".
//   7. With --stand-in: paid again, renewing, and the account deleted from
//      /settings. Its delete form, at 390 dark and 1280 light, and the
//      question before it, say Pro ends now with nothing charged again
//      (Free's said nothing of it, in 2); deleted, the page says Pro has
//      ended, the stand-in erased the customer and ended the subscription,
//      and the sign-in service has no such account.
//
// Pictures in --out. It passes when it ends "billing: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { signWebhook } from "../../tests/fixtures/billing/fake_admission.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("billing_flow: --url=<a relay or a deployment>");
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const standIn = args["stand-in"] ? String(args["stand-in"]).replace(/\/+$/, "") : "";
const out = args.out || "shots/billing";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const AXE = readFileSync(path.join(here, "axe-core", "axe.min.js"), "utf8");
const rand = randomBytes(4).toString("hex");
const email = `delivered+bw-pay-${rand}@resend.dev`;
const NOT_AN_ADDRESS = "That is not an email address.";

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
// A dialog fades in (docs/DESIGN_SYSTEM.md, Motion): pictured and judged once it has.
const settled = (page) => until(page, () => document.getAnimations().every((a) => a.playState !== "running"), null, 5000);
const shot = async (page, name, full = false) => {
  await settled(page);
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

async function api(pathname, { method = "GET", token, body, raw, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined || raw !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: raw ?? (body === undefined ? undefined : JSON.stringify(body)) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// axe's serious or critical findings inside [scope].
async function axe(page, scope) {
  await page.mouse.move(0, 0);
  await settled(page);
  if (!(await page.evaluate(() => Boolean(window.axe)))) await page.evaluate(AXE);
  return page.evaluate(async (inside) => {
    const said = await window.axe.run({ include: [inside] }, { runOnly: { type: "tag",
      values: ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"] }, resultTypes: ["violations"] });
    return said.violations.filter((one) => one.impact === "serious" || one.impact === "critical")
      .map((one) => `${one.id}: ${one.nodes.map((n) => n.target.join(" ")).join(", ")}`);
  }, scope);
}

/// Whether the sign-in service has an account at [address].
async function accountExists(address) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const listed = await (await fetch(`${base}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` } })).json();
  return (listed.users || []).some((u) => (u.email || "").toLowerCase() === address.toLowerCase());
}

const browser = await launch({ signedOut: true });
const stripe = [];

/// /settings (or [pathname]) at [width] in [theme], signed in as [who].
async function open(pathname, { width, theme, who, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  const access = JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000, email: who.kept.email });
  await context.addInitScript(([key, value, token]) => {
    try {
      if (!localStorage.getItem(key)) {
        localStorage.setItem(key, value);
        sessionStorage.setItem("brickworks.access", token);
      }
    } catch { /* a browser that keeps nothing */ }
  }, [STORAGE_KEY, JSON.stringify(who.kept), access]);
  // Stripe's pages, stubbed: where the page was sent is what is checked.
  for (const host of ["checkout.stripe.test", "billing.stripe.test"]) {
    await context.route(`https://${host}/**`, (route) => {
      stripe.push(route.request().url());
      return route.fulfill({ status: 200, contentType: "text/html",
        body: `<!doctype html><title>${host} (stubbed)</title><h1>Stripe, stubbed by billing_flow</h1>` });
    });
  }
  const page = await context.newPage();
  const asked = [];
  page.on("request", (r) => asked.push(new URL(r.url()).pathname + new URL(r.url()).search));
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  await page.goto(site + pathname, { waitUntil: "load", timeout: 60000 });
  await until(page, () => document.documentElement.dataset.settings === "ready", null, 40000);
  return { page, context, asked };
}

/// The delete form opened: what it says of the plan, and whether the page
/// went sideways. The words come with the form's toggle event, a moment
/// after the click: waited for, two seconds at most, since Free's has none.
async function deleteSaid(page) {
  await page.click("#delete-part summary");
  await until(page, () => document.getElementById("delete-plan"), null, 2000);
  return page.evaluate(() => ({ plan: document.getElementById("delete-plan")?.textContent.replace(/\s+/g, " ").trim()
    || null, sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }));
}

const planSaid = (page) => page.evaluate(() => {
  const row = document.getElementById("plan");
  return row ? { state: row.dataset.plan, words: row.innerText.replace(/\s+/g, " ").trim(),
    buttons: [...row.querySelectorAll("button")].map((b) => b.textContent.trim()) } : null;
});
const stepSaid = (page) => page.evaluate(() => {
  const d = document.getElementById("upgrade");
  if (!d || !d.open) return null;
  return {
    title: d.querySelector("h2")?.textContent,
    words: d.innerText.replace(/\s+/g, " ").trim(),
    terms: d.querySelector(".terms")?.textContent.replace(/\s+/g, " ").trim() || "",
    pressed: [...d.querySelectorAll(".segmented button")].filter((b) => b.getAttribute("aria-pressed") === "true")
      .map((b) => b.textContent.trim()),
    ticked: d.querySelector("#upgrade-agree").checked,
    go: !d.querySelector("button[type=submit]").disabled,
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
  };
});

/// Where Continue to checkout went: Stripe's address, or what the step said instead.
const whereTo = (page) => (/stripe\.test/.test(page.url()) ? page.url()
  : page.evaluate(() => `stayed, saying "${document.querySelector("#upgrade .said")?.textContent || ""}"`).catch(() => page.url()));

let who = null;
// Deleted from /settings (7), so not closed again at the end.
let closed = false;
try {
  const offered = await api("/api/plans");
  const on = offered.status === 200 && offered.json?.billing && offered.json.billing !== "off";
  console.log(`billing flow: ${site} (billing ${on ? offered.json.billing : "off"})`);
  who = await mintSession(email);

  if (!on) {
    console.log("Billing off: nothing of paying answers");
    check(`GET /api/plans refused as before: ${offered.status}`, offered.status === 405);
    const me = await api("/api/people?op=me", { token: who.access_token });
    check(`op=me says nothing of billing: ${me.status}`, me.status === 200 && !("billing" in (me.json || {})));
    for (const op of ["checkout", "portal", "webhook"]) {
      const r = await api(`/api/plans?op=${op}`, { method: "POST", token: who.access_token,
        body: { interval: "month", consent: true } });
      check(`POST ?op=${op} is the interest form's: ${r.status} ${r.json?.error}`, r.status === 422 && r.json?.error === NOT_AN_ADDRESS);
    }
    const { page, context, asked } = await open("/settings", { width: 1280, theme: "light", who, label: "off" });
    check("/settings drawn, with no Plan row", (await planSaid(page)) === null);
    await page.waitForTimeout(1500);
    check(`/settings asked nothing of plans: ${asked.filter((p) => /plan/.test(p)).join(" ") || "nothing"}`,
      !asked.some((p) => p.startsWith("/api/plans") || p === "/plan.js"));
    await shot(page, "settings-off-1280-light.png", true);
    await context.close();
  } else {
    // --- 1. The API --------------------------------------------------------
    console.log("1. The API: agreement, portal, webhook");
    let r = await api("/api/plans?op=checkout", { method: "POST", token: who.access_token, body: { interval: "month" } });
    check(`Checkout without the terms agreed: ${r.status} ${r.json?.error}`, r.status === 422 && /Tick the box/.test(r.json?.error || ""));
    r = await api("/api/plans?op=portal", { method: "POST", token: who.access_token, body: {} });
    check(`the portal for an account that never paid: ${r.status} ${r.json?.error}`, r.status === 409 && /never paid/.test(r.json?.error || ""));
    r = await api("/api/plans?op=checkout", { method: "POST", body: { interval: "month", consent: true } });
    check(`Checkout signed out: ${r.status}`, r.status === 401);
    const event = JSON.stringify({ id: `adm_evt_flow_${rand}`, type: "customer.updated", createdAt: new Date().toISOString(),
      mode: "test", seq: 1, data: { customerId: who.kept.user_id, reason: "usage.set", customer: null } });
    r = await api("/api/plans?op=webhook", { method: "POST", raw: event });
    check(`a webhook nobody signed: ${r.status}`, r.status === 400);
    r = await api("/api/plans?op=webhook", { method: "POST", raw: event,
      extra: { "admission-signature": await signWebhook(event, "adm_whsec_notadmissionsatall000000000000") } });
    check(`a webhook signed with another secret: ${r.status}`, r.status === 400);
    r = await api("/api/plans?op=webhook", { method: "POST", raw: event, extra: { "admission-signature": await signWebhook(event) } });
    check(`a webhook Admission signed, its bytes as sent: ${r.status} ${JSON.stringify(r.json)}`,
      r.status === 200 && r.json?.heard === "customer.updated");

    // --- 2. /settings, Free ---------------------------------------------------
    console.log("2. /settings: the Plan row, Free");
    let { page, context } = await open("/settings", { width: 1280, theme: "light", who, label: "1280 light" });
    let plan = await planSaid(page);
    check(`Plan row: ${plan?.state} "${plan?.words.slice(0, 90)}"`, plan?.state === "free" && /^Plan Free\./.test(plan.words));
    check(`Upgrade to Pro offered: ${plan?.buttons.join(", ")}`, plan?.buttons.includes("Upgrade to Pro"));
    let found = await axe(page, "#plan");
    check(`axe in the Plan row: ${found.join("; ") || "nothing serious"}`, found.length === 0);
    await page.locator("#plan").scrollIntoViewIfNeeded();
    await shot(page, "settings-plan-1280-light.png");
    const free = await deleteSaid(page);
    check(`Free: the delete form says nothing of a plan: ${free.plan}`, free.plan === null);

    // --- 3. The step before Checkout -----------------------------------------
    console.log("3. The step before Checkout");
    await page.click("#upgrade-go");
    await until(page, () => document.getElementById("upgrade")?.open);
    let step = await stepSaid(page);
    check(`opened: "${step?.title}", ${step?.pressed.join("")} first`, step?.title === "Upgrade to Pro" && step.pressed.join() === "Yearly");
    check("what Pro adds: any number of models kept with the account, Free's 25, and the desktop app",
      /any number of models kept with your account \(Free keeps 25\)/.test(step?.words || "")
      && /the desktop app for Windows, macOS and Linux/.test(step?.words || "") && !/build|undefined/i.test(step?.words || ""));
    check(`the terms: "${step?.terms.slice(0, 120)}…"`, /^\$80\.00 USD a year, plus any tax/.test(step?.terms || "")
      && /renews automatically at \$80\.00 USD a year until you cancel/.test(step.terms) && /Cancel any time/.test(step.terms)
      && /Sold through Link/.test(step.terms));
    check("the box unticked, and Continue to checkout off", step && !step.ticked && !step.go);
    found = await axe(page, "#upgrade");
    check(`axe in the step: ${found.join("; ") || "nothing serious"}`, found.length === 0);
    await shot(page, "consent-1280-light.png");
    await page.click("#upgrade .segmented button[data-interval=month]");
    await page.click("#upgrade label.choice");
    step = await stepSaid(page);
    check(`Monthly, ticked: "${step?.terms.slice(0, 40)}", Continue on`, /^\$8\.00 USD a month/.test(step?.terms || "") && step.ticked && step.go);
    await page.click("#upgrade .segmented button[data-interval=year]");
    step = await stepSaid(page);
    check("another price unticks the box, and Continue is off again", step && !step.ticked && !step.go);
    await page.click("#upgrade .segmented button[data-interval=month]");
    await page.click("#upgrade label.choice");
    await Promise.all([page.waitForURL(/checkout\.stripe\.test/, { timeout: 30000 }).catch(() => null),
      page.click("#upgrade button[type=submit]")]);
    check(`on to Stripe's Checkout for the month: ${await whereTo(page)}`, /^https:\/\/checkout\.stripe\.test\/c\/pay\/cs_test_\d+#month$/.test(page.url()));

    // --- 4. Back, Checkout closed ---------------------------------------------
    console.log("4. Back with Checkout closed");
    await page.goto(`${site}/settings?billing=cancelled#plan`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.settings === "ready", null, 40000);
    plan = await planSaid(page);
    check(`still Free, and said so: "${plan?.words.slice(-90)}"`, plan?.state === "free" && /Checkout closed\. You have not been charged/.test(plan.words));
    check(`the address cleaned: ${new URL(page.url()).pathname}${new URL(page.url()).search}`, !/billing=/.test(page.url()));
    await context.close();

    // --- 5. 390 px, dark, ?upgrade=year --------------------------------------
    console.log("5. At 390 px dark, from ?upgrade=year");
    ({ page, context } = await open("/settings?upgrade=year#plan", { width: 390, theme: "dark", who, label: "390 dark" }));
    await until(page, () => document.getElementById("upgrade")?.open);
    step = await stepSaid(page);
    check(`opened on ${step?.pressed.join("")}, nothing sideways`, step?.pressed.join() === "Yearly" && !step.sideways);
    await shot(page, "consent-390-dark.png");
    await page.click("#upgrade label.choice");
    await Promise.all([page.waitForURL(/checkout\.stripe\.test/, { timeout: 30000 }).catch(() => null),
      page.click("#upgrade button[type=submit]")]);
    check(`on to Checkout for the year: ${await whereTo(page)}`, /^https:\/\/checkout\.stripe\.test\/.*#year$/.test(page.url()));
    await page.goto(`${site}/settings#plan`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.settings === "ready", null, 40000);
    check("/settings at 390 px: nothing sideways", !(await page.evaluate(() => document.documentElement.scrollWidth
      > document.documentElement.clientWidth + 1)));
    await page.locator("#plan").scrollIntoViewIfNeeded();
    await shot(page, "settings-plan-390-dark.png");
    await context.close();

    // --- 6. Paid, on this machine's stand-in -----------------------------------
    if (standIn) {
      console.log("6. Paid, then cancelled, through the stand-in");
      const pay = await (await fetch(`${standIn}/__stand_in/pay`, { method: "POST",
        body: JSON.stringify({ customerId: who.kept.user_id, interval: "year" }) })).json();
      check(`paid, and the site heard Admission: ${JSON.stringify(pay.heard)}`, pay.heard?.status === 200 && pay.heard.heard === "customer.updated");
      ({ page, context } = await open("/settings#plan", { width: 1280, theme: "dark", who, label: "pro" }));
      plan = await planSaid(page);
      check(`Pro, renewing: "${plan?.words.slice(0, 90)}"`, plan?.state === "pro" && /Pro, \$80\.00 USD a year\. Renews/.test(plan.words));
      check(`Manage billing offered: ${plan?.buttons.join(", ")}`, plan?.buttons.join() === "Manage billing");
      await page.locator("#plan").scrollIntoViewIfNeeded();
      await shot(page, "settings-pro-1280-dark.png");
      await Promise.all([page.waitForURL(/billing\.stripe\.test/, { timeout: 30000 }).catch(() => null),
        page.click("#plan button:has-text('Manage billing')")]);
      check(`on to Stripe's billing portal: ${page.url()}`, /^https:\/\/billing\.stripe\.test\/p\/session\//.test(page.url()));
      r = await api("/api/plans?op=checkout", { method: "POST", token: who.access_token, body: { interval: "month", consent: true } });
      check(`Checkout again for one who pays: the portal (${r.json?.kind})`, r.status === 200 && r.json?.kind === "portal");
      const cancel = await (await fetch(`${standIn}/__stand_in/cancel`, { method: "POST",
        body: JSON.stringify({ customerId: who.kept.user_id }) })).json();
      check(`cancelled, and heard: ${cancel.heard?.status}`, cancel.heard?.status === 200);
      await page.goto(`${site}/settings?billing=portal#plan`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.settings === "ready", null, 40000);
      plan = await planSaid(page);
      check(`"${plan?.words.slice(0, 60)}"`, plan?.state === "ending" && /^Plan Pro until \d+ \w+ \d{4}\./.test(plan.words));
      await shot(page, "settings-ending-1280-dark.png");
      await context.close();

      // --- 7. Deleting the account while Pro renews --------------------------
      console.log("7. Deleting the account while Pro renews");
      const again = await (await fetch(`${standIn}/__stand_in/pay`, { method: "POST",
        body: JSON.stringify({ customerId: who.kept.user_id, interval: "month" }) })).json();
      check(`paid again, renewing: ${again.heard?.status}`, again.heard?.status === 200);
      const ENDS = /^Your Pro plan ends now, with the account, and you are not charged again\. Any refund is as the terms of sale say\.$/;
      ({ page, context } = await open("/settings", { width: 390, theme: "dark", who, label: "delete 390 dark" }));
      let form = await deleteSaid(page);
      check(`390 dark: the delete form says "${form.plan}", nothing sideways`, ENDS.test(form.plan || "") && !form.sideways);
      await page.locator("#delete-plan").scrollIntoViewIfNeeded();
      await shot(page, "delete-pro-390-dark.png");
      found = await axe(page, "#delete-part");
      check(`axe in the delete form: ${found.join("; ") || "nothing serious"}`, found.length === 0);
      await context.close();
      ({ page, context } = await open("/settings", { width: 1280, theme: "light", who, label: "delete 1280 light" }));
      plan = await planSaid(page);
      check(`Pro, renewing, before: ${plan?.state}`, plan?.state === "pro");
      form = await deleteSaid(page);
      check(`1280 light: the delete form says "${form.plan?.slice(0, 40)}…"`, ENDS.test(form.plan || ""));
      check("its refund link is the terms of sale", await page.evaluate(() =>
        document.querySelector("#delete-plan a")?.href === "https://atypic.ai/refunds"));
      await page.fill("#delete-confirm", email);
      await shot(page, "delete-pro-1280-light.png");
      let asked = "";
      page.once("dialog", (dialog) => {
        asked = dialog.message();
        dialog.accept();
      });
      await page.click("#delete-go");
      await until(page, () => document.documentElement.dataset.deleted === "yes", null, 40000);
      check(`asked first: "${asked}"`, asked === "Delete this account and everything in it, for good? "
        + "Your Pro plan ends now, with the account, and you are not charged again.");
      const lede = await page.evaluate(() => document.querySelector("#signed-out .lede")?.textContent || "");
      check(`deleted, and said: "${lede.slice(0, 110)}"`, /^Your account is deleted, and everything in it\. Your Pro plan has ended, and you will not be charged again\./.test(lede));
      await shot(page, "deleted-pro-1280-light.png");
      await context.close();
      const erased = await (await fetch(`${standIn}/__stand_in/erased`, { method: "POST",
        body: JSON.stringify({ customerId: who.kept.user_id }) })).json();
      check(`Admission erased them and ended the subscription: ${JSON.stringify(erased.erasures)}`,
        erased.erasures?.length === 1 && erased.erasures[0].canceled.length === 1);
      closed = !(await accountExists(email));
      check("gone from the sign-in service", closed);
    }
  }
  check(`no errors on any page: ${errors.join(" | ") || "none"}`, errors.length === 0);
} catch (trouble) {
  check(`ran to the end: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" ")}`, false);
} finally {
  if (who) check(`the throwaway account closed: ${email}`, closed || await deleteAccount(email));
  await browser.close();
}
console.log(failed ? `billing: ${failed} FAILED, ${passed} ok` : `billing: all ok (${passed} checks)`);
process.exit(failed ? 1 : 0);
