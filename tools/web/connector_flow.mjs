// Prove the Claude connector on a deployed site, as a person and as Claude.
//
//   node tools/web/connector_flow.mjs --url=https://brickworks.diy/app --out=shots/connector
//   BW_BYPASS=… node tools/web/connector_flow.mjs --url=<a preview>/app --out=…
//
// In a real browser: switch the connector on, press Copy, and read the
// address off the clipboard — the way a person gets it. Then, from here, ask
// that address what Claude asks (initialize, tools/list, real tool calls)
// through the deployed relay, and check the tab answered and shows it. Then
// the page goes out of view, as it does while the person is in claude.ai:
// the page itself must tell the relay, and Claude must be asked to bring it
// back rather than left waiting or told it is closed. Last, a reload: the
// same address, on again by itself.
//
// Costs nothing: no model is called; this plays Claude's part itself. A
// preview's relay sits behind Vercel's login, so with BW_BYPASS the bypass
// goes on the requests made from here as a header, and to the page as a
// cookie for its own domain.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/connector";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
const page = await context.newPage();
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));

async function click(name) {
  for (let tries = 0; tries < 600; tries++) {  // five minutes: at a load of 46 the panel came up later than two
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) return page.mouse.click(where.x, where.y);
    await page.waitForTimeout(500);
  }
  // What the page was showing instead, for whoever reads the failure.
  await page.screenshot({ path: `${out}/never_showed_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed "${name}"; see ${out}/never_showed_${name}.png`);
}

await click("connect_claude");
await page.waitForTimeout(3000);
await click("connector_copy");
await page.waitForTimeout(1500);
const address = await page.evaluate(() => navigator.clipboard.readText());
console.log(`address from the clipboard: ${address.slice(0, 60)}…`);
await page.screenshot({ path: `${out}/1_connected.png` });

let sent = 0;
async function claude(method, params) {
  sent += 1;
  const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
  if (bypass) headers["x-vercel-protection-bypass"] = bypass;
  const answer = await fetch(address, {
    method: "POST", headers,
    body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
  });
  return answer.json();
}
let failures = 0;
const check = (ok, what) => { console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`); if (!ok) failures += 1; };

const hello = await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "connector_flow", version: "1" } });
check(hello.result?.serverInfo?.name === "brickworks" && (hello.result?.instructions || "").length > 1000,
  "initialize is answered by the tab, with the design guidance");
const listed = await claude("tools/list", {});
const names = (listed.result?.tools || []).map((t) => t.name);
check(names.includes("submit_design") && names.includes("search_parts"), `the tab lists its tools: ${names.length}`);
const found = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 2 x 4" } });
const text = (found.result?.content || []).map((c) => c.text || "").join(" ");
check(text.includes("3001") && !found.result?.isError, `a tool call runs in the tab: ${text.slice(0, 50)}`);
const scaled = await claude("tools/call", { name: "plan_scale", arguments: { subject: "a lighthouse", longest_metres: 30 } });
check(((scaled.result?.content || [])[0]?.text || "").includes("studs"), "a second call, the scale, is answered too");
// The style norms have to have reached the web build: they are packed by
// tools/web_pack.py, and without them the check says nothing about how
// squarely a design is built. A plain wall is as square as anything is.
const wall = await claude("tools/call", { name: "check_design", arguments: { bricks: [],
  patterns: [{ pattern: "fill", shape: "rectangle", at: { x: 0, y: 0, z: 0 }, across: 20, deep: 12,
    wall: 1, layers: 6, rise: 3, color: 71 }] } });
const wallText = (wall.result?.content || []).map((c) => c.text || "").join(" ");
check(wallText.includes("more squarely than real"), "a square wall is told how real sets are built");
await page.waitForTimeout(2000);
await page.screenshot({ path: `${out}/2_after_calls.png` });

// Out of view. The browser here keeps drawing a page in the background,
// so it is told the page is hidden the way a real one would be.
const seeing = (hidden) => page.evaluate((hidden) => {
  Object.defineProperty(document, "hidden", { value: hidden, configurable: true });
  Object.defineProperty(document, "visibilityState", { value: hidden ? "hidden" : "visible", configurable: true });
  document.dispatchEvent(new Event("visibilitychange"));
}, hidden);
await seeing(true);
await page.waitForTimeout(1500);
const listedAsleep = await claude("tools/list", {});
check((listedAsleep.result?.tools || []).length === names.length, "out of view, Claude can still list the tools");
const t0 = Date.now();
const asleep = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 1 x 2" } });
const asleepText = (asleep.result?.content || []).map((c) => c.text || "").join(" ");
check(asleep.result?.isError && asleepText.includes("out of view") && !asleepText.includes("not open"),
  `out of view, a call is told to bring the tab back, after ${Math.round((Date.now() - t0) / 1000)}s`);
await seeing(false);
await page.waitForTimeout(1500);
const back = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 1 x 2" } });
check(((back.result?.content || [])[0]?.text || "").includes("3004"), "back in view, the same call is answered");

// A reload is a new visit: the address must not change, and the
// connector must come back on by itself.
await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));
const afterReload = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 2 x 2" } });
check(((afterReload.result?.content || [])[0]?.text || "").includes("3003"),
  "after a reload the same address works, with nothing pressed");
await page.waitForTimeout(2000);
await page.screenshot({ path: `${out}/3_after_reload.png` });
await browser.close();
console.log(failures ? `${failures} failure(s)` : "the connector works on this deployment");
process.exit(failures ? 1 : 0);
