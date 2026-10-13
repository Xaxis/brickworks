// Use the assistant the way a person does, in a real browser.
//
//   node tools/web/assistant_flow.mjs --url=https://brickworks.diy/app --out=shots/flow
//   BW_KEY=sk-ant-… node tools/web/assistant_flow.mjs --url=… --out=… --key=- --seconds=900 --every=120
//   BW_BYPASS=… node tools/web/assistant_flow.mjs --url=<a preview>/app --out=…
//   node tools/web/assistant_flow.mjs --url=http://127.0.0.1:8761/index.html --out=… --recorded
//
// Pastes a key, asks for "a small red house", and records every request to
// Anthropic and a screenshot at each step. With the default fake key it costs
// nothing and proves the path a person takes with a mistyped key: it leaves
// the browser, reaches Anthropic, and the refusal comes back at the form, in
// words someone can act on, before any brief is asked for. With a real key (--key=- reads BW_KEY, so the
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
//
// --recorded answers Anthropic in the browser with a recorded brain
// (tests/fixtures/sketches/lighthouse.json, which sketch_probe.gd answers the
// app with too): the fake key is taken, Build it with Sketch first ticked asks
// for three sketches — which must go to the cheaper model at medium effort —
// and three cards must come up; the second is chosen, and the next request
// must be on the chosen model, opening on that sketch. Nothing leaves the
// browser. Point it at a local export (serve.py) to see a change before it
// is deployed.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, readFileSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/flow";
const key = args.key === "-" ? process.env.BW_KEY
  : (args.key || "sk-ant-api03-notarealkey000000000000000000000000000000000");
const seconds = Number(args.seconds || 40);
const recorded = Boolean(args.recorded);
mkdirSync(out, { recursive: true });

const browser = await launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 860 } });
const seen = [];
const t0 = Date.now();
const at = () => `[${Math.round((Date.now() - t0) / 1000)}s]`;

// The recorded brain: every request to Anthropic answered here, in the
// shapes Anthropic answers in (a stream of server-sent events for a design).
const fixture = recorded ? JSON.parse(readFileSync(
  new URL("../../tests/fixtures/sketches/lighthouse.json", import.meta.url))) : null;
const asked = [];
const cors = {
  "access-control-allow-origin": "*", "access-control-allow-headers": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
};
const stream = (events) => events.map((e) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`).join("");
function reply(id, model, blocks, usage, stop) {
  const events = [{ type: "message_start", message: { id, type: "message", role: "assistant",
    model, content: [], stop_reason: null, usage: { input_tokens: usage.input_tokens, output_tokens: 1 } } }];
  blocks.forEach((block, index) => {
    if (block.text !== undefined) {
      events.push({ type: "content_block_start", index, content_block: { type: "text", text: "" } });
      events.push({ type: "content_block_delta", index, delta: { type: "text_delta", text: block.text } });
    } else {
      events.push({ type: "content_block_start", index,
        content_block: { type: "tool_use", id: `${id}_${index}`, name: "submit_design", input: {} } });
      events.push({ type: "content_block_delta", index,
        delta: { type: "input_json_delta", partial_json: JSON.stringify(block.input) } });
    }
    events.push({ type: "content_block_stop", index });
  });
  events.push({ type: "message_delta", delta: { stop_reason: stop, stop_sequence: null }, usage });
  events.push({ type: "message_stop" });
  return stream(events);
}
async function answer(route) {
  const request = route.request();
  if (request.method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
  if (request.url().includes("/v1/models")) {
    return route.fulfill({ status: 200, headers: { ...cors, "content-type": "application/json" },
      body: JSON.stringify({ data: [{ type: "model", id: "claude-opus-5-5" }], has_more: false }) });
  }
  const body = JSON.parse(request.postData() || "{}");
  const opening = body.messages?.[0]?.content;
  asked.push({ model: body.model, effort: body.output_config?.effort || "",
    messages: (body.messages || []).length,
    opening: Array.isArray(opening) ? opening.map((b) => b.text || "").join("\n") : String(opening || "") });
  const now = asked[asked.length - 1];
  seen.push(`${at()} recorded brain asked on ${now.model} at ${now.effort || "no"} effort, ${now.messages} message(s)`);
  const text = asked.length === 1
    ? reply("msg_sketches", body.model, fixture.sketches.map((input) => ({ input })),
      { input_tokens: 3000, cache_creation_input_tokens: 30000, output_tokens: 2400 }, "tool_use")
    : asked.length === 2
      ? reply("msg_full", body.model, [{ input: fixture.full }],
        { input_tokens: 9000, cache_creation_input_tokens: 30000, output_tokens: 3000 }, "tool_use")
      : reply(`msg_${asked.length}`, body.model, [{ text: "It reads as the lighthouse asked for." }],
        { input_tokens: 2000, cache_read_input_tokens: 39000, output_tokens: 40 }, "end_turn");
  return route.fulfill({ status: 200, headers: { ...cors, "content-type": "text/event-stream" }, body: text });
}
if (recorded) await page.route(/^https:\/\/api\.anthropic\.com\//, answer);
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
await page.screenshot({ timeout: 180000, path: `${out}/1_first_screen.png` });

// Where a control is, as the app tells the page (main._tell_page). Clicking
// at fixed positions broke the first time a paragraph above the key field
// grew, and the key went into the app as keyboard shortcuts.
async function click(name) {
  for (let tries = 0; tries < 600; tries++) {  // five minutes: at a load of 46 the panel came up later than two
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) {
      await page.mouse.click(where.x, where.y);
      return;
    }
    // In a laptop's window the assistant's column starts folded.
    if (tries === 6) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  // What the page was showing instead, for whoever reads the failure.
  await page.screenshot({ timeout: 180000, path: `${out}/never_showed_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed "${name}"; see ${out}/never_showed_${name}.png`);
}

await click("key_field");
await page.waitForTimeout(1500);
await page.keyboard.type(key, { delay: 15 });
await click("use_key");
// The key is checked with Anthropic before it is kept. Taken, the brief box
// appears; refused, the form stays with the reason under the button — which
// is the right answer for the made-up key, and the end of the road for it.
const showing = (n) => page.evaluate((n) => Boolean((window.brickworksControls || {})[n]), n);
let taken = false;
for (let tries = 0; tries < 90 && !taken; tries++) {
  await page.waitForTimeout(500);
  taken = await showing("brief");
}
await page.screenshot({ timeout: 180000, path: `${out}/2_key_taken.png` });
if (!taken) {
  await browser.close();
  console.log(seen.join("\n"));
  const checked = seen.some((line) => / anthropic 40[13]/.test(line));
  const fake = args.key !== "-";
  console.log(checked && fake
    ? `the made-up key was checked with Anthropic and refused at the form; see ${out}/2_key_taken.png`
    : `the key was not taken; see ${out}/2_key_taken.png`);
  process.exit(checked && fake && !refused.length ? 0 : 1);
}

await click("brief");
await page.waitForTimeout(1500);
await page.keyboard.type(recorded ? fixture.brief : "a small red house", { delay: 30 });
seen.push(`${at()} pressed Build it`);
await click("build");
if (recorded) await sketched();
// Three cards, the second chosen, and the design asked for from it.
async function sketched() {
  let cards = 0;
  for (let tries = 0; tries < 600 && cards < 3; tries++) {
    await page.waitForTimeout(500);
    cards = await page.evaluate(() => ["sketch_1", "sketch_2", "sketch_3"]
      .filter((n) => (window.brickworksControls || {})[n]).length);
  }
  await page.screenshot({ timeout: 180000, path: `${out}/3_sketches.png` });
  const sketches = asked[0] || {};
  const cheap = sketches.model === "claude-sonnet-5-5" && sketches.effort === "medium"
    && /call submit_design three times/.test(sketches.opening);
  seen.push(`${at()} ${cards} sketch card(s) to choose from`);
  let chosen = false;
  if (cards === 3) {
    await click("sketch_2");
    for (let tries = 0; tries < 240 && asked.length < 2; tries++) await page.waitForTimeout(500);
    const next = asked[1] || {};
    chosen = next.model === "claude-opus-5-5" && next.messages === 1
      && /the person chose sketch 2/.test(next.opening);
    await page.waitForTimeout(20000);
    await page.screenshot({ timeout: 180000, path: `${out}/4_designing_from_sketch_2.png` });
  }
  await browser.close();
  console.log(seen.join("\n"));
  if (refused.length) console.log(`content security policy refused ${refused.length} thing(s)`);
  const ok = cards === 3 && cheap && chosen && !refused.length;
  console.log(ok
    ? `three sketch cards on ${sketches.model} at ${sketches.effort}; sketch 2 chosen, and the design `
      + `asked of claude-opus-5-5 from it; see ${out}/3_sketches.png`
    : `sketch first did not run as it should: ${cards} card(s), sketches on ${sketches.model} `
      + `at ${sketches.effort}, then ${JSON.stringify((asked[1] || {}).model)}; see ${out}`);
  process.exit(ok ? 0 : 1);
}

// A picture every --every seconds, for watching a whole design run.
const every = Number(args.every || 0);
let waited = 0;
let shot = 0;
while (every > 0 && waited + every < seconds) {
  await page.waitForTimeout(every * 1000);
  waited += every;
  shot += 1;
  await page.screenshot({ timeout: 180000, path: `${out}/3_${String(shot).padStart(2, "0")}_at_${waited}s.png` });
}
await page.waitForTimeout((seconds - waited) * 1000);
await page.screenshot({ timeout: 180000, path: `${out}/3_after_build.png` });
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
