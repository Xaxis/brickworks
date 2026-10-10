// Prove the Claude connector on a deployed site, as a person and as Claude.
//
//   node tools/web/connector_flow.mjs --url=https://brickworks.diy/app --out=shots/connector
//   BW_BYPASS=… node tools/web/connector_flow.mjs --url=<a preview>/app --out=…
//
// In a real browser: turn on Connect Claude, press Copy, and read the
// address off the clipboard — the way a person gets it. Then, from here, ask
// that address what Claude asks (initialize, tools/list, a real tool call)
// through the deployed relay, and check the tab answered and says so.
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
  for (let tries = 0; tries < 40; tries++) {
    const where = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (where) return page.mouse.click(where.x, where.y);
    await page.waitForTimeout(500);
  }
  throw new Error(`the app never showed "${name}"`);
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
await page.waitForTimeout(2000);
await page.screenshot({ path: `${out}/2_after_calls.png` });
await browser.close();
console.log(failures ? `${failures} failure(s)` : "the connector works on this deployment");
process.exit(failures ? 1 : 0);
