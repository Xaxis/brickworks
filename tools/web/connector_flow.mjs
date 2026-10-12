// Prove the Claude connector on a deployed site, as a person and as Claude.
//
//   node tools/web/connector_flow.mjs --url=https://brickworks.diy/app --out=shots/connector
//   BW_BYPASS=… node tools/web/connector_flow.mjs --url=<a preview>/app --out=…
//
// The private per-browser address, which everyone who added one keeps
// using. In a real browser: open Private address, switch it on, press
// Copy, and read the address off the clipboard — the way a person gets it. Then, from here, ask
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
import { launch, openColumnFor } from "./browser.mjs";
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
// A browser stops giving a tab out of view its frames, and that is what
// stopped the app. A browser driven from here never hides a page — it is
// launched never to — so the page is given a gate on its frames, before
// anything else runs, that the steps below close and open as a hidden tab's
// browser would. Faked with document.hidden alone this passed while the
// real thing failed, because the frames never stopped.
await context.addInitScript(() => {
  const real = window.requestAnimationFrame.bind(window);
  const held = [];
  window.brickworksTestFrames = { stopped: false, held };
  window.requestAnimationFrame = (callback) => {
    if (window.brickworksTestFrames.stopped) { held.push(callback); return 0; }
    return real(callback);
  };
});
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
    // In a laptop's window the assistant's column starts folded.
    if (tries === 6) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  // What the page was showing instead, for whoever reads the failure.
  await page.screenshot({ path: `${out}/never_showed_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed "${name}"; see ${out}/never_showed_${name}.png`);
}

// The private address, the way before Claude could sign in (2026-10-11):
// folded away under "Private address", switched on there, and copied. The
// way most people connect now is oauth_flow.mjs.
await click("connector_private");
await page.waitForTimeout(1500);
await click("claude_here");
await page.waitForTimeout(3000);
await click("connector_private_copy");
await page.waitForTimeout(1500);
const address = await page.evaluate(() => navigator.clipboard.readText());
console.log(`address from the clipboard: ${address.slice(0, 60)}…`);
await page.screenshot({ path: `${out}/1_connected.png`, timeout: 120000 }).catch(() => {});

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
await page.screenshot({ path: `${out}/2_after_calls.png`, timeout: 120000 }).catch(() => {});

// Out of view, as when the person is over in claude.ai: the page told it
// is hidden, and its frames stopped.
const seeing = (hidden) => page.evaluate((hidden) => {
  Object.defineProperty(document, "hidden", { value: hidden, configurable: true });
  Object.defineProperty(document, "visibilityState", { value: hidden ? "hidden" : "visible", configurable: true });
  const frames = window.brickworksTestFrames;
  frames.stopped = hidden;
  document.dispatchEvent(new Event("visibilitychange"));
  if (!hidden) frames.held.splice(0).forEach((f) => window.requestAnimationFrame(f));
}, hidden);
await seeing(true);
await page.waitForTimeout(3000);
const listedAsleep = await claude("tools/list", {});
check((listedAsleep.result?.tools || []).length === names.length, "out of view, Claude can still list the tools");
let t0 = Date.now();
const asleep = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 1 x 2" } });
const asleepText = (asleep.result?.content || []).map((c) => c.text || "").join(" ");
check(asleepText.includes("3004") && !asleep.result?.isError,
  `out of view, a call is answered by the tab, in ${Math.round((Date.now() - t0) / 1000)}s: ${asleepText.slice(0, 60)}`);
// And a real build out of view, not only a search: the app has to run
// frames to place bricks.
t0 = Date.now();
const built = await claude("tools/call", { name: "submit_design", arguments: { name: "out of view",
  bricks: [{ part: "3001", color: 4, x: 40, y: 0, z: 40 }, { part: "3001", color: 1, x: 40, y: 3, z: 40 }] } });
const builtText = (built.result?.content || []).map((c) => c.text || "").join(" ");
check(!built.result?.isError && !builtText.includes("out of view") && !builtText.includes("not open"),
  `out of view, a design is built, in ${Math.round((Date.now() - t0) / 1000)}s: ${builtText.slice(0, 60)}`);
// Out of view a minute and more, past the relay's patience for a silent
// tab: the page's own word that it is alive keeps it connected.
await page.waitForTimeout(70000);
const later = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 2 x 2" } });
check(((later.result?.content || [])[0]?.text || "").includes("3003"),
  "out of view for over a minute, it is still connected and answers");
await seeing(false);
await page.waitForTimeout(1500);
const back = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 1 x 2" } });
check(((back.result?.content || [])[0]?.text || "").includes("3004"), "back in view, it answers at once");
await page.screenshot({ path: `${out}/2b_back_in_view.png`, timeout: 120000 }).catch(() => {});

// A reload is a new visit: the address must not change, and the
// connector must come back on by itself.
await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForTimeout(Number(args.load || 90000));
const afterReload = await claude("tools/call", { name: "search_parts", arguments: { query: "brick 2 x 2" } });
check(((afterReload.result?.content || [])[0]?.text || "").includes("3003"),
  "after a reload the same address works, with nothing pressed");
await page.waitForTimeout(2000);
await page.screenshot({ path: `${out}/3_after_reload.png`, timeout: 120000 }).catch(() => {});
await browser.close();
console.log(failures ? `${failures} failure(s)` : "the connector works on this deployment");
process.exit(failures ? 1 : 0);
