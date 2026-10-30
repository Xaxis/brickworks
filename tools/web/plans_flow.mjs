// Plans: Free, and Pro coming soon (web/plans.html, web/plans.js,
// api/plans.js, supabase/plan_interest.sql), in real browsers.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/plans_flow.mjs --url=<preview> --out=DIR
//   node tools/web/plans_flow.mjs --stand-in --out=DIR
//
// With --stand-in, the checkout's web/ with the API answered by
// tools/web/design_stand_in.mjs (api/plans.js's own checks and words), and
// no table: what is kept is not read. On a deployment, the live project's
// table, so plan_interest.sql applied; before it the form says it is not
// open yet, and the flow says so and fails.
//
//   1. /plans at 390 and 1400 px, light and dark: Free and Pro with $0,
//      and Pro at $80 a year, then $8 a month once Monthly is pressed
//      (site356: Yearly first); every row side by side (#compare); Pro
//      Coming soon, with Tell me when it's ready and no way to pay shown
//      (billing is off); what an AI build is; accounts that exist keep
//      everything; education free; what stays free; nothing sideways; the
//      footer links /plans; the privacy page says what the form keeps.
//   2. At 390 px, Pro's button opens the form with yearly chosen. An
//      address that is not one is refused in words, and the API refuses
//      one sent to it straight (422), and a plan off its list (Plus, now).
//   3. A test address of ours (delivered+plans-<random>@resend.dev) for
//      Pro, yearly: the thanks, and its row in the table, kept as 'plus'
//      (api/plans.js PLANS: the table allows Plus and Creator, which both
//      mean Pro now).
//   4. Sent again, monthly, with a line: the same thanks, and still one row
//      for Pro, now monthly with the line.
//   5. Take it off: its words, and no row left. Whatever happens, the
//      address is forgotten at the end: only ours, nothing else touched.
//
// Pictures in --out: plans_<width>_<theme>.png, the form open, the thanks.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const standIn = Boolean(args["stand-in"]);
const site = standIn ? stand.ORIGIN : String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!site) {
  console.error("plans_flow: --url=<deployment> or --stand-in");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/plans"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const EMAIL = `delivered+plans-${randomBytes(4).toString("hex")}@resend.dev`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};

/// [name] asked of the live project as the owner asks it (the secret key,
/// tools/plan_interest.py), for [email]; null with the stand-in or no key.
async function owner(name, email) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY || "";
  if (standIn || !base || !key) return null;
  const answer = await fetch(`${base}/rest/v1/rpc/${name}`, {
    method: "POST", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify({ p_email: email }) });
  if (!answer.ok) throw new Error(`${name}: ${answer.status}`);
  return answer.json();
}
/// What the table keeps for [email]: [{plan, billing, note, created_at, updated_at}].
const rows = (email) => owner("plan_interest_of", email);
const forgetOurs = () => owner("plan_interest_forget", EMAIL)
  .catch((trouble) => console.log(`  (could not forget ${EMAIL}: ${trouble.message})`));

const browser = await launch({ signedOut: true });
async function context({ width, dark }) {
  const made = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 },
    extraHTTPHeaders: headers, colorScheme: dark ? "dark" : "light", isMobile: width < 600, hasTouch: width < 600 });
  if (standIn) await stand.serveSite(made, { web: path.join(root, "web"), api: path.join(root, "api"), state: {} });
  return made;
}
const words = (page, selector) => page.locator(selector).innerText().catch(() => "");

try {
  console.log(`plans: ${site}${standIn ? " (the stand-in)" : ""}, ${EMAIL}`);

  // 1. The page.
  for (const width of [390, 1400]) {
    for (const dark of [false, true]) {
      const made = await context({ width, dark });
      const page = await made.newPage();
      const said = await page.goto(`${site}/plans`, { waitUntil: "networkidle" });
      const at = `${width} px ${dark ? "dark" : "light"}`;
      check(`${at}: /plans answers 200`, said?.status() === 200);
      const theme = await page.evaluate(() => getComputedStyle(document.documentElement).colorScheme);
      check(`${at}: drawn in the ${dark ? "dark" : "light"} theme (${theme})`, theme === (dark ? "dark" : "light"));
      const tiers = await page.$$eval(".tiers .tier", (all) => all.map((one) => ({
        name: one.querySelector("h2")?.textContent.trim(),
        price: one.querySelector(".price b")?.closest("span, p")?.innerText.replace(/\s+/g, " ").trim(),
        soon: Boolean(one.querySelector(".pill.new")?.textContent.includes("Coming soon")),
        ask: one.querySelector("[data-interest]")?.textContent.trim() || "",
        top: Math.round(one.getBoundingClientRect().top) })));
      check(`${at}: Free and Pro (${tiers.map((one) => one.name).join(", ")})`,
        tiers.map((one) => one.name).join() === "Free,Pro");
      check(`${at}: $0, and $80 a year to start with (${tiers.map((one) => one.price).join(" | ")})`,
        tiers[0]?.price === "$0" && tiers[1]?.price === "$80 a year");
      await page.click('[data-billing="month"]');
      const monthly = await page.$eval("#pro .price", (el) => el.innerText.replace(/\s+/g, " ").trim());
      check(`${at}: Monthly shows $8 a month (${monthly})`, monthly.startsWith("$8 a month") && !monthly.includes("$80 a year"));
      await page.click('[data-billing="year"]');
      const table = await page.$$eval("#compare tbody tr", (all) => all.map((one) => one.innerText.replace(/\s+/g, " ").trim()));
      check(`${at}: every row side by side (${table.length} rows), AI builds 10 a month or no limit`,
        table.length > 10 && table.some((one) => /AI builds.*10 a month.*No limit/.test(one)));
      check(`${at}: no way to pay shown while billing is off`, !(await page.isVisible("#pro-upgrade")));
      check(`${at}: Pro marked Coming soon, Free not`, !tiers[0]?.soon && tiers[1]?.soon);
      check(`${at}: Pro has Tell me when it's ready, Free not`,
        /Tell me when it.s ready/.test(tiers[1]?.ask) && !tiers[0]?.ask);
      check(`${at}: the two side by side on a wide screen, one under the other on a phone`,
        width < 600 ? tiers[0].top < tiers[1].top : tiers[0].top === tiers[1].top);
      const body = await words(page, "main");
      check(`${at}: what an AI build is`, /An AI build is an AI working on a model/.test(body));
      check(`${at}: accounts that exist keep everything`,
        /Every account made before 29 October 2026, when this page changed, gets Pro, free and with no end date/.test(body));
      check(`${at}: education is free`, /Education is free/.test(body));
      check(`${at}: what stays free: the web app, by hand, everything else, nothing taken out`,
        /What stays free/.test(body) && /It takes nothing out of Free/.test(body) && /The web app\./.test(body)
        && /Building by hand, without a limit\./.test(body) && /Everything else the app does today\./.test(body));
      check(`${at}: no Claude builds, and no free desktop`,
        !/Claude build/i.test(body) && !/desktop app (is|stays) free(?! to download)/i.test(body));
      check(`${at}: nothing on the page takes money (no checkout, no card form)`,
        !(await page.$('input[autocomplete^="cc-"], [href*="checkout"], [href*="stripe"]')));
      const wide = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      check(`${at}: nothing sideways (${wide} px past the window)`, wide <= 0);
      check(`${at}: the footer links /plans`, Boolean(await page.$('.site-foot a[href="/plans"]')));
      await page.screenshot({ path: path.join(out, `plans_${width}_${dark ? "dark" : "light"}.png`), fullPage: true });
      await made.close();
    }
  }
  {
    const made = await context({ width: 1400, dark: false });
    const page = await made.newPage();
    await page.goto(`${site}/privacy`, { waitUntil: "load" });
    const plans = await words(page, "#plans + p");
    check("/privacy says what the form keeps, why, and how to take it off",
      /hear when Pro opens, your email is kept with/.test(plans) && /only to write to you once/.test(plans) && /take it off/.test(plans));
    await made.close();
  }

  // 2. The form, at a phone's width.
  const made = await context({ width: 390, dark: false });
  const page = await made.newPage();
  await page.goto(`${site}/plans`, { waitUntil: "networkidle" });
  const open = async (plan) => {
    await page.click(`[data-interest="${plan}"]`);
    return page.waitForSelector("dialog#interest[open]", { timeout: 5000 }).then(() => true, () => false);
  };
  const send = async (button = "#interest-send") => {
    const [answer] = await Promise.all([
      page.waitForResponse((r) => r.url().endsWith("/api/plans") && r.request().method() === "POST", { timeout: 15000 }),
      page.click(button)]);
    // What the page said once the answer is drawn: the thanks, or why not.
    await page.waitForFunction(() => !document.getElementById("interest-done").hidden
      || !/Sending/.test(document.getElementById("interest-said").textContent), null, { timeout: 5000 }).catch(() => {});
    return { status: answer.status(), thanks: await words(page, "#interest-thanks"), said: await words(page, "#interest-said"),
      done: await page.isVisible("#interest-done") };
  };
  check("Pro's button opens the form", await open("pro"));
  check("with yearly chosen, and no plan to choose", await page.inputValue("#interest-billing") === "yearly"
    && !(await page.$("#interest-plan")));
  await page.waitForTimeout(400); // past the dialog's rise (--motion-open)
  await page.screenshot({ path: path.join(out, "plans_390_form.png") });

  await page.fill("#interest-email", "not an address");
  const bad = await send();
  check(`an address that is not one is refused in words (${bad.status}: "${bad.said}")`,
    bad.status === 422 && /not an email address/.test(bad.said) && !bad.done);
  const straight = await page.evaluate(async () => {
    const ask = (body) => fetch("/api/plans", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify(body) }).then(async (r) => [r.status, (await r.json().catch(() => ({}))).error || ""]);
    return { email: await ask({ email: "nobody@", plan: "pro", billing: "yearly" }),
      plan: await ask({ email: "delivered@resend.dev", plan: "plus", billing: "yearly" }),
      note: await ask({ email: "delivered@resend.dev", plan: "pro", billing: "yearly", note: "x".repeat(201) }) };
  });
  check(`the API refuses a bad address (${straight.email.join(" ")}), a plan off its list (${straight.plan.join(" ")}) `
    + `and a line past 200 (${straight.note[0]})`,
    straight.email[0] === 422 && straight.plan[0] === 422 && straight.note[0] === 422);

  // 3. Our test address, Pro, yearly.
  await page.fill("#interest-email", EMAIL);
  const first = await send();
  if (first.status === 503) {
    check(`the form is open (it said ${first.status}: "${first.said}": supabase/plan_interest.sql is not applied)`, false);
  } else {
    check(`sent for Pro, yearly: the thanks ("${first.thanks}")`, first.status === 200 && first.done
      && /write to you once/.test(first.thanks));
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(out, "plans_390_thanks.png") });
    const kept = await rows(EMAIL);
    if (kept) {
      check(`its row is in the table, Pro kept as plus (${JSON.stringify(kept.map(({ plan, billing, note }) => [plan, billing, note]))})`,
        kept.length === 1 && kept[0].plan === "plus" && kept[0].billing === "yearly" && kept[0].note === "");
    } else console.log("  (the stand-in: no table to read)");

    // 4. Again, monthly with a line: changed, not added.
    await page.click("#interest-done [data-close]");
    check("the form opens again for a second entry", await open("pro"));
    await page.selectOption("#interest-billing", "monthly");
    await page.fill("#interest-note", "Monthly suits me better");
    const again = await send();
    check(`sent again: the same thanks (${again.status})`, again.status === 200 && again.done && again.thanks === first.thanks);
    const changed = await rows(EMAIL);
    if (changed) {
      check(`still one row for Pro, now monthly with the line (${JSON.stringify(changed.map(({ plan, billing, note }) => [plan, billing, note]))})`,
        changed.length === 1 && changed[0].plan === "plus" && changed[0].billing === "monthly"
        && changed[0].note === "Monthly suits me better" && changed[0].updated_at > changed[0].created_at);
    }

    // 5. Take it off.
    await page.click("#interest-done [data-close]");
    await open("pro");
    const gone = await send("#interest-forget");
    check(`take it off: its words ("${gone.thanks}")`, gone.status === 200 && gone.done && /not on the list/.test(gone.thanks));
    const left = await rows(EMAIL);
    if (left) check(`no row left for it (${left.length})`, left.length === 0);
  }
  await made.close();
} catch (trouble) {
  check(`the flow ran (${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")})`, false);
} finally {
  if (!standIn) await forgetOurs();
  await browser.close();
}
console.log(failed ? `plans: ${failed} FAIL` : "plans: all ok");
process.exit(failed ? 1 : 0);
