// Paying for Pro for real in Admission's test mode and Stripe's sandbox
// (docs/PLANS.md 8.1, golive 2026-11-03), in a real browser at 1280 px:
//
//   tools/deploy.sh --unit --billing-test
//   node --env-file=.env tools/web/billing_real_test.mjs --url=<that preview> --out=DIR [--email=X] [--stage=S]
//
// The preview is reached with Vercel's bypass cookie, set for its own host
// alone, so the bypass is never sent to Stripe. A throwaway account at a
// Resend test address (--email to name one, so later stages find it again).
// Stages, comma-separated, in this order; a browser only for those marked:
//
//   link    no browser: the account agrees to the monthly terms and is given
//           Stripe's Checkout for them (?op=checkout), its address written
//           to checkout.txt, for a person to pay: Stripe's bot check stops
//           a Checkout a script fills in (Admission's own finding).
//   buy     browser: /plans says Pro is for sale, Upgrade to Pro, the step
//           before Checkout ticked for the month, on to Stripe's real
//           Checkout, which says $8.00, filled with the test card 4242 4242
//           4242 4242 and paid. When Stripe does not send it back (its bot
//           check), its address goes to checkout.txt for a person, and the
//           run stops there, exit 3.
//   paid    browser: back on /settings as Pro, what it includes and Cancel
//           Pro shown; /plans then says "You have Pro"; 26 models kept with
//           the account, the 26th too.
//   save26  no browser: 26 models kept with the account (an account given
//           Pro by an override, to see Free after it).
//   cancel  browser: Cancel Pro, Stripe's why (unanswered) and confirm,
//           every click counted; back on /settings, "Pro until" the period's end.
//   free    browser: once Admission has the account on Free (an override
//           ended, or the subscription over): Free, 25 kept at most, every
//           model kept still listed and read, one of them saved again, a new
//           one refused with the way to Pro.
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
const stages = String(args.stage || "buy,paid,cancel").split(",");
const BROWSER = ["buy", "paid", "cancel", "free"];
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

/// 26 models kept with the account: the 26th is past Free's 25.
async function save26() {
  const statuses = [];
  for (let i = 1; i <= 26; i += 1) {
    const ldr = `0 golive model ${i}\n0 Name: golive-${i}.ldr\n1 4 0 ${-24 * i} 0 1 0 0 0 1 0 0 0 1 3001.dat\n`;
    const r = await api("/api/models", { method: "POST", body: { name: `golive ${String(i).padStart(2, "0")}`, base: 0,
      model: gzipSync(Buffer.from(ldr)).toString("base64") } });
    statuses.push(r.status);
  }
  const kept = await api("/api/models");
  check(`26 models saved (${[...new Set(statuses)].join(",")}), ${kept.json?.models?.length} kept, totals named: ${
    "most_models" in (kept.json?.kept || {})}`, statuses.every((s) => s === 200) && kept.json?.models?.length === 26);
}

if (stages.includes("link")) {
  console.log("link: the monthly terms agreed, Stripe's Checkout for a person to pay");
  const offer = await api("/api/plans");
  const made = await api("/api/plans?op=checkout", { method: "POST",
    body: { interval: "month", consent: true, amount: offer.json?.pro?.prices?.month } });
  check(`?op=checkout: ${made.status} ${made.json?.kind} ${String(made.json?.url || made.json?.error).slice(0, 50)}`,
    made.status === 200 && /^https:\/\/checkout\.stripe\.com\/c\/pay\/cs_test_/.test(made.json?.url || ""));
  if (made.json?.url) writeFileSync(path.join(out, "checkout.txt"), `${made.json.url}\n`);
}
if (stages.includes("save26")) {
  console.log("save26: 26 models kept with the account");
  await save26();
}
if (!stages.some((s) => BROWSER.includes(s))) {
  console.log(failed ? `billing real: ${failed} FAILED` : "billing real: all ok");
  process.exit(failed ? 1 : 0);
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
let handedOver = false;
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
    // Card is one of Stripe's choices: press its row, which is drawn. The
    // row's own button is not (a check for visible never pressed it, and a
    // forced press found it outside the viewport), so it is sent a click.
    const row = page.locator('[data-testid="card-accordion-item"]').first();
    if (await row.isVisible().catch(() => false)) await row.click().catch(() => {});
    if (!(await card.isVisible().catch(() => false))) {
      await page.locator('[data-testid="card-accordion-item-button"]').first().dispatchEvent("click").catch(() => {});
    }
  }
  await card.waitFor({ state: "visible", timeout: 30000 });
  await card.fill("4242424242424242");
  await page.locator("input#cardExpiry").fill("12 / 34");
  await page.locator("input#cardCvc").fill("123");
  const name = page.locator("input#billingName");
  if (await name.isVisible().catch(() => false)) await name.fill("Brickworks Test");
  const country = page.locator("select#billingCountry");
  if (await country.isVisible().catch(() => false)) await country.selectOption("US");
  // Stripe asks the whole billing address of a US card.
  for (const [id, words] of [["billingAddressLine1", "1 Test Street"], ["billingLocality", "Anchorage"],
    ["billingPostalCode", "99501"]]) {
    const field = page.locator(`input#${id}`);
    if (await field.isVisible().catch(() => false)) await field.fill(words);
  }
  // Link's own "save my information": not asked of a throwaway, or Stripe
  // wants a phone number too. Its box is drawn over, so a plain untick fails.
  const save = page.locator("input#enableStripePass");
  if (await save.isChecked().catch(() => false)) await save.setChecked(false, { force: true }).catch(() => {});
  if (await save.isChecked().catch(() => false)) await save.dispatchEvent("click").catch(() => {});
  console.log(`    Link's save box left ticked: ${await save.isChecked().catch(() => false)}`);
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
    const checkoutUrl = page.url();
    const filled = await payOnStripe().then(() => true, (trouble) => {
      console.log(`    Stripe's Checkout could not be filled in: ${String(trouble?.message || trouble).split("\n")[0].slice(0, 160)}`);
      return false;
    });
    const back = filled && await page.waitForURL(new RegExp(`^${site.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}/settings`), { timeout: 120000 })
      .then(() => true, () => false);
    if (!back) {
      await shot("stripe-held", true);
      writeFileSync(path.join(out, "checkout.txt"), `${checkoutUrl}\n`);
      console.log(`    Stripe did not send it back (its bot check?): a person pays ${path.join(out, "checkout.txt")}`);
      handedOver = true;
    }
  }

  if (stages.includes("paid") && !handedOver) {
    console.log("paid: back on /settings as Pro, /plans says so, 26 models kept");
    await page.goto(`${site}/settings?billing=done#plan`, { waitUntil: "load" });
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
    await save26();
  }

  if (stages.includes("cancel") && !handedOver) {
    console.log("cancel: Cancel Pro, Stripe's confirm, Pro until the period's end");
    await page.goto(`${site}/settings#plan`, { waitUntil: "load" });
    await settled();
    await Promise.all([page.waitForURL(/billing\.stripe\.com/, { timeout: 60000 }),
      page.click("#plan button:has-text('Cancel Pro')")]);
    await page.waitForLoadState("domcontentloaded");
    await pause(4000);
    await shot("stripe-cancel-step", true);
    let clicks = 1;
    // What Stripe offers at each turn, so a step it adds is seen, not guessed.
    const controls = () => page.evaluate(() => [...document.querySelectorAll("button, [role=button], select, a")]
      .filter((e) => e.offsetWidth || e.offsetHeight)
      .map((e) => `${e.tagName.toLowerCase()}${e.disabled || e.getAttribute("aria-disabled") === "true" ? " (off)" : ""} `
        + `"${(e.textContent || "").replace(/\s+/g, " ").trim().slice(0, 40)}"`));
    console.log(`    on Stripe's cancel step: ${(await controls()).join(" | ")}`);
    // Admission's portal asks why first (its cancellation_reason). Continue
    // waits for an answer when the portal wants one, and that is a click too.
    const onward = page.getByRole("button", { name: "Continue to cancellation" });
    if (await onward.isVisible().catch(() => false)) {
      if (!(await onward.isEnabled().catch(() => true))) {
        const why = page.locator("select").first();
        const options = await why.locator("option").evaluateAll((all) => all.map((o) => o.value).filter(Boolean));
        await why.selectOption(options.includes("other") ? "other" : options[options.length - 1]);
        clicks += 1;
        console.log(`    Continue was off until a reason was chosen, of: ${options.join(", ")}`);
      }
      await onward.click({ timeout: 15000 });
      clicks += 1;
      await pause(3000);
      await shot("stripe-cancel-asked-why", true);
      console.log(`    then: ${(await controls()).join(" | ")}`);
    }
    const confirm = page.getByRole("button", { name: /^(Cancel subscription|Cancel plan|Confirm cancellation)$/ }).first();
    if (await confirm.waitFor({ state: "visible", timeout: 15000 }).then(() => true, () => false)) {
      await confirm.click({ timeout: 15000 });
      clicks += 1;
    }
    await pause(5000);
    await shot("stripe-cancelled", true);
    // docs/PLANS.md 8.2 says three: Cancel Pro, Stripe's Continue (why,
    // unanswered) and its Cancel subscription.
    check(`clicks from Cancel Pro to cancelled: ${clicks}`, clicks <= 3);
    // Stripe sends the person back itself (the flow's after_completion);
    // if it has not, the address does.
    if (!/\/settings/.test(page.url())) {
      await page.waitForURL(/\/settings/, { timeout: 15000 }).catch(() => null);
    }
    if (!/\/settings/.test(page.url())) await page.goto(`${site}/settings?billing=portal#plan`, { waitUntil: "load" });
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

  if (stages.includes("free") && !handedOver) {
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
if (handedOver && !failed) {
  console.log("billing real: Checkout handed to a person (checkout.txt); run --stage=paid,cancel after it is paid");
  process.exit(3);
}
console.log(failed ? `billing real: ${failed} FAILED` : "billing real: all ok");
process.exit(failed ? 1 : 0);
