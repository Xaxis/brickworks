// The loop's card in /admin › Analytics › Funnels (web/admin-analytics.js,
// docs/ANALYTICS.md "The loop"), in a real browser, locally: the page and
// api/admin.js served by tools/web/relay_server.mjs against the live
// database, its MASTER_EMAIL the checks' shared account (never the owner's),
// given only the three Supabase keys. Run under heavy.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/insights/loop_check.mjs --card=OUT/card_loop.json
//   node tools/web/loop_card_check.mjs --card=OUT/card_loop.json --out=OUT [--port=11391] [--env=.env]
//
//   1. As the live database answers ?op=loop: before supabase/loop_funnel.sql
//      the card says it is not measured yet; after it, its steps are drawn.
//   2. With ?op=loop answered from the fixture's own read (--card, the
//      numbers tests/test_loop.py counts by hand), at 1280 and 390, light and
//      dark: the six steps drawn, a legend of two, the table's every number
//      the read's, Built and Came back within 30 beside, each step's names
//      listed; nothing wider than the page; no error in the page.
//   3. At 1280: Tab reaches the chart from the card's title, one stop; the
//      arrow keys, Home and End go from step to step, each saying itself and
//      showing its tooltip.
//   4. Definitions says each step's rule.
//
// Pictures of each card in --out. Ends "loop_card: all ok", or lists what failed.
import { spawn } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "../..");
const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || `--${name}=${fallback}`).slice(name.length + 3);
const out = arg("out");
const cardFile = arg("card");
if (!out || !cardFile) {
  console.error("loop_card_check: --card=FILE (loop_check.mjs --card=) --out=DIR");
  process.exit(2);
}
mkdirSync(out, { recursive: true });
const card = JSON.parse(readFileSync(cardFile, "utf8"));
const port = Number(arg("port", "11391"));

// Only the three keys, never the rest of the file (it holds a real Anthropic key).
const KEEP = ["SUPABASE_URL", "SUPABASE_SECRET_KEY", "SUPABASE_PUBLISHABLE_KEY"];
const given = {};
for (const line of readFileSync(arg("env", join(ROOT, ".env")), "utf8").split("\n")) {
  const found = /^\s*([A-Z_]+)\s*=\s*(.*)\s*$/.exec(line);
  if (found && KEEP.includes(found[1])) given[found[1]] = found[2].replace(/^(['"])(.*)\1$/, "$2");
}
for (const key of KEEP) {
  if (!given[key]) throw new Error(`no ${key} in the env file`);
  process.env[key] = given[key];
}
const { TEST_EMAIL } = await import("./session.mjs");
const { launch } = await import("./browser.mjs");

const relay = spawn(process.execPath, [join(ROOT, "tools/web/relay_server.mjs"), String(port)], { cwd: ROOT,
  env: { PATH: process.env.PATH, HOME: process.env.HOME, ...given, MASTER_EMAIL: TEST_EMAIL }, stdio: ["ignore", "pipe", "pipe"] });
let relayLog = "";
relay.stdout.on("data", (chunk) => { relayLog += chunk; });
relay.stderr.on("data", (chunk) => { relayLog += chunk; });
const site = `http://127.0.0.1:${port}`;

const failed = [];
const found = {};
const errors = [];
const check = (ok, words) => {
  if (!ok) failed.push(words);
  return ok;
};
const number = (text) => Number(String(text).replace(/[^\d−-]/g, "").replace("−", "-"));
const STEPS = [["discovered", "Discovered"], ["opened", "Opened"], ["changed", "Changed"], ["shared", "Shared"],
  ["heard_back", "Heard back"], ["came_back", "Came back"]];

let browser = null;
try {
  for (let tries = 0; ; tries += 1) {
    try {
      if ((await fetch(`${site}/api/admin?op=loop`)).status === 401) break;
    } catch {
      // Not listening yet.
    }
    if (tries > 150 || relay.exitCode !== null) throw new Error(`the relay did not come up on ${port}: ${relayLog.slice(-400)}`);
    await new Promise((done) => setTimeout(done, 200));
  }
  // Signed in as the checks' shared account, the relay's MASTER_EMAIL.
  browser = await launch();

  /// The console's Funnels at [width] in [theme], ?op=loop from the fixture unless [live].
  const open = async (width, theme, { live = false } = {}) => {
    const phone = width < 600;
    const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
      ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
    // The account's own theme kept out, so each picture is the theme it is named for.
    await context.route(/\/theme-account\.js(?:\?.*)?$/, (route) => route.fulfill({ status: 200, contentType: "text/javascript",
      body: "export async function follow() {}" }));
    if (!live) {
      await context.route(/\/api\/admin\?(?:.*&)?op=loop(?:&|$)/, (route) => route.fulfill({ status: 200,
        contentType: "application/json", body: JSON.stringify(card) }));
    }
    const page = await context.newPage();
    const label = `${width} ${theme}${live ? " live" : ""}`;
    page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
    page.on("console", (m) => {
      if (m.type() === "error" && /SyntaxError|TypeError|ReferenceError|Refused to/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 200)}`);
    });
    await page.goto(`${site}/admin?tests=1#analytics/funnels`, { waitUntil: "load", timeout: 120000 });
    await page.waitForSelector('[data-card="loop"] .note, [data-card="loop"] svg', { timeout: 120000 });
    return { page, context };
  };

  // 1. The live database's answer.
  {
    const { page, context } = await open(1280, "light", { live: true });
    await page.waitForFunction(() => {
      const c = document.querySelector('[data-card="loop"]');
      return c && (c.querySelector("svg circle") || /not measured|could not be read/i.test(c.textContent));
    }, null, { timeout: 120000 });
    const said = await page.locator('[data-card="loop"]').innerText();
    found.live = /Not measured on this database yet/.test(said) ? "not applied: says so"
      : (await page.locator('[data-card="loop"] svg circle').count()) === 12 ? "applied: drawn" : said.slice(0, 200);
    check(/says so|drawn/.test(found.live), `live: ${found.live}`);
    await page.locator('[data-card="loop"]').screenshot({ path: join(out, "card_live_1280_light.png") });
    await context.close();
  }

  // 2. The fixture's read, each width and theme.
  for (const [width, theme] of [[1280, "light"], [1280, "dark"], [390, "light"], [390, "dark"]]) {
    const key = `${width}_${theme}`;
    const { page, context } = await open(width, theme);
    const box = page.locator('[data-card="loop"]');
    await page.waitForFunction(() => document.querySelectorAll('[data-card="loop"] svg circle').length === 12, null, { timeout: 60000 });
    const seen = await page.evaluate(() => {
      const c = document.querySelector('[data-card="loop"]');
      const rows = [...c.querySelectorAll("details.as-table tbody tr")].map((tr) => [...tr.cells].map((td) => td.textContent.trim()));
      const acts = document.querySelector('[data-card="loop_acts"]');
      const css = getComputedStyle(c);
      const now = getComputedStyle(c.querySelector("circle.now")).fill;
      const was = getComputedStyle(c.querySelector("circle.was")).fill;
      return {
        rows,
        legend: [...c.querySelectorAll(".legend li")].map((li) => li.textContent.trim()),
        steps: [...c.querySelectorAll("svg text.step")].map((t) => t.textContent),
        stops: [...c.querySelectorAll("svg .hit")].map((h) => h.getAttribute("tabindex")),
        built: c.querySelector('[data-stat="loop_built"] b')?.textContent,
        back30: c.querySelector('[data-stat="loop_came_back_30"] b')?.textContent,
        acts: acts ? [...acts.querySelectorAll("tbody tr")].map((tr) => [...tr.cells].map((td) => td.textContent.trim())) : null,
        wide: Math.max(c.scrollWidth - c.clientWidth, document.documentElement.scrollWidth - innerWidth),
        colours: { now, was, panel: css.backgroundColor },
      };
    });
    found[key] = { legend: seen.legend, built: seen.built, back30: seen.back30, wide: seen.wide, colours: seen.colours,
      acts: seen.acts?.length };
    check(seen.steps.join("|") === STEPS.map((s) => s[1]).join("|"), `${key}: steps drawn ${seen.steps.join("|")}`);
    check(seen.legend.length === 2, `${key}: legend ${seen.legend.join(", ")}`);
    check(seen.stops.filter((t) => t === "0").length === 1 && seen.stops.length === 6, `${key}: tab stops ${seen.stops.join(",")}`);
    check(seen.colours.now !== seen.colours.was, `${key}: this range and before in one colour`);
    check(seen.wide <= 1, `${key}: ${seen.wide}px wider than the page`);
    const now = card.this;
    const was = card.before;
    STEPS.forEach(([step, words], n) => {
      const row = seen.rows[n] || [];
      check(row[0] === words && number(row[1]) === now.steps[step] && number(row[3]) === was.steps[step]
        && number(row[5]) === now.stopped[step], `${key}: table row ${words}: ${row.join(" | ")}`);
    });
    const tail = Object.fromEntries(seen.rows.slice(6).map((r) => [r[0], r]));
    check(number(tail["Came back within 30 days"]?.[1]) === now.steps.came_back_30, `${key}: came back within 30`);
    check(number(tail["Short of the loop"]?.[5]) === now.stopped.none, `${key}: short of the loop`);
    check(number(tail["Built (devices)"]?.[1]) === now.built && number(tail["Built (devices)"]?.[3]) === was.built, `${key}: built row`);
    check(number(seen.built) === now.built && number(seen.back30) === now.steps.came_back_30, `${key}: the stats beside`);
    const listed = now.acts.length + now.kept.length + Object.keys(now.heard).length + 2;
    check(seen.acts?.length === listed, `${key}: ${seen.acts?.length} names listed, ${listed} in the read`);
    const placed = (seen.acts || []).find((r) => r[1] === "studio part placed");
    check(placed && number(placed[2]) === now.acts.find((a) => a.name === "placed").people, `${key}: placed's people`);
    await box.screenshot({ path: join(out, `card_${key}.png`) });
    await page.locator('[data-card="loop_acts"]').screenshot({ path: join(out, `card_acts_${key}.png`) });

    // 3. The keyboard, at 1280.
    if (width === 1280) {
      await page.locator('[data-card="loop"] .lead a').focus();
      let presses = 0;
      for (; presses < 12; presses += 1) {
        await page.keyboard.press("Tab");
        if (await page.evaluate(() => document.activeElement?.classList?.contains("hit"))) break;
      }
      found[`${key}_tabs`] = presses + 1;
      check(presses < 12, `${key}: Tab never reached the chart`);
      const said = async () => page.evaluate(() => ({ label: document.activeElement?.getAttribute("aria-label") || "",
        tip: document.getElementById("an-tip")?.hidden === false ? document.getElementById("an-tip").textContent : "" }));
      const first = await said();
      check(first.label.startsWith("Discovered: ") && /Discovered/.test(first.tip), `${key}: first stop ${first.label} / ${first.tip}`);
      await page.keyboard.press("ArrowDown");
      const second = await said();
      check(second.label.startsWith("Opened: ") && /Opened/.test(second.tip), `${key}: ArrowDown ${second.label}`);
      await page.keyboard.press("End");
      const last = await said();
      check(last.label.startsWith("Came back: "), `${key}: End ${last.label}`);
      await page.keyboard.press("Home");
      check((await said()).label.startsWith("Discovered: "), `${key}: Home`);
      // One stop: Tab leaves the chart.
      await page.keyboard.press("Tab");
      check(!(await page.evaluate(() => document.activeElement?.classList?.contains("hit"))), `${key}: a second Tab stop in the chart`);
      found[`${key}_keys`] = [first.label, second.label, last.label];
      if (theme === "light") {
        await page.locator('[data-card="loop"] .lead a').focus();
        await page.keyboard.press("Tab");
        await page.keyboard.press("ArrowDown");
        await page.keyboard.press("ArrowDown");
        await page.keyboard.press("ArrowDown");
        await box.screenshot({ path: join(out, `card_focus_${key}.png`) });
      }
    }

    // 4. Definitions.
    if (key === "1280_light") {
      await page.goto(`${site}/admin?tests=1#analytics/definitions`, { waitUntil: "load" });
      await page.waitForFunction(() => /Heard back/.test(document.querySelector('[data-section="analytics"]')?.textContent || ""), null,
        { timeout: 60000 });
      const text = await page.locator('[data-section="analytics"]').innerText();
      for (const words of ["The loop", "Discovered", "Opened", "Changed", "Shared", "Heard back", "Came back", "Built"]) {
        check(text.includes(words), `definitions: no ${words}`);
      }
      check(/heard from somebody else/.test(text) && /active again on a later day within 7 days/.test(text), "definitions: the rules");
    }
    await context.close();
  }
  check(errors.length === 0, `page errors: ${errors.join(" / ")}`);
} catch (trouble) {
  failed.push(`stopped: ${trouble?.stack || trouble}`);
} finally {
  await browser?.close().catch(() => {});
  relay.kill("SIGTERM");
}
writeFileSync(join(out, "loop_card.json"), `${JSON.stringify({ found, failed, errors }, null, 1)}\n`);
console.log(JSON.stringify(found, null, 1));
if (failed.length) {
  console.log(`loop_card: ${failed.length} failed`);
  for (const one of failed) console.log(`  FAIL ${one}`);
  process.exit(1);
}
console.log("loop_card: all ok");
