// Paying for Pro for real in Admission's test mode and Stripe's sandbox
// (docs/PLANS.md 8.1, golive 2026-11-03), in a real browser at 1280 px:
//
//   tools/deploy.sh --unit --billing-test
//   node --env-file=.env tools/web/billing_real_test.mjs --url=<that preview> --out=DIR [--email=X] [--stage=S]
//
// The preview is reached with Vercel's bypass cookie, set for its own host
// alone, so the bypass is never sent to Stripe. A throwaway account at a
// Resend test address (--email to name one, so later stages find it again):
//
//   buy     /plans says Pro is for sale, Upgrade to Pro, the step before
//           Checkout ticked for the month, Stripe's real Checkout paid with
//           the test card 4242 4242 4242 4242, back on /settings as Pro,
//           what it includes and Cancel Pro shown; /plans then says
//           "You have Pro"; 26 models kept with the account, the 26th too.
//   cancel  Cancel Pro, Stripe's cancel step confirmed: two clicks; back on
//           /settings, "Pro until" the period's end.
//   free    once Admission has the account on Free (the subscription over):
//           Free, 25 kept at most, every model kept still listed and read,
//           one of them saved again, a new one refused with the way to Pro.
//
// Pictures of each step in --out. No account is deleted: a later stage
// needs it, and Admission's records of it are the proof (audit_log,
// webhook_deliveries). It passes when it ends "billing real: all ok".
import { launch } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { gzipSync } from "node:zlib";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("billing_real_test: --url=<a --billing-test preview>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = String(args.out || "shots/billing_real");
const stages = String(args.stage || "buy,cancel").split(",");
const email = String(args.email || `delivered+bw-real-${randomBytes(4).toString("hex")}@resend.dev`);
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
mkdirSync(out, { recursive: true });

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const pause = (ms) => new Promise((done) => setTimeout(done, ms));

const who = await mintSession(email);
console.log(`account ${who.kept.user_id} (${email})`);
writeFileSync(path.join(out, "account.json"), JSON.stringify({ email, id: who.kept.user_id }, null, 1));

/// [route] of the API as the signed-in account, through the bypass header
/// (a request from here to the preview alone).
async function api(route, { method = "GET", body } = {}) {
  const r = await fetch(`${site}${route}`, { method, headers: { authorization: `Bearer ${who.access_token}`,
    ...(body ? { "content-type": "application/json" } : {}), ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}) },
    body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, json: await r.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, colorScheme: "light" });
await context.addInitScript(([key, value]) => {
  try {
    if (!localStorage.getItem(key)) localStorage.setItem(key, value);
  } catch { /* a browser that keeps nothing */ }
}, [STORAGE_KEY, JSON.stringify(who.kept)]);
const page = await context.newPage();
const errors = [];
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
let n = 0;
const shot = async (name, full = false) => {
  n += 1;
  await page.screenshot({ path: path.join(out, `${String(n).padStart(2, "0")}-${name}.png`), fullPage: full });
};
// The bypass as a cookie of the preview's own host.
if (bypass) {
  await page.goto(`${site}/?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=samesitenone`, { waitUntil: "load" });
}
const planSaid = () => page.evaluate(() => {
  const row = document.getElementById("plan");
  return row ? { state: row.dataset.plan, words: row.innerText.replace(/\s+/g, " ").trim(),
    buttons: [...row.querySelectorAll("button")].map((b) => b.textContent.trim()),
    licence: row.querySelector(".included a")?.getAttribute("href") || null } : null;
});
async function settled(ms = 60000) {
  await page.waitForFunction(() => document.documentElement.dataset.settings === "ready", null, { timeout: ms });
}

/// Fills Stripe's Checkout with the test card and pays.
async function payOnStripe() {
  await page.waitForLoadState("domcontentloaded");
  await pause(4000);
  await shot("stripe-checkout", true);
  const said = (await page.locator("body").innerText()).replace(/\s+/g, " ");
  check(`Stripe's Checkout says the price and who sells it: ${said.match(/\$8\.00[^.]{0,40}/)?.[0] || said.slice(0, 120)}`,
    /\$8\.00/.test(said));
  console.log(`    sold through Link on the page: ${/Link/.test(said)}`);
  const emailField = page.locator("input#email");
  if (await emailField.isVisible().catch(() => false) && !(await emailField.inputValue())) await emailField.fill(email);
  const card = page.locator("input#cardNumber");
  if (!(await card.isVisible().catch(() => false))) {
    const accordion = page.locator('[data-testid="card-accordion-item-button"], button:has-text("Card")').first();
    if (await accordion.isVisible().catch(() => false)) await accordion.click();
  }
  await card.waitFor({ state: "visible", timeout: 30000 });
  await card.fill("4242424242424242");
  await page.locator("input#cardExpiry").fill("12 / 34");
  await page.locator("input#cardCvc").fill("123");
  const name = page.locator("input#billingName");
  if (await name.isVisible().catch(() => false)) await name.fill("Brickworks Test");
  const country = page.locator("select#billingCountry");
  if (await country.isVisible().catch(() => false)) await country.selectOption("US");
  const zip = page.locator("input#billingPostalCode");
  if (await zip.isVisible().catch(() => false)) await zip.fill("99501");
  // Link's own "save my information": not asked of a throwaway.
  const save = page.locator("input#enableStripePass");
  if (await save.isChecked().catch(() => false)) await save.uncheck().catch(() => {});
  await shot("stripe-filled", true);
  await page.locator('button[type="submit"], [data-testid="hosted-payment-submit-button"]').first().click();
}

try {
  if (stages.includes("buy")) {
    console.log("buy: /plans, the step before Checkout, Stripe's Checkout, back as Pro");
    await page.goto(`${site}/plans`, { waitUntil: "load" });
    await page.waitForFunction(() => document.documentElement.dataset.plans === "sale", null, { timeout: 30000 })
      .catch(() => null);
    check("/plans: Pro for sale (data-plans=sale)", await page.evaluate(() => document.documentElement.dataset.plans === "sale"));
    await shot("plans-for-sale");
    await page.click("[data-billing='month']");
    await Promise.all([page.waitForURL(/\/settings/, { timeout: 30000 }), page.click("#pro-upgrade")]);
    await page.waitForSelector("dialog#upgrade[open]", { timeout: 60000 });
    const terms = (await page.locator("#upgrade .terms").innerText()).replace(/\s+/g, " ");
    check(`the step says the price and renewal: ${terms.slice(0, 100)}`,
      /\$8\.00 USD a month/.test(terms) && /renews automatically/.test(terms) && /Cancel any time/.test(terms));
    check("Continue is off until the box is ticked", await page.locator("#upgrade button[type=submit]").isDisabled());
    await page.check("#upgrade-agree");
    await shot("consent-ticked");
    await Promise.all([page.waitForURL(/checkout\.stripe\.com/, { timeout: 60000 }),
      page.click("#upgrade button[type=submit]")]);
    check(`on to Stripe's Checkout: ${page.url().slice(0, 60)}`, /^https:\/\/checkout\.stripe\.com\/c\/pay\/cs_test_/.test(page.url()));
    await payOnStripe();
    await page.waitForURL(new RegExp(`^${site.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/settings`), { timeout: 120000 });
    await settled();
    const began = Date.now();
    let plan = await planSaid();
    while (plan?.state !== "pro" && Date.now() - began < 180000) {
      await pause(2500);
      plan = await planSaid();
    }
    console.log(`    Pro shown after ${Math.round((Date.now() - began) / 1000)} s back on the site`);
    check(`back on /settings as Pro: "${plan?.words.slice(0, 90)}"`, plan?.state === "pro" && /Pro, \$8\.00 USD a month\. Renews/.test(plan.words));
    check(`what Pro includes, the licence linked (${plan?.licence})`,
      /Included: any number of models kept with your account, and a licence for commercial use\./.test(plan?.words || "")
      && plan?.licence === "/terms#commercial-use");
    check(`Manage billing and Cancel Pro: ${plan?.buttons.join(", ")}`, plan?.buttons.join() === "Manage billing,Cancel Pro");
    await page.locator("#plan").scrollIntoViewIfNeeded();
    await shot("settings-pro");
    const mine = await api("/api/plans?op=plan&fresh=1");
    check(`?op=plan: ${mine.json?.plan?.key} by ${mine.json?.plan?.source}, ${mine.json?.subscription?.status}, commercialUse ${mine.json?.commercialUse}, limit ${mine.json?.savedModels?.limit}`,
      mine.json?.plan?.key === "pro" && mine.json?.plan?.source === "subscription" && mine.json?.commercialUse === true
      && mine.json?.savedModels?.limit === null);
    await page.goto(`${site}/plans`, { waitUntil: "load" });
    await page.waitForFunction(() => document.getElementById("pro-upgrade")?.dataset.has === "pro", null, { timeout: 30000 })
      .catch(() => null);
    const button = await page.evaluate(() => ({ words: document.getElementById("pro-upgrade")?.textContent,
      href: document.getElementById("pro-upgrade")?.getAttribute("href") }));
    check(`/plans for a Pro account: "${button.words}" to ${button.href}`, button.words === "You have Pro: your plan" && button.href === "/settings#plan");
    await shot("plans-has-pro");
    // 26 models kept with the account: the 26th is past Free's 25.
    const statuses = [];
    for (let i = 1; i <= 26; i += 1) {
      const ldr = `0 golive model ${i}\n0 Name: golive-${i}.ldr\n1 4 0 ${-24 * i} 0 1 0 0 0 1 0 0 0 1 3001.dat\n`;
      const r = await api("/api/models", { method: "POST", body: { name: `golive ${String(i).padStart(2, "0")}`, base: 0,
        model: gzipSync(Buffer.from(ldr)).toString("base64") } });
      statuses.push(r.status);
    }
    const kept = await api("/api/models");
    check(`26 models saved on Pro (${[...new Set(statuses)].join(",")}), ${kept.json?.models?.length} kept`,
      statuses.every((s) => s === 200) && kept.json?.models?.length === 26);
  }

  if (stages.includes("cancel")) {
    console.log("cancel: Cancel Pro, Stripe's confirm, Pro until the period's end");
    await page.goto(`${site}/settings#plan`, { waitUntil: "load" });
    await settled();
    await Promise.all([page.waitForURL(/billing\.stripe\.com/, { timeout: 60000 }),
      page.click("#plan button:has-text('Cancel Pro')")]);
    await page.waitForLoadState("domcontentloaded");
    await pause(4000);
    await shot("stripe-cancel-step", true);
    const confirm = page.locator('button:has-text("Cancel subscription"), button:has-text("Cancel plan"), [data-testid="confirm"]').first();
    await confirm.waitFor({ state: "visible", timeout: 30000 });
    await confirm.click();
    await pause(5000);
    await shot("stripe-cancelled", true);
    const back = page.locator('a:has-text("Return to"), a:has-text("Brickworks"), button:has-text("Return to")').first();
    if (await back.isVisible().catch(() => false)) {
      await Promise.all([page.waitForURL(/\/settings/, { timeout: 60000 }).catch(() => null), back.click()]);
    } else {
      await page.goto(`${site}/settings?billing=portal#plan`, { waitUntil: "load" });
    }
    await settled();
    const began = Date.now();
    let plan = await planSaid();
    while (plan?.state !== "ending" && Date.now() - began < 120000) {
      await pause(3000);
      await page.goto(`${site}/settings?billing=portal#plan`, { waitUntil: "load" });
      await settled();
      plan = await planSaid();
    }
    check(`"${plan?.words.slice(0, 120)}"`, plan?.state === "ending" && /Pro until \d+ \w+ \d{4}\./.test(plan.words));
    await page.locator("#plan").scrollIntoViewIfNeeded();
    await shot("settings-pro-until");
  }

  if (stages.includes("free")) {
    console.log("free: the subscription over, Free, nothing lost");
    const mine = await api("/api/plans?op=plan&fresh=1");
    check(`?op=plan: ${mine.json?.plan?.key}, limit ${mine.json?.savedModels?.limit}, kept ${mine.json?.savedModels?.kept}`,
      mine.json?.plan?.key === "free" && mine.json?.savedModels?.limit === 25 && mine.json?.savedModels?.kept >= 26);
    await page.goto(`${site}/settings#plan`, { waitUntil: "load" });
    await settled();
    const plan = await planSaid();
    check(`/settings: "${plan?.words.slice(0, 100)}"`, plan?.state === "free" && /Free\. Up to 25 models kept/.test(plan.words));
    await page.locator("#plan").scrollIntoViewIfNeeded();
    await shot("settings-free-after");
    const kept = await api("/api/models");
    const names = (kept.json?.models || []).map((m) => m.name);
    check(`every model still kept: ${names.length}`, names.length >= 26);
    const read = await api(`/api/models?name=${encodeURIComponent("golive 26")}`);
    check(`the 26th read back: ${read.status}, ${read.json?.parts} part`, read.status === 200 && typeof read.json?.model === "string");
    const again = await api("/api/models", { method: "POST", body: { name: "golive 26", base: read.json?.version ?? 0,
      model: gzipSync(Buffer.from("0 golive model 26, changed\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat\n")).toString("base64") } });
    check(`one kept saved again over the cap: ${again.status} v${again.json?.version}`, again.status === 200);
    const more = await api("/api/models", { method: "POST", body: { name: "golive 27", base: 0,
      model: gzipSync(Buffer.from("0 golive model 27\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")).toString("base64") } });
    check(`a new one refused with the way to Pro: ${more.status} ${more.json?.full} ${more.json?.pro}`,
      more.status === 413 && more.json?.full === "plan" && more.json?.pro === "/plans");
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble?.message || trouble).split("\n")[0].slice(0, 300)}`);
  await shot("trouble", true).catch(() => {});
} finally {
  if (errors.length) console.log(`  page errors: ${errors.slice(0, 5).join(" | ")}`);
  await browser.close();
}
console.log(failed ? `billing real: ${failed} FAILED` : "billing real: all ok");
process.exit(failed ? 1 : 0);
