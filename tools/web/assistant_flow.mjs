// Use the assistant the way a person does, in a real browser.
//
//   node tools/web/assistant_flow.mjs --url=https://brickworks.diy/app --out=shots/flow
//   BW_KEY=sk-ant-… node tools/web/assistant_flow.mjs --url=… --out=… --key=- --seconds=90
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
// The panel is drawn inside the canvas, so it is driven by position, for a
// 1280 x 860 window. A preview sits behind Vercel's login: BW_BYPASS goes in
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

const first = process.env.BW_BYPASS
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${process.env.BW_BYPASS}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));
await page.screenshot({ path: `${out}/1_first_screen.png` });

// The key form is the first thing under the panel's title.
await page.mouse.click(1143, 264);
await page.waitForTimeout(1500);
await page.keyboard.type(key, { delay: 15 });
await page.mouse.click(1143, 298);
await page.waitForTimeout(4000);
await page.screenshot({ path: `${out}/2_key_taken.png` });

// The brief box and Build it, at the foot of the panel.
await page.mouse.click(1143, 725);
await page.waitForTimeout(1500);
await page.keyboard.type("a small red house", { delay: 30 });
seen.push(`${at()} pressed Build it`);
await page.mouse.click(1143, 793);
await page.waitForTimeout(seconds * 1000);
await page.screenshot({ path: `${out}/3_after_build.png` });
await browser.close();

const answers = seen.filter((line) => / anthropic \d+/.test(line));
console.log(seen.join("\n"));
console.log(answers.length
  ? `reached Anthropic ${answers.length} time(s); screenshots in ${out}`
  : `never reached Anthropic — see ${out}/3_after_build.png`);
process.exit(answers.length ? 0 : 1);
