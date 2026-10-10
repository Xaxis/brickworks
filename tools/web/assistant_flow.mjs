// Use the assistant the way a person does, in a real browser.
//
//   node tools/web/assistant_flow.mjs --url=https://brickworks.diy/app --out=shots/flow
//   BW_KEY=sk-ant-… node tools/web/assistant_flow.mjs --url=… --out=… --key=- --seconds=900 --every=120
//   BW_BYPASS=… node tools/web/assistant_flow.mjs --url=<a preview>/app --out=…
//
// Pastes a key, asks for "a small red house", and records every request to
// Anthropic and a screenshot at each step. With the default fake key it costs
// nothing and proves the whole path a person takes: the key is accepted, the
// request leaves the browser and reaches Anthropic, and the refusal comes back
// as words someone can act on. With a real key (--key=- reads BW_KEY, so the
// key is never on a command line) it watches the design start, for --seconds.
//
// Why it exists: the live site was reported as "the assistant doesn't work at
// all". It worked — four answers from Anthropic in ninety seconds — and showed
// nothing for all ninety: one line of small grey text and the example car
// still on the baseplate. Every check here had passed, because none of them
// ever pressed Build.
//
// The panel is drawn inside the canvas, so it is driven by position: the app
// publishes where its controls are (window.brickworksControls) and this
// clicks there. A preview sits behind Vercel's login: BW_BYPASS goes in
// the first address only, which sets a cookie for that domain alone, so it is
// never sent to Anthropic.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/flow";
const key = args.key === "-" ? process.env.BW_KEY
  : (args.key || "sk-ant-api03-notarealkey000000000000000000000000000000000");
const seconds = Number(args.seconds || 40);
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 860 } });
const seen = [];
const t0 = Date.now();
const at = () => `[${Math.round((Date.now() - t0) / 1000)}s]`;
page.on("response", (r) => {
  if (/api\.anthropic\.com/.test(r.url())) seen.push(`${at()} anthropic ${r.status()}`);
});
page.on("requestfailed", (r) => {
  if (/anthropic/.test(r.url())) seen.push(`${at()} anthropic FAILED ${r.failure()?.errorText}`);
});
page.on("pageerror", (e) => seen.push(`${at()} page error: ${String(e).slice(0, 200)}`));
// The content security policy refusing something the app needed shows
// only here, in the console; a page that half works is the symptom.
const refused = [];
page.on("console", (m) => {
  const text = m.text();
  if (/Content Security Policy|Refused to (connect|load|execute|create)/i.test(text)) {
    refused.push(text.slice(0, 220));
  }
});

const first = process.env.BW_BYPASS
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${process.env.BW_BYPASS}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));
await page.screenshot({ path: `${out}/1_first_screen.png` });

// Where a control is, as the app tells the page (main._tell_page). Clicking
// at fixed positions broke the first time a paragraph above the key field
// grew, and the key went into the app as keyboard shortcuts.
async function click(name) {
  for (let tries = 0; tries < 40; tries++) {
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) {
      await page.mouse.click(where.x, where.y);
      return;
    }
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
}

await click("key_field");
await page.waitForTimeout(1500);
await page.keyboard.type(key, { delay: 15 });
await click("use_key");
await page.waitForTimeout(4000);
await page.screenshot({ path: `${out}/2_key_taken.png` });

await click("brief");
await page.waitForTimeout(1500);
await page.keyboard.type("a small red house", { delay: 30 });
seen.push(`${at()} pressed Build it`);
await click("build");
// A picture every --every seconds, for watching a whole design run.
const every = Number(args.every || 0);
let waited = 0;
let shot = 0;
while (every > 0 && waited + every < seconds) {
  await page.waitForTimeout(every * 1000);
  waited += every;
  shot += 1;
  await page.screenshot({ path: `${out}/3_${String(shot).padStart(2, "0")}_at_${waited}s.png` });
}
await page.waitForTimeout((seconds - waited) * 1000);
await page.screenshot({ path: `${out}/3_after_build.png` });
await browser.close();

const answers = seen.filter((line) => / anthropic \d+/.test(line));
console.log(seen.join("\n"));
if (refused.length) {
  console.log(`content security policy refused ${refused.length} thing(s):`);
  for (const line of refused.slice(0, 8)) console.log(`  ${line}`);
}
console.log(answers.length
  ? `reached Anthropic ${answers.length} time(s); screenshots in ${out}`
  : `never reached Anthropic — see ${out}/3_after_build.png`);
process.exit(answers.length && !refused.length ? 0 : 1);
